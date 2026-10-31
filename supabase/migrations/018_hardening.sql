-- Hardening from the pre-launch security audit. Each section names the hole it closes.

-- ── 1. Pins: the server decides ownership, moderation state and counters ─────────
-- Before: any guest could insert pins as already 'live', with any confirmations,
-- origin 'permit', or no owner, and could squat a store's place_id so that deleting
-- their pin cascaded everyone's reports away.
--
-- SECURITY INVOKER on purpose: current_user is then the caller's role, so trusted
-- paths (admins, the service role, definer functions such as report triggers and
-- the permit import) pass through untouched.
create or replace function public.guard_pin_write()
returns trigger language plpgsql security invoker set search_path = public as $$
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.origin not in ('host', 'spotted', 'places') then
      raise exception 'pins: origin % is not allowed', new.origin;
    end if;
    if new.origin = 'places' and (new.place_id is null or new.kind <> 'store') then
      raise exception 'pins: store pins need a place id';
    end if;
    if new.origin = 'host' and new.kind <> 'yard_sale' then
      raise exception 'pins: only yard sales are hosted';
    end if;
    -- Store pins belong to no one, so no user can delete them (and their reports).
    new.owner_id      := case when new.origin = 'places' then null else auth.uid() end;
    -- Spotted pins wait for a second report or an admin; hosts and stores go live.
    new.status        := case when new.origin = 'spotted' then 'pending' else 'live' end;
    new.confirmations := 0;
    new.external_id   := null;
    new.ends_on       := null;
    return new;
  end if;

  -- UPDATE by the owner: details may change, identity and moderation may not.
  new.id            := old.id;
  new.mode          := old.mode;
  new.kind          := old.kind;
  new.origin        := old.origin;
  new.owner_id      := old.owner_id;
  new.place_id      := old.place_id;
  new.external_id   := old.external_id;
  new.confirmations := old.confirmations;
  new.share_token   := old.share_token;
  new.ends_on       := old.ends_on;
  new.created_at    := old.created_at;
  -- Owners can end or withdraw their own sale, never approve it.
  if new.status is distinct from old.status and new.status not in ('ended', 'removed') then
    new.status := old.status;
  end if;
  return new;
end;
$$;
drop trigger if exists pins_guard on public.pins;
create trigger pins_guard before insert or update on public.pins
  for each row execute function public.guard_pin_write();

-- Guests can browse; posting needs a real (non-anonymous) account.
drop policy if exists "pins: trusted users create" on public.pins;
create policy "pins: signed-in, trusted users create" on public.pins for insert
  with check (auth.uid() is not null
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and public.my_trust_score() >= 10);

-- Photos attach only to your own pin.
drop policy if exists "pin_photos: own insert" on public.pin_photos;
create policy "pin_photos: own pin" on public.pin_photos for insert
  with check (user_id = auth.uid()
    and exists (select 1 from public.pins p where p.id = pin_id and p.owner_id = auth.uid()));

-- ── 2. Reports: append-only, trust comes from corroboration ──────────────────────
-- Before: deleting your own reports reset the rate limit, and every insert added
-- trust, so a loop took trust from 50 to 100 in a second.
drop policy if exists "reports: own or admin delete" on public.reports;
create policy "reports: admin delete" on public.reports for delete using (public.is_admin());

drop policy if exists "reports: trusted + rate limited" on public.reports;
create policy "reports: signed-in, trusted, rate limited" on public.reports for insert
  with check (user_id = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and public.my_trust_score() >= 10
    and public.report_rate_ok(pin_id));

create or replace function public.on_report_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- A second, different person's first report on a spotted pin confirms it.
  if not exists (select 1 from public.reports r
                 where r.pin_id = new.pin_id and r.user_id = new.user_id and r.id <> new.id) then
    update public.pins p set confirmations = confirmations + 1
    where p.id = new.pin_id and p.origin = 'spotted' and p.owner_id is distinct from new.user_id;
    update public.pins p set status = 'live'
    where p.id = new.pin_id and p.status = 'pending' and p.confirmations >= 1;
    -- Corroborating someone else's spotted sale is what earns trust.
    update public.profiles set trust_score = least(100, trust_score + 1)
    where id = new.user_id
      and exists (select 1 from public.pins p where p.id = new.pin_id and p.origin = 'spotted'
                  and p.owner_id is distinct from new.user_id);
  end if;
  return null;
