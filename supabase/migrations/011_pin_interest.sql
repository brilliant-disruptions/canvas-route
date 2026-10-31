-- How many other people have a pin in one of their routes. Stops are owner-only
-- under RLS, so this runs as definer and answers only the pin's owner (a host
-- seeing interest in their sale) or an admin; anyone else gets null.
create or replace function public.pin_interest(p_pin uuid)
returns int language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from public.pins where id = p_pin and (owner_id = auth.uid() or public.is_admin()))
    then (
      select count(distinct r.user_id)::int
      from public.stops s join public.routes r on r.id = s.route_id
      where s.pin_id = p_pin and r.user_id is distinct from auth.uid()
    )
  end;
$$;
revoke all on function public.pin_interest(uuid) from public;
grant execute on function public.pin_interest(uuid) to authenticated;
