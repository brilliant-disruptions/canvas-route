import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/feature_request.dart';
import 'auth_state.dart';
import 'providers.dart';

typedef BoardQuery = ({String sort, String? category});

final boardProvider = FutureProvider.family<List<FeatureRequest>, BoardQuery>(
  (ref, q) => ref.read(featureRequestRepoProvider).all(sort: q.sort, category: q.category),
);

final myRequestsProvider = FutureProvider<List<FeatureRequest>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  return ref.read(featureRequestRepoProvider).mine(uid);
});

final myUpvotesProvider = FutureProvider<Set<String>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return {};
  return ref.read(featureRequestRepoProvider).myUpvotes(uid);
});

final adminQueueProvider = FutureProvider<List<FeatureRequest>>((ref) => ref.read(featureRequestRepoProvider).adminQueue());
