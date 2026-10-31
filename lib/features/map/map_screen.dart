import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../app/shell.dart';
import '../../core/logic/geo.dart';
import '../../core/logic/pin_labels.dart';
import '../../core/logic/restock.dart';
import '../../core/logic/spotlight.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/app_mode.dart';
import '../../data/models/business.dart';
import '../../data/models/pin.dart';
import '../../data/models/report.dart';
import '../../data/models/store_summary.dart';
import '../../data/models/stop.dart';
import '../../data/services/listing_link.dart';
import '../../modes/mode_pack.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/location_state.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/map/pin_icons.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../community/pin_sheet.dart';
import 'business_sheet.dart';
import 'draft_tray.dart';
import 'manual_stop_sheet.dart';
import 'spotlight_deck.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with WidgetsBindingObserver, PinIconsMixin {
  GoogleMapController? _map;
  final _search = TextEditingController();
  LatLng? _center;
  String? _clipboardUrl;
  bool _movedToUser = false;
  String? _quickStarting;

  /// Report ids already on screen; null until the stream's first snapshot.
  Set<String>? _seenReports;
  ({Pin pin, String status})? _liveDrop;
  Timer? _liveDropTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveDropTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    if (!ref.read(modePackProvider).hasSource(StopSourceId.listingLink)) return;
    final url = await ListingLink.readClipboardUrl();
    final prefs = ref.read(localPrefsProvider);
    if (url != null && url != prefs.lastSeenClipboardUrl && mounted) setState(() => _clipboardUrl = url);
  }

  LatLng get _centerOrDefault {
    if (_center != null) return _center!;
    final c = ref.read(mapCenterProvider);
    return LatLng(c.lat, c.lng);
  }

  Future<void> _runSearch() async {
    final c = _centerOrDefault;
    await ref.read(mapProvider.notifier).search(_search.text, c.latitude, c.longitude);
    final results = ref.read(mapProvider).results;
    if (results.isNotEmpty && _map != null) {
      final lats = results.map((b) => b.lat);
      final lngs = results.map((b) => b.lng);
      await _map!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
            northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
          ),
          64,
        ),
      );
    }
  }

  Business _pinToBusiness(Pin p) => Business(
    pinId: p.id,
    placeId: p.placeId,
    name: p.name,
    address: p.address ?? '',
    lat: p.lat,
    lng: p.lng,
    source: StopSource.community,
    opensAt: p.opensAt,
    closesAt: p.closesAt,
    listingUrl: p.listingUrl,
  );

  Future<void> _onLongPress(LatLng at) async {
    final pack = ref.read(modePackProvider);
    final address = await ref.read(placesServiceProvider).reverseGeocode(at.latitude, at.longitude);
    if (!mounted) return;
    final r = await showManualStopSheet(context, address: address, requiresWindow: pack.requiresTimeWindow);
    if (r == null) return;
    ref
        .read(mapProvider.notifier)
        .addManual(
          name: r.name,
          lat: at.latitude,
          lng: at.longitude,
          address: r.address ?? address ?? '',
          opensAt: r.opensAt,
          closesAt: r.closesAt,
          listingUrl: r.listingUrl,
        );
    if (mounted) toast(context, 'Added "${r.name}" to your draft', icon: Icons.add_location_alt);
  }

  Future<void> _addFromClipboard() async {
    final url = _clipboardUrl;
    if (url == null) return;
    await ref.read(localPrefsProvider).setLastSeenClipboardUrl(url);
    setState(() => _clipboardUrl = null);
    if (!mounted) return;
    final r = await showManualStopSheet(context, requiresWindow: true, listingUrl: url, askAddress: true);
    if (r == null || r.address == null || r.address!.isEmpty) return;
    final geo = await ref.read(placesServiceProvider).geocode(r.address!);
    if (geo == null) {
      if (mounted) toast(context, 'Couldn\'t find that address');
      return;
    }
    ref
        .read(mapProvider.notifier)
        .addManual(
          name: r.name,
          lat: geo.lat,
          lng: geo.lng,
          address: geo.formatted,
          opensAt: r.opensAt,
          closesAt: r.closesAt,
          listingUrl: url,
        );
    _map?.animateCamera(CameraUpdate.newLatLng(LatLng(geo.lat, geo.lng)));
  }

  /// Ranks search results and visible pins for the bottom deck.
  List<SpotEntry> _spotEntries({
    required ModePack pack,
    required MapState map,
    required List<Pin> pins,
    required Map<String, Report> latest,
    required Map<String, StoreSummary> summaries,
  }) {
    final now = DateTime.now();
    final from = ref.read(currentLocationProvider).value;
    final origin = from == null ? _centerOrDefault : LatLng(from.lat, from.lng);
    final byId = <String, (Business, String?)>{};
    final candidates = <SpotCandidate>[];
    for (final b in map.results) {
      if (byId.containsKey(b.identity)) continue;
      byId[b.identity] = (b, b.address.split(',').first);
      candidates.add(SpotCandidate(id: b.identity, lat: b.lat, lng: b.lng, opensAt: b.opensAt, closesAt: b.closesAt));
    }
    for (final p in pins) {
      final b = _pinToBusiness(p);
      if (byId.containsKey(b.identity)) continue;
      final filter = map.productFilter?.toLowerCase();
      final r = latest[p.id];
      final rep = r != null && (filter == null || r.productLabel.toLowerCase().contains(filter)) ? r : null;
      final sum = summaries[p.id];
      final window = sum == null ? null : windowOnDay(sum.bestWindows, now);
      byId[b.identity] = (b, rep?.productLabel.isNotEmpty == true ? rep!.productLabel : p.categories.join(', '));
      candidates.add(
        SpotCandidate(
          id: b.identity,
          lat: p.lat,
          lng: p.lng,
          opensAt: p.opensAt,
          closesAt: p.closesAt,
          reportStatus: rep?.status,
          reportPositive: rep != null && pack.reportStatuses.any((s) => s.value == rep.status && s.positive),
          reportedAt: rep?.createdAt,
          tier: sum?.tier ?? RestockTier.unknown,
          restockToday: window,
        ),
      );
    }
    return [
      for (final s in rankSpots(candidates, fromLat: origin.latitude, fromLng: origin.longitude, now: now))
        (spot: s, business: byId[s.candidate.id]!.$1, detail: byId[s.candidate.id]!.$2),
    ];
  }

  /// One tap: an empty draft gets the top-ranked stops; then straight to the builder.
  void _plan(ModePack pack, List<SpotEntry> entries) {
    _dismissPlanTip();
    final n = ref.read(mapProvider.notifier);
    if (ref.read(mapProvider).draftStops.isNotEmpty) {
      context.push('/route/builder');
      return;
    }
    final picked = pickPlan([for (final e in entries) e.spot], pack.planMaxStops).map((s) => s.candidate.id).toSet();
    for (final e in entries) {
      if (picked.contains(e.spot.candidate.id)) n.addDraft(e.business);
    }
    context.push('/route/builder?plan=1');
  }

  /// Quick start: search a category, then (when [plan]) route the nearest results.
  Future<void> _quickStart(ModePack pack, String category, {required bool plan}) async {
    setState(() => _quickStarting = category);
    _search.text = category;
    try {
      await _runSearch();
      if (!mounted || !plan) return;
      final entries = _spotEntries(
        pack: pack,
        map: ref.read(mapProvider),
        pins: const [],
        latest: const {},
        summaries: const {},
      );
      if (entries.isNotEmpty) _plan(pack, entries);
    } finally {
      if (mounted) setState(() => _quickStarting = null);
    }
  }

  Future<void> _openSpot(Business b, List<Pin> pins) async {
    _map?.animateCamera(CameraUpdate.newLatLng(LatLng(b.lat, b.lng)));
    if (b.pinId == null) return showBusinessSheet(context, b);
    final pin = pins.where((p) => p.id == b.pinId).firstOrNull;
    if (pin != null) await showPinSheet(context, pin);
  }

  void _dismissPlanTip() {
    final prefs = ref.read(localPrefsProvider);
    if (prefs.hasSeenPlanTip) return;
    prefs.setHasSeenPlanTip(true);
    if (mounted) setState(() {});
  }

  /// Realtime: a positive report on a visible pin refreshes the map and drops a banner.
  void _onReports(List<Map<String, dynamic>> rows, ModePack pack, List<Pin> pins) {
    final ids = {for (final r in rows) r['id'] as String};
    final seen = _seenReports;
    _seenReports = {...?seen, ...ids};
    if (seen == null) return; // first snapshot is history, not news
    final me = ref.read(currentUserIdProvider);
    final fresh = rows.where((r) => !seen.contains(r['id']) && r['user_id'] != me).toList();
    if (fresh.isEmpty) return;
    ref.invalidate(latestReportsProvider);
    ref.invalidate(storeSummariesProvider);
    for (final r in fresh) {
      final positive = pack.reportStatuses.any((s) => s.value == r['status'] && s.positive);
      final pin = pins.where((p) => p.id == r['pin_id']).firstOrNull;
      if (!positive || pin == null) continue;
      HapticFeedback.mediumImpact();
      _liveDropTimer?.cancel();
      setState(() => _liveDrop = (pin: pin, status: r['status'] as String));
      _liveDropTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) setState(() => _liveDrop = null);
      });
      return;
    }
  }

  String _statusLabel(ModePack pack, String status) =>
      pack.reportStatuses.where((s) => s.value == status).firstOrNull?.label ?? status;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final pack = ref.watch(modePackProvider);
    final map = ref.watch(mapProvider);
    final center = ref.watch(mapCenterProvider);

    // A new mode starts with an empty search; its results were cleared with the map state.
    ref.listen(activeModeProvider, (prev, next) {
      if (prev == next) return;
      _search.clear();
      if (_clipboardUrl != null) setState(() => _clipboardUrl = null);
      _checkClipboard();
    });

    // Move the camera to the user once GPS resolves.
    ref.listen(currentLocationProvider, (_, next) {
      final loc = next.value;
      if (loc != null && !_movedToUser && _map != null) {
        _movedToUser = true;
        _map!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 13));
      }
    });

    final key = (
      mode: pack.id,
      lat: double.parse((_center?.latitude ?? center.lat).toStringAsFixed(2)),
      lng: double.parse((_center?.longitude ?? center.lng).toStringAsFixed(2)),
      radiusMi: 20.0,
    );
    final pins = pack.communityPins ? (ref.watch(nearbyPinsProvider(key)).value ?? const <Pin>[]) : const <Pin>[];
    final visiblePins = pins.where((p) {
      if (map.selectedDay == null || p.opensAt == null) return true;
      return DateUtils.isSameDay(p.opensAt, map.selectedDay);
    }).toList();
    final joined = visiblePins.map((p) => p.id).join(',');
    final latest = pack.communityReports && joined.isNotEmpty
        ? (ref.watch(latestReportsProvider(joined)).value ?? const <String, Report>{})
        : const <String, Report>{};
    final summaries = pack.productCatalog && joined.isNotEmpty
        ? (ref.watch(storeSummariesProvider(joined)).value ?? const <String, StoreSummary>{})
        : const <String, StoreSummary>{};

    if (pack.communityReports) {
      ref.listen(reportStreamProvider, (_, next) {
        final rows = next.value;
        if (rows != null) _onReports(rows, pack, visiblePins);
      });
    }

    final spots = _spotEntries(pack: pack, map: map, pins: visiblePins, latest: latest, summaries: summaries);
    final showDeck = map.viewMode == MapViewMode.map && spots.isNotEmpty;
    final showQuickStart =
        map.viewMode == MapViewMode.map &&
        spots.isEmpty &&
        map.query.isEmpty &&
        map.draftStops.isEmpty &&
        pack.hasSource(StopSourceId.places) &&
        pack.searchSuggestions.isNotEmpty;

    final markers = <Marker>{};
    // Route order shows on the map: picked stops become numbered dots.
    void add(String id, Business b, PinSpec spec, VoidCallback onTap, {int z = 0, double alpha = 1}) {
      final i = map.draftIndex(b);
      final s = i < 0 ? spec : PinSpec.number(i + 1, fill: c.primary, ink: c.onPrimary);
      final icon = pinIcon(s);
      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: LatLng(b.lat, b.lng),
          icon: icon ?? BitmapDescriptor.defaultMarker,
          visible: icon != null,
          anchor: s.anchor,
          alpha: alpha,
          zIndexInt: i < 0 ? z : 10,
          infoWindow: InfoWindow(title: b.name),
          onTap: onTap,
        ),
      );
    }

    for (final b in map.results) {
      add(
        'r:${b.identity}',
        b,
        PinSpec.pill(shortPlaceName(b.name), fill: c.surfaceHighest, ink: c.onSurface, border: c.primary),
        () => showBusinessSheet(context, b),
      );
    }
    for (final d in map.draftStops) {
      if (map.results.any((r) => r.identity == d.business.identity)) continue;
      if (visiblePins.any((p) => p.id == d.business.pinId)) continue;
      add(
        'd:${d.id}',
        d.business,
        PinSpec.pill(shortPlaceName(d.business.name), fill: c.surfaceHighest, ink: c.onSurface),
        () => showBusinessSheet(context, d.business),
      );
    }
    final now = DateTime.now();
    for (final p in visiblePins) {
      PinSpec spec;
      var z = 0;
      var alpha = 1.0;
      if (p.opensAt != null) {
        final ended = p.closesAt != null && !p.closesAt!.isAfter(now);
        final open = !now.isBefore(p.opensAt!) && !ended;
        spec = PinSpec.pill(
          compactWindow(p.opensAt!, p.closesAt),
          fill: c.surfaceHighest,
          ink: c.onSurface,
          border: open ? c.tertiary : c.outline,
          dot: open ? c.tertiary : null,
        );
        if (ended) alpha = 0.45;
      } else {
        final rep = latest[p.id];
        final filter = map.productFilter;
        final live =
            rep != null &&
            isFresh(rep.createdAt) &&
            pack.reportStatuses.any((s) => s.value == rep.status && s.positive) &&
            (filter == null || rep.productLabel.toLowerCase().contains(filter.toLowerCase()));
        final tier = summaries[p.id]?.tier ?? RestockTier.unknown;
        spec = live
            ? PinSpec.pill(
                '${shortPlaceName(p.name, max: 12)} · ${_statusLabel(pack, rep.status)}',
                fill: c.tertiary,
                ink: c.onTertiary,
                halo: true,
              )
            : PinSpec.pill(
                shortPlaceName(p.name),
                fill: c.surfaceHighest,
                ink: c.onSurface,
                dot: switch (tier) {
                  RestockTier.unknown => c.outline,
                  RestockTier.emerging => c.warning,
                  RestockTier.established => c.statusDone,
                },
              );
        if (live) z = 5;
      }
      add('p:${p.id}', _pinToBusiness(p), spec, () => showPinSheet(context, p), z: z, alpha: alpha);
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(center.lat, center.lng), zoom: 12),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: markers,
          onMapCreated: (ctl) => _map = ctl,
          onCameraIdle: () async {
            final region = await _map?.getVisibleRegion();
            if (region == null) return;
            final mid = LatLng(
              (region.northeast.latitude + region.southwest.latitude) / 2,
              (region.northeast.longitude + region.southwest.longitude) / 2,
            );
            if (mounted) setState(() => _center = mid);
          },
          onLongPress: pack.hasSource(StopSourceId.manual) ? _onLongPress : null,
          padding: EdgeInsets.only(top: 140, bottom: showDeck || showQuickStart ? 200 : 24),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _GlassBar(
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _runSearch(),
                          decoration: InputDecoration(
                            hintText: pack.searchHint,
                            prefixIcon: map.searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : const Icon(Icons.search),
                            suffixIcon: map.query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _search.clear();
                                      ref.read(mapProvider.notifier).clearSearch();
                                    },
                                  ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Sp.s2),
                    _GlassBar(
                      child: IconButton(
                        tooltip: map.viewMode == MapViewMode.map ? 'Show list' : 'Show map',
                        icon: Icon(map.viewMode == MapViewMode.map ? Icons.view_list : Icons.map),
                        onPressed: () => ref
                            .read(mapProvider.notifier)
                            .setViewMode(map.viewMode == MapViewMode.map ? MapViewMode.list : MapViewMode.map),
                      ),
                    ),
                    const SizedBox(width: Sp.s2),
                    const _GlassBar(child: ProfileButton()),
                  ],
                ),
              ),
              const SizedBox(height: Sp.s2),
              _ModeChips(
                pack: pack,
                map: map,
                hideSuggestions: showQuickStart,
                onSuggestion: (s) {
                  _search.text = s;
                  _runSearch();
                },
              ),
              if (_clipboardUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, 0),
                  child: KnCard(
                    tier: 3,
                    padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s2),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: c.tertiary),
                        const SizedBox(width: Sp.s3),
                        Expanded(
                          child: Text(
                            'Add the ${ListingLink.sourceLabel(_clipboardUrl!) ?? 'listing'} sale from your clipboard?',
                          ),
                        ),
                        TextButton(onPressed: _addFromClipboard, child: const Text('Add')),
                        IconButton(
                          tooltip: 'Dismiss',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _clipboardUrl = null),
                        ),
                      ],
                    ),
                  ),
                ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) => SizeTransition(
                  sizeFactor: a,
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: _liveDrop == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        key: ValueKey(_liveDrop),
                        padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, 0),
                        child: _LiveDropBanner(
                          label: '${_statusLabel(pack, _liveDrop!.status)} · ${shortPlaceName(_liveDrop!.pin.name)}',
                          onTap: () {
                            final pin = _liveDrop!.pin;
                            setState(() => _liveDrop = null);
                            _map?.animateCamera(CameraUpdate.newLatLng(LatLng(pin.lat, pin.lng)));
                            showPinSheet(context, pin);
                          },
                        ),
                      ),
              ),
              if (map.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, 0),
                  child: KnBadge(
                    map.error!,
                    color: c.errorContainer,
                    onColor: c.onErrorContainer,
                    icon: Icons.error_outline,
                  ),
                ),
              if (map.viewMode == MapViewMode.list)
                Expanded(
                  child: _ResultsList(
                    results: map.results,
                    pins: visiblePins,
                    pinToBusiness: _pinToBusiness,
                    center: _centerOrDefault,
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: Sp.s4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: Sp.s4),
                child: FloatingActionButton.small(
                  tooltip: 'My location',
                  heroTag: 'loc',
                  backgroundColor: c.surfaceHighest,
                  foregroundColor: c.onSurface,
                  onPressed: () async {
                    final loc = await ref.read(locationServiceProvider).current();
                    if (loc != null) _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 13));
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),
              const SizedBox(height: Sp.s3),
              if (showDeck)
                SpotlightDeck(
                  pack: pack,
                  entries: spots,
                  draftCount: map.draftStops.length,
                  isDraft: map.isDraft,
                  onToggle: ref.read(mapProvider.notifier).toggleDraft,
                  onOpen: (b) => _openSpot(b, visiblePins),
                  onPlan: () => _plan(pack, spots),
                  onOpenDraft: () => showDraftTray(context),
                  statusLabel: (s) => _statusLabel(pack, s),
                  showTip: !ref.read(localPrefsProvider).hasSeenPlanTip,
                  onDismissTip: _dismissPlanTip,
                )
              else if (showQuickStart)
                QuickStartDeck(
                  pack: pack,
                  busy: _quickStarting,
                  onSearch: (s) => _quickStart(pack, s, plan: false),
                  onPlan: (s) => _quickStart(pack, s, plan: true),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: Sp.s4),
                  child: Badge(
                    isLabelVisible: map.draftStops.isNotEmpty,
                    label: Text('${map.draftStops.length}'),
                    backgroundColor: c.primary,
                    textColor: c.onPrimary,
                    offset: const Offset(-4, 4),
                    child: FloatingActionButton.extended(
                      heroTag: 'draft',
                      onPressed: () => map.draftStops.isEmpty
                          ? toast(context, 'Tap a ${pack.stopNoun} to add it')
                          : showDraftTray(context),
                      icon: const Icon(Icons.playlist_add_check),
                      label: Text(map.editingRouteId != null ? 'Editing' : 'Draft'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveDropBanner extends StatelessWidget {
  const _LiveDropBanner({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: c.tertiary,
        borderRadius: BorderRadius.circular(Rad.full),
        elevation: 4,
        shadowColor: c.tertiary.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.full),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s3),
            child: Row(
              children: [
                Icon(Icons.bolt, color: c.onTertiary, size: 20),
                const SizedBox(width: Sp.s2),
                Text(
                  'LIVE',
                  style: t.labelSmall?.copyWith(color: c.onTertiary, fontWeight: FontWeight.w900, letterSpacing: 1.4),
                ),
                const SizedBox(width: Sp.s2),
                Expanded(
                  child: Text(
                    '$label · just now',
                    style: t.titleSmall?.copyWith(color: c.onTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, color: c.onTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  const _GlassBar({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: BoxDecoration(
      color: context.kn.glass,
      borderRadius: BorderRadius.circular(Rad.xl),
      border: Border.all(color: context.kn.ghostBorder),
      boxShadow: [
        BoxShadow(color: context.kn.primaryDim.withValues(alpha: 0.08), blurRadius: 32, offset: const Offset(0, 8)),
      ],
    ),
    child: Center(child: child),
  );
}

/// Mode-specific chip row under the search bar: weekend selector (Yard Sales),
/// product filter (Card Drops), or search suggestions (everything else).
class _ModeChips extends ConsumerWidget {
  const _ModeChips({required this.pack, required this.map, required this.onSuggestion, this.hideSuggestions = false});
  final ModePack pack;
  final MapState map;

  /// The quick-start deck already shows the suggestions as cards.
  final bool hideSuggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(mapProvider.notifier);
    final now = DateTime.now();
    List<Widget> chips;
    if (pack.requiresTimeWindow) {
      final sat = now.add(Duration(days: (DateTime.saturday - now.weekday) % 7));
      final sun = sat.add(const Duration(days: 1));
      final nextSat = sat.add(const Duration(days: 7));
      final opts = [
        (null, 'Any day'),
        (sat, 'Sat ${DateFormat.Md().format(sat)}'),
        (sun, 'Sun ${DateFormat.Md().format(sun)}'),
        (nextSat, 'Next Sat'),
      ];
      chips = [
        for (final (d, label) in opts)
          ChoiceChip(
            label: Text(label),
            selected: d == null ? map.selectedDay == null : DateUtils.isSameDay(map.selectedDay, d),
            showCheckmark: false,
            onSelected: (_) => n.setDay(d),
          ),
      ];
    } else if (pack.productCatalog) {
      final products = ref.watch(productsProvider).value ?? const [];
      final sets = products.map((p) => p.setName).toSet().take(6).toList();
      chips = [
        ChoiceChip(
          label: const Text('Any product'),
          selected: map.productFilter == null,
          showCheckmark: false,
          onSelected: (_) => n.setProductFilter(null),
        ),
        for (final s in sets)
          ChoiceChip(
            label: Text(s),
            selected: map.productFilter == s,
            showCheckmark: false,
            onSelected: (_) => n.setProductFilter(s),
          ),
      ];
    } else if (hideSuggestions) {
      return const SizedBox.shrink();
    } else {
      chips = [for (final s in pack.searchSuggestions) ActionChip(label: Text(s), onPressed: () => onSuggestion(s))];
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Sp.s4),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: Sp.s2),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  const _ResultsList({required this.results, required this.pins, required this.pinToBusiness, required this.center});
  final List<Business> results;
  final List<Pin> pins;
  final Business Function(Pin) pinToBusiness;
  final LatLng center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final map = ref.watch(mapProvider);
    final items = [...results, ...pins.map(pinToBusiness)];
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'No results yet',
        body: 'Search above or long-press the map to drop a stop.',
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, Sp.s4),
      child: Material(
        color: c.glass,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.xl),
          side: BorderSide(color: c.ghostBorder),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: Sp.s2),
          itemCount: items.length,
          separatorBuilder: (_, _) => const GhostDivider(),
          itemBuilder: (_, i) {
            final b = items[i];
            final dist = haversineMeters(center.latitude, center.longitude, b.lat, b.lng);
            return CheckboxListTile(
              value: map.isDraft(b),
              onChanged: (_) => ref.read(mapProvider.notifier).toggleDraft(b),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: c.primary,
              title: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${formatDistance(dist)} · ${b.address}', maxLines: 1, overflow: TextOverflow.ellipsis),
              secondary: IconButton(
                tooltip: 'Details',
                icon: const Icon(Icons.info_outline),
                onPressed: () => b.pinId != null ? _openPin(context, ref, b.pinId!) : showBusinessSheet(context, b),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPin(BuildContext context, WidgetRef ref, String pinId) async {
    final pin = pins.where((p) => p.id == pinId).firstOrNull ?? await ref.read(pinRepoProvider).byId(pinId);
    if (pin != null && context.mounted) showPinSheet(context, pin);
  }
}

/// Exposed for the community sheets so they can enter edit mode.
void goToBuilder(BuildContext context) => context.push('/route/builder');

String modeLabel(AppMode m) => switch (m) {
  AppMode.fieldSales => 'Field Sales',
  AppMode.yardSales => 'Yard Sales',
  AppMode.cardDrops => 'Card Drops',
};
