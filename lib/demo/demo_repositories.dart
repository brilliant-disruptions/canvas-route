import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, OAuthProvider, User;

import '../core/logic/restock.dart';
import '../data/models/alert_item.dart';
import '../data/models/app_mode.dart';
import '../data/models/business.dart';
import '../data/models/draft_stop.dart';
import '../data/models/feature_request.dart';
import '../data/models/json_utils.dart';
import '../data/models/pin.dart';
import '../data/models/product.dart';
import '../data/models/profile.dart';
import '../data/models/report.dart';
import '../data/models/route_model.dart';
import '../data/models/settings.dart';
import '../data/models/stop.dart';
import '../data/models/trip.dart';
import '../data/models/store_summary.dart';
import '../data/models/visit.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/feature_request_repository.dart';
import '../data/repositories/pin_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/route_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/share_repository.dart';
import '../data/repositories/trip_repository.dart';
import '../data/repositories/visit_repository.dart';
import '../data/services/storage_service.dart';
import 'demo_db.dart';

/// Small async delay so loading states behave like a real network.
Future<T> _later<T>(T Function() fn) => Future.delayed(const Duration(milliseconds: 120), fn);

class DemoAuthRepository implements AuthRepository {
  @override
  Stream<AuthState> get changes => const Stream.empty();
  @override
  User? get user => null;
  @override
  bool get isSignedIn => true;
  @override
  bool get isAnonymous => false;
  @override
  Future<void> ensureSession() async {}
  @override
  Future<void> sendMagicLink(String email) async {}
  @override
  Future<void> verifyEmailOtp(String email, String token) async {}
  @override
  Future<bool> signInWithOAuth(OAuthProvider provider) async => true;
  @override
  Future<void> signOut() async {}
}

class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository(this.db);
  final DemoDb db;

  @override
  Future<Profile?> fetch(String userId) => _later(() {
    final r = db.profiles[userId];
    return r == null ? null : Profile.fromRow(r);
  });

  @override
  Future<Profile> update(String userId, Map<String, dynamic> patch) => _later(() {
    final r = db.profiles[userId]!..addAll(patch);
    r['updated_at'] = DemoDb.nowIso();
    return Profile.fromRow(r);
  });

  @override
  Future<Profile> setActiveMode(String userId, AppMode mode) => update(userId, {'active_mode': mode.id});
  @override
  Future<Profile> setOnboarded(String userId) => update(userId, {'has_onboarded': true});
  @override
  Future<Profile> setHome(String userId, double lat, double lng) => update(userId, {'home_lat': lat, 'home_lng': lng});
  @override
  Future<Profile> deactivate(String userId) => update(userId, {'handle': null, 'name': null});
  @override
  Future<bool> handleAvailable(String handle) async => !db.profiles.values.any((p) => p['handle'] == handle);
}

class DemoSettingsRepository implements SettingsRepository {
  DemoSettingsRepository(this.db);
  final DemoDb db;

  @override
  Future<Settings> fetch(String userId) =>
      _later(() => Settings.fromRow(db.settings.putIfAbsent(userId, () => {'user_id': userId})));

  @override
  Future<Settings> save(Settings s) => _later(() {
    final row = {'user_id': s.userId, ...s.toUpdate()};
    db.settings[s.userId] = row;
    return Settings.fromRow(row);
  });
}

class DemoRouteRepository implements RouteRepository {
  DemoRouteRepository(this.db);
  final DemoDb db;

  List<Stop> _stopsFor(String routeId) {
    final rows = db.stops.values.where((s) => s['route_id'] == routeId).toList()
      ..sort((a, b) => (a['stop_order'] as int).compareTo(b['stop_order'] as int));
    return rows.map(Stop.fromRow).toList();
  }

  RouteModel _model(String id) => RouteModel.fromRow(db.routes[id]!, _stopsFor(id));

  void _touch(String routeId, Map<String, dynamic> patch) {
    db.routes[routeId]!
      ..addAll(patch)
      ..['updated_at'] = DemoDb.nowIso();
  }

  void _insertStops(String routeId, List<DraftStop> drafts) {
    for (var i = 0; i < drafts.length; i++) {
      final b = drafts[i].business;
      final id = DemoDb.newId();
      db.stops[id] = {
        'id': id,
        'route_id': routeId,
        'place_id': b.placeId,
        'pin_id': b.pinId,
        'source': b.source.id,
        'name': b.name,
        'address': b.address,
        'lat': b.lat,
        'lng': b.lng,
        'stop_order': i,
        'visited': false,
        'opens_at': b.opensAt == null ? null : DemoDb.iso(b.opensAt!),
        'closes_at': b.closesAt == null ? null : DemoDb.iso(b.closesAt!),
        'listing_url': b.listingUrl,
        'created_at': DemoDb.nowIso(),
      };
    }
  }

