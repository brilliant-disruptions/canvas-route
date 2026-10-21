# CanvasRoute — Spec v3: Modes Platform

> **Status:** Draft for founder review (Michael + Jimmy). Supersedes nothing yet — the v2 feature spec in
> `founders/apps/canvasroute/SPEC.md` remains the source of truth for the shipped Field Sales product.
> This document specifies how CanvasRoute grows from a single-vertical B2B tool into a
> **find → route → run → log** platform with pluggable verticals ("Modes"), starting with
> **Yard Sales** and **Card Drops** (trading-card restock runs).
>
> Written to be executed by a Claude Code agent team. Each phase in §10 is independently shippable.

---

## 1. Why expand, and why this shape

CanvasRoute today: a field rep searches businesses on a map, taps them into a draft, saves an ordered
route, runs it stop-by-stop with turn-by-turn hand-off, and logs an outcome at every door. That loop
is not sales-specific. It is the loop for **anyone who has to physically visit a list of places in a
good order and remember what happened at each one.**

Two consumer verticals share the loop almost exactly and have no good map-first app today:

| Vertical | Who | "Stops" are | "Outcome" is | What's broken today |
|---|---|---|---|---|
| **Field Sales** (shipped) | B2B reps, SMB owners | Businesses from Google Places | Contacted / Interested / … | Spreadsheets + Google Maps tabs |
| **Yard Sales** | Weekend bargain hunters, resellers, estate-sale regulars | Sales posted by hosts or spotted by users, time-boxed to a morning | Bought / Nothing / Closed early | Craigslist + Facebook + a paper list; the one dedicated app is a 2009-era ad-supported iOS app |
| **Card Drops** | Everyday collectors and parents trying to buy Pokémon / sports / TCG product at retail | Retail stores (Target, Walmart, Costco, GameStop, Walgreens, LCS) | In stock / Sold out / Limit 1 / Scalpers lined up | Restock timing is per-store folklore shared in Discords; online stock trackers do not cover the physical shelf |

The Card Drops angle is the sharpest. Every "when does Target restock" guide online ends the same way:
*it varies by store, learn your local pattern by visiting repeatedly.* A visit-logging app with a
community layer **is** that repeated visiting, pooled. Scalpers already run this intel in private
groups; CanvasRoute makes it public to the family that just wants one Elite Trainer Box at MSRP.

**Strategic framing:** Field Sales stays the revenue wedge (direct B2B payment, already built). The
consumer modes are the growth and data wedge: large audiences, viral by nature (shared routes, shared
sightings), and they generate a proprietary dataset (per-store restock patterns, yard-sale density by
neighborhood) that no one else has.

---

## 2. The core abstraction: Modes

A **Mode** is a vertical pack. It does not fork the app; it parameterizes it. Everything the shipped
app already makes per-user configurable (outcome list, visit fields, export columns) becomes a Mode
preset, plus a handful of new platform capabilities that Modes switch on or off.

### 2.1 What a Mode defines

| Dimension | Field Sales | Yard Sales | Card Drops |
|---|---|---|---|
| **Stop sources** | Places text search, manual pin | Community pins (host-posted + user-spotted), manual pin, paste-a-listing-link, Places (for estate-sale companies) | Places search filtered to retail chains, community pins (stores with intel), manual pin |
| **Stop time window** | Optional (business hours from Places) | **Required** — sale start/end (e.g. Sat 7:00–12:00) | Store hours + **restock window** (derived from community reports) |
| **Route optimization** | Shortest drive | **Time-window aware** — earliest-closing / earliest-opening first, then distance | **Restock-window aware** — order stops by when each store's shelf is most likely fresh |
| **Default outcomes** | Contacted / No Answer / Not Interested / Interested | Bought / Looked, nothing / Closed early / Couldn't find | In stock / Sold out / Limit per customer / Restock in progress / Didn't carry |
| **Default visit fields** | Contact name, phone, email, notes, follow-up, photo | Items bought, spent ($), haul photo, notes, "would return" | Product(s) seen, price, qty on shelf, purchase limit, time on shelf, photo, "line / scalpers present" |
| **Community layer** | Off (private data, competitive) | On — pins and "still going?" reports shared | On — pins, stock reports, restock pattern shared |
| **Alerts** | Follow-up reminders (v2 roadmap) | "New sale posted within N mi for this weekend" | **"Product X reported in stock N mi away M min ago"** |
| **Export** | CSV of visits (existing) | CSV of hauls (reseller bookkeeping) | CSV of sightings; personal restock calendar |
| **Copy / onboarding** | "Find businesses near you" | "Plan Saturday morning" | "Know when your store restocks" |
| **Monetization** | Per-rep subscription (existing Free / Pro / Team) | Free; Season Pass for reseller features (export, unlimited routes) | Free reporting; **Drop Alerts Pro** for push alerts + restock calendar |

