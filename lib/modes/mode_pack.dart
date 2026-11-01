import 'package:flutter/material.dart';

import '../data/models/app_mode.dart';
import '../data/models/visit_field.dart';

enum StopSourceId { places, manual, community, listingLink }

enum OptimizerKind { distance, timeWindow }

class ReportStatusOption {
  const ReportStatusOption(this.value, this.label, this.icon, {this.positive = false, this.caution = false, this.ends = false});
  final String value;
  final String label;
  final IconData icon;

  /// Positive statuses light the freshness ring (in stock, still open).
  final bool positive;

  /// Still worth a stop, but hurry (closing soon).
  final bool caution;

  /// The listing is over for the day (packed up): greyed on the map, never planned.
  final bool ends;
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

/// What a mode's paid tier costs and unlocks.
class ProTier {
  const ProTier({
    this.label = 'Pro',
    this.price = '',
    this.pitch = '',
    this.perks = const [],
    this.productId,
    this.freeRouteLimit,
    this.includedInPlan = false,
    this.customFieldsPro = false,
    this.visitHistoryPro = false,
    this.webBilling = false,
  });

  /// Store product for the Team plan, billed per seat on the web.
  static const teamProductId = 'canvasroute_team_monthly';

  /// "Pro", "Season Pass".
  final String label;

  /// Display price, e.g. "\$9.99 / yr".
  final String price;

  /// Paywall headline, e.g. "Every Saturday, planned".
  final String pitch;
  final List<ProPerk> perks;

  /// Store product id; null means nothing to buy in this mode.
  final String? productId;

  /// Saved routes allowed before the paywall; null is unlimited.
  final int? freeRouteLimit;

  /// A Pro/Team plan unlocks this vertical without its own product (Field Sales).
  final bool includedInPlan;

  /// Adding outcomes or custom visit fields needs the paid tier.
  final bool customFieldsPro;

  /// The last outcome and notes at a place you've visited need the paid tier;
  /// "Visited 3×" itself is always shown.
  final bool visitHistoryPro;

  /// Sold on the web (Stripe Checkout) rather than through the app stores:
  /// business plans, often expensed.
  final bool webBilling;

  /// Saving one more route would pass the free limit.
  bool atRouteLimit(int saved, {required bool paying}) => !paying && freeRouteLimit != null && saved >= freeRouteLimit!;
}

/// Listings, live reports and hosting shared between users.
class Community {
  const Community({
    this.pins = false,
    this.reports = false,
    this.statuses = const [],
    this.outcomeToReportStatus = const {},
    this.noun = 'people',
    this.categories = const [],
    this.categoryWildcard,
    this.categoryKeywords = const {},
    this.spotLabel,
    this.photoHint,
    this.waitlistLabel,
    this.hosting = false,
    this.signHeadline = 'SALE',
    this.weekendDigest = false,
  });

  /// Community listings show on the map.
  final bool pins;

  /// Users file one-tap status reports on listings.
  final bool reports;
  final List<ReportStatusOption> statuses;

  /// Visit outcome label → report status; when present, saving a visit auto-files a report.
  final Map<String, String> outcomeToReportStatus;

  /// Who sees shared reports: "Shared with nearby hunters".
  final String noun;

  /// Listing categories, for the hunt filter and for hosts and spotters.
  final List<String> categories;

  /// The category that matches any hunt filter, e.g. "Everything".
  final String? categoryWildcard;

  /// Words that put a pasted post in a category (prefix match), e.g.
  /// Kids: ['kid', 'baby', 'toy']. Empty disables category detection.
  final Map<String, List<String>> categoryKeywords;

  /// When set, a stop dropped on the map can be shared as a community pin
  /// (with a photo of the sign), e.g. "Share it with nearby hunters".
  final String? spotLabel;

  /// Shown under the visit photo picker when photos are shared with the community.
  final String? photoHint;

  /// When set, an area with no listings shows a "not here yet" card whose main
  /// button (this label, e.g. "I'm hunting here") counts the user as waiting, and
  /// hosts see how many are waiting near them.
  final String? waitlistLabel;

  /// Users can post their own listing, with a printable sign and QR.
  final bool hosting;

  /// The big word on a host's printable sign.
  final String signHeadline;

  /// Offer a Friday-evening notification about the coming weekend's listings.
  final bool weekendDigest;

  bool get enabled => pins || reports;
}

/// Tools for people canvassing for work.
class BusinessTools {
  const BusinessTools({
    this.followUpsLabel,
    this.mileageLog = false,
    this.crmExport = false,
    this.teamPlan = false,
    this.featureBoard = false,
    this.editableOutcomes = false,
    this.profileAsksCompany = false,
  });

