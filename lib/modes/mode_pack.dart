import 'package:flutter/material.dart';

import '../data/models/app_mode.dart';
import '../data/models/visit_field.dart';

enum StopSourceId { places, manual, community, listingLink }

enum OptimizerKind { distance, timeWindow, restockWindow }

enum AlertKind { followUp, newPinNearby, stockReportNearby }

class ReportStatusOption {
  const ReportStatusOption(this.value, this.label, this.icon, {this.positive = false});
  final String value;
  final String label;
  final IconData icon;

  /// Positive statuses light the freshness ring (in stock, still open).
  final bool positive;
}

class ProPerk {
  const ProPerk(this.icon, this.label);
  final IconData icon;
  final String label;
}

class OnboardingPage {
  const OnboardingPage({required this.headline, required this.subtext, required this.icon});
  final String headline;
  final String subtext;
  final IconData icon;
}

/// A vertical pack. Screens render from this; they never branch on [id].
/// If a feature needs `if (mode == x)`, add a field here instead (spec §2.3).
class ModePack {
  const ModePack({
    required this.id,
    required this.label,
    required this.tagline,
    required this.icon,
    required this.routeNamePrefix,
    required this.searchHint,
    required this.searchSuggestions,
    required this.stopSources,
    required this.requiresTimeWindow,
    required this.optimizer,
    required this.defaultOutcomes,
    required this.defaultVisitFields,
    required this.defaultExportFields,
    required this.exportHeaders,
    required this.communityPins,
    required this.communityReports,
    required this.reportStatuses,
    required this.outcomeToReportStatus,
    required this.alerts,
    required this.onboarding,
    required this.emptyRoutesCopy,
    required this.visitVerb,
    required this.stopNoun,
    required this.spotlightTitle,
    required this.planLabel,
    required this.planMaxStops,
    required this.outcomeIcons,
    required this.communityNoun,
    required this.winOutcomes,
    required this.winNoun,
    required this.routeNoun,
    required this.routesTitle,
    this.placesQueryPreset,
    this.pinCategories = const [],
    this.freeRouteLimit,
    this.proProductId,
    this.includedInPlan = false,
    this.customFieldsPro = false,
    this.visitHistoryPro = false,
    this.mileageLog = false,
    this.webBilling = false,
    this.crmExport = false,
    this.teamPlan = false,
    this.proLabel = 'Pro',
    this.proPrice = '',
    this.proPitch = '',
    this.proPerks = const [],
    this.suggestionIcons = const {},
    this.summaryTotals = const [],
    this.supportsHosting = false,
    this.hostSignHeadline = 'SALE',
    this.profileAsksCompany = false,
    this.pinsPlacesStops = false,
    this.saveVisitLabel = 'Save visit',
    this.spotLabel,
    this.startLabel,
    this.followUpsLabel,
    this.pinCategoryWildcard,
    this.summaryCountField,
    this.photoHint,
    this.productCatalog = false,
  });

  final AppMode id;
  final String label;
  final String tagline;
  final IconData icon;
  final String routeNamePrefix;
  final String searchHint;
  final List<String> searchSuggestions;
  final List<StopSourceId> stopSources;

  /// Appended to free-text searches, e.g. retail chains for Card Drops.
  final String? placesQueryPreset;
  final bool requiresTimeWindow;
  final OptimizerKind optimizer;
  final List<String> defaultOutcomes;
  final List<VisitFieldDefinition> defaultVisitFields;
  final List<String> defaultExportFields;
  final Map<String, String> exportHeaders;
  final bool communityPins;
  final bool communityReports;
  final List<ReportStatusOption> reportStatuses;

  /// Visit outcome label → report status; when present, saving a visit auto-files a report.
  final Map<String, String> outcomeToReportStatus;
  final List<AlertKind> alerts;
  final List<OnboardingPage> onboarding;
  final String emptyRoutesCopy;
  final String visitVerb; // "Log Visit" / "Log Stop" / "Report Shelf"
  final String stopNoun; // "stop" / "sale" / "store"

  /// Map deck header after the count, e.g. "4 stores worth a stop today".
  final String spotlightTitle;

  /// One-tap planner button on the map deck, e.g. "Plan my run".
  final String planLabel;

