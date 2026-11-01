# CanvasRoute

**Find → route → run → log**, for anyone who has to visit a list of places in a good order and
remember what happened at each one. One Flutter app, two modes:

| Mode | For | What's special |
|---|---|---|
| **Field Sales** | B2B reps | Places search, drive-time optimization, outcome logging, CSV export |
| **Yard Sales** | Weekend hunters, resellers, hosts | Host-posted sales with sign QR, time-window-aware routing, haul log |

Full product spec: [`SPEC.md`](SPEC.md).

**v1 ships Yard Sales only.** `LAUNCH_MODES` (a `--dart-define`, default `yard_sales`) lists the
modes a build offers, in picker order. With one mode, onboarding skips the picker and the drawer
hides mode switching; a profile saved on another mode opens on the first listed one. Build with
`LAUNCH_MODES=yard_sales,field_sales` to turn Field Sales back on.

**Card Drops** (trading-card restock runs) is parked on the `park/card-drops` branch. Its
migrations (`006`, `008`, `010`) stay on `main` so the database never needs a rollback; the app
code, demo seeds and tests for it live only on that branch.

## Stack

Flutter 3.47 · Riverpod 3 · go_router · google_maps_flutter · Supabase (Postgres, Auth, Storage,
Realtime, pg_cron) · Google Places API (New) / Routes API / Geocoding.

## Setup

### 1. Supabase

Create a project, then apply `supabase/migrations/*.sql` in order (Supabase SQL editor or
`supabase db push`). Then in **Authentication → Providers**:

- enable **Anonymous sign-ins** (every device gets a uid on first launch; RLS depends on it)
- enable **Email** (magic link) and optionally **Apple** / **Google**
- add `canvasroute://auth-callback` to **Redirect URLs**

`005`/`006` schedule pg_cron jobs for pin expiry and (parked Card Drops) restock-pattern refresh. Make yourself an admin with
`update profiles set is_admin = true where email = 'you@example.com';`.

### 2. Google Cloud

Enable **Maps SDK for iOS**, **Maps SDK for Android**, **Places API (New)**, **Routes API** and
**Geocoding API** on one key. (The legacy Places and Directions APIs can't be enabled on new
projects.) Restrict the key to the app bundle IDs / SHA-1 and to those five APIs, and set daily
quotas plus a budget alert.

Before release, work through [`docs/ship-checklist.md`](docs/ship-checklist.md).

Running it for $0 and when to pay: [`docs/launch-costs.md`](docs/launch-costs.md).

Cost notes: style the map with client-side JSON, never a cloud **map ID** (a map ID moves native
map loads from free to billed). Search requests only Pro-tier Place fields. Time-window modes keep the planned order by default
(no `optimizeWaypointOrder`), so a day of up to 10 stops bills as Routes Essentials.

### 3. Keys

```bash
cp .env.json.example .env.json   # fill in values; never commit it
```

- **Dart** reads them via `--dart-define-from-file=.env.json`.
- **Android** reads the Maps key from a Gradle property: add
  `GOOGLE_MAPS_API_KEY=AIza...` to `android/local.properties` (gitignored) or export it as an
  environment variable before building.
- **iOS** reads `GoogleMapsApiKey` from `Info.plist`, populated by `$(GOOGLE_MAPS_API_KEY)`:
  create `ios/Flutter/Secrets.xcconfig` (gitignored) containing `GOOGLE_MAPS_API_KEY=AIza...`
  and `#include "Secrets.xcconfig"` from `Debug.xcconfig` and `Release.xcconfig`.

### 4. Run

```bash
flutter pub get
flutter run --dart-define-from-file=.env.json
flutter analyze && flutter test
TZ=America/Chicago flutter test   # date logic must also pass across US DST changes
```

### 5. Billing (Field Sales, Stripe on the web)

Field Sales Pro and Team are sold through Stripe Checkout, not the app stores (business plans,
often expensed). Consumer passes will use in-app purchase.

1. In Stripe, create monthly prices for **Pro** (per rep) and **Team** (per seat).
2. Set function secrets:
   `supabase secrets set STRIPE_SECRET_KEY=sk_... STRIPE_PRICE_PRO=price_... STRIPE_PRICE_TEAM=price_... STRIPE_WEBHOOK_SECRET=whsec_... WEB_ORIGIN=https://your-domain`
3. Deploy: `supabase functions deploy create-checkout` and
   `supabase functions deploy stripe-webhook --no-verify-jwt` (Stripe has no Supabase JWT; its
   signature is checked instead).
4. In Stripe → Webhooks, point an endpoint at `…/functions/v1/stripe-webhook` for
   `customer.subscription.created`, `.updated` and `.deleted`.

The webhook writes `plan`, `entitlements`, `billing_date` and `stripe_id` with the service role.
Users can't write those columns themselves (migration 013). Test the billing rules with
`node --experimental-strip-types --test supabase/functions/_shared/billing_test.ts`.

