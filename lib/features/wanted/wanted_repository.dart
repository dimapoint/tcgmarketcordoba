import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/api_urls.dart';
import '../../core/api/paginated.dart';
import '../../shared/models/wanted_order.dart';

abstract class WantedRepository {
  Future<List<WantedOrder>> fetchActive({String? query});
  Future<PaginatedList<WantedOrder>> fetchActivePage({String? query, String? cursor, int limit = 20});
  Future<WantedOrder> fetchById(String id);
}

class ApiWantedRepository implements WantedRepository {
  final ApiClient _api;
  ApiWantedRepository(this._api);

  @override
  Future<List<WantedOrder>> fetchActive({String? query}) async {
    final page = await fetchActivePage(query: query);
    return page.data;
  }

  @override
  Future<PaginatedList<WantedOrder>> fetchActivePage({String? query, String? cursor, int limit = 20}) async {
    final params = <String, String>{'limit': limit.toString()};
    if (query != null && query.isNotEmpty) params['query'] = query;
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;

    final data = await _api.get('/buy-orders', query: params);
    return PaginatedList.fromJson(
      data as Map<String, dynamic>,
      (j) => _fromJson(j),
    );
  }

  @override
  Future<WantedOrder> fetchById(String id) async {
    final data = await _api.get('/buy-orders/$id');
    return _fromJson(data as Map<String, dynamic>);
  }

  // El backend manda card_image_url relativa (/card-images/...): la sirve él
  // mismo como proxy del CDN de Riot, que no habilita CORS.
  WantedOrder _fromJson(Map<String, dynamic> json) {
    json['card_image_url'] =
        absoluteApiUrl(json['card_image_url'] as String?, _api.baseUrl);
    return WantedOrder.fromJson(json);
  }
}

final wantedRepositoryProvider = Provider<WantedRepository>(
  (ref) => ApiWantedRepository(ref.watch(apiClientProvider)),
);