end;
$$;

-- ── 3. Feature requests: private emails, server-set status and counts ────────────
-- Before: interview_email was readable by anyone for published requests, and a
-- paying user could insert with status 'done' and any vote count.
create table if not exists public.feature_request_contacts (
  -- Deferred: the BEFORE INSERT trigger below writes this row before the request exists.
  request_id uuid primary key references public.feature_requests(id) on delete cascade deferrable initially deferred,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  email      text not null
);
alter table public.feature_request_contacts enable row level security;
create policy "fr contacts: own or admin read" on public.feature_request_contacts for select
  using (user_id = auth.uid() or public.is_admin());

insert into public.feature_request_contacts (request_id, user_id, email)
  select id, user_id, interview_email from public.feature_requests where interview_email is not null
on conflict (request_id) do nothing;
update public.feature_requests set interview_email = null where interview_email is not null;

create or replace function public.guard_feature_request()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and not public.is_admin() then
    new.status := 'queued';
    new.summary := null;
    new.parent_id := null;
    new.upvote_count := 0;
    new.org_count := 0;
  end if;
  -- The email moves to the private table; the public row never holds it.
  if new.interview_email is not null then
    insert into public.feature_request_contacts (request_id, user_id, email)
    values (new.id, new.user_id, new.interview_email)
    on conflict (request_id) do update set email = excluded.email;
    new.interview_email := null;
  end if;
  return new;
end;
$$;
drop trigger if exists feature_requests_guard on public.feature_requests;
-- BEFORE, so the column is blanked before the row is stored; the id default is already set.
create trigger feature_requests_guard before insert or update on public.feature_requests
  for each row execute function public.guard_feature_request();

-- Org count from verified sign-in emails, not the editable profile field or guests.
create or replace function public.recount_upvotes()
returns trigger language plpgsql security definer set search_path = public, auth as $$
declare rid uuid := coalesce(new.request_id, old.request_id);
begin
  update public.feature_requests fr set
    upvote_count = (select count(*) from public.upvotes u where u.request_id = rid),
    org_count = (select count(distinct split_part(au.email, '@', 2))
                 from public.upvotes u join auth.users au on au.id = u.user_id
                 where u.request_id = rid and au.email is not null and not au.is_anonymous)
  where fr.id = rid;
  return null;
end;
$$;

-- ── 4. Visits and trips: only on your own routes ─────────────────────────────────
-- Before: anyone could claim another user's stop (unique stop_id) or route
-- (unique route_id), blocking them from logging it.
drop policy if exists "visits: own" on public.visits;
create policy "visits: own, on own routes" on public.visits for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid()
    and exists (select 1 from public.routes r where r.id = route_id and r.user_id = auth.uid())
    and exists (select 1 from public.stops s where s.id = stop_id and s.route_id = visits.route_id));

drop policy if exists "trips: own" on public.trips;
create policy "trips: own, on own routes" on public.trips for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid()
    and (route_id is null or exists (select 1 from public.routes r where r.id = route_id and r.user_id = auth.uid())));

-- ── 5. Teams: unguessable codes, real accounts, paid seats, throttled joins ──────
-- Before: 32-bit codes with unlimited guesses from anonymous guests, and no seat
-- limit, gave away the Team tier and a competitor's door-knock outcomes.
alter table public.profiles add column if not exists team_seats int;  -- written by the billing webhook

create or replace function public.gen_join_code()
returns text language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no 0/O, 1/I
  bytes bytea := extensions.gen_random_bytes(10);
  code text := '';
begin
  for i in 0..9 loop
    code := code || substr(alphabet, (get_byte(bytes, i) % 32) + 1, 1);
  end loop;
  return code; -- 32^10 ≈ 2^50
end;
$$;
alter table public.teams alter column join_code set default public.gen_join_code();
update public.teams set join_code = public.gen_join_code();

create table if not exists public.team_join_attempts (
  user_id uuid not null references public.profiles(id) on delete cascade,
  at      timestamptz not null default now()
);
create index if not exists team_join_attempts_idx on public.team_join_attempts (user_id, at desc);
alter table public.team_join_attempts enable row level security; -- no policies: definer access only

create or replace function public.join_team(p_code text)
returns public.teams language plpgsql security definer set search_path = public as $$
declare
  t public.teams;
  seats int;
