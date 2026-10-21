import 'json_utils.dart';

const featureRequestCategories = ['map', 'routes', 'visit_logger', 'export', 'settings', 'general'];

const featureRequestStatuses = [
  'queued', 'discarded', 'merged', 'backlog', 'to_do', 'development', 'testing', 'future_release', 'done',
];

String statusLabel(String s) => switch (s) {
      'to_do' => 'To Do',
      'future_release' => 'Future Release',
      _ => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}',
    };

class FeatureRequest {
  const FeatureRequest({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.status,
    required this.upvoteCount,
    required this.orgCount,
    required this.createdAt,
    this.problem,
    this.workaround,
    this.vision,
    this.role,
    this.frequency,
    this.impact,
    this.summary,
    this.parentId,
    this.interviewOptIn = false,
    this.interviewEmail,
  });

  final String id;
  final String userId;
  final String title;
  final String category;
  final String? problem;
  final String? workaround;
  final String? vision;
  final String? role;
  final String? frequency;
  final String? impact;
  final bool interviewOptIn;
  final String? interviewEmail;
  final String status;
  final String? summary;
  final String? parentId;
  final int upvoteCount;
  final int orgCount;
  final DateTime createdAt;

  factory FeatureRequest.fromRow(Map<String, dynamic> r) => FeatureRequest(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        title: r['title'] as String,
        category: r['category'] as String,
        problem: r['problem'] as String?,
        workaround: r['workaround'] as String?,
        vision: r['vision'] as String?,
        role: r['role'] as String?,
        frequency: r['frequency'] as String?,
        impact: r['impact'] as String?,
        interviewOptIn: r['interview_opt_in'] as bool? ?? false,
        interviewEmail: r['interview_email'] as String?,
        status: r['status'] as String,
        summary: r['summary'] as String?,
        parentId: r['parent_id'] as String?,
        upvoteCount: intOr(r['upvote_count'], 0),
        orgCount: intOr(r['org_count'], 0),
        createdAt: dt(r['created_at']),
      );
}
