import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';

abstract class AuthRepository {
  Future<void> signUp({required String email, required String password});
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
}

class ApiAuthRepository implements AuthRepository {
  final ApiClient _api;
  ApiAuthRepository(this._api);

  @override
  Future<void> signUp({required String email, required String password}) =>
      _api.signUp(email: email, password: password);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _api.signIn(email: email, password: password);

  @override
  Future<void> signOut() => _api.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