  @override
  Future<List<RouteModel>> loadRoutes(String userId, AppMode mode) => _later(() {
    final rows = db.routes.values.where((r) => r['user_id'] == userId && r['mode'] == mode.id).toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return rows.map((r) => _model(r['id'] as String)).toList();
  });

  @override
  Future<RouteModel?> byId(String id) => _later(() => db.routes.containsKey(id) ? _model(id) : null);

  @override
  Future<RouteModel> create({
    required String userId,
    required AppMode mode,
    required String name,
    required List<DraftStop> stops,
    bool isOptimized = false,
    String? forkedFrom,
  }) => _later(() {
    final id = DemoDb.newId();
    db.routes[id] = {
      'id': id,
      'user_id': userId,
      'mode': mode.id,
      'name': name,
      'stop_count': stops.length,
      'is_optimized': isOptimized,
      'status': 'not_started',
      'last_run_at': null,
      'forked_from': forkedFrom,
      'created_at': DemoDb.nowIso(),
      'updated_at': DemoDb.nowIso(),
    };
    _insertStops(id, stops);
    return _model(id);
  });

  @override
  Future<RouteModel> replaceStops(RouteModel route, String name, List<DraftStop> stops, {bool isOptimized = true}) =>
      _later(() {
        _touch(route.id, {'name': name, 'stop_count': stops.length, 'status': 'updated', 'is_optimized': isOptimized});
        db.stops.removeWhere((_, s) => s['route_id'] == route.id);
        db.visits.removeWhere((_, v) => v['route_id'] == route.id);
        _insertStops(route.id, stops);
        return _model(route.id);
      });

  @override
  Future<void> rename(String routeId, String name) async => _touch(routeId, {'name': name});

  @override
  Future<void> delete(String routeId) async {
    db.routes.remove(routeId);
    db.stops.removeWhere((_, s) => s['route_id'] == routeId);
    db.visits.removeWhere((_, v) => v['route_id'] == routeId);
  }

  @override
  Future<RouteModel> duplicate(RouteModel source, String userId) => create(
    userId: userId,
    mode: source.mode,
    name: '${source.name} (copy)',
    isOptimized: source.isOptimized,
    stops: [for (final s in source.stops) DraftStop(id: s.id, business: s.toBusiness())],
  );

  @override
  Future<void> setStatus(String routeId, RouteStatus status) async =>
      _touch(routeId, {'status': status.id, if (status == RouteStatus.inProgress) 'last_run_at': DemoDb.nowIso()});

  @override
  Future<void> reorder(List<Stop> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      db.stops[ordered[i].id]?['stop_order'] = i;
    }
  }

  @override
  Future<void> markVisited(String stopId, {bool visited = true}) async => db.stops[stopId]?['visited'] = visited;

  @override
  Future<void> resetVisits(String routeId) async {
    for (final s in db.stops.values.where((s) => s['route_id'] == routeId)) {
      s['visited'] = false;
    }
    db.visits.removeWhere((_, v) => v['route_id'] == routeId);
  }

  @override
  Future<void> renameStop(String stopId, String name) async => db.stops[stopId]?['name'] = name;
}

class DemoVisitRepository implements VisitRepository {
  DemoVisitRepository(this.db);
  final DemoDb db;

  @override
  Future<List<Visit>> forRoute(String routeId) =>
      _later(() => db.visits.values.where((v) => v['route_id'] == routeId).map(Visit.fromRow).toList());

  @override
  Future<List<Visit>> forUser(String userId) =>
      _later(() => db.visits.values.where((v) => v['user_id'] == userId).map(Visit.fromRow).toList());

  @override
  Future<Visit> upsert(Map<String, dynamic> insert) => _later(() {
    final existing = db.visits.values.where((v) => v['stop_id'] == insert['stop_id']).firstOrNull;
    final row = existing ?? {'id': DemoDb.newId(), 'created_at': DemoDb.nowIso()};
    row
      ..addAll(insert)
      ..['updated_at'] = DemoDb.nowIso();
    db.visits[row['id'] as String] = row;
    return Visit.fromRow(row);
  });

