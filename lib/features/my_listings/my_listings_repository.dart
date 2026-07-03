import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/listing.dart';

abstract class MyListingsRepository {
  Future<List<Listing>> fetchMine(
      {required String sellerId, required String status});
  Future<void> markSold(String listingId);
  Future<void> remove(String listingId);
}

class ApiMyListingsRepository implements MyListingsRepository {
  final ApiClient _api;
  ApiMyListingsRepository(this._api);

  @override
  Future<List<Listing>> fetchMine(
      {required String sellerId, required String status}) async {
    // sellerId sale del JWT en el backend; el parámetro queda por compatibilidad
    final data =
        await _api.get('/me/listings', query: {'status': status}, auth: true);
    return (data as List)
        .map((j) => Listing.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markSold(String listingId) =>
      _api.patch('/listings/$listingId', body: {'status': 'sold'}, auth: true);

  @override
  Future<void> remove(String listingId) => _api
      .patch('/listings/$listingId', body: {'status': 'removed'}, auth: true);
}

final myListingsRepositoryProvider = Provider<MyListingsRepository>(
  (ref) => ApiMyListingsRepository(ref.watch(apiClientProvider)),
);
