-- City garage-sale permits as yard-sale pins.
--
-- Some cities publish their garage-sale permits as public ArcGIS layers (address,
-- dates, items, sometimes hours). A nightly job pulls upcoming permits from each
-- *enabled* source and upserts them as live pins with origin 'permit'.
--
-- Every source ships disabled. Enable one only after the city has said in writing
-- that we may reuse the data, and keep its attribution:
--   update public.permit_sources set enabled = true where id = 'arlington_tx';
-- Run once by hand with `select public.import_permits();`.
--
-- Requires the `http` extension (Dashboard → Database → Extensions → http).

alter table public.pins drop constraint if exists pins_origin_check;
alter table public.pins add constraint pins_origin_check
  check (origin in ('host','spotted','places','permit'));

-- Stable id from the source ("arlington_tx:26-086959-GAR"), so nightly runs update
-- rather than duplicate. Separate from place_id, which the app sends to Google.
alter table public.pins add column if not exists external_id text;
create unique index if not exists pins_mode_external_idx on public.pins (mode, external_id);

-- Last day of a multi-day sale. opens_at/closes_at hold the current day's window,
-- and expire_pins rolls it to the next day instead of ending the sale.
alter table public.pins add column if not exists ends_on date;

create table if not exists public.permit_sources (
  id           text primary key,
  city         text not null,
  format       text not null check (format in ('arlington','mckinney')),
  layer_url    text not null,           -- ArcGIS layer, without /query
  attribution  text not null,
  enabled      boolean not null default false,
  last_run_at  timestamptz,
  last_count   int,
  last_error   text
);
alter table public.permit_sources enable row level security;
create policy "permit_sources: admin" on public.permit_sources for all
  using (public.is_admin()) with check (public.is_admin());

insert into public.permit_sources (id, city, format, layer_url, attribution) values
  ('arlington_tx', 'Arlington, TX', 'arlington',
   'https://gis2.arlingtontx.gov/agsext2/rest/services/CommunityServices/GarageSalePermit/MapServer/0',
   'Garage-sale permit data: City of Arlington, Texas'),
  ('mckinney_tx', 'McKinney, TX', 'mckinney',
   'https://maps.mckinneytexas.org/mckinney/rest/services/MapServices/GarageSales/MapServer/0',
   'Garage-sale permit data: City of McKinney, Texas')
on conflict (id) do nothing;

-- "7am", "7:30 am", "12pm" → time; anything else → null.
create or replace function public.permit_time(p text)
returns time language plpgsql immutable as $$
declare m text[]; h int;
begin
  m := regexp_match(lower(coalesce(p, '')), '^\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)\s*$');
  if m is null then return null; end if;
  h := m[1]::int % 12 + case when m[3] = 'pm' then 12 else 0 end;
  return make_time(h, coalesce(m[2], '0')::int, 0);
end;
$$;

-- Free-text item lists → the app's hunt categories. A sale with nothing specific
-- ("Miscellaneous Household Items") is a general sale: Everything.
create or replace function public.permit_categories(p text)
returns text[] language sql immutable as $$
  select coalesce(array_agg(c order by c), '{Everything}') from (
    select distinct c from (values
      ('Furniture',    '(furniture)'),
      ('Kids',         '(toy|baby|child|kid|nursery)'),
      ('Tools',        '(tool|lawn|garden|equipment|hardware)'),
      ('Collectibles', '(antique|collect|vinyl|record)'),
      ('Clothing',     '(cloth|wear|apparel|shoe)'),
      ('Electronics',  '(electronic|computer|tablet)'),
      ('Books',        '(book)')
    ) as k(c, pattern)
    where lower(coalesce(p, '')) ~ pattern
  ) s;
$$;

