-- Realtime: reports and pins stream to clients for freshness rings and alert fan-out.
alter publication supabase_realtime add table public.reports;
alter publication supabase_realtime add table public.pins;
