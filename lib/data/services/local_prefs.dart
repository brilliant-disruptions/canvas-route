import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_mode.dart';
import '../models/draft_stop.dart';

/// Device-local conveniences. Nothing here is source of truth; the profile row is.
class LocalPrefs {
  LocalPrefs(this._p);
  final SharedPreferences _p;

  static Future<LocalPrefs> load() async => LocalPrefs(await SharedPreferences.getInstance());

  bool get hasOnboarded => _p.getBool('hasOnboarded') ?? false;
  Future<void> setHasOnboarded(bool v) => _p.setBool('hasOnboarded', v);

  AppMode get cachedMode => AppMode.fromId(_p.getString('activeMode'));
  Future<void> setCachedMode(AppMode m) => _p.setString('activeMode', m.id);

  String get appearance => _p.getString('appearance') ?? 'system';
  Future<void> setAppearance(String v) => _p.setString('appearance', v);

  List<DraftStop> draftStopsFor(AppMode m) {
    final raw = _p.getString('draft_${m.id}');
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => DraftStop.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setDraftStops(AppMode m, List<DraftStop> stops) =>
      _p.setString('draft_${m.id}', jsonEncode(stops.map((s) => s.toJson()).toList()));

  String? get lastSeenClipboardUrl => _p.getString('lastClipboardUrl');
  Future<void> setLastSeenClipboardUrl(String v) => _p.setString('lastClipboardUrl', v);
}