  @override
  Future<void> setFollowUp(String visitId, DateTime? date) =>
      _later(() => db.visits[visitId]?['follow_up_date'] = date == null ? null : dateOnly(date));

  @override
  Future<void> delete(String visitId) async => db.visits.remove(visitId);
}

class DemoPinRepository implements PinRepository {
  DemoPinRepository(this.db, this.storage);
  final DemoDb db;
  final StorageService storage;

  List<String> _photos(String pinId) => db.pinPhotos
      .where((p) => p['pin_id'] == pinId)
      .map((p) => storage.publicUrl(StorageService.pinPhotos, p['storage_path'] as String))
      .toList();

  Pin _pin(Map<String, dynamic> r) => Pin.fromRow(r, photos: _photos(r['id'] as String));

  Map<String, dynamic> _insert(Map<String, dynamic> row) {
    final id = DemoDb.newId();
    final r = {
      'id': id,
      'categories': <String>[],
      'confirmations': 0,
      'share_token': id.substring(0, 12),
      'created_at': DemoDb.nowIso(),
      'updated_at': DemoDb.nowIso(),
      ...row,
    };
    db.pins[id] = r;
    return r;
  }

  @override
  Future<List<Pin>> nearby(AppMode mode, double lat, double lng, {double radiusMi = 15}) => _later(() {
    final rows = db.pins.values.where((p) => p['mode'] == mode.id && p['status'] == 'live').toList();
    final now = DateTime.now();
    rows.removeWhere((p) => p['closes_at'] != null && DateTime.parse(p['closes_at'] as String).isBefore(now));
    return rows.map(_pin).toList();
  });

  @override
  Future<Pin?> byId(String id) => _later(() => db.pins[id] == null ? null : _pin(db.pins[id]!));

  @override
  Future<Pin?> byShareToken(String token) =>
      _later(() => db.pins.values.where((p) => p['share_token'] == token).map(_pin).firstOrNull);

  @override
  Future<List<Pin>> mine(String userId) => _later(() {
    final rows = db.pins.values.where((p) => p['owner_id'] == userId).toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return rows.map(_pin).toList();
  });

  @override
  Future<Pin> createHosted({
    required String ownerId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    required DateTime opensAt,
    required DateTime closesAt,
    required List<String> categories,
    String? notes,
    String? earlyBirds,
    List<XFile> photos = const [],
  }) async {
    final r = _insert({
      'mode': 'yard_sales',
      'kind': 'yard_sale',
      'origin': 'host',
      'owner_id': ownerId,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'opens_at': DemoDb.iso(opensAt),
      'closes_at': DemoDb.iso(closesAt),
      'categories': categories,
      'notes': notes,
      'early_birds': earlyBirds,
      'status': 'live',
    });
    for (final f in photos) {
      await addPhoto(r['id'] as String, ownerId, f);
    }
    return _pin(r);
  }

  @override
  Future<Pin> createSpotted({
    required String userId,
    required AppMode mode,
    required String name,
    required String? address,
    required double lat,
    required double lng,
    DateTime? opensAt,
    DateTime? closesAt,
    String? listingUrl,
    List<String> categories = const [],
    required XFile signPhoto,
  }) async {
    final r = _insert({
      'mode': mode.id,
      'kind': mode == AppMode.cardDrops ? 'store' : 'yard_sale',
      'origin': 'spotted',
      'owner_id': userId,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'opens_at': opensAt == null ? null : DemoDb.iso(opensAt),
      'closes_at': closesAt == null ? null : DemoDb.iso(closesAt),
      'listing_url': listingUrl,
      'categories': categories,
      'status': 'pending',
    });
    await addPhoto(r['id'] as String, userId, signPhoto);
    return _pin(r);
  }

  @override
  Future<Pin> ensureStorePin(Business b) => _later(() {
    final existing = db.pins.values
        .where((p) => p['mode'] == 'card_drops' && p['place_id'] != null && p['place_id'] == b.placeId)
        .firstOrNull;
    if (existing != null) return _pin(existing);
    return _pin(
      _insert({
        'mode': 'card_drops',
        'kind': 'store',
        'origin': 'places',
        'place_id': b.placeId,
        'name': b.name,
        'address': b.address,
        'lat': b.lat,
        'lng': b.lng,
        'status': 'live',
      }),
    );
  });

  @override
  Future<void> addPhoto(String pinId, String userId, XFile file) async {
    final path = await storage.upload(StorageService.pinPhotos, file);
    db.pinPhotos.add({'pin_id': pinId, 'user_id': userId, 'storage_path': path});
  }

