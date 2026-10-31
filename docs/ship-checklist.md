# Ship checklist: CanvasRoute v1 (Yard Sales)

v1 ships Yard Sales only (`LAUNCH_MODES=yard_sales`, the default). Field Sales and Card Drops
are built but off.

## Verified in the repo

| Check | How to re-run |
|---|---|
| `flutter analyze` is clean; all unit tests pass in Chicago, UTC and Auckland (DST-sensitive date logic) | `flutter analyze && TZ=America/Chicago flutter test` |
| Migrations 001–019 apply in order to a fresh Supabase-like database, and every public table has RLS | `PGHOST=… PGUSER=postgres supabase/tests/apply_all.sh` |
| The security regressions from the pre-launch audit stay closed (fake pins, report farming, private emails, visit squatting, team code guessing, seat limits, function privileges, handle lookups) | runs as part of `apply_all.sh` (`supabase/tests/security_test.sql`) |
| Stripe billing rules: signatures, replay window, out-of-order events, Team seats | `node --experimental-strip-types --test supabase/functions/_shared/billing_test.ts` |
| Demo web build: no page or console errors across onboarding, map, Plan my day, routes, settings, account, hosting, share links, feature requests | `flutter build web -t lib/main_demo.dart` |
| Photos lose EXIF (including GPS) before upload | `test/logic/photo_scrub_test.dart` |

## What only you can do

### Backend (Supabase)
- [ ] Create the production project. Use **Pro** ($25/mo) for backups and no pausing; see `docs/launch-costs.md`.
- [ ] **Auth → Providers:** turn on Anonymous, Email (magic link), Apple and Google. Add `canvasroute://auth-callback` to Redirect URLs.
- [ ] **Database → Extensions:** turn on `pg_cron` and `http`. The permit import uses `http`.
- [ ] Apply migrations: `supabase db push`. All 19 apply cleanly to a fresh project.
- [ ] Make yourself admin: `update profiles set is_admin = true where email = 'you@…';`
- [ ] Deploy functions:
  - `supabase functions deploy delete-account`
  - `supabase functions deploy create-checkout`
  - `supabase functions deploy stripe-webhook --no-verify-jwt`
- [ ] Set function secrets. `delete-account` needs `STRIPE_SECRET_KEY` only if you sell Field Sales. See README → Billing.

### Google Cloud
- [ ] Enable Maps SDK (iOS and Android), Places API (New), Routes API and Geocoding.
- [ ] Restrict the key to your bundle IDs, SHA-1 and those APIs.
- [ ] Set daily quotas and a budget alert (numbers in `docs/launch-costs.md`).

### Web origin (`WEB_ORIGIN`)
- [ ] Host `build/web` on Cloudflare Pages with the link-preview functions (`cloudflare/README.md`). Firebase Hosting works too, but without per-sale previews. It serves:
  - the share pages `/s/…` and `/r/…`. These are real paths, so the host must serve `index.html` for unknown paths. `web/_redirects` handles Netlify and Cloudflare Pages; Firebase needs a `rewrites` rule. **Test a sign's QR on a phone once it's deployed.**
  - `/privacy.html` and `/terms.html`, which the app links to
- [ ] **Have a lawyer review `web/privacy.html` and `web/terms.html`.** They describe what the app actually does, but they're drafts.
- [ ] Make sure `privacy@canvasroute.app` and `support@canvasroute.app` exist, or change them in both pages.

### Supply for launch week
- [ ] Email the Arlington and McKinney GIS teams for written permission. Then run `update permit_sources set enabled = true where id = '…'; select import_permits();`
- [ ] Line up estate sale companies and HOAs, and plan to spot sales yourself the first few Saturdays.

### Android (Play)
- [ ] Create an upload keystore and `android/key.properties`. Without it, release builds are debug-signed and Play rejects them.
- [ ] Build: `flutter build appbundle --dart-define-from-file=.env.json`
- [ ] Play Console:
  - listing, screenshots and content rating
  - **Data safety** form: use the privacy policy's "What we collect"
  - target API level as Play requires

### iOS (App Store)
- [ ] In Xcode, check the signing team, bundle id `com.brilliantdisruptions.canvasroute`, and the **Sign in with Apple** capability.
- [ ] Build: `flutter build ipa --dart-define-from-file=.env.json`
- [ ] App Store Connect:
  - listing, screenshots and privacy policy URL
  - **App Privacy** answers from the privacy policy
  - export compliance: HTTPS only, so it's exempt

### On real devices (nothing here can run Android or iOS)
- [ ] First launch with no signal, then reconnect. The app should sign in on resume.
- [ ] Location prompt, camera, photo library.
- [ ] Sign in with Apple, Google and email. Then delete the account and confirm you land back at onboarding.
- [ ] Host a sale with photos. Print the sign and scan its QR.
- [ ] Spot a sale and approve it as admin.
- [ ] Field Sales builds only: set a follow-up for tomorrow and check the 8:30 reminder arrives. Tap it with the app fully closed; it should open Follow-ups.
- [ ] Android release build compiles. It has core library desugaring and notification receivers, which this repo's CI never compiled.

## Known limits (v1.1 candidates)
- **In-app purchase isn't built.** Consumer passes (Season Pass, Drop Alerts Pro) can't be sold yet, so those features are unlocked rather than shown behind a paywall that can't be paid.
- **Share links open the web page, not the app.** That needs Android App Links and iOS Associated Domains.
- **No push alerts from the server.** Only on-device follow-up reminders exist.
- **Reports and pins carry opaque user ids.** One person's reports can be linked to each other, but not to a name.
- **Store pins:** the first person to report on a store sets its name and position. Admins can correct it.
