import 'app_mode.dart';
import 'json_utils.dart';

enum Plan { free, pro, team }

class Profile {
  const Profile({
    required this.id,
    required this.isAdmin,
    required this.plan,
    required this.activeMode,
    required this.trustScore,
    required this.alertRadiusMi,
    required this.autoShareReports,
    required this.hasOnboarded,
    this.handle,
    this.name,
    this.title,
    this.company,
    this.email,
    this.phone,
    this.officeAddress,
    this.officeLat,
    this.officeLng,
    this.profilePicPath,
    this.industry,
    this.teamSize,
    this.useCase,
    this.crm,
    this.acquisition,
    this.billingDate,
    this.homeLat,
    this.homeLng,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final String id;
  final String? handle;
  final String? name;
  final String? title;
  final String? company;
  final String? email;
  final String? phone;
  final String? officeAddress;
  final double? officeLat;
  final double? officeLng;
  final String? profilePicPath;
  final String? industry;
  final String? teamSize;
  final String? useCase;
  final String? crm;
  final String? acquisition;
  final bool isAdmin;
  final Plan plan;
  final DateTime? billingDate;
  final AppMode activeMode;
  final int trustScore;
  final double? homeLat;
  final double? homeLng;
  final int alertRadiusMi;
  final int? quietHoursStart;
  final int? quietHoursEnd;
  final bool autoShareReports;
  final bool hasOnboarded;

  bool get isPaying => plan != Plan.free;

  factory Profile.fromRow(Map<String, dynamic> r) => Profile(
        id: r['id'] as String,
        handle: r['handle'] as String?,
        name: r['name'] as String?,
        title: r['title'] as String?,
        company: r['company'] as String?,
        email: r['email'] as String?,
        phone: r['phone'] as String?,
        officeAddress: r['office_address'] as String?,
        officeLat: dblOrNull(r['office_lat']),
        officeLng: dblOrNull(r['office_lng']),
        profilePicPath: r['profile_pic_path'] as String?,
        industry: r['industry'] as String?,
        teamSize: r['team_size'] as String?,
        useCase: r['use_case'] as String?,
        crm: r['crm'] as String?,
        acquisition: r['acquisition'] as String?,
        isAdmin: r['is_admin'] as bool? ?? false,
        plan: Plan.values.firstWhere((p) => p.name == r['plan'], orElse: () => Plan.free),
        billingDate: r['billing_date'] == null ? null : DateTime.parse(r['billing_date'] as String),
        activeMode: AppMode.fromId(r['active_mode'] as String?),
        trustScore: intOr(r['trust_score'], 50),
        homeLat: dblOrNull(r['home_lat']),
        homeLng: dblOrNull(r['home_lng']),
        alertRadiusMi: intOr(r['alert_radius_mi'], 5),
        quietHoursStart: r['quiet_hours_start'] as int?,
        quietHoursEnd: r['quiet_hours_end'] as int?,
        autoShareReports: r['auto_share_reports'] as bool? ?? true,
        hasOnboarded: r['has_onboarded'] as bool? ?? false,
      );
}
