import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/wanted_order.dart';
import 'wanted_repository.dart';

final wantedSearchQueryProvider = StateProvider<String>((ref) => '');

final wantedOrdersProvider = FutureProvider.autoDispose<List<WantedOrder>>((ref) {
  final query = ref.watch(wantedSearchQueryProvider);
  return ref.watch(wantedRepositoryProvider).fetchActive(query: query);
});

final wantedDetailProvider =
    FutureProvider.autoDispose.family<WantedOrder, String>((ref, id) {
  return ref.watch(wantedRepositoryProvider).fetchById(id);
});
