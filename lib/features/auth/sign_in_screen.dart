import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../state/auth_state.dart';
import '../../state/providers.dart';
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
      setState(() => _error = e.toString());
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
    final why = switch (widget.reason) {
      'report' => 'Sign in to share reports with the community.',
      'share' => 'Sign in to share routes.',
      'host' => 'Sign in to post your sale.',
      _ => 'Keep your routes across devices, share them, and report what you see.',
    };
    return KnScaffold(
      title: 'Sign in',
      body: ListView(
        padding: const EdgeInsets.all(Sp.s5),
        children: [
          Text(why, style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: Sp.s6),
          if (!_sent) ...[
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email')),
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
            TextField(controller: _code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '6-digit code')),
            const SizedBox(height: Sp.s3),
            KnButton(label: 'Verify code', loading: _busy, onPressed: () => _run(() => auth.verifyEmailOtp(_email.text.trim(), _code.text.trim()))),
            TextButton(onPressed: () => setState(() => _sent = false), child: const Text('Use a different email')),
          ],
          const SizedBox(height: Sp.s6),
          Row(children: [const Expanded(child: GhostDivider()), Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.s3), child: Text('or', style: t.labelMedium)), const Expanded(child: GhostDivider())]),
          const SizedBox(height: Sp.s6),
          OutlinedButton.icon(onPressed: _busy ? null : () => _run(() => auth.signInWithOAuth(OAuthProvider.apple)), icon: const Icon(Icons.apple), label: const Text('Continue with Apple')),
          const SizedBox(height: Sp.s3),
          OutlinedButton.icon(onPressed: _busy ? null : () => _run(() => auth.signInWithOAuth(OAuthProvider.google)), icon: const Icon(Icons.g_mobiledata), label: const Text('Continue with Google')),
          if (_error != null) ...[const SizedBox(height: Sp.s4), Text(_error!, style: t.bodySmall?.copyWith(color: c.error))],
        ],
      ),
    );
  }
}
