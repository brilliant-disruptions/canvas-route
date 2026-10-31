-- Demand before supply: hunters in an area with no sales say "I'm hunting here",
-- hosts see how many are waiting, and admins see where to launch next.
--
-- Location is stored only as a ~7-mile grid cell (lat/lng rounded to 0.1°), never
-- the point the user stood on, and counts are only ever returned in aggregate.

create table if not exists public.hunt_interest (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  mode       text not null,
  cell_lat   numeric(4,1) not null,
  cell_lng   numeric(5,1) not null,
  created_at timestamptz not null default now(),
  primary key (user_id, mode, cell_lat, cell_lng)
);
create index if not exists hunt_interest_cell_idx on public.hunt_interest (mode, cell_lat, cell_lng);
alter table public.hunt_interest enable row level security; -- no policies: definer access only

-- Registers the caller as hunting around a point; returns how many are waiting there now.
create or replace function public.register_hunt_interest(p_mode text, p_lat double precision, p_lng double precision)
returns int language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'no session'; end if;
  insert into public.hunt_interest (user_id, mode, cell_lat, cell_lng)
  values (auth.uid(), p_mode, round(p_lat::numeric, 1), round(p_lng::numeric, 1))
  on conflict do nothing;
  return public.hunters_waiting(p_mode, p_lat, p_lng);
end;
$$;

-- People hunting in the 3×3 block of cells around a point (roughly 20 miles across).
create or replace function public.hunters_waiting(p_mode text, p_lat double precision, p_lng double precision)
returns int language sql stable security definer set search_path = public as $$
  select count(distinct user_id)::int from public.hunt_interest
  where mode = p_mode
    and cell_lat between round(p_lat::numeric, 1) - 0.1 and round(p_lat::numeric, 1) + 0.1
    and cell_lng between round(p_lng::numeric, 1) - 0.1 and round(p_lng::numeric, 1) + 0.1;
$$;

-- Did the caller already raise a hand here? (So the button can say so.)
create or replace function public.my_hunt_interest(p_mode text, p_lat double precision, p_lng double precision)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.hunt_interest
    where user_id = auth.uid() and mode = p_mode
      and cell_lat = round(p_lat::numeric, 1) and cell_lng = round(p_lng::numeric, 1));
$$;

-- The closest live sale anywhere, for "Sales are live in Dallas, 240 mi away".
create or replace function public.nearest_live_pin(p_mode text, p_lat double precision, p_lng double precision)
returns table (lat double precision, lng double precision, address text, miles double precision)
language sql stable security invoker set search_path = public, extensions as $$
  select p.lat, p.lng, p.address, earth_distance(ll_to_earth(p_lat, p_lng), ll_to_earth(p.lat, p.lng)) / 1609.344
  from public.pins p
  where p.mode = p_mode and p.status = 'live' and (p.closes_at is null or p.closes_at > now())
  order by earth_distance(ll_to_earth(p_lat, p_lng), ll_to_earth(p.lat, p.lng))
  limit 1;
$$;

-- Admins: where hunters are waiting, busiest cells first, with live sales alongside.
create or replace function public.demand_by_cell(p_mode text, p_limit int default 50)
returns table (cell_lat numeric, cell_lng numeric, hunters int, live_sales int, newest timestamptz)
language sql stable security definer set search_path = public as $$
  select h.cell_lat, h.cell_lng, count(distinct h.user_id)::int,
    (select count(*)::int from public.pins p
      where p.mode = p_mode and p.status = 'live' and (p.closes_at is null or p.closes_at > now())
        and round(p.lat::numeric, 1) = h.cell_lat and round(p.lng::numeric, 1) = h.cell_lng),
    max(h.created_at)
  from public.hunt_interest h
  where public.is_admin() and h.mode = p_mode
  group by h.cell_lat, h.cell_lng
  order by 3 desc, 5 desc
  limit greatest(1, least(p_limit, 500));
$$;

revoke all on function public.register_hunt_interest(text, double precision, double precision),
  public.hunters_waiting(text, double precision, double precision),
  public.my_hunt_interest(text, double precision, double precision),
  public.nearest_live_pin(text, double precision, double precision),
  public.demand_by_cell(text, int) from public, anon;
grant execute on function public.register_hunt_interest(text, double precision, double precision),
  public.hunters_waiting(text, double precision, double precision),
  public.my_hunt_interest(text, double precision, double precision),
  public.nearest_live_pin(text, double precision, double precision),
  public.demand_by_cell(text, int) to authenticated;
