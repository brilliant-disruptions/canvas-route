create table public.routes (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  mode          text not null default 'field_sales'
                check (mode in ('field_sales','yard_sales','card_drops')),
  name          text not null,
  stop_count    int  not null default 0,
  is_optimized  boolean not null default false,
  status        text not null default 'not_started'
                check (status in ('not_started','in_progress','complete','updated')),
  last_run_at   timestamptz,
  forked_from   uuid references public.routes(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create trigger routes_set_updated_at before update on public.routes
  for each row execute function public.set_updated_at();
create index routes_user_mode_idx on public.routes (user_id, mode, created_at desc);

create table public.stops (
  id          uuid primary key default gen_random_uuid(),
  route_id    uuid not null references public.routes(id) on delete cascade,
  place_id    text,
  pin_id      uuid,                                  -- fk added in 005 after pins exists
  source      text not null default 'places'
              check (source in ('places','manual','community','listing_link')),
  name        text not null,
  address     text,
  lat         double precision not null,
  lng         double precision not null,
  stop_order  int  not null,
  visited     boolean not null default false,
  opens_at    timestamptz,
  closes_at   timestamptz,
  listing_url text,
  created_at  timestamptz not null default now()
);
create index stops_route_order_idx on public.stops (route_id, stop_order);

create table public.visits (
  id             uuid primary key default gen_random_uuid(),
  stop_id        uuid not null references public.stops(id) on delete cascade,
  route_id       uuid not null references public.routes(id) on delete cascade,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  outcome        text,
  contact_name   text,
  phone          text,
  email          text,
  notes          text,
  follow_up_date date,
  photo_path     text,                               -- Supabase Storage path in visit-photos bucket
  custom_fields  jsonb,                              -- mode-specific fields (items, spent, products, qty...)
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (stop_id)                                   -- one visit per stop; re-log updates
);
create trigger visits_set_updated_at before update on public.visits
  for each row execute function public.set_updated_at();
create index visits_route_idx on public.visits (route_id);
create index visits_user_idx on public.visits (user_id, created_at desc);

alter table public.routes enable row level security;
alter table public.stops  enable row level security;
alter table public.visits enable row level security;

create policy "routes: own" on public.routes for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "stops: via own route" on public.stops for all
  using (exists (select 1 from public.routes r where r.id = stops.route_id and r.user_id = auth.uid()))
  with check (exists (select 1 from public.routes r where r.id = stops.route_id and r.user_id = auth.uid()));

create policy "visits: own" on public.visits for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
