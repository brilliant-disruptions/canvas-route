# Launching for $0, upgrading later

Prices checked 2026-10-31. Re-check the pricing pages before launch.

## The $0 stack

| Piece | Free plan | What it covers |
|---|---|---|
| Supabase Free | 500 MB database, 1 GB file storage, 5 GB/month bandwidth, 50k monthly users, 200 live connections | A few thousand active hunters |
| Google Maps SDK (iOS/Android, **no map ID**) | Unlimited | Every map view |
| Google Routes API, Essentials (≤10 stops, no optimize) | 10,000 calls/month | ~1,500 users planning 2 days/month |
| Google Places Text Search, Pro fields | 5,000 calls/month | The search bar |
| Google Place Details (with hours) | 1,000 calls/month | Opening a search result's sheet |
| Google Geocoding | 10,000 calls/month | Host addresses, long-press and "Spot a sale" |
| Web share pages (`/r/…`, `/s/…`) | Cloudflare Pages or Firebase Hosting free tier | Host `build/web`; set `WEB_ORIGIN` |

You can't avoid two fixed costs: Apple Developer at $99 a year and Google Play at $25 once. A domain is optional (about $12 a year), because `WEB_ORIGIN` can point at a free `*.pages.dev` address.

Google needs a billing account (a card) even when you pay $0.

## The app degrades instead of billing

| When this runs out | The app does this |
|---|---|
| Routes quota, no key, or no network | It shows drive times estimated on the phone, labelled "drive times estimated" in the builder. Navigation still hands off to the phone's maps app. |
| Routes calls that repeat in a session | It answers from memory and doesn't bill again. |
| Places search quota | Search shows "Search failed". Community sales on the map still work, because they come from our database. |
| Geocoding quota | Hosts can't publish a new address. **Keep this quota generous, because hosts are your supply.** |
| Supabase storage | Photos are shrunk to about 150 KB on the phone, which fits roughly 6,000 photos in 1 GB. The CDN caches them for a year. |

## Guardrails to set on day one

1. **Quotas** (Cloud Console → APIs & Services → each API → Quotas). Cap requests per day where Google offers it.
   - Yard-sale traffic lands on Fridays and Saturdays, so set each daily cap to about **1/10 of the monthly free amount**, not 1/30:
     - Routes: 1,000/day
     - Places: 500/day
     - Geocoding: 1,000/day
   - Worst case, if every day hits the cap, is about $100 a month. Lower the caps if that's too much.
2. **Budget alert** at $10 (Billing → Budgets). Alerts only email you. Quotas are what actually stop spending.
3. **Key restrictions.** Limit the key to your bundle ID and SHA-1, and to the five APIs.
4. **Never add a cloud map ID.** It moves every map load from free to $7 per 1,000.
5. **Supabase Free pauses after 7 idle days.** That only matters before launch, so open the app weekly.
6. **Supabase Free has no backups.** Run `supabase db dump -f backup.sql` weekly until you upgrade.

## When to upgrade

None of these need an app update. Plans change in place, and quotas are numbers in a console.

| Signal | Upgrade | Cost |
|---|---|---|
| Public launch, or people rely on their saved data | Supabase Pro: daily backups, no pausing, 8 GB database, 100 GB storage, 250 GB bandwidth | $25/month |
| Supabase usage page shows database > 400 MB, storage > 800 MB or bandwidth > 4 GB | Supabase Pro | $25/month |
| "Drive times estimated" shows up on Saturday mornings | Raise the Routes daily quota | $5 per extra 1,000 |
| Search fails on busy days | Raise the Places quota | $32 per extra 1,000 |
| More than 50k monthly users, or 200 people online at once | Supabase Pro, then add compute | $25 + $15–60/month |

## Rough monthly cost by size

| Monthly users | Supabase | Google |
|---|---|---|
| 1,000 | $0 (Free) | $0 |
| 10,000 | $25 | ~$5–275, depending on how many plans exceed 10 stops or use "Shortest drive" |
| 100,000 | ~$150–250 | ~$1,700–3,200 |
