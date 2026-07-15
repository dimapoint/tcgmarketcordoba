import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/paginated.dart';
import '../../shared/models/listing.dart';
import '../../shared/models/wanted_order.dart';
import '../../shared/state/value_state.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

typedef AdminFilter = ({String status, String query});

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ref.watch(adminRepositoryProvider).fetchStats(),
);

final adminListingsFilterProvider =
    valueStateProvider<AdminFilter>((status: '', query: ''));

class AdminListingsNotifier extends AsyncNotifier<PaginatedState<Listing>> {
  @override
  Future<PaginatedState<Listing>> build() async {
    final f = ref.watch(adminListingsFilterProvider);
    final page = await ref
        .watch(adminRepositoryProvider)
        .fetchListingsPage(status: f.status, query: f.query);
    return PaginatedState(items: page.data, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final f = ref.read(adminListingsFilterProvider);
      final page = await ref.read(adminRepositoryProvider).fetchListingsPage(
          status: f.status, query: f.query, cursor: current.nextCursor);
      state = AsyncData(PaginatedState(
        items: [...current.items, ...page.data],
        nextCursor: page.nextCursor,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final adminListingsProvider = AsyncNotifierProvider.autoDispose<
    AdminListingsNotifier, PaginatedState<Listing>>(AdminListingsNotifier.new);

final adminBuyOrdersFilterProvider =
    valueStateProvider<AdminFilter>((status: '', query: ''));

class AdminBuyOrdersNotifier
    extends AsyncNotifier<PaginatedState<WantedOrder>> {
  @override
  Future<PaginatedState<WantedOrder>> build() async {
    final f = ref.watch(adminBuyOrdersFilterProvider);
    final page = await ref
        .watch(adminRepositoryProvider)
        .fetchBuyOrdersPage(status: f.status, query: f.query);
    return PaginatedState(items: page.data, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final f = ref.read(adminBuyOrdersFilterProvider);
      final page = await ref.read(adminRepositoryProvider).fetchBuyOrdersPage(
          status: f.status, query: f.query, cursor: current.nextCursor);
      state = AsyncData(PaginatedState(
        items: [...current.items, ...page.data],
        nextCursor: page.nextCursor,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final adminBuyOrdersProvider = AsyncNotifierProvider.autoDispose<
    AdminBuyOrdersNotifier,
    PaginatedState<WantedOrder>>(AdminBuyOrdersNotifier.new);

final adminFeedbackProvider =
    FutureProvider.autoDispose<List<FeedbackItem>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchFeedback(),
);

/// Estado del sync de cartas; mientras corre se re-consulta solo cada 3s
/// (el polling además mantiene viva la máquina de Fly durante la corrida).
final syncStatusProvider = FutureProvider.autoDispose<SyncStatus>((ref) async {
  final status = await ref.watch(adminRepositoryProvider).fetchSyncStatus();
  if (status.isRunning) {
    final timer = Timer(const Duration(seconds: 3), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return status;
});

class AdminActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setListingStatus(String id, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminRepositoryProvider).setListingStatus(id, status),
    );
    ref.invalidate(adminListingsProvider);
    ref.invalidate(adminStatsProvider);
  }

  Future<void> setBuyOrderStatus(String id, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminRepositoryProvider).setBuyOrderStatus(id, status),
    );
    ref.invalidate(adminBuyOrdersProvider);
    ref.invalidate(adminStatsProvider);
  }

  Future<void> startSync() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminRepositoryProvider).startSync(),
    );
    ref.invalidate(syncStatusProvider);
  }
}

final adminActionsProvider = AsyncNotifierProvider<AdminActionsNotifier, void>(
  AdminActionsNotifier.new,
);
