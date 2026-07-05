import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/wanted_order.dart';

abstract class WantedRepository {
  Future<List<WantedOrder>> fetchActive({String? query});
  Future<WantedOrder> fetchById(String id);
}

class ApiWantedRepository implements WantedRepository {
  final ApiClient _api;
  ApiWantedRepository(this._api);

  @override
  Future<List<WantedOrder>> fetchActive({String? query}) async {
    final data = await _api.get(
      '/buy-orders',
      query: (query == null || query.isEmpty) ? null : {'query': query},
    );
    return (data as List)
        .map((j) => WantedOrder.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WantedOrder> fetchById(String id) async {
    final data = await _api.get('/buy-orders/$id');
    return WantedOrder.fromJson(data as Map<String, dynamic>);
  }
}

final wantedRepositoryProvider = Provider<WantedRepository>(
  (ref) => ApiWantedRepository(ref.watch(apiClientProvider)),
);
