import 'package:flutter/material.dart';

import '../data/models/app_mode.dart';
import '../data/models/visit_field.dart';
import 'mode_pack.dart';

const yardSalesPack = ModePack(
  id: AppMode.yardSales,
  label: 'Yard Sales',
  tagline: 'Plan Saturday morning in the right order.',
  icon: Icons.yard_outlined,
  routeNamePrefix: 'Yard sales',
  searchHint: 'Search estate sales, thrift stores…',
  searchSuggestions: ['estate sale', 'thrift store', 'flea market', 'antique mall'],
  stopSources: [StopSourceId.community, StopSourceId.manual, StopSourceId.listingLink, StopSourceId.places],
  requiresTimeWindow: true,
  optimizer: OptimizerKind.timeWindow,
  defaultOutcomes: ['Bought', 'Looked, nothing', 'Closed early', 'Couldn\'t find'],
  defaultVisitFields: [
    VisitFieldDefinition(key: 'outcome', label: 'Outcome', type: FieldType.selector),
    VisitFieldDefinition(key: 'items', label: 'Items bought', type: FieldType.multiline, hint: 'One per line'),
    VisitFieldDefinition(key: 'spent', label: 'Spent', type: FieldType.currency),
    VisitFieldDefinition(key: 'photo', label: 'Haul photo', type: FieldType.photo),
    VisitFieldDefinition(key: 'wouldReturn', label: 'Would return', type: FieldType.toggle),
    VisitFieldDefinition(key: 'notes', label: 'Notes', type: FieldType.multiline),
  ],
  defaultExportFields: ['stopName', 'address', 'outcome', 'items', 'spent', 'wouldReturn', 'notes', 'visitedAt'],
  exportHeaders: {
    'stopName': 'Sale',
    'address': 'Address',
    'outcome': 'Outcome',
    'items': 'Items',
    'spent': 'Spent (\$)',
    'wouldReturn': 'Would Return',
    'notes': 'Notes',
    'visitedAt': 'Visited At',
  },
  communityPins: true,
  communityReports: true,
  reportStatuses: [
    ReportStatusOption('still_open', 'Still going', Icons.check_circle_outline, positive: true),
    ReportStatusOption('closing_soon', 'Closing soon', Icons.schedule),
    ReportStatusOption('packed_up', 'Packed up', Icons.cancel_outlined),
  ],
  outcomeToReportStatus: {
    'Bought': 'still_open',
    'Looked, nothing': 'still_open',
    'Closed early': 'packed_up',
  },
  alerts: [AlertKind.newPinNearby],
  onboarding: [
    OnboardingPage(
      headline: 'See this weekend\'s sales',
      subtext: 'Sales posted by hosts and spotted by other hunters, with hours, on one map.',
      icon: Icons.weekend_outlined,
    ),
    OnboardingPage(
      headline: 'Plan Saturday morning',
      subtext: 'We order your stops by closing time and warn you when you\'ll arrive too late.',
      icon: Icons.alt_route,
    ),
    OnboardingPage(
      headline: 'Log the haul',
      subtext: 'What you bought, what you spent, and whether you\'d go back. Export for taxes.',
      icon: Icons.shopping_bag_outlined,
    ),
  ],
  tour: ModeTour(
    search: TourCopy(
      'Find sales',
      'Search estate sales and thrift stores. Sales posted by hosts and spotted by other hunters are already on the map.',
    ),
    filters: TourCopy('Pick the day', 'Show only the sales open Saturday, Sunday or next weekend.'),
    draft: TourCopy(
      'Plan Saturday morning',
      'Tap a sale to add it, or long-press the map to drop one you spotted. Open Draft to put them in order by closing time.',
    ),
    routes: TourCopy(
      'Saved routes',
      'Run a route on the day and log the haul at each stop.',
    ),
  ),
  emptyRoutesCopy: 'No routes yet — pick this weekend\'s sales on the map.',
  visitVerb: 'Log Stop',
  stopNoun: 'sale',
  pinCategories: ['Furniture', 'Kids', 'Tools', 'Collectibles', 'Clothing', 'Electronics', 'Books', 'Everything'],
  freeRouteLimit: 1,
  proProductId: 'canvasroute_season_pass',
  proLabel: 'Season Pass',
  summaryTotals: ['spent'],
  supportsHosting: true,
);
