-- Reports and pins carry user ids so the server can rate-limit and moderate. The
-- profiles_public view turned a handle into that id, so anyone could filter reports
-- by a named person and trace where they'd been. Nothing in the app needs that
-- lookup except "is this handle taken?", which becomes a yes/no function; ids stay
-- opaque. Trust shown on content comes from reports.trust_at_filing.
revoke all on public.profiles_public from anon, authenticated;

create or replace function public.handle_available(p_handle text)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (select 1 from public.profiles where lower(handle) = lower(trim(p_handle)));
$$;
revoke all on function public.handle_available(text) from public, anon;
grant execute on function public.handle_available(text) to authenticated;
