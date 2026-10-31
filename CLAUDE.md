# CLAUDE.md — canvas-route

## Project
CanvasRoute v3: a Flutter "find → route → run → log" app with pluggable verticals (Modes).
Field Sales (B2B canvassing), Yard Sales, and Card Drops (trading-card restock runs).
Spec: `SPEC.md`. Backend: Supabase (Postgres + Auth + Storage + Realtime + pg_cron).

## Stack
- Flutter 3.47 / Dart 3.13, Riverpod 3 (hand-written Notifiers, no codegen), go_router
- google_maps_flutter, geolocator, image_picker, share_plus, url_launcher, qr_flutter
- supabase_flutter (anonymous sign-in on first launch, upgraded to email/OAuth later)
- Google Places API (New) Text Search + Details, Routes API, Geocoding via `http` (field masks set the bill)

## Layout
- `lib/core/` — env (`--dart-define`), theme (Kinetic Noir tokens as a ThemeExtension), pure logic
- `lib/modes/` — `ModePack` contract + one file per mode + registry. **Screens never branch on mode id.**
- `lib/data/models` — plain classes with `fromRow`/`toJson`; `repositories` — Supabase I/O; `services` — Google APIs, device I/O
- `lib/state/` — Riverpod providers (one file per domain)
- `lib/features/<feature>/` — screens and sheets; `lib/ui/widgets/kn_widgets.dart` — shared Kinetic Noir widgets
- `supabase/migrations/` — numbered SQL, RLS on every table
- `test/` — unit tests for `core/logic` and mode pack invariants

## Rules
- If a feature needs `if (mode == x)` in a screen, add a field to `ModePack` instead.
- All external I/O in `services/` or `repositories/`; screens read providers only.
- No raw location of a reporter is ever stored; reports store the pin's location.
- Never scrape marketplace listings; store the URL and open it.
- Keep `flutter analyze` at zero issues and `flutter test` green before saying done.
- Atomic commits in imperative mood.
