import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/paginated.dart';
import '../../shared/models/wanted_order.dart';
import '../browse/listing_provider.dart';
import 'wanted_repository.dart';

/// Comparte el buscador de Explorar: el tablero "Se busca" filtra con la
/// misma query que la grilla de "En venta".
class WantedOrdersNotifier extends AsyncNotifier<PaginatedState<WantedOrder>> {
  @override
  Future<PaginatedState<WantedOrder>> build() async {
    final query = ref.watch(searchQueryProvider);
    final page = await ref.watch(wantedRepositoryProvider).fetchActivePage(query: query);
    return PaginatedState(items: page.data, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final query = ref.read(searchQueryProvider);
      final page = await ref.read(wantedRepositoryProvider).fetchActivePage(
        query: query,
        cursor: current.nextCursor,
      );
      state = AsyncData(PaginatedState(
        items: [...current.items, ...page.data],
        nextCursor: page.nextCursor,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final wantedOrdersProvider = AsyncNotifierProvider.autoDispose<WantedOrdersNotifier, PaginatedState<WantedOrder>>(
  WantedOrdersNotifier.new,
);

final wantedDetailProvider =
    FutureProvider.autoDispose.family<WantedOrder, String>((ref, id) {
  return ref.watch(wantedRepositoryProvider).fetchById(id);
});
