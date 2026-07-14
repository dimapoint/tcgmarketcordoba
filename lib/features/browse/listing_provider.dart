import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/paginated.dart';
import '../../shared/models/listing.dart';
import 'listing_repository.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Qué lado del mercado se muestra en Explorar: cartas en venta o búsquedas
/// (demanda) de otros compradores.
enum MarketSide { selling, wanted }

final marketSideProvider = StateProvider<MarketSide>((ref) => MarketSide.selling);

class ListingsNotifier extends AutoDisposeAsyncNotifier<PaginatedState<Listing>> {
  @override
  Future<PaginatedState<Listing>> build() async {
    final query = ref.watch(searchQueryProvider);
    final page = await ref.watch(listingRepositoryProvider).fetchActivePage(query: query);
    return PaginatedState(items: page.data, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final query = ref.read(searchQueryProvider);
      final page = await ref.read(listingRepositoryProvider).fetchActivePage(
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

final listingsProvider = AsyncNotifierProvider.autoDispose<ListingsNotifier, PaginatedState<Listing>>(
  ListingsNotifier.new,
);

final listingDetailProvider =
    FutureProvider.autoDispose.family<Listing, String>((ref, id) {
  return ref.watch(listingRepositoryProvider).fetchById(id);
});

final sellerContactsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, sellerId) async {
  final data =
      await ref.watch(apiClientProvider).get('/profiles/$sellerId/contacts');
  return (data as List).cast<Map<String, dynamic>>();
});
