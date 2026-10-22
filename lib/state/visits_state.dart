import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_mode.dart';
import '../data/models/report.dart';
import '../data/models/route_model.dart';
import '../data/models/stop.dart';
import '../data/models/visit.dart';
import '../data/services/storage_service.dart';
import 'auth_state.dart';
import 'profile_state.dart';
import 'providers.dart';
import 'routes_state.dart';

final visitsForRouteProvider = FutureProvider.family<List<Visit>, String>((ref, routeId) async {
  return ref.read(visitRepoProvider).forRoute(routeId);
});

final allVisitsProvider = FutureProvider<List<Visit>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  return ref.read(visitRepoProvider).forUser(uid);
});

/// Saves a visit, marks the stop visited, and (when the mode's community layer
/// is on and the user opted in) auto-files a report against the stop's pin.
class VisitLogger {
  VisitLogger(this.ref);
  final Ref ref;

  Future<({Visit visit, bool shared})> log({
    required RouteModel route,
    required Stop stop,
    required VisitDraft draft,
    XFile? photo,
  }) async {
    final uid = ref.read(currentUserIdProvider)!;
    String? photoPath;
    if (photo != null) {
      photoPath = await ref.read(storageServiceProvider).upload(StorageService.visitPhotos, photo);
    }
    final visit = await ref.read(visitRepoProvider).upsert(
          draft.toInsert(stopId: stop.id, routeId: route.id, userId: uid, photoPath: photoPath),
        );
    await ref.read(routesProvider.notifier).markVisited(route.id, stop.id);
    ref.invalidate(visitsForRouteProvider(route.id));

    final shared = await _autoFileReport(route, stop, visit);
    return (visit: visit, shared: shared);
  }

  Future<bool> _autoFileReport(RouteModel route, Stop stop, Visit visit) async {
    final pack = ref.read(modePackProvider);
    final profile = ref.read(profileProvider).value;
    if (!pack.communityReports || profile == null || !profile.autoShareReports) return false;
    if (ref.read(isAnonymousProvider)) return false;
    final status = pack.outcomeToReportStatus[visit.outcome];
    if (status == null) return false;

    var pinId = stop.pinId;
    if (pinId == null && route.mode == AppMode.cardDrops && stop.placeId != null) {
      final pin = await ref.read(pinRepoProvider).ensureStorePin(stop.toBusiness());
      pinId = pin.id;
    }
    if (pinId == null) return false;

    final cf = visit.customFields;
    final products = (cf['products'] as List?)?.cast<Map>() ?? const [];
    final first = products.isEmpty ? null : products.first;
    try {
      await ref.read(reportRepoProvider).create(
            ReportDraft(
              pinId: pinId,
              status: status,
              visitId: visit.id,
              productId: first?['id'] as String?,
              productText: first?['name'] as String?,
              qty: _int(cf['qty']),
              priceCents: cf['price'] == null ? null : ((cf['price'] as num) * 100).round(),
              purchaseLimit: _int(cf['purchaseLimit']),
              linePresent: cf['linePresent'] as bool?,
              photoPath: visit.photoPath,
            ),
            ref.read(currentUserIdProvider)!,
          );
      return true;
    } catch (_) {
      return false; // Rate limit or trust gate; the visit itself is saved.
    }
  }

  int? _int(dynamic v) => v == null ? null : (v as num).toInt();
}

final visitLoggerProvider = Provider((ref) => VisitLogger(ref));
