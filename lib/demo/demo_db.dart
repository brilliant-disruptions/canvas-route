import 'package:uuid/uuid.dart';

import '../core/logic/geo.dart';
import '../data/models/directions.dart';

/// In-memory stand-in for the Supabase database. Rows use the same
/// snake_case columns as the real tables so the app's `fromRow` mappers
/// work unchanged. Everything resets on reload.
class DemoDb {
  DemoDb._();

  static const userId = 'demo-user';
  static const home = Waypoint(32.8140, -96.7900); // Dallas, between Uptown and Lakewood

  final profiles = <String, Map<String, dynamic>>{};
  final settings = <String, Map<String, dynamic>>{};
  final routes = <String, Map<String, dynamic>>{};
  final stops = <String, Map<String, dynamic>>{};
  final visits = <String, Map<String, dynamic>>{};
  final pins = <String, Map<String, dynamic>>{};
  final pinPhotos = <Map<String, dynamic>>[];
  final products = <String, Map<String, dynamic>>{};
  final reports = <String, Map<String, dynamic>>{};
  final follows = <String>{};
  final alerts = <String, Map<String, dynamic>>{};
  final featureRequests = <String, Map<String, dynamic>>{};
  final upvotes = <String>{}; // "$userId|$requestId"
  final comments = <Map<String, dynamic>>[];
  final shares = <String, String>{}; // token → routeId
  final pinInterest = <String, int>{}; // pinId → other hunters planning to go (seeded)

  static String newId() => const Uuid().v4();
  static String iso(DateTime d) => d.toUtc().toIso8601String();
  static String nowIso() => iso(DateTime.now());

  double milesFromHome(double lat, double lng) => metersToMiles(haversineMeters(home.lat, home.lng, lat, lng));

  factory DemoDb.seeded() {
    final db = DemoDb._();
    _seed(db);
    return db;
  }
}

// ---------------------------------------------------------------------------
// Seed data. Places are real Dallas neighborhoods; businesses are fictional.
// ---------------------------------------------------------------------------

/// The Saturday the demo's sales are on: this one, unless it's Saturday
/// afternoon and they'd all be over, in which case next week's.
DateTime _nextSaturday(DateTime from) {
  final d = DateTime(from.year, from.month, from.day);
  final add = (DateTime.saturday - d.weekday) % 7;
  return d.add(Duration(days: add == 0 && from.hour >= 13 ? 7 : add));
}

