import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/logic/errors.dart';
import '../../core/logic/geo.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/profile.dart';
import '../../data/models/team.dart';
import '../../modes/mode_pack.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/team_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Managers see each rep's week; reps see who's on the team. Joining takes a code.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(myTeamProvider);
    return KnScaffold(
      title: 'Team',
      body: AsyncView(
        value: team,
        onRetry: () => ref.invalidate(myTeamProvider),
        data: (t) => t == null ? const _NoTeam() : _TeamView(team: t),
      ),
    );
  }
}

class _NoTeam extends ConsumerStatefulWidget {
  const _NoTeam();
  @override
  ConsumerState<_NoTeam> createState() => _NoTeamState();
}

class _NoTeamState extends ConsumerState<_NoTeam> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(myTeamProvider);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (ref.read(isAnonymousProvider)) {
      context.push('/signin?reason=team');
      return;
    }
    final plan = ref.read(profileProvider).value?.plan;
    if (plan != Plan.team) {
      final seats = await promptText(context, title: 'How many reps, including you?', initial: '3', confirmLabel: 'Continue to checkout');
      final n = int.tryParse(seats ?? '');
      if (n == null || !mounted) return;
      await _run(() async {
        final url = await ref.read(billingServiceProvider).checkoutUrl(ModePack.teamProductId, seats: n);
        await ref.read(navLauncherProvider).open(url.toString());
        if (mounted) toast(context, 'Finish checkout in your browser, then come back to name your team.');
      });
      return;
    }
    final name = await promptText(context, title: 'Team name', confirmLabel: 'Create');
    if (name == null || name.trim().isEmpty) return;
    await _run(() => ref.read(teamRepoProvider).create(name.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Sp.s4),
      children: [
        Text('Work a territory together', style: t.headlineSmall),
        const SizedBox(height: Sp.s2),
        Text(
          'See who already knocked on a door before you go, and give managers each rep\'s week at a glance.',
          style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        ),
        const SectionHeader('Join your team'),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), LengthLimitingTextInputFormatter(8)],
          decoration: const InputDecoration(labelText: 'Team code from your manager'),
        ),
        const SizedBox(height: Sp.s3),
        KnButton(
          label: 'Join',
          icon: Icons.group_add_outlined,
          loading: _busy,
          onPressed: () {
            if (ref.read(isAnonymousProvider)) {
              context.push('/signin?reason=team');
              return;
            }
            if (_code.text.trim().length < 4) return;
            _run(() => ref.read(teamRepoProvider).join(_code.text.trim()));
          },
        ),
        const SectionHeader('Managing reps?'),
        OutlinedButton.icon(
          onPressed: _busy ? null : _create,
          icon: const Icon(Icons.groups_outlined),
          label: const Text('Start a team'),
        ),
      ],
    );
  }
}

