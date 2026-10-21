import 'app_mode.dart';
import 'json_utils.dart';
import 'stop.dart';

enum RouteStatus {
  notStarted('not_started'),
  inProgress('in_progress'),
  complete('complete'),
  updated('updated');

  const RouteStatus(this.id);
  final String id;
  static RouteStatus fromId(String? id) =>
      RouteStatus.values.firstWhere((s) => s.id == id, orElse: () => RouteStatus.notStarted);
}

class RouteModel {
  const RouteModel({
    required this.id,
    required this.userId,
    required this.mode,
    required this.name,
    required this.stops,
    required this.isOptimized,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastRunAt,
    this.forkedFrom,
  });

  final String id;
  final String userId;
  final AppMode mode;
  final String name;
  final List<Stop> stops;
  final bool isOptimized;
  final RouteStatus status;
  final DateTime? lastRunAt;
  final String? forkedFrom;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get stopCount => stops.length;
  int get visitedCount => stops.where((s) => s.visited).length;
  bool get allVisited => stops.isNotEmpty && visitedCount == stops.length;

  RouteModel copyWith({
    String? name,
    List<Stop>? stops,
    bool? isOptimized,
    RouteStatus? status,
    DateTime? lastRunAt,
  }) =>
      RouteModel(
        id: id,
        userId: userId,
        mode: mode,
        name: name ?? this.name,
        stops: stops ?? this.stops,
        isOptimized: isOptimized ?? this.isOptimized,
        status: status ?? this.status,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        forkedFrom: forkedFrom,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory RouteModel.fromRow(Map<String, dynamic> r, List<Stop> stops) => RouteModel(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        mode: AppMode.fromId(r['mode'] as String?),
        name: r['name'] as String,
        stops: stops,
        isOptimized: r['is_optimized'] as bool? ?? false,
        status: RouteStatus.fromId(r['status'] as String?),
        lastRunAt: dtOrNull(r['last_run_at']),
        forkedFrom: r['forked_from'] as String?,
        createdAt: dt(r['created_at']),
        updatedAt: dt(r['updated_at']),
      );
}
