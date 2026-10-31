// /r/<token>: a shared route. Adds its preview, then serves the app.
import { loadRoute, routeMeta, servePreview, type Env } from '../../lib/preview.ts';

export const onRequestGet = async ({ request, env, params }: { request: Request; env: Env; params: { token: string } }) =>
  servePreview(request, env, async () => {
    const route = await loadRoute(env, String(params.token));
    return route && routeMeta(route, new URL(request.url).origin);
  });
