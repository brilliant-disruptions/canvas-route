-- Regression tests for the pre-launch security audit. Run after apply_all.sh:
--   psql -d canvasroute_migration_check -v ON_ERROR_STOP=1 -f supabase/tests/security_test.sql
-- Each block raises (and stops the run) if a hole reopens.
\set QUIET on
\o /dev/null
set client_min_messages = warning;

-- Users: A and B are signed in, G is a guest. A trigger creates their profiles.
insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-00000000000a', 'a@acme.test', false),
  ('00000000-0000-0000-0000-00000000000b', 'b@other.test', false),
  ('00000000-0000-0000-0000-00000000000c', 'c@third.test', false),
  ('00000000-0000-0000-0000-0000000000a9', null, true);

create function pg_temp.act(uid text, guest boolean default false) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', uid, false);
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'is_anonymous', guest)::text, false);
end $$;
create function pg_temp.fails(sql text) returns boolean language plpgsql as $$
begin
  execute sql;
  return false;
exception when others then
  return true;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── pins ──
select pg_temp.act('00000000-0000-0000-0000-0000000000a9', true);
set role authenticated;
do $$ begin
  if not pg_temp.fails($q$insert into pins (mode, kind, origin, name, lat, lng) values ('yard_sales','yard_sale','host','x',1,1)$q$)
  then raise exception 'FAIL: a guest posted a pin'; end if;
end $$;
reset role;

select pg_temp.act('00000000-0000-0000-0000-00000000000a');
set role authenticated;
do $$
declare p pins;
begin
  insert into pins (mode, kind, origin, owner_id, name, lat, lng, status, confirmations)
  values ('yard_sales','yard_sale','spotted','00000000-0000-0000-0000-00000000000b','Spotted',1,1,'live',99)
  returning * into p;
  if p.status <> 'pending' or p.confirmations <> 0 or p.owner_id <> auth.uid() then
    raise exception 'FAIL: spotted pin kept client status/confirmations/owner: % % %', p.status, p.confirmations, p.owner_id;
  end if;
  update pins set status = 'live' where id = p.id;
  if (select status from pins where id = p.id) <> 'pending' then raise exception 'FAIL: owner approved own pin'; end if;
  update pins set status = 'ended' where id = p.id;
  if (select status from pins where id = p.id) <> 'ended' then raise exception 'FAIL: owner could not end own sale'; end if;

  if not pg_temp.fails($q$insert into pins (mode, kind, origin, name, lat, lng) values ('yard_sales','yard_sale','permit','x',1,1)$q$)
  then raise exception 'FAIL: client posted a permit pin'; end if;

  insert into pins (mode, kind, origin, owner_id, place_id, name, lat, lng)
  values ('card_drops','store','places', auth.uid(), 'pl_target_1', 'Target', 1, 1) returning * into p;
  if p.owner_id is not null then raise exception 'FAIL: store pin has an owner'; end if;
  delete from pins where id = p.id;
  if not exists (select 1 from pins where id = p.id) then raise exception 'FAIL: user deleted a shared store pin'; end if;
end $$;
reset role;

-- B can't attach photos to A's pin (B may not even see it, so pass its id in).
select set_config('test.apin', id::text, false) from pins where origin = 'spotted' limit 1;
select pg_temp.act('00000000-0000-0000-0000-00000000000b');
set role authenticated;
do $$ begin
  if not pg_temp.fails($q$insert into pin_photos (pin_id, user_id, storage_path)
     values (current_setting('test.apin')::uuid, auth.uid(), 'b/x.jpg')$q$)
  then raise exception 'FAIL: photo attached to someone else''s pin'; end if;
end $$;
reset role;

-- ── reports: append-only, trust only from corroboration ──
update pins set status = 'pending' where origin = 'spotted';
select pg_temp.act('00000000-0000-0000-0000-00000000000b');
set role authenticated;
do $$
declare pid uuid := current_setting('test.apin')::uuid;
declare rid uuid;
declare t0 int := public.my_trust_score();
begin
  insert into reports (pin_id, user_id, status) values (pid, auth.uid(), 'still_open') returning id into rid;
  insert into reports (pin_id, user_id, status) values (pid, auth.uid(), 'still_open');
  delete from reports where id = rid;
  if not exists (select 1 from reports where id = rid) then raise exception 'FAIL: user deleted a report'; end if;
  if public.my_trust_score() <> t0 + 1 then raise exception 'FAIL: trust moved by % for one corroboration', public.my_trust_score() - t0; end if;
