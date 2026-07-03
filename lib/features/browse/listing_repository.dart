import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/listing.dart';

abstract class ListingRepository {
  Future<List<Listing>> fetchActive({String? query});
  Future<Listing> fetchById(String id);
}

class ApiListingRepository implements ListingRepository {
  final ApiClient _api;
  ApiListingRepository(this._api);

  @override
  Future<List<Listing>> fetchActive({String? query}) async {
    final data = await _api.get(
      '/listings',
      query: (query == null || query.isEmpty) ? null : {'query': query},
    );
    return (data as List)
        .map((j) => Listing.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Listing> fetchById(String id) async {
    final data = await _api.get('/listings/$id');
    return Listing.fromJson(data as Map<String, dynamic>);
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ApiListingRepository(ref.watch(apiClientProvider)),
);
