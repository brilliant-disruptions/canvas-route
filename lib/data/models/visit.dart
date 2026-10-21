import 'json_utils.dart';

class Visit {
  const Visit({
    required this.id,
    required this.stopId,
    required this.routeId,
    required this.userId,
    required this.customFields,
    required this.createdAt,
    required this.updatedAt,
    this.outcome,
    this.contactName,
    this.phone,
    this.email,
    this.notes,
    this.followUpDate,
    this.photoPath,
  });

  final String id;
  final String stopId;
  final String routeId;
  final String userId;
  final String? outcome;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime? followUpDate;
  final String? photoPath;
  final Map<String, dynamic> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Reads a value by field key regardless of whether it is a column or custom.
  dynamic valueFor(String key) => switch (key) {
        'outcome' => outcome,
        'contactName' => contactName,
        'phone' => phone,
        'email' => email,
        'notes' => notes,
        'followUpDate' => followUpDate == null ? null : dateOnly(followUpDate!),
        'photo' => photoPath,
        _ => customFields[key],
      };

  factory Visit.fromRow(Map<String, dynamic> r) => Visit(
        id: r['id'] as String,
        stopId: r['stop_id'] as String,
        routeId: r['route_id'] as String,
        userId: r['user_id'] as String,
        outcome: r['outcome'] as String?,
        contactName: r['contact_name'] as String?,
        phone: r['phone'] as String?,
        email: r['email'] as String?,
        notes: r['notes'] as String?,
        followUpDate: r['follow_up_date'] == null ? null : DateTime.parse(r['follow_up_date'] as String),
        photoPath: r['photo_path'] as String?,
        customFields: mapOf(r['custom_fields']),
        createdAt: dt(r['created_at']),
        updatedAt: dt(r['updated_at']),
      );
}

/// Values collected by the Visit Logger before they are persisted.
class VisitDraft {
  VisitDraft({Map<String, dynamic>? values}) : values = values ?? {};

  final Map<String, dynamic> values;

  String? get outcome => values['outcome'] as String?;

  Map<String, dynamic> toInsert({
    required String stopId,
    required String routeId,
    required String userId,
    String? photoPath,
  }) {
    final custom = <String, dynamic>{};
    for (final e in values.entries) {
      if (!{'outcome', 'contactName', 'phone', 'email', 'notes', 'followUpDate', 'photo'}.contains(e.key)) {
        custom[e.key] = e.value;
      }
    }
    final fu = values['followUpDate'];
    return {
      'stop_id': stopId,
      'route_id': routeId,
      'user_id': userId,
      'outcome': values['outcome'],
      'contact_name': values['contactName'],
      'phone': values['phone'],
      'email': values['email'],
      'notes': values['notes'],
      'follow_up_date': fu is DateTime ? dateOnly(fu) : fu,
      'photo_path': photoPath ?? values['photo'],
      'custom_fields': custom,
    };
  }

  factory VisitDraft.fromVisit(Visit v) => VisitDraft(values: {
        'outcome': v.outcome,
        'contactName': v.contactName,
        'phone': v.phone,
        'email': v.email,
        'notes': v.notes,
        'followUpDate': v.followUpDate,
        'photo': v.photoPath,
        ...v.customFields,
      });
}
