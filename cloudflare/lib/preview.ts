// Link previews for shared sales and routes. Pure: builds tags and rewrites
// index.html; the Pages Functions fetch the data. Runs in Workers and in Node tests.

export interface SalePreview {
  name: string;
  address?: string | null;
  opensAt?: string | null; // ISO
  closesAt?: string | null;
  categories?: string[];
  photoUrl?: string | null;
}

export interface RoutePreview {
  name: string;
  stops: number;
  ownerHandle?: string | null;
}

export interface Meta {
  title: string;
  description: string;
  image: string;
  imageIsPhoto: boolean;
}

const esc = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** "Sat, Nov 7 · 7–11 AM" in the sale's time zone. */
export function saleWhen(opensAt: string, closesAt: string | null | undefined, timeZone: string): string {
  const o = new Date(opensAt);
  const day = o.toLocaleDateString('en-US', { timeZone, weekday: 'short', month: 'short', day: 'numeric' });
  const t = (d: Date) =>
    d.toLocaleTimeString('en-US', { timeZone, hour: 'numeric', minute: '2-digit' }).replace(':00', '');
  if (!closesAt) return `${day} · from ${t(o)}`;
  const c = new Date(closesAt);
  const [os, oap] = t(o).split(' ');
  const [cs, cap] = t(c).split(' ');
  return `${day} · ${oap === cap ? `${os}–${cs} ${cap}` : `${t(o)}–${t(c)}`}`;
}

export function saleMeta(p: SalePreview, origin: string, timeZone = 'America/Chicago'): Meta {
  const street = p.address?.split(',').slice(0, 2).join(',').trim();
  const parts = [
    p.opensAt ? saleWhen(p.opensAt, p.closesAt, timeZone) : null,
    p.categories?.filter((c) => c !== 'Everything').slice(0, 3).join(', ') || null,
    street || null,
  ].filter(Boolean);
  return {
    title: p.name,
    description: `${parts.join(' · ')}. See it and the other sales nearby on CanvasRoute.`,
    image: p.photoUrl || `${origin}/icons/Icon-512.png`,
    imageIsPhoto: !!p.photoUrl,
  };
}

export function routeMeta(r: RoutePreview, origin: string): Meta {
  const by = r.ownerHandle ? ` by @${r.ownerHandle}` : '';
  return {
    title: r.name,
    description: `${r.stops} stop${r.stops === 1 ? '' : 's'}, planned in order${by}. Open it, then save or run it yourself.`,
    image: `${origin}/icons/Icon-512.png`,
    imageIsPhoto: false,
  };
}

export function metaTags(m: Meta, url: string): string {
  const t = esc(m.title), d = esc(m.description);
  return [
    `<meta name="description" content="${d}">`,
    `<meta property="og:site_name" content="CanvasRoute">`,
    `<meta property="og:title" content="${t}">`,
    `<meta property="og:description" content="${d}">`,
    `<meta property="og:image" content="${esc(m.image)}">`,
    `<meta property="og:url" content="${esc(url)}">`,
    `<meta property="og:type" content="website">`,
    `<meta name="twitter:card" content="${m.imageIsPhoto ? 'summary_large_image' : 'summary'}">`,
    `<meta name="twitter:title" content="${t}">`,
    `<meta name="twitter:description" content="${d}">`,
  ].join('\n  ');
}

/** Swaps the default preview block and <title> in index.html for [m]. */
export function injectPreview(html: string, m: Meta, url: string): string {
  const block = /<!-- preview:start[\s\S]*?<!-- preview:end -->/;
  const tags = `<!-- preview:start -->\n  ${metaTags(m, url)}\n  <!-- preview:end -->`;
  const withTags = block.test(html) ? html.replace(block, tags) : html.replace('</head>', `  ${tags}\n</head>`);
  return withTags.replace(/<title>[\s\S]*?<\/title>/, `<title>${esc(m.title)} · CanvasRoute</title>`);
}

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SALE_TIME_ZONE?: string;
  ASSETS: { fetch(input: URL | string): Promise<Response> };
}

type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

/** A live sale by share token, through the public API (anon key; RLS allows live pins). */
export async function loadSale(env: Env, token: string, fetcher: Fetch = fetch): Promise<SalePreview | null> {
  const h = { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${env.SUPABASE_ANON_KEY}` };
  const q = new URLSearchParams({ share_token: `eq.${token}`, status: 'eq.live', select: 'id,name,address,opens_at,closes_at,categories', limit: '1' });
  const res = await fetcher(`${env.SUPABASE_URL}/rest/v1/pins?${q}`, { headers: h });
  if (!res.ok) return null;
  const [pin] = (await res.json()) as any[];
  if (!pin) return null;
  const photos = await fetcher(`${env.SUPABASE_URL}/rest/v1/pin_photos?pin_id=eq.${pin.id}&select=storage_path&limit=1`, { headers: h });
  const [photo] = photos.ok ? ((await photos.json()) as any[]) : [];
  return {
    name: pin.name,
    address: pin.address,
    opensAt: pin.opens_at,
    closesAt: pin.closes_at,
    categories: pin.categories ?? [],
    photoUrl: photo ? `${env.SUPABASE_URL}/storage/v1/object/public/pin-photos/${photo.storage_path}` : null,
  };
}

/** A shared route by token, through the read-only shared_route RPC. */
export async function loadRoute(env: Env, token: string, fetcher: Fetch = fetch): Promise<RoutePreview | null> {
  const res = await fetcher(`${env.SUPABASE_URL}/rest/v1/rpc/shared_route`, {
    method: 'POST',
    headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_token: token }),
  });
  if (!res.ok) return null;
  const data = (await res.json()) as any;
  if (!data?.route) return null;
  return { name: data.route.name, stops: (data.stops ?? []).length, ownerHandle: data.owner_handle };
}

/** Serves index.html with this page's preview. Any failure serves the plain app. */
export async function servePreview(
  request: Request,
  env: Env,
  load: () => Promise<Meta | null>,
): Promise<Response> {
  const page = await env.ASSETS.fetch(new URL('/index.html', request.url));
  let html = await page.text();
  try {
    const meta = await load();
    if (meta) html = injectPreview(html, meta, request.url);
  } catch {
    // Previews are a nicety; the app must still load.
  }
  return new Response(html, {
    headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'public, max-age=300' },
  });
}