### 2.2 Mode selection

- Chosen during onboarding (new Screen 0: "What are you here to do?") and switchable in Settings.
- One **active mode** per user at a time. Routes carry the mode they were created in; a route list
  only shows the active mode's routes. Switching modes is a tab-switch, not a data migration.
- Mode is a `text` enum stored on `users.active_mode` and `routes.mode`. Mode packs live in code
  (`src/modes/<mode>.ts`) as typed config objects, not in the database. Adding a fourth vertical
  (estate sales, open houses, sneaker drops, disc golf, political canvassing) is a new config file
  plus any new stop-source adapters it needs.

### 2.3 Mode pack contract (TypeScript)

```ts
// src/modes/types.ts
export interface ModePack {
  id: 'field_sales' | 'yard_sales' | 'card_drops';
  label: string;
  stopSources: StopSourceId[];              // 'places' | 'manual' | 'community' | 'listing_link'
  placesQueryPreset?: string;               // e.g. 'Target OR Walmart OR GameStop'
  requiresTimeWindow: boolean;
  optimizer: 'distance' | 'time_window' | 'restock_window';
  defaultOutcomes: string[];
  defaultVisitFields: VisitFieldDefinition[];
  community: { pins: boolean; reports: boolean; reportSchema?: ReportFieldDefinition[] };
  alerts: AlertKind[];                      // 'follow_up' | 'new_pin_nearby' | 'stock_report_nearby'
  copy: OnboardingCopy;
  billing: { freeRouteLimit: number | null; proProductId: string | null };
}
```

Hard rule: **no screen may branch on mode id directly.** Screens read the active `ModePack` and
render from its config. If a feature needs `if (mode === 'card_drops')`, the config contract is
missing a field — add the field.

---

## 3. Platform capabilities added by v3

These are new to the app and shared by every mode that enables them.

### 3.1 Real authentication (prerequisite for community modes)

The shipped app is `device_id`-keyed with RLS off. That is acceptable for private sales data on one
phone; it is **not acceptable** for a community layer where anyone can post a pin or a stock report.

- Supabase Auth: email magic link + Apple + Google sign-in.
- `device_id` → `user_id` migration path the v2 spec reserved is executed in Phase 0 (§10).
- Field Sales users are not forced to sign in to keep working; sign-in is prompted when they first
  touch a community feature or switch to a community mode. Existing local routes are claimed on
  first sign-in (`users.device_id` matched, rows re-keyed).
- RLS on every table. Community tables are world-readable, writer-restricted; private tables
  (routes, stops, visits, settings) are owner-only.

### 3.2 Community pins

A **pin** is a stop that nobody owns and anybody in the mode can see. Two origins:

- **Host-posted** (yard sales): the person running the sale posts it — address, hours, categories,
  photos, optional "early birds welcome / not welcome". Hosts get a shareable link and QR for their
  sign. This is the acquisition loop: every physical yard-sale sign can carry a QR.
- **User-spotted** (both modes): a user drops a pin on something they found — a sale with no
  listing, or a store that stocks cards. Requires a photo or a confirming second report before it
  surfaces to others (§7).

Pins have a lifecycle: `draft → live → ended → removed`. Yard-sale pins auto-end at their window
close. Store pins are persistent.