void _seed(DemoDb db) {
  final now = DateTime.now();
  final sat = _nextSaturday(now);
  final lastSat = sat.subtract(const Duration(days: 7));
  DateTime at(DateTime day, int h, [int m = 0]) => DateTime(day.year, day.month, day.day, h, m);
  const uid = DemoDb.userId;
  final h = DemoDb.home;

  db.profiles[uid] = {
    'id': uid,
    'handle': 'sam_demo',
    'name': 'Sam Demo',
    'title': 'Territory Rep',
    'company': 'Lone Star Dental Supply',
    'email': 'sam@demo.canvasroute.app',
    'phone': '(214) 555-0142',
    'office_address': '2100 Ross Ave, Dallas, TX',
    'office_lat': 32.7876,
    'office_lng': -96.7985,
    'is_admin': true,
    'plan': 'pro',
    'active_mode': 'field_sales',
    'trust_score': 62,
    'home_lat': h.lat,
    'home_lng': h.lng,
    'alert_radius_mi': 10,
    'auto_share_reports': true,
    'has_onboarded': false,
    'created_at': DemoDb.nowIso(),
    'updated_at': DemoDb.nowIso(),
  };
  db.settings[uid] = {
    'user_id': uid,
    'mode_overrides': <String, dynamic>{},
    'appearance': 'dark', // matches the brand; switch in Preferences
    'route_end_preference': 'current_location',
  };

  // ---- Products (Pokémon TCG catalog, same as migration 008) ----
  const sets = [
    ('Scarlet & Violet 151', '2023-09-22'), ('Paldean Fates', '2024-01-26'), ('Temporal Forces', '2024-03-22'),
    ('Twilight Masquerade', '2024-05-24'), ('Shrouded Fable', '2024-08-02'), ('Stellar Crown', '2024-09-13'),
    ('Surging Sparks', '2024-11-08'), ('Prismatic Evolutions', '2025-01-17'), ('Journey Together', '2025-03-28'),
    ('Destined Rivals', '2025-05-30'), ('Black Bolt', '2025-07-18'), ('White Flare', '2025-07-18'),
    ('Mega Evolution', '2025-09-26'), ('Phantasmal Flames', '2025-11-14'), ('Ascended Heroes', '2026-01-30'),
    ('Perfect Order', '2026-03-27'), ('Chaos Rising', '2026-05-22'), ('Pitch Black', '2026-07-17'),
    ('Delta Reign', '2026-11-06'),
  ];
  const skus = [
    ('etb', 'Elite Trainer Box'), ('booster_box', 'Booster Box'), ('bundle', 'Booster Bundle'),
    ('blister', 'Blister Pack'), ('tin', 'Tin'), ('collection', 'Collection Box'), ('pack', 'Single Booster Pack'),
  ];
  final productIds = <String, String>{};
  for (final (set, date) in sets) {
    for (final (sku, label) in skus) {
      final id = DemoDb.newId();
      final name = '$set — $label';
      productIds[name] = id;
      db.products[id] = {
        'id': id, 'game': 'pokemon', 'set_name': set, 'sku_type': sku, 'display_name': name,
        'release_date': date, 'is_canonical': true, 'created_at': DemoDb.nowIso(),
      };
    }
  }
  String pid(String name) => productIds[name]!;

  // ---- Field Sales routes ----
  final dental = demoCatalog['dental']!;
  String addRoute(String mode, String name, List<Map<String, dynamic>> places,
      {int visited = 0, String status = 'not_started', DateTime? lastRun, bool optimized = false, List<Map<String, dynamic>> visitValues = const []}) {
    final rid = DemoDb.newId();
    db.routes[rid] = {
      'id': rid, 'user_id': uid, 'mode': mode, 'name': name, 'stop_count': places.length, 'is_optimized': optimized,
      'status': status, 'last_run_at': lastRun == null ? null : DemoDb.iso(lastRun), 'forked_from': null,
      'created_at': DemoDb.iso(now.subtract(Duration(days: 20 - db.routes.length))), 'updated_at': DemoDb.nowIso(),
    };
    for (var i = 0; i < places.length; i++) {
      final p = places[i];
      final sid = DemoDb.newId();
      db.stops[sid] = {
        'id': sid, 'route_id': rid, 'place_id': p['place_id'], 'pin_id': p['pin_id'], 'source': p['source'] ?? 'places',
        'name': p['name'], 'address': p['address'], 'lat': p['lat'], 'lng': p['lng'], 'stop_order': i, 'visited': i < visited,
        'opens_at': p['opens_at'], 'closes_at': p['closes_at'], 'listing_url': p['listing_url'], 'created_at': DemoDb.nowIso(),
      };
      if (i < visited && i < visitValues.length) {
        final v = visitValues[i];
        final vid = DemoDb.newId();
        final when = DemoDb.iso((lastRun ?? now).subtract(Duration(minutes: (visited - i) * 20)));
        db.visits[vid] = {
          'id': vid, 'stop_id': sid, 'route_id': rid, 'user_id': uid, 'outcome': v['outcome'], 'contact_name': v['contact_name'],
          'phone': v['phone'], 'email': v['email'], 'notes': v['notes'], 'follow_up_date': v['follow_up_date'], 'photo_path': null,
          'custom_fields': v['custom_fields'] ?? <String, dynamic>{}, 'created_at': when, 'updated_at': when,
        };
      }
    }
    return rid;
  }

  addRoute('field_sales', 'Lakewood dentists', dental.take(6).toList(),
      visited: 2, status: 'in_progress', lastRun: now.subtract(const Duration(hours: 2)), optimized: true, visitValues: [
    {'outcome': 'Interested', 'contact_name': 'Dr. Priya Shah', 'phone': '(214) 555-0118', 'notes': 'Wants a quote on sterilization pouches. Office manager is Dana.', 'follow_up_date': _date(now.add(const Duration(days: 3)))},
    {'outcome': 'No Answer', 'notes': 'Closed for lunch until 1:30.'},
  ]);
  addRoute('field_sales', 'Uptown med spas', demoCatalog['salons']!.take(5).toList());
  addRoute('field_sales', 'Deep Ellum restaurants', demoCatalog['restaurants']!.take(7).toList(),
      visited: 7, status: 'complete', lastRun: now.subtract(const Duration(days: 6)), optimized: true, visitValues: [
    for (final o in ['Contacted', 'Interested', 'Not Interested', 'Contacted', 'No Answer', 'Interested', 'Contacted'])
      {'outcome': o, 'notes': o == 'Interested' ? 'Asked for pricing sheet.' : null},
  ]);

  // ---- Yard sale pins (this Saturday, plus one next week) ----
  String pin(Map<String, dynamic> row) {
    final id = DemoDb.newId();
    db.pins[id] = {
      'id': id, 'owner_id': null, 'place_id': null, 'categories': <String>[], 'status': 'live', 'confirmations': 0,
      'share_token': id.substring(0, 12), 'created_at': DemoDb.nowIso(), 'updated_at': DemoDb.nowIso(), ...row,
    };
    return id;
  }

  Map<String, dynamic> sale(String name, String addr, double dLat, double dLng, int open, int close, List<String> cats,
          {String origin = 'host', DateTime? day, String? early, String? notes, String? owner, int confirms = 0}) =>
      {
        'mode': 'yard_sales', 'kind': 'yard_sale', 'origin': origin, 'name': name, 'address': addr,
        'lat': h.lat + dLat, 'lng': h.lng + dLng, 'opens_at': DemoDb.iso(at(day ?? sat, open)), 'closes_at': DemoDb.iso(at(day ?? sat, close)),
        'categories': cats, 'early_birds': early, 'notes': notes, 'owner_id': owner, 'confirmations': confirms,
      };

  final ys = [
    pin(sale('Multi-family sale — 4 houses', '6120 Velasco Ave, Dallas, TX', 0.010, 0.022, 7, 13, ['Furniture', 'Kids', 'Tools'],
        early: 'not_welcome', notes: 'Cash or Venmo. Big furniture in the garage. Please no early birds before 7.')),
    pin(sale('Estate sale: mid-century + vinyl', '5810 Llano Ave, Dallas, TX', 0.004, 0.012, 8, 14, ['Collectibles', 'Furniture'],
        notes: 'Numbers handed out at 7:30. Teak dining set, 300+ records, barware.')),
    pin(sale('Moving sale — everything goes', '4431 Bryan St, Dallas, TX', -0.010, -0.004, 7, 11, ['Everything'], early: 'welcome')),
    pin(sale('Kids clothes & toys', '6810 La Vista Dr, Dallas, TX', 0.020, 0.040, 7, 12, ['Kids', 'Clothing'])),
    pin(sale('Garage cleanout', '5302 Vickery Blvd, Dallas, TX', 0.026, 0.004, 8, 12, ['Tools'], origin: 'spotted', confirms: 2)),
    pin(sale('Church rummage sale', '4015 Normandy Ave, Dallas, TX', 0.034, -0.030, 7, 13, ['Everything', 'Books'])),
    pin(sale('Neighborhood sale — 12 homes', 'Lakewood Heights, Dallas, TX', -0.002, 0.050, 7, 14, ['Everything'],
        notes: 'Look for the orange balloons. Maps at the corner of Lakewood Blvd and Abrams.')),
    pin(sale('Book & record swap', '5714 Martel Ave, Dallas, TX', 0.016, -0.006, 9, 15, ['Books', 'Collectibles'],
        day: sat.add(const Duration(days: 7)))),
    pin(sale('Your sale: Velasco garage sale', '6127 Velasco Ave, Dallas, TX', 0.011, 0.020, 7, 12, ['Furniture', 'Electronics'],
        owner: uid, notes: 'Posted from the demo account.')),
  ];

  db.pins[ys.last]!['share_token'] = 'demo-sale'; // the demo host's sign QR: /s/demo-sale
  db.pinInterest[ys.last] = 14;

  final lastSales = [
    for (final (name, dLat, dLng) in [
      ('Swiss Ave estate sale', 0.002, 0.018), ('Junius Heights garage sale', -0.004, 0.026), ('Lowest Greenville moving sale', -0.012, 0.008),
      ('Munger Place multi-family', -0.008, 0.012), ('Bryan Place yard sale', -0.016, -0.002),
    ])
      {'name': name, 'address': '$name, Dallas, TX', 'lat': h.lat + dLat, 'lng': h.lng + dLng, 'source': 'manual',
       'opens_at': DemoDb.iso(at(lastSat, 7)), 'closes_at': DemoDb.iso(at(lastSat, 12))},
  ];
  addRoute('yard_sales', 'Yard sales · last Saturday', lastSales, visited: 5, status: 'complete', lastRun: at(lastSat, 11), visitValues: [
    {'outcome': 'Bought', 'custom_fields': {'items': 'Eames-style lounge chair\nCast iron skillet', 'spent': 42.0, 'wouldReturn': true}},
    {'outcome': 'Bought', 'custom_fields': {'items': 'Blue Note pressing, 1962\nRecord crate', 'spent': 18.5, 'wouldReturn': true}},
    {'outcome': 'Looked, nothing', 'custom_fields': {'wouldReturn': false}},
    {'outcome': 'Bought', 'custom_fields': {'items': 'LEGO bin (~4 lbs)\nKids bike helmet\nBoard games x3', 'spent': 12.0, 'wouldReturn': false}},
    {'outcome': 'Closed early', 'custom_fields': <String, dynamic>{}},
  ]);

  // ---- Card Drops stores and report history ----
  final storeIds = <String, String>{};
  for (final s in demoCatalog['stores']!) {
    storeIds[s['place_id'] as String] = pin({
      'mode': 'card_drops', 'kind': 'store', 'origin': 'places', 'place_id': s['place_id'], 'name': s['name'],
      'address': s['address'], 'lat': s['lat'], 'lng': s['lng'],
    });
  }
  String sid(String placeId) => storeIds[placeId]!;

  void history(String pinId, int weekday, int hour, int weeks, String product, {int every = 1}) {
    for (var w = 1; w <= weeks; w += every) {
      final base = now.subtract(Duration(days: 7 * w));
      final day = base.subtract(Duration(days: (base.weekday - weekday) % 7));
      final when = at(day, hour, 10 + (w * 7) % 40);
      final id = DemoDb.newId();
      db.reports[id] = {
        'id': id, 'pin_id': pinId, 'user_id': 'community-${w % 5}', 'status': w % 4 == 0 ? 'restocking_now' : 'in_stock',
        'product_id': pid(product), 'qty': 4 + (w * 3) % 9, 'price_cents': null, 'purchase_limit': w.isEven ? 2 : null,
        'line_present': w % 3 == 0, 'trust_at_filing': 55 + w % 20, 'created_at': DemoDb.iso(when),
      };
    }
  }

  history(sid('pl_target_central'), DateTime.tuesday, 8, 12, 'Prismatic Evolutions — Elite Trainer Box');
  history(sid('pl_target_central'), DateTime.friday, 8, 8, 'Destined Rivals — Booster Bundle', every: 2);
  history(sid('pl_walmart_retail'), DateTime.thursday, 9, 6, 'Phantasmal Flames — Booster Bundle');
  history(sid('pl_costco_churchill'), DateTime.saturday, 10, 11, 'Ascended Heroes — Collection Box');
  history(sid('pl_bn_northwest'), DateTime.saturday, 9, 3, 'Chaos Rising — Elite Trainer Box');
  history(sid('pl_collectors_cave'), DateTime.saturday, 11, 9, 'Pitch Black — Booster Box');
  history(sid('pl_collectors_cave'), DateTime.wednesday, 16, 6, 'Perfect Order — Booster Bundle');

  void report(String pinId, String status, Duration ago, String product, {int? qty, int? price, int? limit, bool? line}) {
    final id = DemoDb.newId();
    db.reports[id] = {
      'id': id, 'pin_id': pinId, 'user_id': 'community-9', 'status': status, 'product_id': pid(product), 'qty': qty,
      'price_cents': price, 'purchase_limit': limit, 'line_present': line, 'trust_at_filing': 70, 'created_at': DemoDb.iso(now.subtract(ago)),
    };
  }

  report(sid('pl_gamestop_greenville'), 'in_stock', const Duration(minutes: 9), 'Prismatic Evolutions — Elite Trainer Box', qty: 6, price: 4999, limit: 2);
  report(sid('pl_gamestop_greenville'), 'sold_out', const Duration(days: 9), 'Destined Rivals — Booster Bundle');
  report(sid('pl_target_central'), 'sold_out', const Duration(hours: 3), 'Prismatic Evolutions — Elite Trainer Box', line: true);
  report(sid('pl_walgreens_greenville'), 'didnt_carry', const Duration(days: 2), 'Surging Sparks — Blister Pack');

  final cardStops = [
    for (final p in ['pl_gamestop_greenville', 'pl_target_central', 'pl_collectors_cave', 'pl_walmart_retail'])
      {...demoCatalog['stores']!.firstWhere((s) => s['place_id'] == p), 'pin_id': sid(p), 'source': 'community'},
  ];
  // Shared at /r/demo-run so the invite landing can be opened cold.
  db.shares['demo-run'] = addRoute('card_drops', 'Card run · Saturday', cardStops, visited: 1, status: 'in_progress', lastRun: now.subtract(const Duration(minutes: 40)), visitValues: [
    {'outcome': 'In stock', 'notes': 'Vendor was stocking at 8:10. Two people already waiting.', 'custom_fields': {
      'products': [
        {'id': pid('Prismatic Evolutions — Elite Trainer Box'), 'name': 'Prismatic Evolutions — Elite Trainer Box'},
      ],
      'price': 49.99, 'qty': 6, 'purchaseLimit': 2, 'linePresent': true,
    }},
  ]);

  db.follows.add(pid('Prismatic Evolutions — Elite Trainer Box'));
  void alert(String kind, String pinId, String title, String body, Duration ago, {bool opened = true}) {
    final id = DemoDb.newId();
    db.alerts[id] = {
      'id': id, 'user_id': uid, 'kind': kind, 'pin_id': pinId, 'report_id': null, 'title': title, 'body': body,
      'sent_at': DemoDb.iso(now.subtract(ago)), 'opened_at': opened ? DemoDb.nowIso() : null,
    };
  }

  alert('stock_report_nearby', sid('pl_gamestop_greenville'), 'Prismatic Evolutions ETB in stock', 'GameStop · 1.9 mi · 6 left', const Duration(minutes: 9), opened: false);
  alert('stock_report_nearby', sid('pl_target_central'), 'Restocking now at Target', 'Target · 0.9 mi · line present', const Duration(days: 1));
  alert('new_pin_nearby', ys[1], 'New estate sale this Saturday', 'Mid-century + vinyl · 0.8 mi', const Duration(days: 2));

  // ---- Feature requests ----
  for (final (title, cat, status, votes, orgs, summary) in [
    ('Sync visits to HubSpot', 'export', 'development', 41, 4, 'Two-way sync of outcomes and notes into HubSpot activities.'),
    ('Offline mode for rural territories', 'routes', 'to_do', 28, 6, null),
    ('Bulk import stops from a spreadsheet', 'routes', 'backlog', 17, 3, null),
    ('Team leaderboard by outcomes', 'general', 'future_release', 12, 2, null),
    ('Show parking tips per stop', 'map', 'done', 9, 1, 'Shipped: notes field now shows on the stop card.'),
  ]) {
    final id = DemoDb.newId();
    db.featureRequests[id] = {
      'id': id, 'user_id': 'other-user', 'title': title, 'category': cat, 'status': status, 'summary': summary,
      'upvote_count': votes, 'org_count': orgs, 'interview_opt_in': false, 'created_at': DemoDb.iso(now.subtract(Duration(days: votes))),
      'problem': 'Submitted by a field rep during the beta.', 'role': 'field_rep', 'frequency': 'weekly', 'impact': 'lost_time',
    };
  }
}