  @override
  Future<void> setStatus(String pinId, PinStatus status) async => db.pins[pinId]?['status'] = status.name;

  @override
  Future<void> update(String pinId, Map<String, dynamic> patch) async => db.pins[pinId]?.addAll(patch);

  /// Mirrors migration 011, plus the demo's seeded interest from other hunters.
  @override
  Future<int?> interest(String pinId) => _later(() {
    final pin = db.pins[pinId];
    if (pin == null || pin['owner_id'] != DemoDb.userId) return null;
    final planners = {
      for (final s in db.stops.values.where((s) => s['pin_id'] == pinId)) db.routes[s['route_id']]?['user_id'],
    }..remove(DemoDb.userId);
    return planners.length + (db.pinInterest[pinId] ?? 0);
  });

  @override
  Future<List<Pin>> pendingForAdmin() => _later(
    () => db.pins.values.where((p) => p['status'] == 'pending' || p['status'] == 'removed').map(_pin).toList(),
  );
}

class DemoReportRepository implements ReportRepository {
  DemoReportRepository(this.db);
  final DemoDb db;

  static const _positive = {'in_stock', 'restocking_now'};

  Map<String, dynamic> _withProduct(Map<String, dynamic> r) {
    final p = r['product_id'] == null ? null : db.products[r['product_id']];
    return {
      ...r,
      'products': p == null ? null : {'display_name': p['display_name']},
    };
  }

  @override
  Future<Report> create(ReportDraft draft, String userId) => _later(() {
    final trust = (db.profiles[userId]?['trust_score'] as int?) ?? 50;
    if (trust < 10) throw StateError('Your trust score is too low to report right now.');
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final recent = db.reports.values.where(
      (r) =>
          r['user_id'] == userId &&
          r['pin_id'] == draft.pinId &&
          DateTime.parse(r['created_at'] as String).isAfter(hourAgo),
    );
    if (recent.length >= 3) throw StateError('You can report this place 3 times an hour. Try again later.');
    final id = DemoDb.newId();
    final row = {...draft.toInsert(userId), 'id': id, 'trust_at_filing': trust, 'created_at': DemoDb.nowIso()};
    db.reports[id] = row;
    final pin = db.pins[draft.pinId];
    if (pin != null && pin['origin'] == 'spotted' && pin['owner_id'] != userId) {
      pin['confirmations'] = (pin['confirmations'] as int) + 1;
      if (pin['status'] == 'pending') pin['status'] = 'live';
    }
    db.profiles[userId]?['trust_score'] = (trust + 1).clamp(0, 100);
    return Report.fromRow(_withProduct(row));
  });

  List<Map<String, dynamic>> _forPin(String pinId) =>
      db.reports.values.where((r) => r['pin_id'] == pinId).toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));

  @override
  Future<List<Report>> recentForPin(String pinId, {int limit = 10}) =>
      _later(() => _forPin(pinId).take(limit).map((r) => Report.fromRow(_withProduct(r))).toList());

  @override
  Future<Map<String, Report>> latestForPins(List<String> pinIds) => _later(() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final out = <String, Report>{};
    for (final id in pinIds) {
      final latest = _forPin(id).where((r) => DateTime.parse(r['created_at'] as String).isAfter(cutoff)).firstOrNull;
      if (latest != null) out[id] = Report.fromRow(_withProduct(latest));
    }
    return out;
  });

  /// Mirrors migration 006: trusted positive reports in the last 90 days,
  /// bucketed by local weekday × hour.
  StoreSummary _summary(String pinId) {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final rows = _forPin(pinId).where(
      (r) => DateTime.parse(r['created_at'] as String).isAfter(cutoff) && (r['trust_at_filing'] as int? ?? 50) >= 30,
    );
    final buckets = <(int, int), int>{};
    final days = List.filled(7, 0);
    var hits = 0;
    DateTime? lastSeen;
    for (final r in rows) {
      final t = DateTime.parse(r['created_at'] as String).toLocal();
      lastSeen ??= t;
      if (!_positive.contains(r['status'])) continue;
      hits++;
      final k = (t.weekday % 7, t.hour);
      buckets[k] = (buckets[k] ?? 0) + 1;
      days[t.weekday % 7]++;
    }
    final best = buckets.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return StoreSummary(
      totalHits: hits,
      totalReports: rows.length,
      lastSeen: lastSeen,
      tier: tierForHits(hits),
      bestWindows: [for (final e in best.take(3)) (dow: e.key.$1, hour: e.key.$2, hits: e.value)],
      dayHits: days,
      recent: const [],
    );
  }

  @override
  Future<StoreSummary> storeSummary(String pinId) => _later(() => _summary(pinId));

  @override
  Future<Map<String, StoreSummary>> summaries(List<String> pinIds) =>
      _later(() => {for (final id in pinIds) id: _summary(id)});

  @override
  Future<void> delete(String reportId) async => db.reports.remove(reportId);

  @override
  Stream<List<Map<String, dynamic>>> stream() async* {
    List<Map<String, dynamic>> latest() =>
        (db.reports.values.toList()..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String)))
            .take(50)
            .toList();
    yield latest();
    // Demo only: a community sighting arrives shortly after launch, so the live-drop banner can be seen.
    await Future<void>.delayed(const Duration(seconds: 20));
    final target = db.pins.values.where((p) => p['place_id'] == 'pl_target_central').firstOrNull;
    final etb = db.products.values
        .where((p) => p['display_name'] == 'Prismatic Evolutions — Elite Trainer Box')
        .firstOrNull;
    if (target == null) return;
    final id = DemoDb.newId();
    db.reports[id] = {
      'id': id,
      'pin_id': target['id'],
      'user_id': 'community-7',
      'status': 'in_stock',
      'product_id': etb?['id'],
      'qty': 4,
      'price_cents': 4999,
      'purchase_limit': 2,
      'line_present': false,
      'trust_at_filing': 72,
      'created_at': DemoDb.nowIso(),
    };
    yield latest();
  }
}

