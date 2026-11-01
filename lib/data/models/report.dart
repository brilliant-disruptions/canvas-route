import 'json_utils.dart';

/// A community report on a listing ("still going", "packed up"). It's filed
/// against the listing's pin, so it carries the listing's location, never the
/// reporter's.
class Report {
  const Report({
    required this.id,
    required this.pinId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.visitId,
    this.photoPath,
    this.trustAtFiling = 50,
  });

  final String id;
  final String pinId;
  final String userId;
  final String? visitId;
  final String status;
  final String? photoPath;
  final int trustAtFiling;
  final DateTime createdAt;

  factory Report.fromRow(Map<String, dynamic> r) => Report(
        id: r['id'] as String,
        pinId: r['pin_id'] as String,
        userId: r['user_id'] as String,
        visitId: r['visit_id'] as String?,
        status: r['status'] as String,
        photoPath: r['photo_path'] as String?,
        trustAtFiling: intOr(r['trust_at_filing'], 50),
        createdAt: dt(r['created_at']),
      );
}

class ReportDraft {
  ReportDraft({required this.pinId, required this.status, this.photoPath, this.visitId});

  final String pinId;
  final String status;
  final String? photoPath;
  final String? visitId;

  Map<String, dynamic> toInsert(String userId) => {
        'pin_id': pinId,
        'user_id': userId,
        'visit_id': visitId,
        'status': status,
        'photo_path': photoPath,
      };
}
