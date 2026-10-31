# Web hosting (Cloudflare Pages)

The Flutter web build (`build/web`) is the public site: share pages `/s/<token>` and
`/r/<token>`, `privacy.html` and `terms.html`. These Pages Functions give each shared
sale or route its own link preview (title, time, photo) on Facebook, iMessage,
Nextdoor and the rest, whose crawlers don't run the app. Everyone else gets the
normal app.

## Deploy

```bash
flutter build web --dart-define-from-file=.env.json
cd cloudflare
npx wrangler pages deploy ../build/web --project-name canvasroute
```

Wrangler picks up `cloudflare/functions/` because it's run from this folder.

In the Pages project → Settings → Variables, set:
- `SUPABASE_URL` and `SUPABASE_ANON_KEY`: the same public values the app uses. Reads go through RLS: live pins, their photos, and the `shared_route` RPC.
- `SALE_TIME_ZONE` (optional, default `America/Chicago`): the time zone used to write sale times in previews.

## Check it

- Paste a sale link into https://developers.facebook.com/tools/debug/ and confirm the
  name, time and photo.
- Run the tests: `node --experimental-strip-types --test cloudflare/test/preview_test.ts`.

If the database is unreachable, the function serves the plain app with the default
preview, so links never break.