class DemoProductRepository implements ProductRepository {
  DemoProductRepository(this.db);
  final DemoDb db;

  List<Product> _where(bool Function(Map<String, dynamic>) test) =>
      db.products.values.where(test).map(Product.fromRow).toList();

  @override
  Future<List<Product>> canonical() => _later(() {
    final list = _where((p) => p['is_canonical'] == true);
    list.sort((a, b) => (b.releaseDate ?? DateTime(2000)).compareTo(a.releaseDate ?? DateTime(2000)));
    // Show only released sets first, like the catalog a shopper would see.
    final now = DateTime.now();
    return [
      ...list.where((p) => p.releaseDate == null || !p.releaseDate!.isAfter(now)),
      ...list.where((p) => p.releaseDate != null && p.releaseDate!.isAfter(now)),
    ];
  });

  @override
  Future<List<Product>> search(String q) => _later(
    () => _where((p) => (p['display_name'] as String).toLowerCase().contains(q.toLowerCase())).take(30).toList(),
  );

  @override
  Future<Product> addFreeText(String name, String userId) => _later(() {
    final id = DemoDb.newId();
    db.products[id] = {
      'id': id,
      'game': 'other',
      'set_name': name,
      'sku_type': 'other',
      'display_name': name,
      'is_canonical': false,
      'created_by': userId,
      'created_at': DemoDb.nowIso(),
    };
    return Product.fromRow(db.products[id]!);
  });

  @override
  Future<Set<String>> follows(String userId) async => {...db.follows};
  @override
  Future<void> follow(String userId, String productId) async => db.follows.add(productId);
  @override
  Future<void> unfollow(String userId, String productId) async => db.follows.remove(productId);
  @override
  Future<List<Product>> nonCanonical() => _later(() => _where((p) => p['is_canonical'] == false));
  @override
  Future<void> merge(String fromId, String intoId) async => db.products[fromId]?['canonical_id'] = intoId;
}

class DemoFeatureRequestRepository implements FeatureRequestRepository {
  DemoFeatureRequestRepository(this.db);
  final DemoDb db;

  List<FeatureRequest> _list(Iterable<Map<String, dynamic>> rows) => rows.map(FeatureRequest.fromRow).toList();

  @override
  Future<List<FeatureRequest>> all({String sort = 'upvotes', String? category}) => _later(() {
    final rows = db.featureRequests.values
        .where(
          (r) =>
              r['status'] != 'queued' && r['status'] != 'discarded' && (category == null || r['category'] == category),
        )
        .toList();
    int byVotes(Map a, Map b) => (b['upvote_count'] as int).compareTo(a['upvote_count'] as int);
    rows.sort(switch (sort) {
      'status' => (a, b) => (a['status'] as String).compareTo(b['status'] as String),
      'date' => (a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String),
      _ => byVotes,
    });
    return _list(rows);
  });

  @override
  Future<List<FeatureRequest>> mine(String userId) =>
      _later(() => _list(db.featureRequests.values.where((r) => r['user_id'] == userId)));

