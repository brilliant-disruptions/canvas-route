// /s/<token>: a shared sale or a sign's QR. Adds its preview, then serves the app.
import { loadSale, saleMeta, servePreview, type Env } from '../../lib/preview.ts';

export const onRequestGet = async ({ request, env, params }: { request: Request; env: Env; params: { token: string } }) =>
  servePreview(request, env, async () => {
    const sale = await loadSale(env, String(params.token));
    return sale && saleMeta(sale, new URL(request.url).origin, env.SALE_TIME_ZONE);
  });