  /// When set, visits with a follow-up date are gathered on a screen with this
  /// title ("Follow-ups"), reachable from the drawer and the routes list.
  final String? followUpsLabel;

  /// Log each run's miles for expense reports, with the IRS rate applied.
  final bool mileageLog;

  /// Offer HubSpot and Salesforce import files next to the plain CSV (paid tier).
  final bool crmExport;

  /// Teams: a manager's activity view, a join code for reps, and teammates'
  /// recent outcomes on business sheets. Creating a team needs the Team plan.
  final bool teamPlan;

  /// A public feature-request board in the drawer (business users vote on the
  /// roadmap). Without it the drawer offers a plain "Send feedback" email.
  final bool featureBoard;

  /// Preferences link to edit outcomes and custom fields and export visits.
  final bool editableOutcomes;

  /// Profile asks for company and title (they head CSV exports).
  final bool profileAsksCompany;
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
    required this.onboarding,
    required this.emptyRoutesCopy,
    required this.visitVerb,
    required this.stopNoun,
    required this.spotlightTitle,
    required this.planLabel,
    required this.planMaxStops,
    required this.outcomeIcons,
    required this.winOutcomes,
    required this.winNoun,
    required this.routeNoun,
    required this.routesTitle,
    this.pro = const ProTier(),
    this.community = const Community(),
    this.tools = const BusinessTools(),
    this.placesQueryPreset,
    this.suggestionIcons = const {},
    this.summaryTotals = const [],
    this.saveVisitLabel = 'Save visit',
    this.startLabel,
    this.summaryCountField,
  });

  final AppMode id;
  final String label;
  final String tagline;
  final IconData icon;
  final String routeNamePrefix;
  final String searchHint;
  final List<String> searchSuggestions;
  final List<StopSourceId> stopSources;

  /// Appended to free-text searches when the query lacks it (no mode sets one today).
  final String? placesQueryPreset;
  final bool requiresTimeWindow;
  final OptimizerKind optimizer;
  final List<String> defaultOutcomes;
  final List<VisitFieldDefinition> defaultVisitFields;
  final List<String> defaultExportFields;
  final Map<String, String> exportHeaders;
  final List<OnboardingPage> onboarding;
  final String emptyRoutesCopy;
  final String visitVerb; // "Log Visit" / "Log Stop"
  final String stopNoun; // "stop" / "sale"

  /// Map deck header after the count, e.g. "10 sales worth the drive".
  final String spotlightTitle;

  /// One-tap planner button on the map deck, e.g. "Plan my day".
  final String planLabel;

  /// How many top-ranked stops the one-tap planner takes.
  final int planMaxStops;

  /// Icons for the runner's one-tap outcome tiles; custom outcomes fall back to a check.
  final Map<String, IconData> outcomeIcons;

  /// Outcomes the run recap counts as a win, e.g. "Bought".
  final List<String> winOutcomes;

  /// Singular noun for a win on the recap: "3 finds", "2 leads".
  final String winNoun;

  /// "route" / "run": the routes tab is its plural.
  final String routeNoun;

  /// Routes screen title, e.g. "Saved routes".
  final String routesTitle;

  /// What the paid tier costs and unlocks.
  final ProTier pro;

  /// Listings, live reports and hosting shared between users. Off by default.
  final Community community;

  /// Tools for people canvassing for work: follow-ups, mileage, teams, CRM files.
  final BusinessTools tools;

  String get routesTab => '${routeNoun[0].toUpperCase()}${routeNoun.substring(1)}s';

  IconData outcomeIcon(String outcome) => outcomeIcons[outcome] ?? Icons.check_circle_outline;
  /// Icons for the map's quick-start category cards.
  final Map<String, IconData> suggestionIcons;
  IconData suggestionIcon(String s) => suggestionIcons[s] ?? Icons.search;

  /// Custom-field keys summed on the Route Summary (e.g. "spent").
  final List<String> summaryTotals;
  /// The visit form's save button, e.g. "Save report".
  final String saveVisitLabel;

  /// Onboarding button when this build ships only this mode ("Show me sales near me").
  /// Null reads "Start with <label>".
  final String? startLabel;

  /// A one-per-line visit field whose lines the recap counts, e.g. items bought.
  final ({String key, String noun})? summaryCountField;

  bool get usesTimeWindows => optimizer != OptimizerKind.distance;
  bool get hasCommunity => community.enabled;
  bool hasSource(StopSourceId s) => stopSources.contains(s);
  List<VisitFieldDefinition> get enabledVisitFields => defaultVisitFields.where((f) => f.enabled).toList();
}