Adding a pin to a route copies it into `stops` (`source: 'community'`, `pin_id` set) so routes stay
private and stable even if the pin is later edited or removed.

### 3.3 Reports (time-stamped observations on a pin)

The crowd-sourced signal. A report is small, fast to file (two taps from the Route Runner), and
structured by the mode's `reportSchema`:

| Mode | Report fields |
|---|---|
| Yard Sales | status: `still_open` / `closing_soon` / `packed_up`; optional crowd level; optional photo |
| Card Drops | product (picker, free-text fallback), status: `in_stock` / `sold_out` / `restocking_now`; qty estimate; price; purchase limit; `line_present` bool; optional photo |

**Logging a visit auto-files a report** when the mode's community layer is on and the visit's
outcome maps to a report status (configured in the mode pack). The user sees a one-line toast
("Shared with nearby collectors") and can turn auto-share off in Settings. This is what makes the
dataset grow without asking anyone to do extra work.

### 3.4 Restock patterns (Card Drops only)

A materialized view per store pin: histogram of `in_stock` and `restocking_now` reports by
day-of-week × hour, decayed over 90 days, with a confidence tier based on report count:

- **Unknown** (< 3 reports) — "Help map this store"
- **Emerging** (3–9 reports) — "Often Tue mornings (4 reports)"
- **Established** (10+ reports, consistent) — "Restocks Tue 8–10am · 23 reports · last seen 2 days ago"

The pattern drives the `restock_window` optimizer and the "Best time to go" chip on every store
sheet. Patterns never claim certainty; copy always shows the report count.

### 3.5 Alerts

- `new_pin_nearby` — a host posts a sale within the user's alert radius for the coming weekend.
- `stock_report_nearby` — an `in_stock` / `restocking_now` report for a product the user follows,
  within radius, within the last N minutes. **Latency is the product here**: Supabase Realtime on
  `reports` → Edge Function → Expo push, target < 60 s from report to phone.
- Alert radius, followed products, and quiet hours are user settings. Alerts are the paid tier in
  Card Drops (§8) — reporting is always free so the dataset stays open.

### 3.6 Time-window-aware routing

Google Directions `optimize:true` solves distance only. For Yard Sales and Card Drops the route
builder runs a local pre-pass before calling Directions:

1. Sort stops by **hard deadline** (sale end time, or restock window end) ascending.
2. Walk the list; if stop *k*'s ETA (cumulative Directions legs) lands after its window closes,
   flag it red in the builder ("You'll arrive 20 min after this sale ends") and offer
   **Drop it** / **Move earlier** / **Keep anyway**.
3. For Card Drops, prefer stops whose restock window *starts* soonest, so the user is at the shelf
   when it's fresh rather than first by distance.

A proper VRP-with-time-windows solver is explicitly **out of scope**; the greedy pre-pass plus the
builder's red flags covers Saturday-morning scale (3–15 stops).

### 3.7 Shared routes

A route can be shared read-only via link (web view, no install) or forked by another CanvasRoute
user. Yard-sale crews plan together; parents share a Saturday card run. Also serves Field Sales
"team routes" on the v2 roadmap. Shared route pages are the SEO surface for the consumer modes
("Saturday yard sale route — Plano, TX — Oct 25").

---

## 4. Yard Sales mode

### 4.1 User stories
- As a bargain hunter, I open the app Friday night and see this weekend's sales near me on a map,
  with hours, so I can plan Saturday morning in the right order.
- As a host, I post my sale once and get a link + QR for my sign and Facebook post.
- As a reseller, I log what I bought and what I spent at each stop and export it for taxes.
- As a crew, we share one route and all see who has already hit which stop.

### 4.2 Stop sources
- **Host-posted pins** — the primary source once the network exists.
- **User-spotted pins** — drive-by sign spotting; photo of the sign required.
- **Paste a listing link** — user pastes a Craigslist / Facebook / estate-sale URL. The app stores
  the URL and lets the user type the address and hours; it **does not scrape** the listing (ToS and
  fragility). A small helper reads the clipboard on the Map screen and offers "Add the sale from
  your clipboard?".
