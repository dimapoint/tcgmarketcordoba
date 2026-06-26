import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/models/listing.dart';
import 'my_listings_repository.dart';

final myListingsProvider =
    FutureProvider.autoDispose.family<List<Listing>, String>((ref, status) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return [];
  return ref.watch(myListingsRepositoryProvider).fetchMine(
        sellerId: session.user.id,
        status: status,
      );
});

class MyListingsActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markSold(String listingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(myListingsRepositoryProvider).markSold(listingId),
    );
    ref.invalidate(myListingsProvider);
  }

  Future<void> remove(String listingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(myListingsRepositoryProvider).remove(listingId),
    );
    ref.invalidate(myListingsProvider);
  }
}

final myListingsActionsProvider =
    AsyncNotifierProvider<MyListingsActionsNotifier, void>(
  MyListingsActionsNotifier.new,
);
