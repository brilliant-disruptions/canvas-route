import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/errors.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/feature_request.dart';
import '../../state/auth_state.dart';
import '../../state/feature_requests_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../settings/paywall_sheet.dart';

class FeatureRequestsScreen extends ConsumerStatefulWidget {
  const FeatureRequestsScreen({super.key});
  @override
  ConsumerState<FeatureRequestsScreen> createState() => _State();
}

class _State extends ConsumerState<FeatureRequestsScreen> {
  String _sort = 'upvotes';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final paying = ref.watch(paysForAnythingProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feature requests'),
          bottom: const TabBar(tabs: [Tab(text: 'All requests'), Tab(text: 'My requests')]),
          actions: [
            // Free users get the reason and the upgrade, not a silently disabled button,
            // where an upgrade can be bought. Elsewhere the board is read-and-upvote.
            if (paying || ref.watch(canBuyProProvider))
              TextButton.icon(
              onPressed: () => paying
                  ? showKnSheet(context, builder: (_) => const _NewRequestSheet())
                  : showPaywall(
                      context,
                      ref.read(modePackProvider),
                      reason: 'Suggesting features is part of ${ref.read(modePackProvider).proLabel}. Anyone can upvote.',
                    ),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
          ],
        ),
        body: TabBarView(children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s4, 0),
              child: Row(children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      ChoiceChip(label: const Text('All'), selected: _category == null, showCheckmark: false, onSelected: (_) => setState(() => _category = null)),
                      for (final c in featureRequestCategories) ...[
                        const SizedBox(width: Sp.s2),
                        ChoiceChip(label: Text(statusLabel(c).replaceAll('_', ' ')), selected: _category == c, showCheckmark: false, onSelected: (_) => setState(() => _category = c)),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(width: Sp.s1),
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'upvotes', child: Text('Upvotes')),
                    PopupMenuItem(value: 'status', child: Text('Status')),
                    PopupMenuItem(value: 'date', child: Text('Date submitted')),
                  ],
                ),
              ]),
            ),
            Expanded(child: _Board(query: (sort: _sort, category: _category))),
          ]),
          const _Mine(),
        ]),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.query});
  final BoardQuery query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(boardProvider(query));
    return AsyncView(
      value: list,
      onRetry: () => ref.invalidate(boardProvider(query)),
      data: (items) => items.isEmpty
          ? const EmptyState(icon: Icons.lightbulb_outline, title: 'Nothing here yet')
          : ListView.separated(
              padding: const EdgeInsets.all(Sp.s4),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: Sp.s3),
              itemBuilder: (_, i) => RequestCard(request: items[i], onChanged: () => ref.invalidate(boardProvider(query))),
            ),
    );
  }
}

class _Mine extends ConsumerWidget {
  const _Mine();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myRequestsProvider);
    return AsyncView(
      value: list,
      onRetry: () => ref.invalidate(myRequestsProvider),
      data: (items) => items.isEmpty
          ? const EmptyState(icon: Icons.lightbulb_outline, title: 'You haven\'t submitted anything', body: 'Paid plans can submit requests. Anyone can upvote.')
          : ListView.separated(
              padding: const EdgeInsets.all(Sp.s4),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: Sp.s3),
              itemBuilder: (_, i) => RequestCard(request: items[i], onChanged: () => ref.invalidate(myRequestsProvider)),
            ),
    );
  }
}

Color statusColor(BuildContext context, String s) {
  final c = context.kn;
  return switch (s) {
    'to_do' => c.statusTodo,
    'development' => c.statusDevelopment,
    'testing' => c.statusTesting,
    'future_release' => c.statusFutureRelease,
    'done' => c.statusDone,
    _ => c.statusBacklog,
  };
}

