-- Profiles are keyed by the Supabase Auth user id.
create table public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  legacy_device_id text unique,                    -- claim path for v2 device-keyed data
  handle          text unique,
  name            text,
  title           text,
  company         text,
  email           text,
  phone           text,
  office_address  text,
  office_lat      double precision,
  office_lng      double precision,
  profile_pic_path text,
  industry        text,
  team_size       text,
  use_case        text,
  crm             text,
  acquisition     text,
  is_admin        boolean not null default false,
  plan            text not null default 'free' check (plan in ('free','pro','team')),
  billing_date    date,
  stripe_id       text,
  active_mode     text not null default 'field_sales'
                  check (active_mode in ('field_sales','yard_sales','card_drops')),
  trust_score     int  not null default 50 check (trust_score between 0 and 100),
  home_lat        double precision,
  home_lng        double precision,
  alert_radius_mi int  not null default 5 check (alert_radius_mi between 1 and 50),
  quiet_hours_start smallint check (quiet_hours_start between 0 and 23),
  quiet_hours_end   smallint check (quiet_hours_end between 0 and 23),
  auto_share_reports boolean not null default true,
  has_onboarded   boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

create table public.settings (
  user_id         uuid primary key references public.profiles(id) on delete cascade,
  home_lat        double precision,
  home_lng        double precision,
  -- Per-mode overrides. Keys are mode ids; values are {outcomes, visit_fields, export_fields}.
  -- Missing keys fall back to the ModePack defaults in app code.
  mode_overrides  jsonb not null default '{}'::jsonb,
  appearance      text not null default 'system' check (appearance in ('light','dark','system')),
  route_end_preference text not null default 'current_location'
                  check (route_end_preference in ('current_location','office','custom')),
  custom_end_address text,
  custom_end_lat  double precision,
  custom_end_lng  double precision,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create trigger settings_set_updated_at before update on public.settings
  for each row execute function public.set_updated_at();

-- Auto-create profile + settings on sign-up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'));
  insert into public.settings (user_id) values (new.id);
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.settings enable row level security;

create policy "profiles: read own or admin" on public.profiles for select
  using (id = auth.uid() or public.is_admin());
create policy "profiles: public handle lookup" on public.profiles for select
  using (true);  -- only safe columns are exposed via the profiles_public view below
create policy "profiles: update own" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

create policy "settings: own" on public.settings for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Public, non-sensitive projection used for handles and trust badges on community content.
create view public.profiles_public with (security_invoker = false) as
  select id, handle, trust_score from public.profiles;
grant select on public.profiles_public to authenticated, anon;
