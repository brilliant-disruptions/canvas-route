import 'package:flutter/material.dart';

import '../data/models/app_mode.dart';
import '../data/models/visit_field.dart';
import 'mode_pack.dart';

const cardDropsPack = ModePack(
  id: AppMode.cardDrops,
  label: 'Card Drops',
  tagline: 'Know when your store restocks.',
  icon: Icons.style_outlined,
  routeNamePrefix: 'Card run',
  searchHint: 'Search stores, e.g. "Target"',
  searchSuggestions: ['Target', 'Walmart', 'Costco', 'GameStop', 'Barnes & Noble', 'Walgreens', 'card shop'],
  placesQueryPreset: 'store',
  stopSources: [StopSourceId.places, StopSourceId.community, StopSourceId.manual],
  requiresTimeWindow: false,
  optimizer: OptimizerKind.restockWindow,
  defaultOutcomes: ['In stock', 'Sold out', 'Limit per customer', 'Restocking now', 'Didn\'t carry'],
  defaultVisitFields: [
    VisitFieldDefinition(key: 'outcome', label: 'Shelf status', type: FieldType.selector),
    VisitFieldDefinition(key: 'products', label: 'Products seen', type: FieldType.productMulti),
    VisitFieldDefinition(key: 'price', label: 'Price', type: FieldType.currency),
    VisitFieldDefinition(key: 'qty', label: 'Qty on shelf', type: FieldType.number),
    VisitFieldDefinition(key: 'purchaseLimit', label: 'Purchase limit', type: FieldType.number),
    VisitFieldDefinition(key: 'linePresent', label: 'Line / scalpers present', type: FieldType.toggle),
    VisitFieldDefinition(key: 'photo', label: 'Photo', type: FieldType.photo),
    VisitFieldDefinition(key: 'notes', label: 'Notes', type: FieldType.multiline),
  ],
  defaultExportFields: ['stopName', 'address', 'outcome', 'products', 'price', 'qty', 'purchaseLimit', 'linePresent', 'visitedAt'],
  exportHeaders: {
    'stopName': 'Store',
    'address': 'Address',
    'outcome': 'Shelf Status',
    'products': 'Products',
    'price': 'Price (\$)',
    'qty': 'Qty',
    'purchaseLimit': 'Limit',
    'linePresent': 'Line Present',
    'visitedAt': 'Visited At',
  },
  communityPins: true,
  communityReports: true,
  reportStatuses: [
    ReportStatusOption('in_stock', 'In stock', Icons.inventory_2_outlined, positive: true),
    ReportStatusOption('restocking_now', 'Restocking now', Icons.local_shipping_outlined, positive: true),
    ReportStatusOption('limit_per_customer', 'Limit per customer', Icons.rule),
    ReportStatusOption('sold_out', 'Sold out', Icons.remove_shopping_cart_outlined),
    ReportStatusOption('didnt_carry', 'Didn\'t carry', Icons.block),
  ],
  outcomeToReportStatus: {
    'In stock': 'in_stock',
    'Sold out': 'sold_out',
    'Limit per customer': 'limit_per_customer',
    'Restocking now': 'restocking_now',
    'Didn\'t carry': 'didnt_carry',
  },
  alerts: [AlertKind.stockReportNearby],
  onboarding: [
    OnboardingPage(
      headline: 'Every store, one map',
      subtext: 'Target, Walmart, Costco, GameStop, your local card shop — with what the community saw on the shelf.',
      icon: Icons.map_outlined,
    ),
    OnboardingPage(
      headline: 'Know when it restocks',
      subtext: 'Every visit you log builds your store\'s restock pattern. Pooled with everyone else\'s, it stops being a guess.',
      icon: Icons.insights_outlined,
    ),
    OnboardingPage(
      headline: 'Get there first',
      subtext: 'Routes ordered by restock window, and alerts the minute product is reported near you.',
      icon: Icons.notifications_active_outlined,
    ),
  ],
  emptyRoutesCopy: 'No card runs yet — add your stores from the map.',
  visitVerb: 'Report Shelf',
  stopNoun: 'store',
  freeRouteLimit: 1,
  proProductId: 'canvasroute_drop_alerts_pro',
  proLabel: 'Drop Alerts Pro',
  productCatalog: true,
);