class RequestCard extends ConsumerWidget {
  const RequestCard({super.key, required this.request, required this.onChanged});
  final FeatureRequest request;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final voted = ref.watch(myUpvotesProvider).value?.contains(request.id) ?? false;
    final uid = ref.watch(currentUserIdProvider);
    return KnCard(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request.title, style: t.titleMedium),
            const SizedBox(height: Sp.s1),
            Wrap(spacing: Sp.s2, children: [
              KnBadge(statusLabel(request.status), color: statusColor(context, request.status), onColor: c.surface),
              KnBadge(request.category.replaceAll('_', ' '), color: c.surfaceHighest, onColor: c.onSurface),
            ]),
            if (request.summary != null) ...[const SizedBox(height: Sp.s2), Text(request.summary!, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))],
          ]),
        ),
        // A pill you can see you've pressed: lime with the count when voted.
        Column(children: [
          Semantics(
            button: true,
            selected: voted,
            label: voted ? 'Remove upvote, ${request.upvoteCount} votes' : 'Upvote, ${request.upvoteCount} votes',
            child: Material(
              color: voted ? c.tertiary : c.surfaceHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Rad.lg),
                side: BorderSide(color: voted ? c.tertiary : c.ghostBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.lg),
                onTap: uid == null
                    ? null
                    : () async {
                        final repo = ref.read(featureRequestRepoProvider);
                        voted ? await repo.unvote(uid, request.id) : await repo.upvote(uid, request.id);
                        ref.invalidate(myUpvotesProvider);
                        onChanged();
                      },
                child: SizedBox(
                  width: 56,
                  height: 60,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.arrow_upward_rounded, size: 20, color: voted ? c.onTertiary : c.onSurface),
                    Text(
                      '${request.upvoteCount}',
                      style: t.titleMedium?.copyWith(color: voted ? c.onTertiary : c.onSurface),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: Sp.s1),
          Text(
            '${request.orgCount} org${request.orgCount == 1 ? '' : 's'}',
            style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ]),
      ]),
    );
  }
}

class _NewRequestSheet extends ConsumerStatefulWidget {
  const _NewRequestSheet();
  @override
  ConsumerState<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends ConsumerState<_NewRequestSheet> {
  final _c = {for (final k in ['title', 'problem', 'workaround', 'vision']) k: TextEditingController()};
  String _category = 'general';
  String? _role;
  String? _frequency;
  String? _impact;
  bool _interview = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s6),
        children: [
          Text('Describe your world', style: t.headlineSmall),
          Text('We\'re not looking for solutions. What are you trying to get done, and what\'s in the way?', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: Sp.s4),
          TextField(controller: _c['title'], decoration: const InputDecoration(labelText: 'Title *')),
          const SizedBox(height: Sp.s3),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final k in featureRequestCategories) DropdownMenuItem(value: k, child: Text(k.replaceAll('_', ' ')))],
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: Sp.s3),
          TextField(controller: _c['problem'], maxLines: 3, decoration: const InputDecoration(labelText: 'What are you trying to accomplish, and what\'s getting in your way?')),
          const SizedBox(height: Sp.s3),
          TextField(controller: _c['workaround'], maxLines: 2, decoration: const InputDecoration(labelText: 'How are you solving this right now?')),
          const SizedBox(height: Sp.s3),
          TextField(controller: _c['vision'], maxLines: 2, decoration: const InputDecoration(labelText: 'What would success look like?')),
          const SizedBox(height: Sp.s3),
          _pick('Your role', ['field_rep', 'team_lead', 'manager', 'owner'], _role, (v) => setState(() => _role = v)),
          _pick('How often does this come up?', ['daily', 'few_times_week', 'weekly', 'occasionally'], _frequency, (v) => setState(() => _frequency = v)),
          _pick('Impact', ['lost_time', 'lost_deals', 'data_accuracy', 'team_visibility'], _impact, (v) => setState(() => _impact = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('I\'m open to a 20-minute interview'), value: _interview, onChanged: (v) => setState(() => _interview = v)),
          const SizedBox(height: Sp.s4),
          KnButton(
            label: 'Submit',
            lime: true,
            loading: _busy,
            onPressed: () async {
              if (_c['title']!.text.trim().isEmpty) return;
              setState(() => _busy = true);
              final uid = ref.read(currentUserIdProvider)!;
              final email = ref.read(profileProvider).value?.email;
              try {
                await ref.read(featureRequestRepoProvider).create({
                  'user_id': uid,
                  'title': _c['title']!.text.trim(),
                  'category': _category,
                  'problem': _c['problem']!.text.trim(),
                  'workaround': _c['workaround']!.text.trim(),
                  'vision': _c['vision']!.text.trim(),
                  'role': _role,
                  'frequency': _frequency,
                  'impact': _impact,
                  'interview_opt_in': _interview,
                  'interview_email': _interview ? email : null,
                });
                ref.invalidate(myRequestsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  toast(context, 'Thanks — your request is in the queue', icon: Icons.check);
                }
              } catch (e) {
                if (context.mounted) {
                  setState(() => _busy = false);
                  toast(context, 'Couldn\'t submit. ${friendlyError(e)}');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _pick(String label, List<String> opts, String? v, ValueChanged<String?> on) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.s3),
        child: DropdownButtonFormField<String>(
          initialValue: v,
          decoration: InputDecoration(labelText: label),
          items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o.replaceAll('_', ' ')))],
          onChanged: on,
        ),
      );
}
