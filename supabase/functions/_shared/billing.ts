// Stripe billing rules shared by the create-checkout and stripe-webhook functions.
// Pure apart from WebCrypto, so it runs under Deno (edge) and Node (tests) alike.

/** Web-billed products: store product id → profile plan and the env var holding its Stripe price. */
export const PRODUCTS: Record<string, { plan: 'pro' | 'team'; priceEnv: string }> = {
  canvasroute_pro_monthly: { plan: 'pro', priceEnv: 'STRIPE_PRICE_PRO' },
  canvasroute_team_monthly: { plan: 'team', priceEnv: 'STRIPE_PRICE_TEAM' },
};

const ACTIVE = new Set(['active', 'trialing', 'past_due']);

export interface Grant {
  userId: string;
  product: string;
  active: boolean;
  customer: string | null;
  periodEnd: string | null; // YYYY-MM-DD
}

/** Reads who/what a Stripe subscription object is for. Null when it isn't ours. */
export function grantFromSubscription(sub: any): Grant | null {
  const userId = sub?.metadata?.user_id;
  const product = sub?.metadata?.product;
  if (typeof userId !== 'string' || typeof product !== 'string' || !(product in PRODUCTS)) return null;
  // Newer API versions moved the period end from the subscription onto its items.
  const end = sub.current_period_end ?? sub.items?.data?.[0]?.current_period_end ?? null;
  return {
    userId,
    product,
    active: ACTIVE.has(sub.status),
    customer: typeof sub.customer === 'string' ? sub.customer : (sub.customer?.id ?? null),
    periodEnd: typeof end === 'number' ? new Date(end * 1000).toISOString().slice(0, 10) : null,
  };
}

export interface ProfileBilling {
  plan: string;
  entitlements: string[];
}

export interface DerivedBilling extends ProfileBilling {
  billing_date: string | null;
  team_seats: number | null;
}

/**
 * The profile's billing columns from *all* of a customer's Stripe subscriptions,
 * so late, retried or out-of-order events can't re-grant a cancelled plan.
 * Entitlements from other stores (App Store / Play) are kept as they are.
 */
export function deriveBilling(current: ProfileBilling, subs: any[]): DerivedBilling {
  const live = subs.filter((s) => ACTIVE.has(s?.status) && (s?.metadata?.product in PRODUCTS));
  const products = [...new Set(live.map((s) => s.metadata.product as string))];
  const plans = new Set(products.map((p) => PRODUCTS[p].plan));
  const ends = live
    .map((s) => s.current_period_end ?? s.items?.data?.[0]?.current_period_end)
    .filter((e): e is number => typeof e === 'number');
  const team = live.filter((s) => PRODUCTS[s.metadata.product].plan === 'team');
  const seats = team.reduce((n, s) => n + (Number(s.items?.data?.[0]?.quantity) || 0), 0);
  return {
    plan: plans.has('team') ? 'team' : plans.has('pro') ? 'pro' : 'free',
    entitlements: [...current.entitlements.filter((e) => !(e in PRODUCTS)), ...products],
    billing_date: ends.length ? new Date(Math.max(...ends) * 1000).toISOString().slice(0, 10) : null,
    team_seats: team.length ? seats : null,
  };
}

function hex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Constant-time string compare. */
function same(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

/**
 * Checks a `Stripe-Signature` header (t=…,v1=…) against the raw body, rejecting
 * signatures older than [toleranceSec] to stop replays.
 */
export async function verifyStripeSignature(
  payload: string,
  header: string | null,
  secret: string,
  nowSec: number,
  toleranceSec = 300,
): Promise<boolean> {
  if (!header || !secret) return false;
  const parts = header.split(',').map((s) => s.trim().split('='));
  const t = parts.find(([k]) => k === 't')?.[1];
  const sigs = parts.filter(([k]) => k === 'v1').map(([, v]) => v);
  if (!t || sigs.length === 0 || Math.abs(nowSec - Number(t)) > toleranceSec) return false;
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const expected = hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${t}.${payload}`)));
  return sigs.some((s) => same(s, expected));
}