-- Upserts one source's ArcGIS features (f=json, outSR=4326). Pure: no network, so
-- it can be tested with a saved response. Returns the number of pins written.
create or replace function public.import_permit_features(p_source text, p_features jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare
  src     public.permit_sources;
  f       jsonb;
  a       jsonb;
  tz      constant text := 'America/Chicago';
  ref     text;
  addr    text;
  items   text;
  d1      date;
  d2      date;
  t1      time;
  t2      time;
  hours   boolean;
  today   date := (now() at time zone 'America/Chicago')::date;
  day     date;
  n       int := 0;
begin
  select * into src from public.permit_sources where id = p_source;
  if src is null then raise exception 'unknown permit source %', p_source; end if;

  for f in select * from jsonb_array_elements(coalesce(p_features, '[]')) loop
    a := f->'attributes';
    if f->'geometry'->>'x' is null or f->'geometry'->>'y' is null then continue; end if;

    if src.format = 'arlington' then
      if coalesce(a->>'STATUSDESC', '') not in ('Active', 'Pending') then continue; end if;
      ref   := a->>'PermitNumber';
      addr  := initcap(a->>'FOLDERNAME') || ', Arlington, TX';
      items := a->>'SaleItems';
      d1    := to_date(a->>'StrStartDate', 'MM/DD/YYYY');
      d2    := to_date(a->>'StrEndDate', 'MM/DD/YYYY');
      t1    := null;
      t2    := null;
    else -- mckinney
      if coalesce(a->>'permit_status', '') <> 'Issued' then continue; end if;
      ref   := a->>'permit_number';
      addr  := initcap(a->>'main_address') || ', McKinney, TX';
      -- Category columns hold "No … for Sale" when empty.
      select string_agg(v, ', ') into items
      from (select a->>k as v from unnest(array['Clothing','Electronics','Equipment','Household',
                                               'Kitchen','Misc','MusicFilm','Other']) k) s
      where v is not null and v !~* '^no ';
      -- Dates are midnight local stored as epoch ms; the end date is sometimes a day early.
      d1    := (to_timestamp((a->>'SaleStartDate')::bigint / 1000) at time zone tz)::date;
      d2    := (to_timestamp((a->>'SaleEndDate')::bigint / 1000) at time zone tz)::date;
      t1    := public.permit_time(a->>'SaleStartTime');
      t2    := public.permit_time(a->>'SaleEndTime');
    end if;

    if ref is null or d1 is null then continue; end if;
    d2 := greatest(d1, coalesce(d2, d1));
    if d2 < today then continue; end if;
    hours := t1 is not null and t2 is not null and t2 > t1;
    day := greatest(d1, today); -- the window shown is the next sale day

    insert into public.pins as p (mode, kind, origin, external_id, name, address, lat, lng,
                                  opens_at, closes_at, ends_on, categories, notes, status)
    values (
      'yard_sales', 'yard_sale', 'permit', src.id || ':' || ref,
      'Garage sale', addr,
      (f->'geometry'->>'y')::double precision, (f->'geometry'->>'x')::double precision,
      (day + case when hours then t1 else time '07:00' end) at time zone tz,
      (day + case when hours then t2 else time '14:00' end) at time zone tz,
      case when d2 > day then d2 end,
      public.permit_categories(items),
      concat_ws(E'\n',
        nullif(items, ''),
        case when d2 > d1 then 'Runs ' || to_char(d1, 'Dy') || ' to ' || to_char(d2, 'Dy') || ', same hours each day.' end,
        case when not hours then 'Hours not posted; most sales run about 7 AM to 2 PM.' end,
        src.attribution),
      'live'
    )
    on conflict (mode, external_id) do update set
      address = excluded.address, lat = excluded.lat, lng = excluded.lng,
      opens_at = excluded.opens_at, closes_at = excluded.closes_at, ends_on = excluded.ends_on,
      categories = excluded.categories, notes = excluded.notes,
      status = case when p.status = 'ended' and excluded.closes_at > now() then 'live' else p.status end
    -- An admin removal sticks; the next run doesn't bring the sale back.
    where p.status <> 'removed';
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function public.import_permit_features(text, jsonb) from public, anon, authenticated;

-- Fetches every enabled source and imports sales ending today or later.
create or replace function public.import_permits()
returns void language plpgsql security definer set search_path = public, extensions as $$
declare
  src   public.permit_sources;
  since text := to_char((now() at time zone 'America/Chicago')::date, 'YYYY-MM-DD');
  q     text;
  res   record;
  body  jsonb;
begin
  for src in select * from public.permit_sources where enabled loop
    begin
      q := case src.format
        when 'arlington' then format('EndDate >= DATE ''%s''', since)
        else format('SaleEndDate >= DATE ''%s'' OR SaleStartDate >= DATE ''%s''', since, since)
      end;
      select * into res from extensions.http_get(
        src.layer_url || '/query?f=json&outSR=4326&returnGeometry=true&outFields=*&resultRecordCount=2000&where='
          || replace(replace(replace(replace(q, ' ', '%20'), '''', '%27'), '>', '%3E'), '=', '%3D'));
      if res.status <> 200 then raise exception 'HTTP %', res.status; end if;
      body := res.content::jsonb;
      if body ? 'error' then raise exception '%', body->'error'->>'message'; end if;
      update public.permit_sources set last_run_at = now(), last_error = null,
        last_count = public.import_permit_features(src.id, body->'features')
      where id = src.id;
    exception when others then
      update public.permit_sources set last_run_at = now(), last_error = sqlerrm where id = src.id;
    end;
  end loop;
end;
$$;
revoke all on function public.import_permits() from public, anon, authenticated;

-- Multi-day sales roll to their next day at close instead of ending. Day math is in
-- Central time so DST weekends keep the posted hours; store a zone per pin before
-- adding sales outside Central time.
create or replace function public.expire_pins()
returns void language sql security definer set search_path = public as $$
  update public.pins set
    opens_at  = ((opens_at  at time zone 'America/Chicago') + interval '1 day') at time zone 'America/Chicago',
    closes_at = ((closes_at at time zone 'America/Chicago') + interval '1 day') at time zone 'America/Chicago',
    ends_on   = case when (closes_at at time zone 'America/Chicago')::date + 1 < ends_on then ends_on end
  where kind = 'yard_sale' and status in ('live','pending') and closes_at < now()
    and ends_on > (closes_at at time zone 'America/Chicago')::date;
  update public.pins set status = 'ended'
  where kind = 'yard_sale' and status in ('live','pending') and closes_at < now();
  delete from public.pins
  where kind = 'yard_sale' and status in ('ended','removed') and closes_at < now() - interval '14 days';
$$;

-- 4:20 AM Central, before Saturday-morning planning.
select cron.schedule('import_permits', '20 9 * * *', $$select public.import_permits()$$);
