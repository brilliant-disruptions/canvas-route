-- Profiles: close two holes.
--
-- 1. "profiles: public handle lookup" (002) was `using (true)`. RLS policies are OR'ed,
--    so it exposed every column of every profile (email, phone, office and home
--    location) to anyone with the anon key. Public lookups go through
--    `profiles_public` (id, handle, trust_score), which keeps working without it.
-- 2. "profiles: update own" allowed any column, so a user could set their own
--    is_admin, plan or trust_score. Users now update only their own details;
--    role, plan, trust, billing (and entitlements, 014) change only through
--    security-definer functions, the service role (store webhooks) or the dashboard.

drop policy if exists "profiles: public handle lookup" on public.profiles;

revoke update on public.profiles from anon, authenticated;
grant update (
  handle, name, title, company, email, phone,
  office_address, office_lat, office_lng, profile_pic_path,
  industry, team_size, use_case, crm, acquisition,
  active_mode, home_lat, home_lng, alert_radius_mi, quiet_hours_start, quiet_hours_end,
  auto_share_reports, has_onboarded
) on public.profiles to authenticated;
