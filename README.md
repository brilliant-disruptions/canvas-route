# CanvasRoute

**Find → route → run → log**, for anyone who has to visit a list of places in a good order and
remember what happened at each one. One Flutter app, three modes:

| Mode | For | What's special |
|---|---|---|
| **Field Sales** | B2B reps | Places search, drive-time optimization, outcome logging, CSV export |
| **Yard Sales** | Weekend hunters, resellers, hosts | Host-posted sales with sign QR, time-window-aware routing, haul log |
| **Card Drops** | Collectors and parents buying TCG product at retail | Crowd-sourced per-store restock patterns, two-tap shelf reports, stock alerts |

Full product spec: [`SPEC.md`](SPEC.md).

## Stack

Flutter 3.47 · Riverpod 3 · go_router · google_maps_flutter · Supabase (Postgres, Auth, Storage,
Realtime, pg_cron) · Google Places / Directions / Geocoding.

## Setup

### 1. Supabase

Create a project, then apply `supabase/migrations/*.sql` in order (Supabase SQL editor or
`supabase db push`). Then in **Authentication → Providers**:

- enable **Anonymous sign-ins** (every device gets a uid on first launch; RLS depends on it)
- enable **Email** (magic link) and optionally **Apple** / **Google**
- add `canvasroute://auth-callback` to **Redirect URLs**

Migration `008` seeds the Pokémon TCG product catalog; `005`/`006` schedule pg_cron jobs for
pin expiry and restock-pattern refresh. Make yourself an admin with
`update profiles set is_admin = true where email = 'you@example.com';`.

### 2. Google Cloud

Enable **Maps SDK for iOS**, **Maps SDK for Android**, **Places API**, **Directions API**,
**Geocoding API** on one key.

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
```

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

## Status

Phases 0–3 of the spec are implemented in this codebase: Field Sales parity, Yard Sales mode,
the community layer (pins, reports, trust gates, admin moderation, shared routes), and Card Drops
with restock patterns. **Not yet wired:** push delivery for alerts (the `alerts` table and
Realtime stream exist; an Edge Function + Expo/FCM sender is Phase 4), store billing (RevenueCat,
Phase 4; the paywall sheet explains the tier), and public web pages for shared links (Phase 5).

This build has been validated with `flutter analyze` and `flutter test`. It has not yet been run
on a device from this environment, which has no Android SDK or Xcode.
