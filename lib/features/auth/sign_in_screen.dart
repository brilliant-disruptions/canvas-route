import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/logic/errors.dart';
import '../../core/logic/recap.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../state/visits_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Upgrades the anonymous session to a real account. The uid is preserved, so
/// routes and visits logged as a guest stay with the user.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.reason});
  final String? reason;
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final auth = ref.read(authRepoProvider);
    ref.listen(isAnonymousProvider, (_, anon) {
      if (!anon && mounted) context.pop();
    });
    final pack = ref.watch(modePackProvider);
    // Both counts are for the active mode, which is what the user is looking at.
    final routeIds = {...?ref.watch(routesProvider).value?.map((r) => r.id)};
    final routes = routeIds.length;
    final visits = ref.watch(allVisitsProvider).value?.where((v) => routeIds.contains(v.routeId)).length ?? 0;
    final headline = switch (widget.reason) {
      'report' => 'Join nearby ${pack.communityNoun}',
      'share' => 'Share your ${pack.routeNoun}',
      'host' => 'Post your sale',
      'upgrade' => 'Sign in to upgrade',
      'team' => 'Sign in to join your team',
      _ => 'Keep everything you\'ve built',
    };
    // Linking keeps the same uid, so nothing a guest made is lost: say so.
    final keep = routes + visits == 0
        ? 'It\'s free and takes a few seconds.'
        : 'Your ${countNoun(routes, pack.routeNoun)} and ${countNoun(visits, 'visit')} stay with you. Nothing to re-enter.';
    final perks = [
      (Icons.devices_outlined, 'Your ${pack.routeNoun}s on every device'),
      (Icons.ios_share, 'Share links and recaps with friends'),
      if (pack.hasCommunity) (Icons.campaign_outlined, 'Report what you see and get alerts'),
    ];

    return KnScaffold(
      title: '',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s6),
        children: [
          Text(headline, style: t.displaySmall),
          const SizedBox(height: Sp.s2),
          Text(keep, style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: Sp.s5),
          for (final (icon, label) in perks)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s3),
              child: Row(
                children: [
                  Icon(icon, color: c.tertiary, size: 22),
                  const SizedBox(width: Sp.s3),
                  Expanded(child: Text(label, style: t.titleMedium)),
                ],
              ),
            ),
          const SizedBox(height: Sp.s4),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c.onSurface, foregroundColor: c.surface),
            onPressed: _busy ? null : () => _run(() => auth.signInWithOAuth(OAuthProvider.apple)),
            icon: const Icon(Icons.apple),
            label: const Text('Continue with Apple'),
          ),
          const SizedBox(height: Sp.s3),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(() => auth.signInWithOAuth(OAuthProvider.google)),
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: Sp.s5),
          Row(
            children: [
              const Expanded(child: GhostDivider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.s3),
                child: Text('or use email', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant)),
              ),
              const Expanded(child: GhostDivider()),
            ],
          ),
          const SizedBox(height: Sp.s5),
          if (!_sent) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: Sp.s3),
            KnButton(
              label: 'Email me a sign-in link',
              loading: _busy,
              onPressed: () => _run(() async {
                await auth.sendMagicLink(_email.text.trim());
                setState(() => _sent = true);
              }),
            ),
          ] else ...[
            Text('Check ${_email.text} for a link. If the email shows a code, enter it here.', style: t.bodyMedium),
            const SizedBox(height: Sp.s3),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '6-digit code'),
            ),
            const SizedBox(height: Sp.s3),
            KnButton(
              label: 'Verify code',
              loading: _busy,
              onPressed: () => _run(() => auth.verifyEmailOtp(_email.text.trim(), _code.text.trim())),
            ),
            TextButton(onPressed: () => setState(() => _sent = false), child: const Text('Use a different email')),
          ],
          if (_error != null) ...[
            const SizedBox(height: Sp.s4),
            Text(_error!, style: t.bodySmall?.copyWith(color: c.error)),
          ],
          const SizedBox(height: Sp.s5),
          Text(
            'Free. No spam. We never post anything as you.',
            textAlign: TextAlign.center,
            style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: () => ref.read(navLauncherProvider).open(Env.termsUrl), child: const Text('Terms')),
              Text('·', style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
              TextButton(onPressed: () => ref.read(navLauncherProvider).open(Env.privacyUrl), child: const Text('Privacy')),
            ],
          ),
        ],
      ),
    );
  }
}
