// Run: node --experimental-strip-types --test cloudflare/test/preview_test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { injectPreview, loadSale, routeMeta, saleMeta, saleWhen, servePreview, type Env } from '../lib/preview.ts';

const html = `<html><head>
  <!-- preview:start (defaults) -->
  <meta property="og:title" content="CanvasRoute default">
  <!-- preview:end -->
  <title>CanvasRoute</title>
</head><body></body></html>`;

test('sale times read in the sale\'s time zone, across DST', () => {
  // Nov 7 2026 is after fall-back: 13:00Z is 7 AM Central.
  assert.equal(saleWhen('2026-11-07T13:00:00Z', '2026-11-07T17:00:00Z', 'America/Chicago'), 'Sat, Nov 7 · 7–11 AM');
  assert.equal(saleWhen('2026-11-07T14:30:00Z', '2026-11-07T20:00:00Z', 'America/Chicago'), 'Sat, Nov 7 · 8:30 AM–2 PM');
  assert.equal(saleWhen('2026-11-07T13:00:00Z', null, 'America/Chicago'), 'Sat, Nov 7 · from 7 AM');
});

test('a sale preview names when, what and where, with its photo', () => {
  const m = saleMeta(
    { name: 'Moving sale', address: '4431 Bryan St, Dallas, TX 75204', opensAt: '2026-11-07T13:00:00Z', closesAt: '2026-11-07T17:00:00Z', categories: ['Furniture', 'Everything', 'Kids'], photoUrl: 'https://x.supabase.co/p.jpg' },
    'https://canvasroute.app',
  );
  assert.equal(m.title, 'Moving sale');
  assert.equal(m.description, 'Sat, Nov 7 · 7–11 AM · Furniture, Kids · 4431 Bryan St, Dallas. See it and the other sales nearby on CanvasRoute.');
  assert.equal(m.image, 'https://x.supabase.co/p.jpg');
  assert.equal(m.imageIsPhoto, true);
});

test('no photo falls back to the app icon', () => {
  assert.equal(saleMeta({ name: 'x' }, 'https://canvasroute.app').image, 'https://canvasroute.app/icons/Icon-512.png');
});

test('route previews', () => {
  assert.equal(routeMeta({ name: 'Lakewood loop', stops: 8, ownerHandle: 'sam' }, 'https://a.b').description,
    '8 stops, planned in order by @sam. Open it, then save or run it yourself.');
});

test('the default block and title are replaced, and text is escaped', () => {
  const out = injectPreview(html, { title: 'Bob\'s "big" <sale>', description: 'a & b', image: 'https://i', imageIsPhoto: true }, 'https://canvasroute.app/s/abc');
  assert.ok(!out.includes('CanvasRoute default'), 'default tags removed');
  assert.equal((out.match(/og:title/g) ?? []).length, 1);
  assert.ok(out.includes('content="Bob\'s &quot;big&quot; &lt;sale&gt;"'));
  assert.ok(out.includes('content="a &amp; b"'));
  assert.ok(out.includes('<title>Bob\'s &quot;big&quot; &lt;sale&gt; · CanvasRoute</title>'));
  assert.ok(out.includes('twitter:card" content="summary_large_image"'));
});

const env = (pins: unknown[], photos: unknown[] = []): Env => ({
  SUPABASE_URL: 'https://proj.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  ASSETS: { fetch: async () => new Response(html) },
});
const fakeFetch = (pins: unknown[], photos: unknown[] = []) => async (url: string) =>
  new Response(JSON.stringify(url.includes('/pin_photos') ? photos : pins), { status: 200 });

test('loads a live sale by token with its first photo', async () => {
  const sale = await loadSale(env([]), 'abc', fakeFetch(
    [{ id: 'p1', name: 'Moving sale', address: 'a', opens_at: '2026-11-07T13:00:00Z', closes_at: null, categories: ['Tools'] }],
    [{ storage_path: 'u1/x.jpg' }],
  ));
  assert.equal(sale?.name, 'Moving sale');
  assert.equal(sale?.photoUrl, 'https://proj.supabase.co/storage/v1/object/public/pin-photos/u1/x.jpg');
  assert.equal(await loadSale(env([]), 'gone', fakeFetch([])), null);
});

test('serves the app even when the preview fails', async () => {
  const res = await servePreview(new Request('https://canvasroute.app/s/x'), env([]), async () => { throw new Error('db down'); });
  assert.equal(res.status, 200);
  assert.ok((await res.text()).includes('CanvasRoute default'));
  assert.equal(res.headers.get('content-type'), 'text/html; charset=utf-8');
});

test('serves the app with the sale preview', async () => {
  const res = await servePreview(new Request('https://canvasroute.app/s/x'), env([]), async () =>
    saleMeta({ name: 'Estate sale', opensAt: '2026-11-07T14:00:00Z', closesAt: '2026-11-07T20:00:00Z' }, 'https://canvasroute.app'));
  const body = await res.text();
  assert.ok(body.includes('og:title" content="Estate sale"'));
  assert.ok(body.includes('Sat, Nov 7 · 8 AM–2 PM'));
});