**Where checkout appears:** `WEB_CHECKOUT` (a `--dart-define`, default `web`) lists the platforms
allowed to open Stripe Checkout. Apple allows an in-app purchase link only on the US storefront,
and Google only under its US external-offers rules, so add `ios` or `android` only for builds that
meet those terms. Where a mode's paid tier can't be bought on a platform, the app hides plans and
upgrade buttons and **unlocks** those features rather than showing a paywall that can't be paid.
In-app purchase for the consumer passes isn't built yet, so Yard Sales v1 has no paywall at all.

## Architecture

```
Screen (features/*)  ──reads──▶  Providers (state/*)  ──calls──▶  Repositories / Services (data/*)
        │                               │
        └── renders from ──▶  ModePack (modes/*)   ← outcomes, fields, sources, optimizer, copy
```

A **Mode** is a typed config object (`lib/modes/mode_pack.dart`). Screens render from the active
pack and never branch on mode id. Adding a vertical is a new pack file plus any new stop-source
adapters it needs.

Auth: anonymous session on first launch so Row Level Security works immediately; linking an email
or Apple/Google identity keeps the same uid, so guest routes carry over. Community actions
(reports, hosting, sharing) require a linked account.

## TestFlight

The demo build ships to TestFlight from GitHub Actions. One-time Apple setup and the per-build
steps are in [`docs/testflight.md`](docs/testflight.md).

## Status

Phases 0–3 of the spec are implemented in this codebase: Field Sales parity, Yard Sales mode,
and the community layer (pins, reports, trust gates, admin moderation, shared routes). Card Drops
(phase 3) is parked on `park/card-drops`. **Not yet wired:** server push (the `alerts` table
exists; an Edge Function + FCM sender is Phase 4), store billing (RevenueCat,
Phase 4; the paywall sheet explains the tier), and public web pages for shared links (Phase 5).

Share links are generated as `<webOrigin>/r/<token>` (routes) and `/s/<token>` (a host's sign QR).
Both are routed in the app, but phones only open them in the app once Android App Links and iOS
Associated Domains are configured and the matching verification files are hosted on that domain.
Migration `011` adds `pin_interest`, which
tells a host how many other people have their sale in a route (owner and admins only).

Migration `012` imports city garage-sale permits (Arlington and McKinney, TX to start) as live
yard-sale pins every night at 4:20 AM Central, using Postgres's `http` extension. **Every
source ships disabled**: get the city's written OK, then
`update permit_sources set enabled = true where id = 'arlington_tx';` and run
`select import_permits();` once. `last_run_at`, `last_count` and `last_error` on `permit_sources`
show how each run went. Multi-day sales show today's window and roll to the next day at close.
An admin removing a permit pin keeps it removed.

Migration `013` closes two holes in `profiles` (**apply it before launch**): it removes a read policy
that exposed every user's email, phone and home location, and limits users to editing their own
details, not `is_admin`, `plan` or `trust_score`. Migration `014` adds `entitlements`, the store
product ids a user has paid for. Paid tiers are per vertical: a Season Pass unlocks Yard Sales,
not Field Sales Pro. Store webhooks write it with the service role.

Migration `015` adds `trips`, the mileage log: one row per route run, written when its summary
opens. Migration `016` adds teams for the Field Sales Team plan, using security-definer functions
scoped to the caller's team:
- `create_team` needs `plan = 'team'`; `join_team` takes the join code.
- `team_roster` lists the team.
- `team_activity` is for managers only.
- `team_visits_at` shows teammates' recent outcomes at a business, never their notes.

Members of a team whose owner holds the Team plan get Pro. Seat counts aren't enforced yet.

Migration `020` adds the demand loop:
- In an area with no listings, the map shows a "not here yet" card. "I'm hunting here" counts the
  user as waiting, stored only as a ~7-mile grid cell.
- Hosts see "N hunters near you are waiting".
- Admin → **Demand** ranks areas by hunters waiting against live sales, to show where to recruit
  hosts next.
- Build the demo with `--dart-define=DEMO_AWAY=true` to see the empty-area state from Tulsa.

Follow-up reminders are local notifications (`flutter_local_notifications`). Android enables
core library desugaring plus the plugin's scheduling receivers; iOS asks for permission the first
time a reminder is scheduled. **Check both on a device**: this repo's CI has no Android or iOS
toolchain.

The web build uses real paths (`/s/<token>`, `/r/<token>`), so the host must serve `index.html`
for unknown paths. `web/_redirects` covers Netlify and Cloudflare Pages; Firebase needs a rewrite.

Each shared sale or route gets its own link preview (title, time, photo) from the Cloudflare Pages
Functions in `cloudflare/`. Deploy steps are in `cloudflare/README.md`.

The demo build seeds two share tokens (`/r/demo-run`, `/s/demo-sale`) and simulates one
community sighting about 20 seconds after launch, so the invite, sign and live-drop flows can be
shown without a backend.

This build has been validated with `flutter analyze` and `flutter test`. It has not yet been run
on a device from this environment, which has no Android SDK or Xcode.
