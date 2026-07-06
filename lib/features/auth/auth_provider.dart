import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/session.dart';
import 'auth_repository.dart';

final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  return ref.watch(apiClientProvider).onSessionChange;
});

class AuthActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password),
    );
  }

  Future<void> signInWithGoogle(String idToken) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(idToken),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}

final authActionsProvider =
    AsyncNotifierProvider<AuthActionsNotifier, void>(AuthActionsNotifier.new);
