-- Adds day_hits to store_summary: positive reports per weekday (Sun = 0), for the
-- store sheet's restock rhythm chart. Same window and trust filter as 006.
create or replace function public.store_summary(p_pin uuid)
returns jsonb language sql stable security invoker as $$
  with hist as (
    select dow, hour, sum(hits) as hits, sum(reports) as reports, max(last_seen) as last_seen
    from public.restock_patterns where pin_id = p_pin group by dow, hour
  ),
  totals as (select coalesce(sum(hits),0) as hits, coalesce(sum(reports),0) as reports, max(last_seen) as last_seen from hist),
  best as (select dow, hour, hits from hist where hits > 0 order by hits desc, last_seen desc limit 3),
  days as (
    select d.dow, coalesce(sum(h.hits), 0)::int as hits
    from generate_series(0, 6) as d(dow) left join hist h on h.dow = d.dow
    group by d.dow order by d.dow
  )
  select jsonb_build_object(
    'total_hits', (select hits from totals),
    'total_reports', (select reports from totals),
    'last_seen', (select last_seen from totals),
    'tier', case when (select hits from totals) >= 10 then 'established'
                 when (select hits from totals) >= 3 then 'emerging'
                 else 'unknown' end,
    'best_windows', (select coalesce(jsonb_agg(jsonb_build_object('dow', dow, 'hour', hour, 'hits', hits)), '[]'::jsonb) from best),
    'day_hits', (select jsonb_agg(hits order by dow) from days),
    'recent', (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from (
                 select r.status, r.qty, r.price_cents, r.purchase_limit, r.line_present, r.created_at,
                        coalesce(pr.display_name, r.product_text) as product
                 from public.reports r left join public.products pr on pr.id = r.product_id
                 where r.pin_id = p_pin order by r.created_at desc limit 5) x)
  );
$$;
