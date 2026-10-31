// Stripe → profile plan and entitlements. Deploy with --no-verify-jwt (Stripe has
// no Supabase JWT); the Stripe signature is the authentication.
// Secrets: STRIPE_WEBHOOK_SECRET, STRIPE_SECRET_KEY. Events: customer.subscription.created|updated|deleted.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { deriveBilling, grantFromSubscription, verifyStripeSignature } from '../_shared/billing.ts';

Deno.serve(async (req) => {
  const body = await req.text();
  const ok = await verifyStripeSignature(
    body,
    req.headers.get('Stripe-Signature'),
    Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '',
    Math.floor(Date.now() / 1000),
  );
  if (!ok) return new Response('bad signature', { status: 400 });

  const event = JSON.parse(body);
  if (!String(event.type).startsWith('customer.subscription.')) return new Response('ignored');
  // The event only says whose subscription changed; what they're entitled to is
  // read fresh from Stripe, so event order and retries don't matter.
  const grant = grantFromSubscription(event.data?.object);
  if (!grant || !grant.customer) return new Response('not ours');

  const list = await fetch(
    `https://api.stripe.com/v1/subscriptions?customer=${encodeURIComponent(grant.customer)}&status=all&limit=100`,
    { headers: { Authorization: `Bearer ${Deno.env.get('STRIPE_SECRET_KEY')}` } },
  );
  if (!list.ok) return new Response('stripe unavailable', { status: 502 }); // Stripe retries
  const subs = (await list.json()).data ?? [];

  // Service role: plan and entitlements are not user-writable (migration 013).
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: profile, error } = await admin
    .from('profiles').select('plan, entitlements').eq('id', grant.userId).single();
  if (error || !profile) return new Response('no profile', { status: 404 });

  const next = deriveBilling({ plan: profile.plan, entitlements: profile.entitlements ?? [] }, subs);
  const { error: upd } = await admin
    .from('profiles')
    .update({ ...next, stripe_id: grant.customer })
    .eq('id', grant.userId);
  // A 500 makes Stripe retry, which is what we want for a transient failure.
  if (upd) return new Response(upd.message, { status: 500 });
  return new Response('ok');
});