end $$;
reset role;
do $$ begin
  if (select status from pins where origin = 'spotted' limit 1) <> 'live' then raise exception 'FAIL: corroboration did not publish the pin'; end if;
  if (select confirmations from pins where origin = 'spotted' limit 1) <> 1 then raise exception 'FAIL: repeat reports inflated confirmations'; end if;
end $$;

-- ── feature requests ──
update profiles set plan = 'pro' where id = '00000000-0000-0000-0000-00000000000b';
select pg_temp.act('00000000-0000-0000-0000-00000000000b');
set role authenticated;
insert into feature_requests (user_id, title, category, status, upvote_count, interview_opt_in, interview_email)
values (auth.uid(), 'Dark map', 'map', 'done', 99999, true, 'b-private@other.test');
reset role;
do $$
declare r feature_requests := (select f from feature_requests f where title = 'Dark map');
begin
  if r.status <> 'queued' or r.upvote_count <> 0 then raise exception 'FAIL: client set status/votes: % %', r.status, r.upvote_count; end if;
  if r.interview_email is not null then raise exception 'FAIL: email stored on the public row'; end if;
  if (select email from feature_request_contacts where request_id = r.id) <> 'b-private@other.test' then
    raise exception 'FAIL: interview email lost'; end if;
end $$;
update feature_requests set status = 'backlog' where title = 'Dark map';
select pg_temp.act('00000000-0000-0000-0000-00000000000a');
set role authenticated;
do $$ begin
  if exists (select 1 from feature_request_contacts) then raise exception 'FAIL: another user read interview emails'; end if;
  if exists (select 1 from feature_requests where interview_email is not null) then raise exception 'FAIL: emails visible on the board'; end if;
end $$;
reset role;

-- ── visits and trips only on your own routes ──
select pg_temp.act('00000000-0000-0000-0000-00000000000b');
set role authenticated;
insert into routes (id, user_id, mode, name) values ('10000000-0000-0000-0000-00000000000b', auth.uid(), 'field_sales', 'B');
insert into stops (id, route_id, name, address, lat, lng, stop_order, source)
values ('20000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-00000000000b', 'Shop', 'a', 1, 1, 0, 'places');
insert into route_shares (route_id) values ('10000000-0000-0000-0000-00000000000b');
reset role;
do $$ begin
  if (select length(token) from route_shares limit 1) <> 12 then raise exception 'FAIL: share token not generated'; end if;
end $$;
select pg_temp.act('00000000-0000-0000-0000-00000000000a');
set role authenticated;
do $$ begin
  if not pg_temp.fails($q$insert into visits (stop_id, route_id, user_id, outcome)
     values ('20000000-0000-0000-0000-00000000000b','10000000-0000-0000-0000-00000000000b', auth.uid(), 'x')$q$)
  then raise exception 'FAIL: visit squatted on another user''s stop'; end if;
  if not pg_temp.fails($q$insert into trips (user_id, route_id, mode, route_name, day, distance_m, stops_visited)
     values (auth.uid(), '10000000-0000-0000-0000-00000000000b', 'field_sales', 'x', current_date, 1, 2)$q$)
  then raise exception 'FAIL: trip squatted on another user''s route'; end if;
end $$;
reset role;

-- ── teams ──
update profiles set plan = 'team', team_seats = 2 where id = '00000000-0000-0000-0000-00000000000a';
select pg_temp.act('00000000-0000-0000-0000-00000000000a');
set role authenticated;
select create_team('Acme reps');
reset role;
do $$ begin
  if (select length(join_code) from teams limit 1) <> 10 then raise exception 'FAIL: short join code'; end if;
end $$;
-- Non-members can't read teams, so hand the code to the tests the way a manager would.
select set_config('test.code', join_code, false) from teams limit 1;
select pg_temp.act('00000000-0000-0000-0000-0000000000a9', true);
set role authenticated;
do $$ begin
  if not pg_temp.fails(format('select join_team(%L)', current_setting('test.code')))
  then raise exception 'FAIL: a guest joined a team'; end if;
