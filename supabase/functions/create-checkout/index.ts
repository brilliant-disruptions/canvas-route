// POST { product, seats? } with the user's JWT → { url } of a Stripe Checkout page.
// Secrets: STRIPE_SECRET_KEY, STRIPE_PRICE_PRO, STRIPE_PRICE_TEAM, WEB_ORIGIN.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { PRODUCTS } from '../_shared/billing.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  // Guests have no email or durable account to attach a subscription to.
  if (!user || user.is_anonymous) return json({ error: 'Sign in to upgrade' }, 401);

  const { product, seats } = await req.json().catch(() => ({}));
  const p = PRODUCTS[product as string];
  const price = p && Deno.env.get(p.priceEnv);
  if (!p || !price) return json({ error: 'Unknown product' }, 400);
  const quantity = p.plan === 'team' ? Math.min(Math.max(Number(seats) || 2, 2), 500) : 1;

  const origin = Deno.env.get('WEB_ORIGIN') ?? 'https://canvasroute.app';
  const form = new URLSearchParams({
    mode: 'subscription',
    'line_items[0][price]': price,
    'line_items[0][quantity]': String(quantity),
    client_reference_id: user.id,
    // The webhook reads these off the subscription to know whose plan to change.
    'subscription_data[metadata][user_id]': user.id,
    'subscription_data[metadata][product]': product,
    allow_promotion_codes: 'true',
    success_url: `${origin}/#/billing/done`,
    cancel_url: `${origin}/#/settings/account`,
  });
  if (user.email) form.set('customer_email', user.email);

  const res = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${Deno.env.get('STRIPE_SECRET_KEY')}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: form,
  });
  const session = await res.json();
  if (!res.ok) return json({ error: session?.error?.message ?? 'Checkout failed' }, 502);
  return json({ url: session.url });
});
