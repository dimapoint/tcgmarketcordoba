import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/api_urls.dart';
import '../../core/api/paginated.dart';
import '../../shared/models/listing.dart';

abstract class ListingRepository {
  Future<List<Listing>> fetchActive({String? query});
  Future<PaginatedList<Listing>> fetchActivePage({String? query, String? cursor, int limit = 20});
  Future<Listing> fetchById(String id);
}

class ApiListingRepository implements ListingRepository {
  final ApiClient _api;
  ApiListingRepository(this._api);

  @override
  Future<List<Listing>> fetchActive({String? query}) async {
    final page = await fetchActivePage(query: query);
    return page.data;
  }

  @override
  Future<PaginatedList<Listing>> fetchActivePage({String? query, String? cursor, int limit = 20}) async {
    final params = <String, String>{'limit': limit.toString()};
    if (query != null && query.isNotEmpty) params['query'] = query;
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;

    final data = await _api.get('/listings', query: params);
    return PaginatedList.fromJson(
      data as Map<String, dynamic>,
      (j) => _fromJson(j),
    );
  }

  @override
  Future<Listing> fetchById(String id) async {
    final data = await _api.get('/listings/$id');
    return _fromJson(data as Map<String, dynamic>);
  }

  // El backend manda card_image_url relativa (/card-images/...): la sirve él
  // mismo como proxy del CDN de Riot, que no habilita CORS.
  Listing _fromJson(Map<String, dynamic> json) {
    json['card_image_url'] =
        absoluteApiUrl(json['card_image_url'] as String?, _api.baseUrl);
    return Listing.fromJson(json);
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ApiListingRepository(ref.watch(apiClientProvider)),
);
