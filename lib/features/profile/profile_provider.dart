import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/models/profile.dart';
import 'profile_repository.dart';

final profileProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(session.user.id);
});

// Lista de ciudades de referencia (endpoint público, cambia poco).
final citiesProvider = FutureProvider<List<City>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchCities();
});

final contactMethodsProvider =
    FutureProvider.autoDispose<List<ContactMethod>>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return [];
  return ref
      .watch(profileRepositoryProvider)
      .fetchContactMethods(session.user.id);
});

class ProfileActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateUsername(String username) async {
    final session = ref.read(authSessionProvider).value;
    if (session == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(
            session.user.id,
            username: username,
          ),
    );
    ref.invalidate(profileProvider);
  }

  Future<void> updateCity(String cityId) async {
    final session = ref.read(authSessionProvider).value;
    if (session == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(
            session.user.id,
            cityId: cityId,
          ),
    );
    ref.invalidate(profileProvider);
  }

  Future<void> upsertContact(String type, String value) async {
    final session = ref.read(authSessionProvider).value;
    if (session == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).upsertContactMethod(
            session.user.id,
            type,
            value,
          ),
    );
    ref.invalidate(contactMethodsProvider);
  }

  Future<void> deleteContact(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).deleteContactMethod(id),
    );
    ref.invalidate(contactMethodsProvider);
  }
}

final profileActionsProvider =
    AsyncNotifierProvider<ProfileActionsNotifier, void>(
  ProfileActionsNotifier.new,
);
