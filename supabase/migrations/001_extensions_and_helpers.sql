-- CanvasRoute v3 — extensions and shared helpers
create extension if not exists "pgcrypto";
create extension if not exists "cube";
create extension if not exists "earthdistance";
create extension if not exists "pg_cron";

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Is the calling user an admin? Used by RLS policies.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- Trust score of the calling user (default 0 when anonymous).
create or replace function public.my_trust_score()
returns int language sql stable security definer set search_path = public as $$
  select coalesce((select trust_score from public.profiles where id = auth.uid()), 0);
$$;