end $$;
reset role;
-- C guesses 10 times, then even the right code is refused for an hour.
select pg_temp.act('00000000-0000-0000-0000-00000000000c');
set role authenticated;
do $$ begin
  for i in 1..10 loop
    if (select join_team('WRONGCODE' || i)) is not null then raise exception 'FAIL: wrong code joined'; end if;
  end loop;
  if not pg_temp.fails(format('select join_team(%L)', current_setting('test.code')))
  then raise exception 'FAIL: guessing is not throttled'; end if;
end $$;
reset role;
delete from team_join_attempts;
-- Seats: owner + B fill 2 seats; C is turned away.
select pg_temp.act('00000000-0000-0000-0000-00000000000b');
set role authenticated;
select join_team(lower(current_setting('test.code')));
reset role;
select pg_temp.act('00000000-0000-0000-0000-00000000000c');
set role authenticated;
do $$ begin
  if not pg_temp.fails(format('select join_team(%L)', current_setting('test.code')))
  then raise exception 'FAIL: joined past the paid seats'; end if;
end $$;
reset role;
-- Owner cancels: the manager view goes dark.
update profiles set plan = 'free' where id = '00000000-0000-0000-0000-00000000000a';
select pg_temp.act('00000000-0000-0000-0000-00000000000a');
set role authenticated;
do $$ begin
  if exists (select 1 from team_activity(7)) then raise exception 'FAIL: team view works after cancelling'; end if;
end $$;
reset role;

-- ── privileges ──
set role anon;
do $$ begin
  if not pg_temp.fails('select public.expire_pins()') then raise exception 'FAIL: anon ran expire_pins'; end if;
  if not pg_temp.fails('select public.refresh_restock_patterns()') then raise exception 'FAIL: anon ran refresh_restock_patterns'; end if;
  if not pg_temp.fails('select public.purge_stale_guests()') then raise exception 'FAIL: anon ran purge_stale_guests'; end if;
end $$;
reset role;

-- ── handles don't resolve to user ids ──
update profiles set handle = 'bee' where id = '00000000-0000-0000-0000-00000000000b';
select pg_temp.act('00000000-0000-0000-0000-00000000000a');
set role authenticated;
do $$ begin
  if not pg_temp.fails('select id from profiles_public where handle = ''bee''') then
    raise exception 'FAIL: a handle resolved to a user id'; end if;
  if handle_available('BEE') or not handle_available('free_one') then raise exception 'FAIL: handle_available is wrong'; end if;
end $$;
reset role;

-- ── demand: coarse cells, aggregate counts, admin-only map ──
select pg_temp.act('00000000-0000-0000-0000-00000000000a');
set role authenticated;
do $$ begin
  if register_hunt_interest('yard_sales', 36.1539, -95.9928) <> 1 then raise exception 'FAIL: first hunter not counted'; end if;
  if register_hunt_interest('yard_sales', 36.1540, -95.9930) <> 1 then raise exception 'FAIL: same hunter counted twice'; end if;
  if not my_hunt_interest('yard_sales', 36.15, -95.99) then raise exception 'FAIL: own interest not found'; end if;
  if exists (select 1 from demand_by_cell('yard_sales')) then raise exception 'FAIL: non-admin read the demand map'; end if;
  if exists (select 1 from hunt_interest) then raise exception 'FAIL: raw interest rows readable'; end if;
end $$;
reset role;
select pg_temp.act('00000000-0000-0000-0000-00000000000b');
set role authenticated;
do $$ begin
  -- A neighbouring cell (about 7 miles away) still counts toward the same area.
  if register_hunt_interest('yard_sales', 36.24, -95.99) <> 2 then raise exception 'FAIL: neighbour cell not aggregated'; end if;
  if hunters_waiting('yard_sales', 37.5, -95.99) <> 0 then raise exception 'FAIL: far-away area counted'; end if;
end $$;
reset role;
do $$ begin
  if exists (select 1 from hunt_interest where cell_lat <> round(cell_lat, 1)) then raise exception 'FAIL: precise location stored'; end if;
end $$;
set role anon;
do $$ begin
  if not pg_temp.fails('select hunters_waiting(''yard_sales'', 36.15, -95.99)') then raise exception 'FAIL: anon read demand'; end if;
end $$;
reset role;

\echo 'security tests passed'
