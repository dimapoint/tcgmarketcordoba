import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/models/wanted_order.dart';
import 'my_wanted_repository.dart';

final myWantedProvider =
    FutureProvider.autoDispose.family<List<WantedOrder>, String>((ref, status) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return [];
  return ref.watch(myWantedRepositoryProvider).fetchMine(
        buyerId: session.user.id,
        status: status,
      );
});

class MyWantedActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markFulfilled(String wantedOrderId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(myWantedRepositoryProvider).markFulfilled(wantedOrderId),
    );
    ref.invalidate(myWantedProvider);
  }

  Future<void> remove(String wantedOrderId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(myWantedRepositoryProvider).remove(wantedOrderId),
    );
    ref.invalidate(myWantedProvider);
  }
}

final myWantedActionsProvider =
    AsyncNotifierProvider<MyWantedActionsNotifier, void>(
  MyWantedActionsNotifier.new,
);
