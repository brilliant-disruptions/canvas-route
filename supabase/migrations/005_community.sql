-- Community layer: pins (shared stops), photos, reports, follows, alerts, route shares.

create table public.pins (
  id            uuid primary key default gen_random_uuid(),
  mode          text not null check (mode in ('yard_sales','card_drops')),
  kind          text not null check (kind in ('yard_sale','store')),
  origin        text not null check (origin in ('host','spotted','places')),
  owner_id      uuid references public.profiles(id) on delete set null,
  place_id      text,
  name          text not null,
  address       text,
  lat           double precision not null,
  lng           double precision not null,
  opens_at      timestamptz,
  closes_at     timestamptz,
  categories    text[] not null default '{}',
  notes         text,
  listing_url   text,
  early_birds   text check (early_birds in ('welcome','not_welcome')),
  status        text not null default 'draft'
                check (status in ('draft','pending','live','ended','removed')),
  confirmations int  not null default 0,
  share_token   text unique default encode(gen_random_bytes(6), 'hex'),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (mode, place_id)
);
create trigger pins_set_updated_at before update on public.pins
  for each row execute function public.set_updated_at();
create index pins_geo_idx on public.pins using gist (ll_to_earth(lat, lng));
create index pins_mode_status_idx on public.pins (mode, status, closes_at);

alter table public.stops
  add constraint stops_pin_fk foreign key (pin_id) references public.pins(id) on delete set null;

