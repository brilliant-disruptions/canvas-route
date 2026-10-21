import 'json_utils.dart';

class Report {
  const Report({
    required this.id,
    required this.pinId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.visitId,
    this.productId,
    this.productText,
    this.productName,
    this.qty,
    this.priceCents,
    this.purchaseLimit,
    this.linePresent,
    this.crowdLevel,
    this.photoPath,
    this.trustAtFiling = 50,
  });

  final String id;
  final String pinId;
  final String userId;
  final String? visitId;
  final String status;
  final String? productId;
  final String? productText;
  final String? productName;
  final int? qty;
  final int? priceCents;
  final int? purchaseLimit;
  final bool? linePresent;
  final String? crowdLevel;
  final String? photoPath;
  final int trustAtFiling;
  final DateTime createdAt;

  String get productLabel => productName ?? productText ?? '';

  factory Report.fromRow(Map<String, dynamic> r) => Report(
        id: r['id'] as String,
        pinId: r['pin_id'] as String,
        userId: r['user_id'] as String,
        visitId: r['visit_id'] as String?,
        status: r['status'] as String,
        productId: r['product_id'] as String?,
        productText: r['product_text'] as String?,
        productName: (r['products'] as Map?)?['display_name'] as String? ?? r['product'] as String?,
        qty: r['qty'] as int?,
        priceCents: r['price_cents'] as int?,
        purchaseLimit: r['purchase_limit'] as int?,
        linePresent: r['line_present'] as bool?,
        crowdLevel: r['crowd_level'] as String?,
        photoPath: r['photo_path'] as String?,
        trustAtFiling: intOr(r['trust_at_filing'], 50),
        createdAt: dt(r['created_at']),
      );
}

class ReportDraft {
  ReportDraft({
    required this.pinId,
    required this.status,
    this.productId,
    this.productText,
    this.qty,
    this.priceCents,
    this.purchaseLimit,
    this.linePresent,
    this.crowdLevel,
    this.photoPath,
    this.visitId,
  });

  final String pinId;
  final String status;
  final String? productId;
  final String? productText;
  final int? qty;
  final int? priceCents;
  final int? purchaseLimit;
  final bool? linePresent;
  final String? crowdLevel;
  final String? photoPath;
  final String? visitId;

  Map<String, dynamic> toInsert(String userId) => {
        'pin_id': pinId,
        'user_id': userId,
        'visit_id': visitId,
        'status': status,
        'product_id': productId,
        'product_text': productText,
        'qty': qty,
        'price_cents': priceCents,
        'purchase_limit': purchaseLimit,
        'line_present': linePresent,
        'crowd_level': crowdLevel,
        'photo_path': photoPath,
      };
}
