-- Mileage log: one trip per route run, written when the run's summary opens.
-- Distance is the drive between visited stops in visit order (home to the first
-- stop is commuting under IRS rules, so it's left out). Trips outlive their route.

create table if not exists public.trips (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  route_id      uuid unique references public.routes(id) on delete set null,
  mode          text not null,
  route_name    text not null,
  day           date not null,
  distance_m    int  not null check (distance_m >= 0),
  stops_visited int  not null check (stops_visited >= 0),
  estimated     boolean not null default false,   -- on-device estimate, not Google's
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create trigger trips_set_updated_at before update on public.trips
  for each row execute function public.set_updated_at();
create index if not exists trips_user_day_idx on public.trips (user_id, mode, day desc);

alter table public.trips enable row level security;
create policy "trips: own" on public.trips for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