begin
  if auth.uid() is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'sign in first';
  end if;
  if public.my_team_id() is not null then raise exception 'already on a team'; end if;
  if (select count(*) from public.team_join_attempts
      where user_id = auth.uid() and at > now() - interval '1 hour') >= 10 then
    raise exception 'too many tries; wait an hour';
  end if;
  select * into t from public.teams where join_code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'));
  if t is null then
    -- Return instead of raising: an exception would roll back this attempt and
    -- the throttle would never count. The app reads null as "no team with that code".
    insert into public.team_join_attempts (user_id) values (auth.uid());
    return null;
  end if;
  select coalesce(o.team_seats, 5) into seats from public.profiles o where o.id = t.owner_id;
  if (select count(*) from public.team_members where team_id = t.id) >= seats then
    raise exception 'this team is full; ask your manager to add seats';
  end if;
  insert into public.team_members (team_id, user_id, role) values (t.id, auth.uid(), 'rep');
  return t;
end;
$$;

-- A manager can issue a new code, e.g. after a rep leaves.
create or replace function public.rotate_join_code()
returns text language plpgsql security definer set search_path = public as $$
declare code text := public.gen_join_code();
begin
  if not public.is_team_manager() then raise exception 'managers only'; end if;
  update public.teams set join_code = code where id = public.my_team_id();
  return code;
end;
$$;

create or replace function public.create_team(p_name text)
returns public.teams language plpgsql security definer set search_path = public as $$
declare t public.teams;
begin
  if auth.uid() is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'sign in first';
  end if;
  if (select plan from public.profiles where id = auth.uid()) <> 'team' then
    raise exception 'creating a team needs the Team plan';
  end if;
  if public.my_team_id() is not null then raise exception 'already on a team'; end if;
  insert into public.teams (name, owner_id) values (trim(p_name), auth.uid()) returning * into t;
  insert into public.team_members (team_id, user_id, role) values (t.id, auth.uid(), 'manager');
  return t;
end;
$$;

-- ── 6. Storage: public buckets serve files by URL without being listable ──────────
drop policy if exists "pin-photos: read" on storage.objects;
drop policy if exists "avatars: read" on storage.objects;

-- ── 7. Function privileges ───────────────────────────────────────────────────────
-- Supabase grants EXECUTE to anon and authenticated directly, so revoking from
-- PUBLIC alone isn't enough. Maintenance and trigger functions are for cron and
-- triggers only; the team functions are for signed-in users only.
revoke all on function public.expire_pins() from public, anon, authenticated;
revoke all on function public.refresh_restock_patterns() from public, anon, authenticated;
revoke all on function public.pin_interest(uuid) from anon;
revoke all on function public.gen_join_code() from public, anon, authenticated;
revoke all on function public.join_team(text), public.create_team(text), public.rotate_join_code()
  from public, anon;
grant execute on function public.join_team(text), public.create_team(text), public.rotate_join_code()
  to authenticated;

-- ── 8. Team features need a live Team plan ───────────────────────────────────────
-- Before: after the owner cancelled, managers kept the activity view and reps kept
-- teammates' outcomes. Both now require the owner to hold the Team plan.
create or replace function public.team_activity(p_days int default 7)
returns table (user_id uuid, name text, visits int, outcomes jsonb, meters bigint, last_visit_at timestamptz)
language sql stable security definer set search_path = public as $$
  with members as (
    select m.user_id, coalesce(p.name, p.handle, 'Rep') as name
    from public.team_members m join public.profiles p on p.id = m.user_id
    where public.is_team_manager() and public.my_team_covered() and m.team_id = public.my_team_id()
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

create or replace function public.team_visits_at(p_place_id text)
returns table (name text, outcome text, visited_at timestamptz)
language sql stable security definer set search_path = public as $$
  select distinct on (vi.user_id) coalesce(p.name, p.handle, 'A teammate'), vi.outcome, vi.created_at
  from public.visits vi
  join public.stops s on s.id = vi.stop_id
  join public.team_members m on m.user_id = vi.user_id
  join public.profiles p on p.id = vi.user_id
  where public.my_team_covered()
    and m.team_id = public.my_team_id()
    and vi.user_id <> auth.uid()
    and s.place_id = p_place_id
    and vi.created_at > now() - interval '90 days'
  order by vi.user_id, vi.created_at desc;
$$;
