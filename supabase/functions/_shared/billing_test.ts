// Run: node --experimental-strip-types --test supabase/functions/_shared/billing_test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyGrant, grantFromSubscription, verifyStripeSignature } from './billing.ts';

async function sign(payload: string, secret: string, t: number): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${t}.${payload}`));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

test('signature: valid, tampered, stale and missing', async () => {
  const body = '{"id":"evt_1"}';
  const t = 1_800_000_000;
  const v1 = await sign(body, 'whsec_test', t);
  assert.equal(await verifyStripeSignature(body, `t=${t},v1=${v1}`, 'whsec_test', t + 10), true);
  assert.equal(await verifyStripeSignature(body + ' ', `t=${t},v1=${v1}`, 'whsec_test', t + 10), false);
  assert.equal(await verifyStripeSignature(body, `t=${t},v1=${v1}`, 'other', t + 10), false);
  assert.equal(await verifyStripeSignature(body, `t=${t},v1=${v1}`, 'whsec_test', t + 301), false);
  assert.equal(await verifyStripeSignature(body, null, 'whsec_test', t), false);
  // Stripe may send several v1 values during secret rotation.
  assert.equal(await verifyStripeSignature(body, `t=${t},v1=deadbeef,v1=${v1}`, 'whsec_test', t), true);
});

test('subscription → grant, reading the period end from either place', () => {
  const base = { status: 'active', customer: 'cus_1', metadata: { user_id: 'u1', product: 'canvasroute_pro_monthly' } };
  assert.deepEqual(grantFromSubscription({ ...base, current_period_end: 1_800_000_000 }), {
    userId: 'u1', product: 'canvasroute_pro_monthly', active: true, customer: 'cus_1', periodEnd: '2027-01-15',
  });
  assert.equal(grantFromSubscription({ ...base, items: { data: [{ current_period_end: 1_800_000_000 }] } })!.periodEnd, '2027-01-15');
  assert.equal(grantFromSubscription({ ...base, status: 'canceled' })!.active, false);
  assert.equal(grantFromSubscription({ ...base, metadata: {} }), null);
  assert.equal(grantFromSubscription({ ...base, metadata: { user_id: 'u1', product: 'canvasroute_season_pass' } }), null);
});

test('grants add and remove only their own product', () => {
  const g = { userId: 'u1', product: 'canvasroute_pro_monthly', active: true, customer: 'cus_1', periodEnd: '2026-12-01' };
  const before = { plan: 'free', entitlements: ['canvasroute_season_pass'] };
  const on = applyGrant(before, g);
  assert.deepEqual(on, { plan: 'pro', entitlements: ['canvasroute_season_pass', 'canvasroute_pro_monthly'], billing_date: '2026-12-01' });
  assert.deepEqual(applyGrant(on, g).entitlements, ['canvasroute_season_pass', 'canvasroute_pro_monthly'], 'idempotent');
  const off = applyGrant(on, { ...g, active: false });
  assert.deepEqual(off, { plan: 'free', entitlements: ['canvasroute_season_pass'], billing_date: null });
  // Cancelling Pro doesn't downgrade someone who has since moved to Team.
  assert.equal(applyGrant({ plan: 'team', entitlements: [] }, { ...g, active: false }).plan, 'team');
});