  /// How many top-ranked stops the one-tap planner takes.
  final int planMaxStops;

  /// Icons for the runner's one-tap outcome tiles; custom outcomes fall back to a check.
  final Map<String, IconData> outcomeIcons;

  /// Who sees shared reports: "Shared with nearby collectors".
  final String communityNoun;

  /// Outcomes the run recap counts as a win, e.g. "In stock".
  final List<String> winOutcomes;

  /// Singular noun for a win on the recap: "3 finds", "2 leads".
  final String winNoun;

  /// "route" / "run": the routes tab is its plural.
  final String routeNoun;

  /// Routes screen title, e.g. "Card runs".
  final String routesTitle;

  String get routesTab => '${routeNoun[0].toUpperCase()}${routeNoun.substring(1)}s';

  IconData outcomeIcon(String outcome) => outcomeIcons[outcome] ?? Icons.check_circle_outline;
  final List<String> pinCategories;
  final int? freeRouteLimit;
  final String? proProductId;

  /// A Pro/Team plan unlocks this vertical without its own product (Field Sales).
  final bool includedInPlan;

  /// Adding outcomes or custom visit fields needs the paid tier.
  final bool customFieldsPro;

  /// The last outcome and notes at a place you've visited need the paid tier;
  /// "Visited 3×" itself is always shown.
  final bool visitHistoryPro;

  /// Log each run's miles for expense reports, with the IRS rate applied.
  final bool mileageLog;

  /// Sold on the web (Stripe Checkout) rather than through the app stores:
  /// business plans, often expensed.
  final bool webBilling;

  /// Offer HubSpot and Salesforce import files next to the plain CSV (paid tier).
  final bool crmExport;

  /// Teams: a manager's activity view, a join code for reps, and teammates'
  /// recent outcomes on business sheets. Creating a team needs the Team plan.
  final bool teamPlan;

  /// Store product for the Team plan, billed per seat on the web.
  static const teamProductId = 'canvasroute_team_monthly';
  final String proLabel;

  /// Display price, e.g. "\$4.99 / mo".
  final String proPrice;

  /// Paywall headline, e.g. "Never miss a restock".
  final String proPitch;
  final List<ProPerk> proPerks;

  /// Icons for the map's quick-start category cards.
  final Map<String, IconData> suggestionIcons;
  IconData suggestionIcon(String s) => suggestionIcons[s] ?? Icons.search;

  /// Saving one more route would pass the free limit.
  bool atRouteLimit(int saved, {required bool paying}) => !paying && freeRouteLimit != null && saved >= freeRouteLimit!;

  /// Custom-field keys summed on the Route Summary (e.g. "spent").
  final List<String> summaryTotals;
  final bool supportsHosting;

  /// The big word on a host's printable sign.
  final String hostSignHeadline;

  /// Profile asks for company and title (they head CSV exports).
  final bool profileAsksCompany;

  /// A logged Places stop gets a community store pin so its report has a home.
  final bool pinsPlacesStops;

  /// The visit form's save button, e.g. "Save report".
  final String saveVisitLabel;

  /// When set, a stop dropped on the map can be shared as a community pin
  /// (with a photo of the sign), e.g. "Share it with nearby hunters".
  /// Onboarding button when this build ships only this mode ("Show me sales near me").
  /// Null reads "Start with <label>".
  final String? startLabel;

  /// When set, visits with a follow-up date are gathered on a screen with this
  /// title ("Follow-ups"), reachable from the drawer and the routes list.
  final String? followUpsLabel;

  final String? spotLabel;

  /// The category that matches any hunt filter, e.g. "Everything".
  final String? pinCategoryWildcard;

  /// A one-per-line visit field whose lines the recap counts, e.g. items bought.
  final ({String key, String noun})? summaryCountField;

  /// Shown under the visit photo picker when photos are shared with the community.
  final String? photoHint;
  final bool productCatalog;

  bool get usesTimeWindows => optimizer != OptimizerKind.distance;
  bool get hasCommunity => communityPins || communityReports;
  bool hasSource(StopSourceId s) => stopSources.contains(s);
  List<VisitFieldDefinition> get enabledVisitFields => defaultVisitFields.where((f) => f.enabled).toList();
}