create table public.pin_photos (
  id           uuid primary key default gen_random_uuid(),
  pin_id       uuid not null references public.pins(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  created_at   timestamptz not null default now()
);
create index pin_photos_pin_idx on public.pin_photos (pin_id);

create table public.products (
  id           uuid primary key default gen_random_uuid(),
  game         text not null check (game in ('pokemon','sports','one_piece','lorcana','mtg','other')),
  set_name     text not null,
  sku_type     text not null
               check (sku_type in ('etb','booster_box','bundle','blister','tin','collection','pack','other')),
  display_name text not null,
  release_date date,
  canonical_id uuid references public.products(id) on delete set null,
  is_canonical boolean not null default true,
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index products_display_idx on public.products (lower(display_name));

create table public.reports (
  id              uuid primary key default gen_random_uuid(),
  pin_id          uuid not null references public.pins(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  visit_id        uuid references public.visits(id) on delete set null,
  status          text not null check (status in (
                    'still_open','closing_soon','packed_up',                 -- yard sales
                    'in_stock','sold_out','restocking_now','limit_per_customer','didnt_carry' -- card drops
                  )),
  product_id      uuid references public.products(id) on delete set null,
  product_text    text,
  qty             int check (qty >= 0),
  price_cents     int check (price_cents >= 0),
  purchase_limit  int check (purchase_limit >= 0),
  line_present    boolean,
  crowd_level     text check (crowd_level in ('quiet','busy','packed')),
  photo_path      text,
  trust_at_filing int not null default 50,
  created_at      timestamptz not null default now()
);
create index reports_pin_time_idx on public.reports (pin_id, created_at desc);
create index reports_product_time_idx on public.reports (product_id, created_at desc);
create index reports_user_time_idx on public.reports (user_id, created_at desc);

create table public.follows (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.alerts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null check (kind in ('new_pin_nearby','stock_report_nearby','follow_up')),
  pin_id     uuid references public.pins(id) on delete cascade,
  report_id  uuid references public.reports(id) on delete cascade,
  title      text not null,
  body       text not null,
  sent_at    timestamptz not null default now(),
  opened_at  timestamptz
);
create index alerts_user_idx on public.alerts (user_id, sent_at desc);

create table public.route_shares (
  id         uuid primary key default gen_random_uuid(),
  route_id   uuid not null references public.routes(id) on delete cascade,
  token      text unique not null default encode(gen_random_bytes(9), 'base64url'),
  can_fork   boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.push_tokens (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('ios','android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

-- Trust: snapshot the reporter's score; bump pin confirmations on spotted pins.
create or replace function public.on_report_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.trust_at_filing := public.my_trust_score();
  return new;
end;
$$;
create trigger reports_before_insert before insert on public.reports
  for each row execute function public.on_report_insert();

create or replace function public.on_report_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- A corroborating report from a second user promotes a pending spotted pin to live.
  update public.pins p set confirmations = confirmations + 1
  where p.id = new.pin_id and p.origin = 'spotted' and p.owner_id is distinct from new.user_id;
  update public.pins p set status = 'live'
  where p.id = new.pin_id and p.status = 'pending' and p.confirmations >= 1;
  -- Small trust reward for contributing.
  update public.profiles set trust_score = least(100, trust_score + 1) where id = new.user_id;
  return null;
end;
$$;
create trigger reports_after_insert after insert on public.reports
  for each row execute function public.on_report_after_insert();

-- Rate limit: max 3 reports per user per pin per hour, 60 per user per day.
create or replace function public.report_rate_ok(p_pin uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select (select count(*) from public.reports
          where user_id = auth.uid() and pin_id = p_pin and created_at > now() - interval '1 hour') < 3
     and (select count(*) from public.reports
          where user_id = auth.uid() and created_at > now() - interval '1 day') < 60;
$$;

-- Nearby pins for the map, by mode, within radius miles of a point.
create or replace function public.nearby_pins(p_mode text, p_lat double precision, p_lng double precision, p_radius_mi double precision default 10)
returns setof public.pins language sql stable security invoker as $$
  select * from public.pins
  where mode = p_mode and status = 'live'
    and earth_box(ll_to_earth(p_lat, p_lng), p_radius_mi * 1609.34) @> ll_to_earth(lat, lng)
    and earth_distance(ll_to_earth(p_lat, p_lng), ll_to_earth(lat, lng)) <= p_radius_mi * 1609.34
  order by earth_distance(ll_to_earth(p_lat, p_lng), ll_to_earth(lat, lng));
$$;

-- Expire yard-sale pins at window close. Runs every 15 minutes.
create or replace function public.expire_pins()
returns void language sql security definer set search_path = public as $$
  update public.pins set status = 'ended'
  where kind = 'yard_sale' and status in ('live','pending') and closes_at < now();
  delete from public.pins
  where kind = 'yard_sale' and status in ('ended','removed') and closes_at < now() - interval '14 days';
$$;
select cron.schedule('expire_pins', '*/15 * * * *', $$select public.expire_pins()$$);

-- RLS
alter table public.pins enable row level security;
alter table public.pin_photos enable row level security;
alter table public.products enable row level security;
alter table public.reports enable row level security;
alter table public.follows enable row level security;
alter table public.alerts enable row level security;
alter table public.route_shares enable row level security;
alter table public.push_tokens enable row level security;

create policy "pins: read live, own, or admin" on public.pins for select
  using (status = 'live' or owner_id = auth.uid() or public.is_admin());
create policy "pins: trusted users create" on public.pins for insert
  with check (auth.uid() is not null and public.my_trust_score() >= 10
    and (owner_id = auth.uid() or owner_id is null));
create policy "pins: owner or admin update" on public.pins for update
  using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());
create policy "pins: owner or admin delete" on public.pins for delete
  using (owner_id = auth.uid() or public.is_admin());

create policy "pin_photos: read" on public.pin_photos for select using (true);
create policy "pin_photos: own insert" on public.pin_photos for insert with check (user_id = auth.uid());
create policy "pin_photos: own or admin delete" on public.pin_photos for delete
  using (user_id = auth.uid() or public.is_admin());

create policy "products: read" on public.products for select using (true);
create policy "products: users add free-text" on public.products for insert
  with check (auth.uid() is not null and created_by = auth.uid() and is_canonical = false);
create policy "products: admin manage" on public.products for update
  using (public.is_admin()) with check (public.is_admin());

create policy "reports: read" on public.reports for select using (true);
create policy "reports: trusted + rate limited" on public.reports for insert
  with check (user_id = auth.uid() and public.my_trust_score() >= 10 and public.report_rate_ok(pin_id));
create policy "reports: own or admin delete" on public.reports for delete
  using (user_id = auth.uid() or public.is_admin());

create policy "follows: own" on public.follows for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "alerts: own read" on public.alerts for select using (user_id = auth.uid());
create policy "alerts: own update" on public.alerts for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "route_shares: owner manages" on public.route_shares for all
  using (exists (select 1 from public.routes r where r.id = route_shares.route_id and r.user_id = auth.uid()))
  with check (exists (select 1 from public.routes r where r.id = route_shares.route_id and r.user_id = auth.uid()));

create policy "push_tokens: own" on public.push_tokens for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Shared route lookup by token (bypasses owner-only RLS on routes/stops, read-only).
create or replace function public.shared_route(p_token text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'route', to_jsonb(r) - 'user_id',
    'stops', (select coalesce(jsonb_agg(to_jsonb(s) order by s.stop_order), '[]'::jsonb)
              from public.stops s where s.route_id = r.id),
    'can_fork', rs.can_fork,
    'owner_handle', (select handle from public.profiles where id = r.user_id)
  )
  from public.route_shares rs join public.routes r on r.id = rs.route_id
  where rs.token = p_token;
$$;
