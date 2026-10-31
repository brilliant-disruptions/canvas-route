-- Per-store restock pattern: trusted in-stock/restocking reports bucketed by local day-of-week × hour.
-- Timezone: store-local is unknown server-side; we bucket in America/Chicago by default and let the
-- app re-bucket if a pin carries a tz. Good enough for v3 (US-only launch).
create materialized view public.restock_patterns as
select r.pin_id,
       extract(dow  from r.created_at at time zone 'America/Chicago')::int as dow,
       extract(hour from r.created_at at time zone 'America/Chicago')::int as hour,
       count(*) filter (where r.status in ('in_stock','restocking_now'))::int as hits,
       count(*)::int as reports,
       max(r.created_at) as last_seen
from public.reports r
join public.pins p on p.id = r.pin_id
where p.kind = 'store'
  and r.created_at > now() - interval '90 days'
  and r.trust_at_filing >= 30
group by r.pin_id, dow, hour;
create unique index restock_patterns_pk on public.restock_patterns (pin_id, dow, hour);
grant select on public.restock_patterns to authenticated, anon;

create or replace function public.refresh_restock_patterns()
returns void language sql security definer set search_path = public as $$
  refresh materialized view concurrently public.restock_patterns;
$$;
select cron.schedule('refresh_restock_patterns', '*/15 * * * *', $$select public.refresh_restock_patterns()$$);

-- Store summary used by the store sheet and the builder's restock-window optimizer.
create or replace function public.store_summary(p_pin uuid)
returns jsonb language sql stable security invoker as $$
  with hist as (
    select dow, hour, sum(hits) as hits, sum(reports) as reports, max(last_seen) as last_seen
    from public.restock_patterns where pin_id = p_pin group by dow, hour
  ),
  totals as (select coalesce(sum(hits),0) as hits, coalesce(sum(reports),0) as reports, max(last_seen) as last_seen from hist),
  best as (select dow, hour, hits from hist where hits > 0 order by hits desc, last_seen desc limit 3)
  select jsonb_build_object(
    'total_hits', (select hits from totals),
    'total_reports', (select reports from totals),
    'last_seen', (select last_seen from totals),
    'tier', case when (select hits from totals) >= 10 then 'established'
                 when (select hits from totals) >= 3 then 'emerging'
                 else 'unknown' end,
    'best_windows', (select coalesce(jsonb_agg(jsonb_build_object('dow', dow, 'hour', hour, 'hits', hits)), '[]'::jsonb) from best),
    'recent', (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from (
                 select r.status, r.qty, r.price_cents, r.purchase_limit, r.line_present, r.created_at,
                        coalesce(pr.display_name, r.product_text) as product
                 from public.reports r left join public.products pr on pr.id = r.product_id
                 where r.pin_id = p_pin order by r.created_at desc limit 5) x)
  );
$$;
