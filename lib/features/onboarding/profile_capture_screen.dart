import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../state/profile_state.dart';
import '../../ui/widgets/kn_widgets.dart';

class ProfileCaptureScreen extends ConsumerStatefulWidget {
  const ProfileCaptureScreen({super.key});
  @override
  ConsumerState<ProfileCaptureScreen> createState() => _State();
}

class _State extends ConsumerState<ProfileCaptureScreen> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _title = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(profileProvider.notifier).patch({
      'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
      'company': _company.text.trim().isEmpty ? null : _company.text.trim(),
      'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
    });
    if (mounted) context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final isSales = ref.watch(modePackProvider).id.name == 'fieldSales';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Sp.s6),
          children: [
            const SizedBox(height: Sp.s6),
            Text('Help us personalize\nyour experience', style: t.displaySmall),
            const SizedBox(height: Sp.s2),
            Text('Takes 30 seconds. Completely optional.', style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Sp.s8),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), textCapitalization: TextCapitalization.words),
            const SizedBox(height: Sp.s3),
            if (isSales) ...[
              TextField(controller: _company, decoration: const InputDecoration(labelText: 'Company')),
              const SizedBox(height: Sp.s3),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: Sp.s3),
            ],
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: Sp.s8),
            KnButton(label: 'Save & Start', onPressed: _save, loading: _saving, lime: true),
            const SizedBox(height: Sp.s3),
            TextButton(onPressed: () => context.go('/map'), child: const Text('Skip')),
          ],
        ),
      ),
    );
  }
}
