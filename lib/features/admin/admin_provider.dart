import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/listing.dart';
import '../../shared/models/wanted_order.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

typedef AdminFilter = ({String status, String query});

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ref.watch(adminRepositoryProvider).fetchStats(),
);

final adminListingsFilterProvider =
    StateProvider<AdminFilter>((ref) => (status: '', query: ''));

final adminListingsProvider =
    FutureProvider.autoDispose<List<Listing>>((ref) {
  final f = ref.watch(adminListingsFilterProvider);
  return ref
      .watch(adminRepositoryProvider)
      .fetchListings(status: f.status, query: f.query);
});

final adminBuyOrdersFilterProvider =
    StateProvider<AdminFilter>((ref) => (status: '', query: ''));

final adminBuyOrdersProvider =
    FutureProvider.autoDispose<List<WantedOrder>>((ref) {
  final f = ref.watch(adminBuyOrdersFilterProvider);
  return ref
      .watch(adminRepositoryProvider)
      .fetchBuyOrders(status: f.status, query: f.query);
});

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