- **Manual pin** — existing long-press behavior.
- **Places** — only for estate-sale companies and thrift stores (preset query), opt-in.

### 4.3 Screens (deltas from v2)
- **Map** gains a **weekend selector** chip row (This Sat / This Sun / Next weekend) and a time slider
  that greys out pins outside the chosen window. Pin colors by category tags (furniture, kids,
  tools, collectibles, everything).
- **Pin sheet** shows hours, categories, host notes, photos, and the live "last reported" status
  with a one-tap **Still going?** report.
- **Route Builder** shows each stop's window next to its ETA, with the red-flag logic from §3.6.
  Auto-name: `Yard sales · Sat Oct 25`.
- **Visit Logger** default fields: Outcome chips (Bought / Nothing / Closed early / Couldn't find),
  Items (multiline), Spent ($, number), Haul photo, Notes.
- **Host flow** (new, `app/host/`): Post a sale → address (autocomplete), date(s), hours, categories,
  photos, notes → publish → share sheet with link + QR PNG. Hosts can mark **Packed up** to end early.
- **Route Summary** adds total spent and item count.

### 4.4 Out of scope (v3)
Payments between buyers and hosts, item-level listings, chat, scraping any marketplace.

---

## 5. Card Drops mode

### 5.1 User stories
- As a parent, I want to know which store near me is most likely to have cards on the shelf
  Saturday morning and in what order to hit them.
- As a collector, I want a push alert the minute someone reports product in stock near me.
- As a regular, I want my own visits to build my store's restock pattern so I stop guessing.
- As a community, we want scalper-heavy stores and purchase limits visible so people don't waste a
  trip.

### 5.2 Stop sources
- **Places search with retail preset** — query preset `Target | Walmart | Costco | GameStop |
  Barnes & Noble | Walgreens | Meijer | Fred Meyer` plus "card shop" / "comic shop" for LCS. A store
  found via Places is promoted to a community pin on first report so intel attaches to it.
- **Community store pins** — stores that already have intel, shown with their pattern tier.
- **Manual pin** — for an LCS or grocery not in Places.

### 5.3 Product catalog
Reports and alerts need a shared vocabulary. Ship a seeded `products` table (set name + SKU type:
ETB, booster box, booster bundle, blister, tin, collection box) for current Pokémon TCG sets, with
free-text fallback that admins can merge into canonical products. Expand to sports cards, One Piece,
Lorcana, Magic as free-text clusters demand. Catalog maintenance is an admin-panel job, not a user
job.

**Naming note:** the app and marketing never use "Pokémon" as part of the product name. "Card Drops"
is generic; product names in the catalog are factual references. Same rule for retailer names.

### 5.4 Screens (deltas from v2)
- **Map** shows store pins with a tier badge (grey Unknown, amber Emerging, green Established) and a
  **freshness ring** — pulses for 30 min after an `in_stock` report. Product filter chip row at top
  ("151", "Prismatic", "Any").
- **Store sheet**: name, hours, **Best time to go** (from pattern), last 5 reports as a feed, the
  **Report** button (two taps: product, status; everything else optional).
- **Route Builder**: stops ordered by restock window start by default; each row shows the window
  and tier. Auto-name: `Card run · Sat Oct 25`.
- **Visit Logger** default fields: Outcome chips (In stock / Sold out / Limit per customer /
  Restocking now / Didn't carry), Products seen (multi-pick from catalog), Price, Qty on shelf,
  Purchase limit, Line present (toggle), Photo, Notes. Saving auto-files a report (§3.3).
- **Alerts** screen (new, `app/alerts/`): followed products, radius, quiet hours, alert history.
  Tapping an alert opens the store sheet with **Add to route** / **Navigate** prominent.
- **Restock calendar** (Pro): the user's saved stores on a week grid, each store's established
  window shaded. Exportable to the phone calendar.

### 5.5 The scalper question (be honest in the spec)
Scalpers can download this app too. The app cannot stop them; the claim is **leveling**, not
exclusion. Scalper groups already run private restock intel; this product makes comparable intel
public and cheap. Design choices that tilt toward everyday buyers:

- Reporting is free and auto-filed from visits, so the dataset reflects what regular shoppers see,
  not what resellers choose to share.
- `line_present` and purchase-limit fields let the community flag stores where scalping is heavy, so
  people can route elsewhere.
- Alerts carry the report's age and quantity so a "2 left, 25 min ago" alert does not send ten people
  on a wasted trip.
- No "buy / sell / trade" marketplace in the app. The app ends at the shelf.

---

## 6. Field Sales mode (what changes)

Nothing is removed. Deltas: mode selection in onboarding, sign-in prompt for shared routes, team
routes via §3.7, and follow-up reminder alerts via §3.5 (closing the v2 roadmap item). Community
pins and reports are **off** in this mode and the pack contract enforces it; a rep's prospect list
is never visible to other users.

---

## 7. Trust, abuse, and legal

- **Residential addresses.** Yard-sale pins are homes. Host-posted pins are consent by definition.
  User-spotted pins require a sign photo, surface to others only after a second independent report
  or admin approval, auto-expire at window end, and have a one-tap **Report / remove this** on the
  sheet that hides the pin pending review. Pins are never retained past 14 days after end.
- **Report integrity.** Rate limits per user (reports per store per hour), a trust score that rises
  with corroborated reports and falls with contradicted ones (report `sold_out` five minutes after
  three others saw stock), and admin tooling to ban. Low-trust reports do not trigger alerts.
- **No scraping.** Craigslist, Facebook Marketplace, retailer sites. Listing links are stored and
  opened, never fetched server-side.
- **Store relations.** Everything reported is a public observation on a retail floor. No employee
  names, no back-room photos (copy in the photo picker says so). Retailer names are factual use.
- **Minors.** Card Drops skews young. Age gate 13+ via Apple/Google account age where available;
  no DMs, no user profiles beyond a handle and trust badge.
- **Location privacy.** Reports store the store pin's location, never the reporter's GPS. Alert
  radius calculations happen server-side against the user's chosen home point.

---

## 8. Monetization

| Mode | Free | Paid |
|---|---|---|
| Field Sales | Existing Free tier | Pro / Team subscription (existing, Stripe) |
| Yard Sales | Unlimited browsing, 1 saved route per weekend, reporting, hosting a sale | **Season Pass** ($9.99/yr, RevenueCat): unlimited routes, haul export, crew sharing |
| Card Drops | Map, patterns, reporting, 1 saved route, alerts for **1** followed product at 5 mi | **Drop Alerts Pro** ($4.99/mo or $29.99/yr): unlimited followed products, radius to 50 mi, sub-minute alerts, restock calendar |

Consumer modes bill through the app stores (RevenueCat over StoreKit / Play Billing); Field Sales
keeps Stripe because it is sold to businesses and often expensed. Hosting a yard sale is always free
because hosts are the supply side.

---

## 9. Data model changes

New migrations continue the numeric sequence (`007_...` onward). Column conventions match v2.

```sql
-- 007_auth_and_modes.sql
alter table users
  add column user_id     uuid unique references auth.users(id),   -- null until first sign-in
  add column handle      text unique,
  add column active_mode text not null default 'field_sales',
  add column trust_score int  not null default 50,
  add column home_lat    double precision,
  add column home_lng    double precision,
  add column alert_radius_mi int not null default 5;

alter table routes add column mode text not null default 'field_sales';

alter table stops
  add column pin_id    uuid,                       -- references pins(id), set when source='community'
  add column opens_at  timestamptz,
  add column closes_at timestamptz;
alter table stops add constraint stops_source_check
  check (source in ('places','manual','community','listing_link'));

-- 008_community.sql
create table pins (
  id            uuid primary key default gen_random_uuid(),
  mode          text not null,                     -- 'yard_sales' | 'card_drops'
  kind          text not null,                     -- 'yard_sale' | 'store'
  origin        text not null,                     -- 'host' | 'spotted' | 'places'
  owner_id      uuid references users(id),         -- host for yard sales; null for stores
  place_id      text,                              -- Google place_id for stores
  name          text not null,
  address       text,
  lat           double precision not null,
  lng           double precision not null,
  opens_at      timestamptz,                       -- yard sales: window; stores: null
  closes_at     timestamptz,
  categories    text[] default '{}',
  notes         text,
  listing_url   text,
  status        text not null default 'draft',     -- draft | pending | live | ended | removed
  confirmations int  not null default 0,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);
create index on pins using gist (ll_to_earth(lat, lng));  -- earthdistance ext; or PostGIS geography
create index on pins (mode, status, closes_at);

create table pin_photos (
  id uuid primary key default gen_random_uuid(),
  pin_id uuid references pins(id) on delete cascade,
  user_id uuid references users(id),
  storage_path text not null,                      -- Supabase Storage; replaces local URI pattern
  created_at timestamptz default now()
);

create table products (                            -- Card Drops catalog
  id uuid primary key default gen_random_uuid(),
  game text not null,                              -- 'pokemon' | 'sports' | 'one_piece' | 'lorcana' | 'mtg'
  set_name text not null,
  sku_type text not null,                          -- 'etb' | 'booster_box' | 'bundle' | 'blister' | 'tin' | 'collection' | 'other'
  display_name text not null,
  canonical_id uuid references products(id),       -- admin merge target for free-text dupes
  is_canonical boolean not null default true,
  created_at timestamptz default now()
);

create table reports (
  id          uuid primary key default gen_random_uuid(),
  pin_id      uuid not null references pins(id) on delete cascade,
  user_id     uuid not null references users(id),
  visit_id    uuid references visits(id) on delete set null,   -- set when auto-filed from a visit
  status      text not null,                       -- mode-specific enum, validated in app + check constraint
  product_id  uuid references products(id),
  product_text text,                               -- free-text fallback
  qty         int,
  price_cents int,
  purchase_limit int,
  line_present boolean,
  crowd_level text,                                -- yard sales: 'quiet' | 'busy' | 'packed'
  photo_path  text,
  trust_at_filing int not null,                    -- snapshot of users.trust_score
  created_at  timestamptz default now()
);
create index on reports (pin_id, created_at desc);
create index on reports (product_id, created_at desc);

create table follows (                             -- products a user wants alerts for
  user_id uuid references users(id),
  product_id uuid references products(id),
  primary key (user_id, product_id)
);

create table alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  kind text not null,                              -- 'new_pin_nearby' | 'stock_report_nearby' | 'follow_up'
  pin_id uuid references pins(id),
  report_id uuid references reports(id),
  sent_at timestamptz default now(),
  opened_at timestamptz
);

create table route_shares (
  id uuid primary key default gen_random_uuid(),
  route_id uuid references routes(id) on delete cascade,
  token text unique not null,
  can_fork boolean not null default true,
  created_at timestamptz default now()
);

-- 009_restock_patterns.sql
create materialized view restock_patterns as
select pin_id,
       extract(dow  from created_at at time zone 'UTC') as dow,   -- convert to store-local tz in app
       extract(hour from created_at at time zone 'UTC') as hour,
       count(*) filter (where status in ('in_stock','restocking_now')) as hits,
       count(*) as reports,
       max(created_at) as last_seen
from reports r join pins p on p.id = r.pin_id
where p.kind = 'store' and r.created_at > now() - interval '90 days' and r.trust_at_filing >= 30
group by pin_id, dow, hour;
-- refreshed by pg_cron every 15 min
```

RLS summary: `pins`, `pin_photos`, `products`, `reports`, `restock_patterns` readable by any
authenticated user in the matching mode; insert restricted to authenticated users with
`trust_score >= 10`; update/delete restricted to owner or admin. `routes`, `stops`, `visits`,
`settings`, `follows`, `alerts` owner-only. `route_shares` readable by token via an Edge Function.

Visit photos move from local URI to Supabase Storage in Phase 0 (needed for pin photos anyway;
closes a v2 roadmap item).

---

## 10. Phasing

Each phase ships to TestFlight / internal track and is usable on its own.

| Phase | Deliverable | Exit criteria |
|---|---|---|
| **0 — Foundation** | Supabase Auth, `device_id` → `user_id` claim flow, RLS on every table, Storage for photos, `ModePack` contract with Field Sales as the only pack, mode column plumbing | Existing Field Sales users upgrade with zero data loss; all v2 screens render from the pack config, no mode branching in screens |
| **1 — Yard Sales (solo)** | Yard Sales pack: time windows on stops, weekend selector, time-window-aware builder, listing-link and manual sources, new visit fields, haul summary, host flow with link + QR | A user can plan and run a Saturday from manually entered sales; a host can post and share a sale |
| **2 — Community layer** | `pins`, `reports`, user-spotted pins with photo + confirmation, "Still going?" reports, abuse tooling in admin panel, shared routes | Two devices see each other's pins and reports within 10 s; admin can remove a pin |
| **3 — Card Drops** | Card Drops pack: retail Places preset, product catalog + admin merge, store pins, report flow, auto-file from visits, restock patterns view + tier badges + "Best time to go", restock-window optimizer | Patterns appear after 3 reports; builder orders by window; visit → report round-trip is 2 taps |
| **4 — Alerts + Pro** | Realtime → Edge Function → Expo push for `stock_report_nearby` and `new_pin_nearby`, follows, radius, quiet hours, RevenueCat paywall for Drop Alerts Pro and Season Pass, restock calendar | Report-to-push p95 < 60 s; purchase restores across reinstall |
| **5 — Growth surfaces** | Public web pages for shared routes and host-posted sales (Next.js, same Supabase), QR on yard-sale signs, "map this store" empty-state loop | Shared route link opens without install; host sale page is indexable |

Phase 1 before Phase 2 on purpose: Yard Sales is useful solo (you already know the sales you want to
hit), so it ships value before the network exists. Card Drops is network-dependent and goes after the
community layer is hardened.

---

## 11. Decisions needed from founders

1. **Brand.** One app with modes (recommended: one install, one review stream, cross-mode discovery)
   vs. separate App Store listings per vertical sharing a codebase. Affects onboarding Screen 0 and
   ASO.
2. **Stack.** This spec assumes extending the shipped Expo / React Native codebase. Michael's default
   is Flutter; a rewrite is a separate decision and is not costed here.
3. **Repo.** `michaeljwilt/canvas-route` is empty. Is it the new home for the app (move from
   `founders/apps/canvasroute`), or only for this spec?
4. **Geography for the Card Drops seed.** Patterns need density. Pick one or two metros to seed
   (the founders' own) and run the first 100 reports ourselves before promoting.
5. **Pokémon-first vs. multi-game catalog at launch.** Recommended: Pokémon TCG only in the seeded
   catalog, free-text for the rest, expand on demand.
6. **Price points** in §8 are placeholders for review.

---

## 12. Landscape notes (October 2026, lightly verified)

- **Yard sales:** Yard Sale Treasure Map (iOS, 2009, ad-supported, route optimization and sharing),
  Local Garage Sales Map Finder, gsalr.com, and Garage Sale Mapper. All are listing aggregators first;
  none have host-side posting with a QR loop or a visit/haul log.
- **Card restocks:** TrackaLacker (free app, push alerts for online stock at Target, Walmart, Best Buy,
  Pokémon Center) and Vortix TCG Monitor (Chrome extension watching retailer product pages). Both
  track **online** inventory. Physical-shelf timing lives in Discord servers and SEO blog posts that
  contradict each other (Target: Friday morning vs. Monday/Thursday; Walmart: Tue/Fri vs. Tue/Thu/Sat)
  and all end with "learn your local store's pattern through repeated visits". That gap is the
  product.

---

## 13. Non-goals (all of v3)

Marketplace or payments between users, chat or DMs, scraping any third-party listing or retailer
site, a full vehicle-routing solver, web-first consumer app (web is for shared pages only), CRM
integrations (still Field Sales roadmap, unchanged).
