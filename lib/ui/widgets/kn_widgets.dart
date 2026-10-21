import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';

/// Primary CTA with the 45° primary → primaryDim gradient (design.md §2).
class KnButton extends StatelessWidget {
  const KnButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.lime = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  /// Vibrant Lime variant for the single most important action on a screen.
  final bool lime;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final enabled = onPressed != null && !loading;
    final fg = lime ? c.onTertiary : c.onPrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.lg),
          gradient: lime
              ? null
              : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.primary, c.primaryDim]),
          color: lime ? c.tertiary : null,
          boxShadow: [BoxShadow(color: c.primaryDim.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(Rad.lg),
            child: SizedBox(
              height: compact ? 44 : 52,
              child: Center(
                child: loading
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: Sp.s2)],
                          Flexible(
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: fg)),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tonal card: depth from surface tiers, never from borders.
class KnCard extends StatelessWidget {
  const KnCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Sp.s4), this.tier = 2, this.accent});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// 0 = lowest … 3 = highest surface tier.
  final int tier;

  /// Optional left accent bar (e.g. in-progress routes).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final bg = switch (tier) {
      0 => c.surfaceLow,
      1 => c.surfaceContainer,
      2 => c.surfaceHigh,
      _ => c.surfaceHighest,
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Rad.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rad.xl),
        // The accent bar must match the content height. IntrinsicHeight gives the
        // stretched Row a bounded height inside scrolling parents.
        child: accent == null
            ? Padding(padding: padding, child: child)
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(Rad.xl)),
                      ),
                    ),
                    Expanded(child: Padding(padding: padding, child: child)),
                  ],
                ),
              ),
      ),
    );
  }
}

class KnBadge extends StatelessWidget {
  const KnBadge(this.label, {super.key, this.color, this.icon, this.onColor});
  final String label;
  final Color? color;
  final Color? onColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final bg = color ?? c.primaryContainer;
    final fg = onColor ?? (color == null ? c.onPrimaryContainer : c.surface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.s2, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Horizontal chip row used for outcome selectors and filters.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.options, required this.selected, required this.onSelected, this.allowNone = true});
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options) ...[
            ChoiceChip(
              label: Text(o),
              selected: selected == o,
              onSelected: (v) => onSelected(v ? o : (allowNone ? null : o)),
              labelStyle: TextStyle(color: selected == o ? c.onPrimaryContainer : c.onSurface),
              showCheckmark: false,
            ),
            const SizedBox(width: Sp.s2),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.s6, bottom: Sp.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.headlineSmall),
                if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: context.kn.onSurfaceVariant)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(Rad.xxl)),
              child: Icon(icon, size: 34, color: c.primary),
            ),
            const SizedBox(height: Sp.s5),
            Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: Sp.s2),
              Text(body!, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: Sp.s6), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        body: error.toString(),
        action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      );
}

/// Renders an AsyncValue with shared loading/error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e, onRetry: onRetry),
      );
}

class ProgressPill extends StatelessWidget {
  const ProgressPill(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.s3, vertical: Sp.s2),
      decoration: BoxDecoration(
        color: c.glass,
        borderRadius: BorderRadius.circular(Rad.full),
        border: Border.all(color: c.ghostBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c.tertiary), const SizedBox(width: Sp.s1)],
          Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.onSurface)),
        ],
      ),
    );
  }
}

/// Numbered circular marker used in lists and on map pins.
class NumberDot extends StatelessWidget {
  const NumberDot(this.number, {super.key, this.color, this.size = 28, this.done = false});
  final int number;
  final Color? color;
  final double size;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: done ? c.pinVisited : (color ?? c.primary), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: done
          ? Icon(Icons.check, size: size * 0.55, color: c.surface)
          : Text('$number', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.surface, fontWeight: FontWeight.w800)),
    );
  }
}

Future<T?> showKnSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scrollable = true}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scrollable,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      ),
    );

Future<bool> confirm(BuildContext context, {required String title, String? body, String confirmLabel = 'Confirm', bool destructive = false}) async {
  final c = context.kn;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive ? TextButton.styleFrom(foregroundColor: c.error) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(BuildContext context, {required String title, String? hint, String? initial, String confirmLabel = 'Save'}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: hint), textCapitalization: TextCapitalization.sentences),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(confirmLabel)),
      ],
    ),
  );
}

void toast(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        if (icon != null) ...[Icon(icon, size: 18, color: context.kn.tertiary), const SizedBox(width: Sp.s2)],
        Expanded(child: Text(message)),
      ]),
    ));
}

/// Ghost 1px line at 20% — the only border this design system allows.
class GhostDivider extends StatelessWidget {
  const GhostDivider({super.key});
  @override
  Widget build(BuildContext context) => Divider(color: context.kn.ghostBorder);
}

class KnScaffold extends StatelessWidget {
  const KnScaffold({super.key, required this.title, required this.body, this.actions, this.bottom, this.fab, this.leading});
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? fab;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions, leading: leading),
        body: body,
        bottomNavigationBar: bottom == null
            ? null
            : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, Sp.s4), child: bottom)),
        floatingActionButton: fab,
      );
}
