-- Teams (Field Sales Team plan): a manager and their reps.
--
-- Profiles stay private (013), so everything a teammate may see goes through
-- security-definer functions scoped to the caller's own team:
--   team_roster()            names and roles of my team
--   team_activity(days)      per-rep visits, outcomes, miles (managers only)
--   team_visits_at(place)    teammates' recent outcomes at a business, so two
--                            reps don't knock the same door (outcome only, no notes)
-- One team per user. Creating a team needs the Team plan; joining needs the code.

create table if not exists public.teams (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(trim(name)) between 1 and 80),
  owner_id   uuid not null references public.profiles(id) on delete cascade,
  join_code  text not null unique default upper(encode(gen_random_bytes(4), 'hex')),
  created_at timestamptz not null default now()
);

create table if not exists public.team_members (
  team_id   uuid not null references public.teams(id) on delete cascade,
  user_id   uuid not null unique references public.profiles(id) on delete cascade,
  role      text not null default 'rep' check (role in ('manager','rep')),
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

alter table public.teams enable row level security;
alter table public.team_members enable row level security;

create or replace function public.my_team_id()
returns uuid language sql stable security definer set search_path = public as $$
  select team_id from public.team_members where user_id = auth.uid();
$$;

create or replace function public.is_team_manager()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.team_members where user_id = auth.uid() and role = 'manager');
$$;

-- Read-only from the client; writes go through the functions below.
create policy "teams: members read" on public.teams for select using (id = public.my_team_id());
create policy "team_members: members read" on public.team_members for select using (team_id = public.my_team_id());

create or replace function public.create_team(p_name text)
returns public.teams language plpgsql security definer set search_path = public as $$
declare t public.teams;
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  if (select plan from public.profiles where id = auth.uid()) <> 'team' then
    raise exception 'creating a team needs the Team plan';
  end if;
  if public.my_team_id() is not null then raise exception 'already on a team'; end if;
  insert into public.teams (name, owner_id) values (trim(p_name), auth.uid()) returning * into t;
  insert into public.team_members (team_id, user_id, role) values (t.id, auth.uid(), 'manager');
  return t;
end;
$$;

create or replace function public.join_team(p_code text)
returns public.teams language plpgsql security definer set search_path = public as $$
declare t public.teams;
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  if public.my_team_id() is not null then raise exception 'already on a team'; end if;
  select * into t from public.teams where join_code = upper(trim(p_code));
  if t is null then raise exception 'no team with that code'; end if;
  insert into public.team_members (team_id, user_id, role) values (t.id, auth.uid(), 'rep');
  return t;
end;
$$;

-- The owner can't leave (they'd orphan the team); they delete it instead.
create or replace function public.leave_team()
returns void language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.teams where id = public.my_team_id() and owner_id = auth.uid()) then
    delete from public.teams where owner_id = auth.uid();
  else
    delete from public.team_members where user_id = auth.uid();
  end if;
end;
$$;

-- Managers remove reps (not themselves).
create or replace function public.remove_teammate(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_team_manager() then raise exception 'managers only'; end if;
  delete from public.team_members
  where team_id = public.my_team_id() and user_id = p_user and user_id <> auth.uid();
end;
$$;

-- Members of a team whose owner holds the Team plan get the paid tier: the
-- manager pays per seat, reps don't buy their own.
create or replace function public.my_team_covered()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.team_members m
    join public.teams t on t.id = m.team_id
    join public.profiles o on o.id = t.owner_id
    where m.user_id = auth.uid() and o.plan = 'team'
  );
$$;

create or replace function public.team_roster()
returns table (user_id uuid, name text, role text, joined_at timestamptz)
language sql stable security definer set search_path = public as $$
  select m.user_id, coalesce(p.name, p.handle, 'Rep'), m.role, m.joined_at
  from public.team_members m join public.profiles p on p.id = m.user_id
  where m.team_id = public.my_team_id()
  order by m.role, coalesce(p.name, p.handle);
$$;

-- Per rep over the last p_days: visit count, outcome counts, miles, last visit.
create or replace function public.team_activity(p_days int default 7)
returns table (user_id uuid, name text, visits int, outcomes jsonb, meters bigint, last_visit_at timestamptz)
language sql stable security definer set search_path = public as $$
  with members as (
    select m.user_id, coalesce(p.name, p.handle, 'Rep') as name
    from public.team_members m join public.profiles p on p.id = m.user_id
    where public.is_team_manager() and m.team_id = public.my_team_id()
  ),
  v as (
    select vi.user_id, vi.outcome, vi.created_at
    from public.visits vi join members using (user_id)
    where vi.created_at > now() - make_interval(days => greatest(1, least(p_days, 366)))
  )
  select m.user_id, m.name,
    (select count(*)::int from v where v.user_id = m.user_id),
    coalesce((select jsonb_object_agg(outcome, n) from (
      select outcome, count(*) as n from v where v.user_id = m.user_id and outcome is not null group by outcome
    ) o), '{}'::jsonb),
    coalesce((select sum(distance_m) from public.trips t
              where t.user_id = m.user_id and t.day > current_date - greatest(1, least(p_days, 366))), 0),
    (select max(created_at) from v where v.user_id = m.user_id)
  from members m
  order by 3 desc, m.name;
$$;

-- Teammates' latest visit at a business in the last 90 days (outcome only).
create or replace function public.team_visits_at(p_place_id text)
returns table (name text, outcome text, visited_at timestamptz)
language sql stable security definer set search_path = public as $$
  select distinct on (vi.user_id) coalesce(p.name, p.handle, 'A teammate'), vi.outcome, vi.created_at
  from public.visits vi
  join public.stops s on s.id = vi.stop_id
  join public.team_members m on m.user_id = vi.user_id
  join public.profiles p on p.id = vi.user_id
  where m.team_id = public.my_team_id()
    and vi.user_id <> auth.uid()
    and s.place_id = p_place_id
    and vi.created_at > now() - interval '90 days'
  order by vi.user_id, vi.created_at desc;
$$;

revoke all on function public.create_team(text), public.join_team(text), public.leave_team(),
  public.remove_teammate(uuid), public.my_team_covered(), public.team_roster(), public.team_activity(int),
  public.team_visits_at(text) from public, anon;
grant execute on function public.create_team(text), public.join_team(text), public.leave_team(),
  public.remove_teammate(uuid), public.my_team_covered(), public.team_roster(), public.team_activity(int),
  public.team_visits_at(text) to authenticated;
