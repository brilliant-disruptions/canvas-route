import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/logic/check_in.dart';
import '../../core/logic/errors.dart';
import '../../core/logic/pin_labels.dart';
import '../../core/logic/spotlight.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/business.dart';
import '../../data/models/pin.dart';
import '../../data/models/report.dart';
import '../../data/services/listing_link.dart';
import '../../modes/mode_pack.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/demand_state.dart';
import '../../state/follow_ups_state.dart';
import '../../state/location_state.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/map/pin_icons.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../community/pin_sheet.dart';
import 'business_sheet.dart';
import 'check_in_banner.dart';
import 'cold_start_card.dart';
import 'draft_tray.dart';
import 'manual_stop_sheet.dart';
import 'map_markers.dart';
import 'map_overlays.dart';
import 'map_top_bar.dart';
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

  /// Re-reads GPS while the map is open, so "Still going?" knows where you are.
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
    _locationTimer = Timer.periodic(const Duration(seconds: 90), (_) => ref.invalidate(currentLocationProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveDropTimer?.cancel();
    _locationTimer?.cancel();
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

  Future<void> _onLongPress(LatLng at) => _dropStop(at);

  /// Spot a sale where you're standing (or the middle of the map without GPS).
  Future<void> _spotHere() async {
    final loc = await ref.read(locationServiceProvider).current();
    final at = loc == null ? _centerOrDefault : LatLng(loc.lat, loc.lng);
    _map?.animateCamera(CameraUpdate.newLatLng(at));
    await _dropStop(at);
  }

  /// A stop dropped on the map: private by default, or shared as a community pin
  /// (with a photo of the sign) in modes that allow spotting.
  Future<void> _dropStop(LatLng at) async {
    final pack = ref.read(modePackProvider);
    final address = await ref.read(placesServiceProvider).reverseGeocode(at.latitude, at.longitude);
    if (!mounted) return;
    final r = await showManualStopSheet(
      context,
      address: address,
      requiresWindow: pack.requiresTimeWindow,
      shareLabel: pack.community.spotLabel,
      categories: pack.community.categories,
      readSign: ref.read(signReaderProvider).available ? ref.read(signReaderProvider).read : null,
      categoryKeywords: pack.community.categoryKeywords,
    );
    if (r == null || !mounted) return;
    void addPrivately() => ref
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
    if (!r.share) {
      addPrivately();
      toast(context, 'Added "${r.name}" to your route', icon: Icons.add_location_alt);
      return;
    }
    if (ref.read(isAnonymousProvider)) {
      addPrivately();
      context.push('/signin?reason=report');
      return;
    }
    try {
      final pin = await ref
          .read(pinRepoProvider)
          .createSpotted(
            userId: ref.read(currentUserIdProvider)!,
            mode: pack.id,
            name: r.name,
            address: r.address ?? address,
            lat: at.latitude,
            lng: at.longitude,
            opensAt: r.opensAt,
            closesAt: r.closesAt,
            listingUrl: r.listingUrl,
            categories: r.categories,
            signPhoto: r.signPhoto!,
          );
      ref.read(mapProvider.notifier).addDraft(businessFromPin(pin));
      if (mounted) {
        toast(
          context,
          'Thanks! Other ${pack.community.noun} will see it after a quick check.',
          icon: Icons.campaign_outlined,
        );
      }
    } catch (e) {
      addPrivately();
      if (mounted) {
        toast(
          context,
          'Added to your route, but not shared. ${friendlyError(e, denied: 'Sharing unlocks after a few reports.')}',
        );
      }
    }
  }

  /// The + button's "Paste a listing link": whatever link is on the clipboard now.
  Future<void> _pasteLink() async {
    final url = await ListingLink.readClipboardUrl();
    if (!mounted) return;
    if (url == null) {
      toast(context, 'Copy the sale\'s link first (Facebook, Craigslist, Nextdoor…), then tap here.', icon: Icons.link);
      return;
    }
    await _addFromClipboard(url);
  }

  Future<void> _addFromClipboard(String url) async {
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
      final b = businessFromPin(p);
      if (byId.containsKey(b.identity)) continue;
      final rep = latest[p.id];
      byId[b.identity] = (b, p.categories.join(', '));
      candidates.add(
        SpotCandidate(
          id: b.identity,
          lat: p.lat,
          lng: p.lng,
          opensAt: p.opensAt,
          closesAt: p.closesAt,
          reportStatus: rep?.status,
          reportPositive: rep != null && pack.community.statuses.any((s) => s.value == rep.status && s.positive),
          reportCaution: rep != null && pack.community.statuses.any((s) => s.value == rep.status && s.caution),
          reportEnds: rep != null && pack.community.statuses.any((s) => s.value == rep.status && s.ends),
          reportedAt: rep?.createdAt,
        ),
      );
    }
    return [
      for (final s in rankSpots(candidates, fromLat: origin.latitude, fromLng: origin.longitude, now: now))
        (spot: s, business: byId[s.candidate.id]!.$1, detail: byId[s.candidate.id]!.$2),
    ];
  }

  /// One tap: an empty draft gets the top-ranked stops; then straight to the builder.
  void _toggle(Business b) {
    HapticFeedback.selectionClick();
    ref.read(mapProvider.notifier).toggleDraft(b);
  }

  void _plan(ModePack pack, List<SpotEntry> entries) {
    HapticFeedback.mediumImpact();
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
    for (final r in fresh) {
      final positive = pack.community.statuses.any((s) => s.value == r['status'] && s.positive);
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
      pack.community.statuses.where((s) => s.value == status).firstOrNull?.label ?? status;

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
    final nearby = pack.community.pins ? ref.watch(nearbyPinsProvider(key)) : null;
    final pins = nearby?.value ?? const <Pin>[];
    final visiblePins = pins.where((p) {
      if (!matchesHunt(p.categories, map.huntFilter, wildcard: pack.community.categoryWildcard)) return false;
      if (map.openNow) {
        final now = DateTime.now();
        return p.opensAt != null &&
            !now.isBefore(p.opensAt!.subtract(const Duration(minutes: 30))) &&
            (p.closesAt == null || p.closesAt!.isAfter(now));
      }
      if (map.selectedDay == null || p.opensAt == null) return true;
      return DateUtils.isSameDay(p.opensAt, map.selectedDay);
    }).toList();
    final joined = visiblePins.map((p) => p.id).join(',');
    final latest = pack.community.reports && joined.isNotEmpty
        ? (ref.watch(latestReportsProvider(joined)).value ?? const <String, Report>{})
        : const <String, Report>{};

    if (pack.community.reports) {
      ref.listen(reportStreamProvider, (_, next) {
        final rows = next.value;
        if (rows != null) _onReports(rows, pack, visiblePins);
      });
    }

    // Standing at an open listing (signed in, so the report can be filed): ask once.
    final here = ref.watch(currentLocationProvider).value;
    final doneToday = ref.read(localPrefsProvider).checkInsDone;
    final checkInId = !pack.community.reports || !pack.requiresTimeWindow || here == null || ref.watch(isAnonymousProvider)
        ? null
        : checkInCandidate(
            [
              for (final p in pins)
                if (p.opensAt != null && !doneToday.contains(checkInKey(p.id, DateTime.now())))
                  (id: p.id, lat: p.lat, lng: p.lng, opensAt: p.opensAt!, closesAt: p.closesAt),
            ],
            here.lat,
            here.lng,
            DateTime.now(),
          );
    final checkIn = checkInId == null ? null : pins.firstWhere((p) => p.id == checkInId);

    final spots = _spotEntries(pack: pack, map: map, pins: visiblePins, latest: latest);
    final listView = map.viewMode == MapViewMode.list;
    final showDeck = spots.isNotEmpty;
    // Nothing listed anywhere near: say so, count the user in, and offer the ways
    // to change it, instead of an empty map.
    final coldStart =
        pack.community.waitlistLabel != null &&
        (nearby?.hasValue ?? false) &&
        pins.isEmpty &&
        map.viewMode == MapViewMode.map &&
        map.query.isEmpty &&
        map.draftStops.isEmpty;
    final showQuickStart =
        !coldStart &&
        map.viewMode == MapViewMode.map &&
        spots.isEmpty &&
        map.query.isEmpty &&
        map.draftStops.isEmpty &&
        pack.hasSource(StopSourceId.places) &&
        pack.searchSuggestions.isNotEmpty;

    final markers = buildMapMarkers(
      c: c,
      pack: pack,
      map: map,
      pins: visiblePins,
      latest: latest,
      visited: ref.watch(visitHistoryProvider).keys.toSet(),
      iconFor: pinIcon,
      onBusiness: (b) => showBusinessSheet(context, b),
      onPin: (p) => showPinSheet(context, p),
      now: DateTime.now(),
    );

    // One banner at a time, most urgent first: you're standing at a sale, a
    // neighbor just confirmed one, then a link waiting on the clipboard.
    final Widget? banner = checkIn != null
        ? CheckInBanner(
            key: ValueKey('checkin:${checkIn.id}'),
            pack: pack,
            pin: checkIn,
            onDone: () async {
              await ref.read(localPrefsProvider).addCheckInDone(checkInKey(checkIn.id, DateTime.now()));
              if (mounted) setState(() {});
            },
          )
        : _liveDrop != null
        ? LiveDropBanner(
            key: ValueKey(_liveDrop),
            label: '${_statusLabel(pack, _liveDrop!.status)} · ${shortPlaceName(_liveDrop!.pin.name)}',
            onTap: () {
              final pin = _liveDrop!.pin;
              setState(() => _liveDrop = null);
              _map?.animateCamera(CameraUpdate.newLatLng(LatLng(pin.lat, pin.lng)));
              showPinSheet(context, pin);
            },
          )
        : _clipboardUrl != null
        ? ClipboardBanner(
            key: ValueKey(_clipboardUrl),
            source: ListingLink.sourceLabel(_clipboardUrl!) ?? 'listing',
            onAdd: () => _addFromClipboard(_clipboardUrl!),
            onDismiss: () => setState(() => _clipboardUrl = null),
          )
        : null;

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
          padding: EdgeInsets.only(top: 140, bottom: coldStart ? 300 : (showDeck || showQuickStart) && !listView ? 200 : 24),
        ),
        // List view sits on the page, not over the map's pins.
        if (listView) Positioned.fill(child: ColoredBox(color: c.surface)),
        SafeArea(
          child: Column(
            children: [
              MapTopBar(
                pack: pack,
                search: _search,
                onSearch: _runSearch,
                hideSuggestions: showQuickStart,
                onSuggestion: (s) {
                  _search.text = s;
                  _runSearch();
                },
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) => SizeTransition(
                  sizeFactor: a,
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: banner == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        key: banner.key,
                        padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, 0),
                        child: banner,
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
              if (listView)
                Expanded(
                  child: SpotList(
                    entries: spots,
                    isDraft: map.isDraft,
                    onToggle: _toggle,
                    onOpen: (b) => _openSpot(b, visiblePins),
                    statusLabel: (s) => _statusLabel(pack, s),
                    bottomPadding: showDeck ? 96 : Sp.s4,
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
              if (!listView && !coldStart && (pack.community.spotLabel != null || pack.hasSource(StopSourceId.listingLink))) ...[
                Padding(
                  padding: const EdgeInsets.only(right: Sp.s4),
                  child: AddSaleButton(
                    noun: pack.stopNoun,
                    onSpot: pack.community.spotLabel == null ? null : _spotHere,
                    onPasteLink: pack.hasSource(StopSourceId.listingLink) ? _pasteLink : null,
                  ),
                ),
                const SizedBox(height: Sp.s2),
              ],
              if (!listView)
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
                  onToggle: _toggle,
                  onOpen: (b) => _openSpot(b, visiblePins),
                  onPlan: () => _plan(pack, spots),
                  onOpenDraft: () => showDraftTray(context),
                  statusLabel: (s) => _statusLabel(pack, s),
                  showCards: !listView,
                )
              else if (coldStart)
                ColdStartCard(
                  pack: pack,
                  area: demandKey(pack.id, key.lat, key.lng),
                  onSpot: _spotHere,
                  onBrowse: (lat, lng) => _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 12)),
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
