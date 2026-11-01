import '../core/env.dart';
import '../data/models/app_mode.dart';
import 'field_sales.dart';
import 'mode_pack.dart';
import 'yard_sales.dart';

const modePacks = <AppMode, ModePack>{
  AppMode.fieldSales: fieldSalesPack,
  AppMode.yardSales: yardSalesPack,
};

ModePack packFor(AppMode mode) => modePacks[mode]!;

/// Parses a comma-separated list of mode ids, keeping order and dropping unknowns and
/// duplicates. An empty or unusable list falls back to Yard Sales, the launch vertical.
List<AppMode> parseLaunchModes(String ids) {
  final out = <AppMode>[];
  for (final raw in ids.split(',')) {
    final m = AppMode.values.where((m) => m.id == raw.trim()).firstOrNull;
    if (m != null && !out.contains(m)) out.add(m);
  }
  return out.isEmpty ? const [AppMode.yardSales] : out;
}

/// The modes this build offers; onboarding and the drawer show only these.
final launchModes = parseLaunchModes(Env.launchModes);

/// [mode] when this build offers it, else the build's default mode. A profile saved by a
/// build with more verticals lands on one this build ships.
AppMode launchable(AppMode mode) => launchModes.contains(mode) ? mode : launchModes.first;
