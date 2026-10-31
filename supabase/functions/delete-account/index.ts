// POST with the user's JWT → deletes their account and everything that is theirs.
// App Store guideline 5.1.1(v) requires in-app deletion, not just deactivation.
// Secrets: STRIPE_SECRET_KEY (optional; active subscriptions are cancelled first).
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const BUCKETS = ['visit-photos', 'pin-photos', 'avatars'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);

  // Who is asking comes from their JWT, never from the body.
  const asUser = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });
  const { data: { user } } = await asUser.auth.getUser();
  if (!user) return json({ error: 'Not signed in' }, 401);

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  // 1. Stop billing. A failure here stops the deletion so nobody is charged for a deleted account.
  const { data: profile } = await admin.from('profiles').select('stripe_id').eq('id', user.id).maybeSingle();
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
  if (profile?.stripe_id && stripeKey) {
    const list = await fetch(
      `https://api.stripe.com/v1/subscriptions?customer=${encodeURIComponent(profile.stripe_id)}&status=active`,
      { headers: { Authorization: `Bearer ${stripeKey}` } },
    );
    if (!list.ok) return json({ error: 'Could not reach billing; try again' }, 502);
    for (const sub of (await list.json()).data ?? []) {
      const del = await fetch(`https://api.stripe.com/v1/subscriptions/${sub.id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${stripeKey}` },
      });
      if (!del.ok) return json({ error: 'Could not cancel your subscription; try again' }, 502);
    }
  }

  // 2. Files: every object lives under <uid>/ in each bucket.
  for (const bucket of BUCKETS) {
    for (;;) {
      const { data: files } = await admin.storage.from(bucket).list(user.id, { limit: 100 });
      if (!files || files.length === 0) break;
      const { error } = await admin.storage.from(bucket).remove(files.map((f) => `${user.id}/${f.name}`));
      if (error) return json({ error: 'Could not delete your photos; try again' }, 500);
    }
  }

  // 3. Sales they host are residential addresses: remove them rather than orphan them.
  await admin.from('pins').delete().eq('owner_id', user.id);

  // 4. The auth user. Profiles, routes, stops, visits, trips, reports, teams they own
  //    and memberships all cascade from it.
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) return json({ error: 'Could not delete the account; try again' }, 500);
  return json({ deleted: true });
});
