import 'app_mode.dart';
import 'json_utils.dart';
import 'visit_field.dart';

enum RouteEndPreference { currentLocation, office, custom }

/// Per-mode user overrides of the ModePack defaults.
class ModeOverride {
  const ModeOverride({this.outcomes, this.visitFields, this.exportFields});

  final List<String>? outcomes;
  final List<VisitFieldDefinition>? visitFields;
  final List<String>? exportFields;

  ModeOverride copyWith({
    List<String>? outcomes,
    List<VisitFieldDefinition>? visitFields,
    List<String>? exportFields,
  }) =>
      ModeOverride(
        outcomes: outcomes ?? this.outcomes,
        visitFields: visitFields ?? this.visitFields,
        exportFields: exportFields ?? this.exportFields,
      );

  factory ModeOverride.fromJson(Map<String, dynamic> j) => ModeOverride(
        outcomes: j['outcomes'] == null ? null : strList(j['outcomes']),
        visitFields: j['visit_fields'] == null
            ? null
            : (j['visit_fields'] as List)
                .map((e) => VisitFieldDefinition.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
        exportFields: j['export_fields'] == null ? null : strList(j['export_fields']),
      );

  Map<String, dynamic> toJson() => {
        if (outcomes != null) 'outcomes': outcomes,
        if (visitFields != null) 'visit_fields': visitFields!.map((f) => f.toJson()).toList(),
        if (exportFields != null) 'export_fields': exportFields,
      };
}

class Settings {
  const Settings({
    required this.userId,
    required this.modeOverrides,
    required this.appearance,
    required this.routeEndPreference,
    this.homeLat,
    this.homeLng,
    this.customEndAddress,
    this.customEndLat,
    this.customEndLng,
  });

  final String userId;
  final double? homeLat;
  final double? homeLng;
  final Map<AppMode, ModeOverride> modeOverrides;
  final String appearance; // light | dark | system
  final RouteEndPreference routeEndPreference;
  final String? customEndAddress;
  final double? customEndLat;
  final double? customEndLng;

  ModeOverride overrideFor(AppMode m) => modeOverrides[m] ?? const ModeOverride();

  Settings copyWith({
    Map<AppMode, ModeOverride>? modeOverrides,
    String? appearance,
    RouteEndPreference? routeEndPreference,
    double? homeLat,
    double? homeLng,
    String? customEndAddress,
    double? customEndLat,
    double? customEndLng,
  }) =>
      Settings(
        userId: userId,
        homeLat: homeLat ?? this.homeLat,
        homeLng: homeLng ?? this.homeLng,
        modeOverrides: modeOverrides ?? this.modeOverrides,
        appearance: appearance ?? this.appearance,
        routeEndPreference: routeEndPreference ?? this.routeEndPreference,
        customEndAddress: customEndAddress ?? this.customEndAddress,
        customEndLat: customEndLat ?? this.customEndLat,
        customEndLng: customEndLng ?? this.customEndLng,
      );

  factory Settings.fromRow(Map<String, dynamic> r) {
    final raw = mapOf(r['mode_overrides']);
    final overrides = <AppMode, ModeOverride>{};
    for (final e in raw.entries) {
      overrides[AppMode.fromId(e.key)] = ModeOverride.fromJson(Map<String, dynamic>.from(e.value as Map));
    }
    final pref = r['route_end_preference'] as String? ?? 'current_location';
    return Settings(
      userId: r['user_id'] as String,
      homeLat: dblOrNull(r['home_lat']),
      homeLng: dblOrNull(r['home_lng']),
      modeOverrides: overrides,
      appearance: r['appearance'] as String? ?? 'system',
      routeEndPreference: switch (pref) {
        'office' => RouteEndPreference.office,
        'custom' => RouteEndPreference.custom,
        _ => RouteEndPreference.currentLocation,
      },
      customEndAddress: r['custom_end_address'] as String?,
      customEndLat: dblOrNull(r['custom_end_lat']),
      customEndLng: dblOrNull(r['custom_end_lng']),
    );
  }

  Map<String, dynamic> toUpdate() => {
        'home_lat': homeLat,
        'home_lng': homeLng,
        'mode_overrides': {for (final e in modeOverrides.entries) e.key.id: e.value.toJson()},
        'appearance': appearance,
        'route_end_preference': switch (routeEndPreference) {
          RouteEndPreference.office => 'office',
          RouteEndPreference.custom => 'custom',
          RouteEndPreference.currentLocation => 'current_location',
        },
        'custom_end_address': customEndAddress,
        'custom_end_lat': customEndLat,
        'custom_end_lng': customEndLng,
      };
}
