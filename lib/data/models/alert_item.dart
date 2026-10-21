import 'json_utils.dart';

class AlertItem {
  const AlertItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.sentAt,
    this.pinId,
    this.reportId,
    this.openedAt,
  });

  final String id;
  final String kind;
  final String? pinId;
  final String? reportId;
  final String title;
  final String body;
  final DateTime sentAt;
  final DateTime? openedAt;

  factory AlertItem.fromRow(Map<String, dynamic> r) => AlertItem(
        id: r['id'] as String,
        kind: r['kind'] as String,
        pinId: r['pin_id'] as String?,
        reportId: r['report_id'] as String?,
        title: r['title'] as String,
        body: r['body'] as String,
        sentAt: dt(r['sent_at']),
        openedAt: dtOrNull(r['opened_at']),
      );
}
