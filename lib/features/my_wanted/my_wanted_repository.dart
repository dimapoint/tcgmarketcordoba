import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/wanted_order.dart';

abstract class MyWantedRepository {
  Future<List<WantedOrder>> fetchMine(
      {required String buyerId, required String status});
  Future<void> markFulfilled(String wantedOrderId);
  Future<void> remove(String wantedOrderId);
}

class ApiMyWantedRepository implements MyWantedRepository {
  final ApiClient _api;
  ApiMyWantedRepository(this._api);

  @override
  Future<List<WantedOrder>> fetchMine(
      {required String buyerId, required String status}) async {
    // buyerId sale del JWT en el backend; el parámetro queda por compatibilidad
    final data = await _api
        .get('/me/buy-orders', query: {'status': status}, auth: true);
    return (data as List)
        .map((j) => WantedOrder.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markFulfilled(String wantedOrderId) => _api.patch(
      '/buy-orders/$wantedOrderId',
      body: {'status': 'fulfilled'},
      auth: true);

  @override
  Future<void> remove(String wantedOrderId) => _api.patch(
      '/buy-orders/$wantedOrderId',
      body: {'status': 'removed'},
      auth: true);
}

final myWantedRepositoryProvider = Provider<MyWantedRepository>(
  (ref) => ApiMyWantedRepository(ref.watch(apiClientProvider)),
);
