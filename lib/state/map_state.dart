import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/logic/errors.dart';
import '../data/models/business.dart';
import '../data/models/draft_stop.dart';
import '../data/models/route_model.dart';
import '../data/models/stop.dart';
import 'profile_state.dart';
import 'providers.dart';

enum MapViewMode { map, list }

class MapState {
  const MapState({
    this.query = '',
    this.results = const [],
    this.draftStops = const [],
    this.viewMode = MapViewMode.map,
    this.editingRouteId,
    this.editingRouteName,
    this.selectedDay,
    this.productFilter,
    this.huntFilter = const {},
    this.searching = false,
    this.error,
  });

  final String query;
  final List<Business> results;
  final List<DraftStop> draftStops;
  final MapViewMode viewMode;
  final String? editingRouteId;
  final String? editingRouteName;

  /// Yard Sales weekend selector; null = any day.
  final DateTime? selectedDay;

  /// Card Drops product filter chip; null = any.
  final String? productFilter;

  /// Pin categories the user is hunting for; empty = all.
  final Set<String> huntFilter;
  final bool searching;
  final String? error;

  bool isDraft(Business b) => draftStops.any((d) => d.business.identity == b.identity);
  int draftIndex(Business b) => draftStops.indexWhere((d) => d.business.identity == b.identity);

  MapState copyWith({
    String? query,
    List<Business>? results,
    List<DraftStop>? draftStops,
    MapViewMode? viewMode,
    String? editingRouteId,
    String? editingRouteName,
    DateTime? selectedDay,
    String? productFilter,
    Set<String>? huntFilter,
    bool? searching,
    String? error,
    bool clearEditing = false,
    bool clearDay = false,
    bool clearProduct = false,
    bool clearError = false,
  }) =>
      MapState(
        query: query ?? this.query,
        results: results ?? this.results,
        draftStops: draftStops ?? this.draftStops,
        viewMode: viewMode ?? this.viewMode,
        editingRouteId: clearEditing ? null : editingRouteId ?? this.editingRouteId,
        editingRouteName: clearEditing ? null : editingRouteName ?? this.editingRouteName,
        selectedDay: clearDay ? null : selectedDay ?? this.selectedDay,
        productFilter: clearProduct ? null : productFilter ?? this.productFilter,
        huntFilter: huntFilter ?? this.huntFilter,
        searching: searching ?? this.searching,
        error: clearError ? null : error ?? this.error,
      );
}

class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() {
    final mode = ref.watch(activeModeProvider);
    final prefs = ref.read(localPrefsProvider);
    return MapState(draftStops: prefs.draftStopsFor(mode));
  }

  void _persist() {
    ref.read(localPrefsProvider).setDraftStops(ref.read(activeModeProvider), state.draftStops);
  }

  Future<void> search(String query, double lat, double lng) async {
    final q = query.trim();
    if (q.isEmpty) return;
    state = state.copyWith(query: q, searching: true, clearError: true);
    try {
      final pack = ref.read(modePackProvider);
      final preset = pack.placesQueryPreset;
      final results = await ref.read(placesServiceProvider).textSearch(
            preset == null || q.toLowerCase().contains(preset) ? q : '$q $preset',
            lat,
            lng,
          );
      // Keep already-added stops visible even if the new search drops them.
      final merged = <String, Business>{for (final b in results) b.identity: b};
      state = state.copyWith(results: merged.values.toList(), searching: false);
    } catch (e) {
      state = state.copyWith(searching: false, error: 'Search failed. ${friendlyError(e)}');
    }
  }

  void clearSearch() => state = state.copyWith(query: '', results: const []);
  void setViewMode(MapViewMode m) => state = state.copyWith(viewMode: m);
  void setDay(DateTime? d) => state = d == null ? state.copyWith(clearDay: true) : state.copyWith(selectedDay: d);
  void setProductFilter(String? p) =>
      state = p == null ? state.copyWith(clearProduct: true) : state.copyWith(productFilter: p);
  void setHunt(Set<String> categories) => state = state.copyWith(huntFilter: categories);
  void showResults(List<Business> results) => state = state.copyWith(results: results);

  void addDraft(Business b) {
    if (state.isDraft(b)) return;
    state = state.copyWith(draftStops: [...state.draftStops, DraftStop(id: const Uuid().v4(), business: b)]);
    _persist();
  }

  void toggleDraft(Business b) => state.isDraft(b) ? removeDraftByBusiness(b) : addDraft(b);

  void removeDraft(String id) {
    state = state.copyWith(draftStops: state.draftStops.where((d) => d.id != id).toList());
    _persist();
  }

  void removeDraftByBusiness(Business b) {
    state = state.copyWith(draftStops: state.draftStops.where((d) => d.business.identity != b.identity).toList());
    _persist();
  }

  void updateDraft(String id, Business Function(Business) fn) {
    state = state.copyWith(
      draftStops: state.draftStops.map((d) => d.id == id ? d.copyWith(business: fn(d.business)) : d).toList(),
    );
    _persist();
  }

  void reorderDrafts(int oldIndex, int newIndex) {
    final list = [...state.draftStops];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(draftStops: list);
    _persist();
  }

  void setDrafts(List<DraftStop> drafts) {
    state = state.copyWith(draftStops: drafts);
    _persist();
  }

  void addManual({
    required String name,
    required double lat,
    required double lng,
    required String address,
    DateTime? opensAt,
    DateTime? closesAt,
    String? listingUrl,
  }) =>
      addDraft(Business(
        name: name,
        address: address,
        lat: lat,
        lng: lng,
        source: listingUrl != null ? StopSource.listingLink : StopSource.manual,
        opensAt: opensAt,
        closesAt: closesAt,
        listingUrl: listingUrl,
      ));

  void clearDrafts() {
    state = state.copyWith(draftStops: const [], clearEditing: true);
    _persist();
  }

  void editRoute(RouteModel route) {
    state = state.copyWith(
      editingRouteId: route.id,
      editingRouteName: route.name,
      draftStops: route.stops.map((s) => DraftStop(id: s.id, business: s.toBusiness())).toList(),
      query: '',
      results: const [],
    );
    _persist();
  }

  void clearEditing() => state = state.copyWith(clearEditing: true);
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);
