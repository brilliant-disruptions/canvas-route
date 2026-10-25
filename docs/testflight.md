# Getting CanvasRoute onto your iPhone with TestFlight

The **iOS TestFlight** workflow (`.github/workflows/ios-testflight.yml`) builds the app on a
GitHub-hosted Mac, signs it, and uploads it to App Store Connect. Until a backend is chosen it
ships the **demo build** (`lib/main_demo.dart`): the full app on sample Dallas data, no sign-in,
nothing leaves the phone.

You do the Apple-side steps once. After that, every build is one click.

## One-time setup (about 20 minutes)

1. **Apple Developer Program.** Enroll at developer.apple.com/programs if the company isn't
   enrolled yet (see `founders/app-store/setup.md`; organization enrollment needs a D-U-N-S number).

2. **Register the bundle ID.** developer.apple.com → Certificates, Identifiers & Profiles →
   Identifiers → **+** → App IDs → App. Bundle ID (Explicit):

   ```
   com.brilliantdisruptions.canvasroute
   ```

   Description: `CanvasRoute`. No extra capabilities are needed yet.

3. **Create the app record.** appstoreconnect.apple.com → Apps → **+** → New App.
   Platform iOS · Name `CanvasRoute` (if taken, try `CanvasRoute Route Planner`) ·
   Bundle ID from step 2 · SKU `canvasroute-ios` · Full access.

4. **Create an API key for the build robot.** App Store Connect → Users and Access →
   Integrations → App Store Connect API → Team Keys → **Generate API Key**.
   Name `GitHub CI`, Access **Admin**. Admin is required so the build can create its own
   signing certificate; nothing else uses it. Download the `.p8` file (one chance only) and
   note the **Key ID** and the **Issuer ID** shown above the table.

5. **Find your Team ID.** developer.apple.com → Account → Membership details → Team ID
   (10 characters).

6. **Add four repository secrets.** github.com/michaeljwilt/canvas-route → Settings →
   Secrets and variables → Actions → **New repository secret**:

   | Name | Value |
   |---|---|
   | `APPLE_TEAM_ID` | Team ID from step 5 |
   | `ASC_KEY_ID` | Key ID from step 4 |
   | `ASC_ISSUER_ID` | Issuer ID from step 4 |
   | `ASC_KEY_P8` | The full text of the `.p8` file, including the BEGIN and END lines |

## Each build

1. GitHub → **Actions** → **iOS TestFlight** → **Run workflow**. Leave `demo` and
   `Upload to TestFlight` checked.
2. The run takes about 15 minutes. Apple then processes the build for another 5 to 15 minutes.
3. App Store Connect → your app → **TestFlight** → Internal Testing → create a group (for
   example `Founders`), add yourself and Jimmy, and add the build. Internal testers need no
   App Review.
4. Install **TestFlight** from the App Store on your iPhone, open the invite email, and tap
   Install. New builds show up there automatically.

## Good to know

- Build numbers come from the workflow run number, so every upload is unique.
- The app already declares standard encryption only, so TestFlight won't ask the
  export-compliance question.
- Pushes that change the app run the same workflow as an unsigned compile check, with no upload.
- To ship the real backend later, run the workflow with `production` after adding
  `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `GOOGLE_MAPS_API_KEY` secrets.
- If the upload step says the app record can't be found, the bundle ID in step 3 doesn't match
  `com.brilliantdisruptions.canvasroute` exactly.
