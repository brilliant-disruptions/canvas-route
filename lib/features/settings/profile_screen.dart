import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/errors.dart';
import '../../core/logic/trust.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/visits_state.dart';
import '../../ui/widgets/kn_widgets.dart';

const _industries = ['SaaS', 'Insurance', 'Real estate', 'Telecom', 'Solar / Energy', 'Payments', 'Food & beverage', 'Other'];
const _teamSizes = ['Just me', '2–5', '6–20', '21–100', '100+'];
const _useCases = ['Prospecting', 'Follow-ups', 'Both'];
const _crms = ['None', 'HubSpot', 'Salesforce', 'Pipedrive', 'Zoho', 'Other'];
const _heard = ['App Store', 'Referral', 'Search', 'Social', 'Other'];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _c = <String, TextEditingController>{};
  final _pick = <String, String?>{};
  bool _init = false;
  bool _saving = false;

  TextEditingController _ctrl(String k, String? v) => _c.putIfAbsent(k, () => TextEditingController(text: v));

  Future<void> _save() async {
    setState(() => _saving = true);
    String? s(String k) => _c[k]?.text.trim().isEmpty ?? true ? null : _c[k]!.text.trim();
    final patch = <String, dynamic>{
      'name': s('name'), 'title': s('title'), 'company': s('company'), 'email': s('email'), 'phone': s('phone'),
      'handle': s('handle')?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), ''),
      'office_address': s('office'), ..._pick.map((k, v) => MapEntry(k, v)),
    };
    final office = s('office');
    if (office != null) {
      final geo = await ref.read(placesServiceProvider).geocode(office);
      if (geo != null) {
        patch['office_address'] = geo.formatted;
        patch['office_lat'] = geo.lat;
        patch['office_lng'] = geo.lng;
      }
    }
    try {
      await ref.read(profileProvider.notifier).patch(patch);
      if (mounted) toast(context, 'Profile saved', icon: Icons.check);
    } catch (e) {
      if (mounted) toast(context, 'Couldn\'t save. ${friendlyError(e)}');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider).value;
    final pack = ref.watch(modePackProvider);
    if (p == null) return const Scaffold(body: LoadingView());
    if (!_init) {
      _pick['industry'] = p.industry;
      _pick['team_size'] = p.teamSize;
      _pick['use_case'] = p.useCase;
      _pick['crm'] = p.crm;
      _pick['acquisition'] = p.acquisition;
      _init = true;
    }
    final isSales = pack.profileAsksCompany;
    final visits = ref.watch(allVisitsProvider).value ?? const [];

    Widget picker(String key, String label, List<String> opts) => DropdownButtonFormField<String>(
          initialValue: _pick[key],
          decoration: InputDecoration(labelText: label),
          items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => _pick[key] = v),
        );

    return KnScaffold(
      title: 'Profile',
      bottom: KnButton(label: 'Save', loading: _saving, onPressed: _save),
      body: ListView(
        padding: const EdgeInsets.all(Sp.s4),
        children: [
          _ImpactCard(
            initial: (p.name ?? p.handle ?? 'C').characters.first.toUpperCase(),
            trustScore: p.trustScore,
            showTrust: pack.hasCommunity,
            visits: visits.length,
            routes: visits.map((v) => v.routeId).toSet().length,
          ),
          const SizedBox(height: Sp.s5),
          TextField(controller: _ctrl('name', p.name), decoration: const InputDecoration(labelText: 'Name'), textCapitalization: TextCapitalization.words),
          const SizedBox(height: Sp.s3),
          if (pack.hasCommunity) ...[
            TextField(controller: _ctrl('handle', p.handle), decoration: const InputDecoration(labelText: 'Handle', prefixText: '@', helperText: 'Shown on your reports and shared routes')),
            const SizedBox(height: Sp.s3),
          ],
          TextField(controller: _ctrl('email', p.email), decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: Sp.s3),
          TextField(controller: _ctrl('phone', p.phone), decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
          if (isSales) ...[
            const SizedBox(height: Sp.s3),
            TextField(controller: _ctrl('title', p.title), decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: Sp.s3),
            TextField(controller: _ctrl('company', p.company), decoration: const InputDecoration(labelText: 'Company')),
            const SizedBox(height: Sp.s3),
            TextField(controller: _ctrl('office', p.officeAddress), decoration: const InputDecoration(labelText: 'Office address', helperText: 'Validated when you save')),
            const SectionHeader('Help us improve CanvasRoute', subtitle: 'Optional'),
            picker('industry', 'Industry', _industries),
            const SizedBox(height: Sp.s3),
            picker('team_size', 'Team size', _teamSizes),
            const SizedBox(height: Sp.s3),
            picker('use_case', 'Primary use case', _useCases),
            const SizedBox(height: Sp.s3),
            picker('crm', 'CRM you use', _crms),
            const SizedBox(height: Sp.s3),
          ] else
            const SizedBox(height: Sp.s3),
          picker('acquisition', 'How did you hear about us?', _heard),
          const SizedBox(height: Sp.s6),
        ],
      ),
    );
  }
}

/// Who you are here: your trust level (and what it unlocks) plus what you've logged.
class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.initial,
    required this.trustScore,
    required this.showTrust,
    required this.visits,
    required this.routes,
  });

  final String initial;
  final int trustScore;
  final bool showTrust;
  final int visits;
  final int routes;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final standing = trustStanding(trustScore);
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: t.headlineMedium?.copyWith(color: c.tertiary)),
            Text(label, style: t.labelMedium?.copyWith(color: c.onSurfaceVariant)),
          ]),
        );
    return KnCard(
      tier: 3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: c.primaryContainer,
            child: Text(initial, style: t.headlineSmall?.copyWith(color: c.onPrimaryContainer)),
          ),
          const SizedBox(width: Sp.s3),
          if (showTrust)
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.verified_outlined, size: 18, color: c.tertiary),
                  const SizedBox(width: Sp.s1),
                  Text('${standing.label} reporter', style: t.titleMedium),
                  const Spacer(),
                  Text('$trustScore', style: t.titleMedium?.copyWith(color: c.tertiary)),
                ]),
                const SizedBox(height: Sp.s2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Rad.full),
                  child: LinearProgressIndicator(
                    value: standing.progress(trustScore),
                    minHeight: 6,
                    color: c.tertiary,
                    backgroundColor: c.surfaceLow,
                  ),
                ),
                const SizedBox(height: Sp.s1),
                Text(
                  standing.next == null ? 'Top level' : '${standing.next! - trustScore} to the next level',
                  style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ]),
            )
          else
            Expanded(child: Text('Your activity', style: t.titleMedium)),
        ]),
        if (showTrust) ...[
          const SizedBox(height: Sp.s3),
          Text(standing.unlock, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
        const SizedBox(height: Sp.s3),
        const GhostDivider(),
        const SizedBox(height: Sp.s3),
        Row(children: [stat('$visits', 'visits logged'), stat('$routes', 'routes run')]),
      ]),
    );
  }
}
