-- Guests (anonymous sign-ins) who never came back: delete them after 60 days so
-- they don't accumulate as monthly users or rows. Deleting the auth user cascades
-- their profile, routes, visits and trips. Anyone who linked an email or OAuth
-- identity is no longer anonymous and is never touched.
create or replace function public.purge_stale_guests()
returns int language plpgsql security definer set search_path = public, auth as $$
declare n int;
begin
  delete from auth.users u
  where u.is_anonymous
    and coalesce(u.last_sign_in_at, u.created_at) < now() - interval '60 days'
    and not exists (select 1 from public.pins p where p.owner_id = u.id and p.status in ('live','pending'));
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.purge_stale_guests() from public, anon, authenticated;

select cron.schedule('purge_stale_guests', '40 8 * * *', $$select public.purge_stale_guests()$$);
