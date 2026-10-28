import 'package:flutter/material.dart';

import '../data/models/app_mode.dart';
import '../data/models/visit_field.dart';
import 'mode_pack.dart';

const fieldSalesPack = ModePack(
  id: AppMode.fieldSales,
  label: 'Field Sales',
  tagline: 'Find businesses, build the route, log every door.',
  icon: Icons.storefront_outlined,
  routeNamePrefix: 'Route',
  searchHint: 'Search businesses, e.g. "dental offices"',
  searchSuggestions: ['restaurants', 'dental offices', 'auto repair', 'salons', 'law firms', 'gyms'],
  stopSources: [StopSourceId.places, StopSourceId.manual],
  requiresTimeWindow: false,
  optimizer: OptimizerKind.distance,
  defaultOutcomes: ['Contacted', 'No Answer', 'Not Interested', 'Interested'],
  defaultVisitFields: [
    VisitFieldDefinition(key: 'outcome', label: 'Outcome', type: FieldType.selector),
    VisitFieldDefinition(key: 'contactName', label: 'Contact Name', type: FieldType.text),
    VisitFieldDefinition(key: 'phone', label: 'Phone', type: FieldType.text),
    VisitFieldDefinition(key: 'email', label: 'Email', type: FieldType.text),
    VisitFieldDefinition(key: 'notes', label: 'Notes', type: FieldType.multiline),
    VisitFieldDefinition(key: 'followUpDate', label: 'Follow-up Date', type: FieldType.date),
    VisitFieldDefinition(key: 'photo', label: 'Photo', type: FieldType.photo),
  ],
  defaultExportFields: ['stopName', 'address', 'outcome', 'contactName', 'phone', 'email', 'notes', 'followUpDate', 'visitedAt'],
  exportHeaders: {
    'stopName': 'Stop Name',
    'address': 'Address',
    'outcome': 'Outcome',
    'contactName': 'Contact Name',
    'phone': 'Phone',
    'email': 'Email',
    'notes': 'Notes',
    'followUpDate': 'Follow-up Date',
    'visitedAt': 'Visited At',
  },
  communityPins: false,
  communityReports: false,
  reportStatuses: [],
  outcomeToReportStatus: {},
  alerts: [AlertKind.followUp],
  onboarding: [
    OnboardingPage(
      headline: 'Find businesses near you',
      subtext: 'Search any area, tap the map, and build your prospect list on the fly.',
      icon: Icons.travel_explore,
    ),
    OnboardingPage(
      headline: 'Build your perfect route',
      subtext: 'Reorder stops, optimize for drive time, and see your whole day at a glance.',
      icon: Icons.alt_route,
    ),
    OnboardingPage(
      headline: 'Log every door',
      subtext: 'Capture outcomes, notes, and contacts at each stop. Export when you\'re done.',
      icon: Icons.fact_check_outlined,
    ),
  ],
  tour: ModeTour(
    search: TourCopy(
      'Find businesses',
      'Search any kind of business. Results land on the map around wherever you\'re looking.',
    ),
    filters: TourCopy('One-tap searches', 'Tap one to search the area on screen.'),
    draft: TourCopy(
      'Your draft route',
      'Tap a pin to add it, or long-press the map to drop your own stop. Open Draft to put them in order and save.',
    ),
    routes: TourCopy(
      'Saved routes',
      'Start a route, pick up where you left off, or export what you logged.',
    ),
  ),
  emptyRoutesCopy: 'No routes yet — head to the map to start building.',
  visitVerb: 'Log Visit',
  stopNoun: 'stop',
  proProductId: 'canvasroute_pro_monthly',
  proLabel: 'Pro',
);