class _TeamView extends ConsumerStatefulWidget {
  const _TeamView({required this.team});
  final Team team;
  @override
  ConsumerState<_TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends ConsumerState<_TeamView> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final roster = ref.watch(teamRosterProvider).value ?? const <TeamMember>[];
    final me = ref.watch(currentUserIdProvider);
    final manager = roster.any((m) => m.userId == me && m.isManager);
    final activity = manager ? ref.watch(teamActivityProvider(_days)) : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teamRosterProvider);
        ref.invalidate(teamActivityProvider(_days));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s6),
        children: [
          SectionHeader(widget.team.name, subtitle: '${roster.length} ${roster.length == 1 ? 'member' : 'members'}'),
          if (manager)
            KnCard(
              tier: 3,
              accent: c.tertiary,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invite reps with this code', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        Text(widget.team.joinCode, style: t.headlineMedium?.copyWith(letterSpacing: 4, color: c.tertiary)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'New code (the old one stops working)',
                    icon: const Icon(Icons.autorenew),
                    onPressed: () async {
                      if (!await confirm(context, title: 'Issue a new code?', body: 'The current code stops working. Reps already on the team stay.', confirmLabel: 'New code')) return;
                      try {
                        await ref.read(teamRepoProvider).rotateCode();
                        ref.invalidate(myTeamProvider);
                      } catch (e) {
                        if (context.mounted) toast(context, friendlyError(e));
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Share code',
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => ref.read(shareServiceProvider).shareText(
                          'Join ${widget.team.name} on CanvasRoute: open Team in the menu and enter ${widget.team.joinCode}',
                          subject: 'Join ${widget.team.name}',
                        ),
                  ),
                ],
              ),
            ),
          if (activity != null) ...[
            SectionHeader(
              'Activity',
              trailing: SegmentedButton<int>(
                segments: const [ButtonSegment(value: 7, label: Text('7d')), ButtonSegment(value: 30, label: Text('30d'))],
                selected: {_days},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
            ),
            AsyncView(
              value: activity,
              onRetry: () => ref.invalidate(teamActivityProvider(_days)),
              data: (reps) => Column(
                children: [
                  for (final r in reps) ...[
                    _RepCard(rep: r, winOutcomes: pack.winOutcomes, winNoun: pack.winNoun),
                    const SizedBox(height: Sp.s2),
                  ],
                ],
              ),
            ),
          ],
          const SectionHeader('Members'),
          for (final m in roster)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase())),
              title: Text(m.userId == me ? '${m.name} (you)' : m.name),
              subtitle: Text(m.isManager ? 'Manager' : 'Rep'),
              trailing: manager && !m.isManager
                  ? IconButton(
                      tooltip: 'Remove from team',
                      icon: Icon(Icons.person_remove_outlined, color: c.error),
                      onPressed: () async {
                        if (!await confirm(context, title: 'Remove ${m.name}?', body: 'They keep their own routes and visits; they just leave the team.', confirmLabel: 'Remove', destructive: true)) return;
                        try {
                          await ref.read(teamRepoProvider).remove(m.userId);
                        } catch (e) {
                          if (context.mounted) toast(context, friendlyError(e));
                        }
                        ref.invalidate(teamRosterProvider);
                        ref.invalidate(teamActivityProvider(_days));
                      },
                    )
                  : null,
            ),
          const SizedBox(height: Sp.s4),
          TextButton(
            onPressed: () async {
              final owner = widget.team.ownerId == me;
              if (!await confirm(
                context,
                title: owner ? 'Delete ${widget.team.name}?' : 'Leave ${widget.team.name}?',
                body: owner ? 'Everyone leaves the team. Routes and visits stay with each rep.' : 'Your routes and visits stay with you.',
                confirmLabel: owner ? 'Delete team' : 'Leave',
                destructive: true,
              )) {
                return;
              }
              try {
                await ref.read(teamRepoProvider).leave();
              } catch (e) {
                if (context.mounted) toast(context, friendlyError(e));
                return;
              }
              ref.invalidate(myTeamProvider);
            },
            child: Text(widget.team.ownerId == me ? 'Delete team' : 'Leave team', style: TextStyle(color: c.error)),
          ),
        ],
      ),
    );
  }
}

class _RepCard extends StatelessWidget {
  const _RepCard({required this.rep, required this.winOutcomes, required this.winNoun});
  final RepActivity rep;
  final List<String> winOutcomes;
  final String winNoun;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final wins = rep.count(winOutcomes);
    final quiet = rep.lastVisitAt == null || DateTime.now().difference(rep.lastVisitAt!).inDays >= 3;
    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: t.titleLarge),
              Text(label, style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
            ],
          ),
        );
    return KnCard(
      tier: 2,
      accent: quiet ? c.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(rep.name, style: t.titleMedium)),
              Text(
                rep.lastVisitAt == null ? 'No visits' : 'Last visit ${DateFormat.MMMd().add_jm().format(rep.lastVisitAt!)}',
                style: t.bodySmall?.copyWith(color: quiet ? c.error : c.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Sp.s2),
          Row(
            children: [
              stat('${rep.visits}', 'visits'),
              stat('$wins', '${winNoun}s'),
              stat(rep.visits == 0 ? '—' : '${(wins * 100 / rep.visits).round()}%', 'hit rate'),
              stat(metersToMiles(rep.meters.toDouble()).toStringAsFixed(0), 'miles'),
            ],
          ),
        ],
      ),
    );
  }
}
