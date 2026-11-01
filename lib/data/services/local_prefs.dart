import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_mode.dart';
import '../models/draft_stop.dart';

/// Device-local conveniences. Nothing here is source of truth; the profile row is.
///
/// Backed by SharedPreferences on devices, or by memory for the demo build
/// (where browser storage may be unavailable and every load should start fresh).
class LocalPrefs {
  LocalPrefs(SharedPreferences prefs)
      : _p = prefs,
        _mem = null;

  LocalPrefs.memory()
      : _p = null,
        _mem = {};

  final SharedPreferences? _p;
  final Map<String, Object>? _mem;

  /// Forgets everything on this device (after an account is deleted).
  Future<void> clear() async {
    await _p?.clear();
    _mem?.clear();
  }

  static Future<LocalPrefs> load() async => LocalPrefs(await SharedPreferences.getInstance());

  String? _str(String k) => _p?.getString(k) ?? _mem?[k] as String?;
  bool? _bool(String k) => _p?.getBool(k) ?? _mem?[k] as bool?;
  Future<void> _put(String k, Object v) async {
    final p = _p;
    if (p == null) {
      _mem![k] = v;
    } else if (v is bool) {
      await p.setBool(k, v);
    } else {
      await p.setString(k, v as String);
    }
  }

  bool get hasOnboarded => _bool('hasOnboarded') ?? false;
  Future<void> setHasOnboarded(bool v) => _put('hasOnboarded', v);

  /// The map's first-run hint pointing at the one-tap planner.

  /// Friday weekend heads-up: null until the user has been asked.
  bool? get weekendDigest => _bool('weekendDigest');
  Future<void> setWeekendDigest(bool v) => _put('weekendDigest', v);

  AppMode get cachedMode => AppMode.fromId(_str('activeMode'));
  Future<void> setCachedMode(AppMode m) => _put('activeMode', m.id);

  String get appearance => _str('appearance') ?? 'system';
  Future<void> setAppearance(String v) => _put('appearance', v);

  List<DraftStop> draftStopsFor(AppMode m) {
    final raw = _str('draft_${m.id}');
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => DraftStop.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setDraftStops(AppMode m, List<DraftStop> stops) =>
      _put('draft_${m.id}', jsonEncode(stops.map((s) => s.toJson()).toList()));

  String? get lastSeenClipboardUrl => _str('lastClipboardUrl');
  Future<void> setLastSeenClipboardUrl(String v) => _put('lastClipboardUrl', v);

  /// "Still going?" prompts already answered or dismissed, as checkInKey values.
  Set<String> get checkInsDone => (_str('checkInsDone') ?? '').split('\n').where((s) => s.isNotEmpty).toSet();
  Future<void> addCheckInDone(String key) {
    // Keep the last 50; old days don't matter.
    final keys = [...checkInsDone, key];
    return _put('checkInsDone', keys.skip(keys.length > 50 ? keys.length - 50 : 0).join('\n'));
  }
}
