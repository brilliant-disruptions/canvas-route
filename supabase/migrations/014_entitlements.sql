-- Paid access per vertical.

-- Paid access is per vertical: store product ids the user owns, e.g.
-- {canvasroute_season_pass}. Written by the RevenueCat / Stripe webhook with the
-- service role. The older `plan` column still covers Field Sales Pro/Team.
alter table public.profiles add column if not exists entitlements text[] not null default '{}';

-- Feature requests: any paid product counts, not just a Field Sales plan.
drop policy if exists "fr: paying users submit" on public.feature_requests;
create policy "fr: paying users submit" on public.feature_requests for insert
  with check (user_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid()
                and (p.plan in ('pro','team') or cardinality(p.entitlements) > 0)));