  @override
  Future<List<FeatureRequest>> adminQueue() => _later(() => _list(db.featureRequests.values));

  @override
  Future<FeatureRequest> create(Map<String, dynamic> insert) => _later(() {
    final id = DemoDb.newId();
    db.featureRequests[id] = {
      ...insert,
      'id': id,
      'status': 'queued',
      'upvote_count': 0,
      'org_count': 0,
      'created_at': DemoDb.nowIso(),
    };
    return FeatureRequest.fromRow(db.featureRequests[id]!);
  });

  @override
  Future<Set<String>> myUpvotes(String userId) async =>
      db.upvotes.where((k) => k.startsWith('$userId|')).map((k) => k.split('|').last).toSet();

  void _count(String requestId, int delta) {
    final r = db.featureRequests[requestId];
    if (r != null) r['upvote_count'] = (r['upvote_count'] as int) + delta;
  }

  @override
  Future<void> upvote(String userId, String requestId) async {
    if (db.upvotes.add('$userId|$requestId')) _count(requestId, 1);
  }

  @override
  Future<void> unvote(String userId, String requestId) async {
    if (db.upvotes.remove('$userId|$requestId')) _count(requestId, -1);
  }

  @override
  Future<void> setStatus(String id, String status, {String? summary, String? parentId}) async =>
      db.featureRequests[id]?.addAll({'status': status, 'summary': ?summary, 'parent_id': ?parentId});

  @override
  Future<List<Map<String, dynamic>>> comments(String requestId) async =>
      db.comments.where((c) => c['request_id'] == requestId).toList();

  @override
  Future<void> comment(String userId, String requestId, String body) async => db.comments.add({
    'id': DemoDb.newId(),
    'request_id': requestId,
    'user_id': userId,
    'body': body,
    'created_at': DemoDb.nowIso(),
  });
}

class DemoAlertRepository implements AlertRepository {
  DemoAlertRepository(this.db);
  final DemoDb db;

  @override
  Future<List<AlertItem>> list(String userId) => _later(() {
    final rows = db.alerts.values.where((a) => a['user_id'] == userId).toList()
      ..sort((a, b) => (b['sent_at'] as String).compareTo(a['sent_at'] as String));
    return rows.map(AlertItem.fromRow).toList();
  });

  @override
  Future<void> markOpened(String id) async => db.alerts[id]?['opened_at'] = DemoDb.nowIso();
  @override
  Future<void> registerPushToken(String userId, String token) async {}
  @override
  Stream<List<Map<String, dynamic>>> stream(String userId) => const Stream.empty();
}

class DemoShareRepository implements ShareRepository {
  DemoShareRepository(this.db);
  final DemoDb db;

  @override
  Future<String> createLink(String routeId) async {
    final existing = db.shares.entries.where((e) => e.value == routeId).firstOrNull;
    final token = existing?.key ?? DemoDb.newId().substring(0, 10);
    db.shares[token] = routeId;
    return 'https://canvasroute.app/r/$token';
  }

  @override
  Future<SharedRoute?> fetch(String token) => _later(() {
    final routeId = db.shares[token];
    final r = routeId == null ? null : db.routes[routeId];
    if (r == null) return null;
    final stops = db.stops.values.where((s) => s['route_id'] == routeId).toList()
      ..sort((a, b) => (a['stop_order'] as int).compareTo(b['stop_order'] as int));
    return SharedRoute(
      name: r['name'] as String,
      mode: r['mode'] as String,
      stops: stops.map(Stop.fromRow).toList(),
      canFork: true,
      ownerHandle: db.profiles[r['user_id']]?['handle'] as String?,
    );
  });
}

class DemoTripRepository implements TripRepository {
  DemoTripRepository(this.db);
  final DemoDb db;

  @override
  Future<List<Trip>> forUser(String userId, String mode) => _later(() {
    final rows = db.trips.values.where((t) => t['user_id'] == userId && t['mode'] == mode).map(Trip.fromRow).toList();
    return rows..sort((a, b) => b.day.compareTo(a.day));
  });

  @override
  Future<Trip> upsert(Map<String, dynamic> insert) => _later(() {
    final existing = db.trips.values.where((t) => t['route_id'] == insert['route_id']).firstOrNull;
    final row = existing ?? {'id': DemoDb.newId()};
    row.addAll(insert);
    db.trips[row['id'] as String] = row;
    return Trip.fromRow(row);
  });
}