String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Searchable catalog for the demo Places service. Coordinates are offsets
// from DemoDb.home so everything lands on the demo map.
// ---------------------------------------------------------------------------

Map<String, dynamic> _place(String key, String name, String address, double dLat, double dLng, {double? rating}) => {
      'place_id': 'pl_$key',
      'name': name,
      'address': address,
      'lat': DemoDb.home.lat + dLat,
      'lng': DemoDb.home.lng + dLng,
      'rating': rating,
      'source': 'places',
    };

final demoCatalog = <String, List<Map<String, dynamic>>>{
  'dental': [
    _place('lakewood_dental', 'Lakewood Family Dental', '6333 E Mockingbird Ln, Dallas, TX', 0.012, 0.035, rating: 4.8),
    _place('uptown_smiles', 'Uptown Smiles', '2911 Turtle Creek Blvd, Dallas, TX', -0.012, -0.012, rating: 4.6),
    _place('greenville_dentistry', 'Greenville Ave Dentistry', '5521 Greenville Ave, Dallas, TX', 0.030, 0.010, rating: 4.9),
    _place('knox_dental', 'Knox Henderson Dental Studio', '4514 Travis St, Dallas, TX', 0.002, -0.006, rating: 4.7),
    _place('preston_ortho', 'Preston Hollow Orthodontics', '8222 Douglas Ave, Dallas, TX', 0.048, -0.022, rating: 4.5),
    _place('white_rock_peds', 'White Rock Pediatric Dentistry', '9221 Garland Rd, Dallas, TX', 0.020, 0.060, rating: 4.9),
    _place('oak_lawn_dental', 'Oak Lawn Dental Group', '3500 Oak Lawn Ave, Dallas, TX', -0.004, -0.030, rating: 4.4),
    _place('lower_greenville_dental', 'Lower Greenville Dental', '1910 Greenville Ave, Dallas, TX', -0.002, 0.028, rating: 4.6),
  ],
  'restaurants': [
    _place('pecan_lodge', 'Smokestack BBQ', '2702 Main St, Dallas, TX', -0.030, 0.012, rating: 4.7),
    _place('taco_y_vino', 'Taco y Vino', '213 N Bishop Ave, Dallas, TX', -0.040, -0.020, rating: 4.5),
    _place('mesa_grill', 'Mesa Verde Grill', '2933 Commerce St, Dallas, TX', -0.032, 0.006, rating: 4.4),
    _place('noodle_bar', 'Elm St Noodle Bar', '2820 Elm St, Dallas, TX', -0.028, 0.014, rating: 4.6),
    _place('henderson_kitchen', 'Henderson Kitchen', '2213 N Henderson Ave, Dallas, TX', -0.002, 0.004, rating: 4.3),
    _place('lakewood_cafe', 'Lakewood Corner Cafe', '6340 Gaston Ave, Dallas, TX', 0.006, 0.030, rating: 4.5),
    _place('uptown_sushi', 'Uptown Sushi House', '3001 McKinney Ave, Dallas, TX', -0.010, -0.018, rating: 4.6),
    _place('greenville_pizza', 'Greenville Slice', '5600 Greenville Ave, Dallas, TX', 0.032, 0.012, rating: 4.2),
  ],
  'auto': [
    _place('ross_auto', 'Ross Ave Auto Care', '4500 Ross Ave, Dallas, TX', -0.012, 0.010, rating: 4.6),
    _place('lakewood_tire', 'Lakewood Tire & Brake', '6600 E Mockingbird Ln, Dallas, TX', 0.014, 0.040, rating: 4.4),
    _place('central_collision', 'Central Collision Center', '4300 N Central Expy, Dallas, TX', 0.008, -0.010, rating: 4.3),
    _place('lemmon_lube', 'Lemmon Ave Quick Lube', '5100 Lemmon Ave, Dallas, TX', 0.010, -0.040, rating: 4.1),
    _place('garland_motors', 'Garland Rd Motor Works', '8800 Garland Rd, Dallas, TX', 0.018, 0.064, rating: 4.7),
  ],
  'salons': [
    _place('knox_medspa', 'Knox Street Med Spa', '4527 Travis St, Dallas, TX', 0.004, -0.008, rating: 4.8),
    _place('glow_aesthetics', 'Glow Aesthetics Uptown', '2501 N Harwood St, Dallas, TX', -0.022, -0.016, rating: 4.6),
    _place('lakewood_salon', 'Lakewood Hair Studio', '1906 Abrams Pkwy, Dallas, TX', 0.000, 0.040, rating: 4.7),
    _place('mckinney_spa', 'McKinney Ave Skin & Laser', '3699 McKinney Ave, Dallas, TX', -0.004, -0.014, rating: 4.5),
    _place('greenville_barber', 'Greenville Barber Co.', '5810 Greenville Ave, Dallas, TX', 0.036, 0.012, rating: 4.9),
    _place('snider_beauty', 'Snider Plaza Beauty Bar', '6627 Snider Plaza, Dallas, TX', 0.042, -0.012, rating: 4.4),
  ],
  'law': [
    _place('ross_law', 'Ross & Partners LLP', '2200 Ross Ave, Dallas, TX', -0.026, -0.006, rating: 4.5),
    _place('turtle_creek_law', 'Turtle Creek Legal', '3811 Turtle Creek Blvd, Dallas, TX', -0.002, -0.022, rating: 4.7),
    _place('lakewood_law', 'Lakewood Family Law', '6301 Gaston Ave, Dallas, TX', 0.004, 0.028, rating: 4.6),
    _place('central_ip', 'Central Expressway IP Group', '5000 N Central Expy, Dallas, TX', 0.016, -0.008, rating: 4.3),
  ],
  'gyms': [
    _place('uptown_fit', 'Uptown Fitness Lab', '3200 McKinney Ave, Dallas, TX', -0.008, -0.016, rating: 4.6),
    _place('white_rock_crossfit', 'White Rock CrossFit', '9100 Garland Rd, Dallas, TX', 0.022, 0.066, rating: 4.8),
    _place('greenville_yoga', 'Greenville Yoga Collective', '5710 Greenville Ave, Dallas, TX', 0.034, 0.010, rating: 4.9),
    _place('deep_ellum_boxing', 'Deep Ellum Boxing Club', '2900 Canton St, Dallas, TX', -0.034, 0.010, rating: 4.5),
    _place('lemmon_pilates', 'Lemmon Ave Pilates', '4800 Lemmon Ave, Dallas, TX', 0.006, -0.036, rating: 4.7),
  ],
  'stores': [
    _place('target_central', 'Target', '4092 N Central Expy, Dallas, TX', 0.006, -0.012, rating: 4.3),
    _place('walmart_retail', 'Walmart Supercenter', '6185 Retail Rd, Dallas, TX', 0.040, 0.030, rating: 3.9),
    _place('costco_churchill', 'Costco Wholesale', '8055 Churchill Way, Dallas, TX', 0.050, -0.020, rating: 4.6),
    _place('gamestop_greenville', 'GameStop', '5500 Greenville Ave, Dallas, TX', 0.026, 0.012, rating: 4.2),
    _place('bn_northwest', 'Barnes & Noble', '7700 W Northwest Hwy, Dallas, TX', 0.044, -0.040, rating: 4.5),
    _place('walgreens_greenville', 'Walgreens', '2706 Greenville Ave, Dallas, TX', -0.006, 0.020, rating: 3.8),
    _place('collectors_cave', 'Collectors Cave (card shop)', '1820 Abrams Rd, Dallas, TX', -0.002, 0.040, rating: 4.9),
    _place('target_skillman', 'Target', '6464 E Northwest Hwy, Dallas, TX', 0.052, 0.034, rating: 4.2),
    _place('walmart_lemmon', 'Walmart Neighborhood Market', '4300 Lemmon Ave, Dallas, TX', 0.002, -0.034, rating: 3.7),
  ],
  'secondhand': [
    _place('estate_lakewood', 'Lakewood Estate Sales Co.', '6440 Lakewood Blvd, Dallas, TX', 0.010, 0.036, rating: 4.6),
    _place('thrift_greenville', 'Greenville Thrift', '5530 Greenville Ave, Dallas, TX', 0.030, 0.012, rating: 4.1),
    _place('flea_dallas', 'Dallas Flea Market (monthly)', '1200 S Lamar St, Dallas, TX', -0.048, -0.004, rating: 4.4),
    _place('antique_lovers', 'Lovers Lane Antique Mall', '5001 W Lovers Ln, Dallas, TX', 0.040, -0.036, rating: 4.5),
    _place('vintage_ross', 'Ross Ave Vintage', '4214 Ross Ave, Dallas, TX', -0.014, 0.004, rating: 4.3),
  ],
};

/// Search terms that select a catalog category.
const demoCatalogKeywords = <String, List<String>>{
  'dental': ['dental', 'dentist', 'orthodont', 'smile'],
  'restaurants': ['restaurant', 'food', 'bbq', 'taco', 'pizza', 'sushi', 'cafe', 'kitchen'],
  'auto': ['auto', 'repair', 'tire', 'mechanic', 'collision', 'lube'],
  'salons': ['salon', 'spa', 'hair', 'barber', 'beauty', 'aesthetic'],
  'law': ['law', 'legal', 'attorney', 'lawyer'],
  'gyms': ['gym', 'fitness', 'yoga', 'crossfit', 'pilates', 'boxing'],
  'stores': ['target', 'walmart', 'costco', 'gamestop', 'barnes', 'noble', 'walgreens', 'card', 'shop', 'store'],
  'secondhand': ['estate', 'thrift', 'flea', 'antique', 'vintage', 'garage', 'yard'],
};
