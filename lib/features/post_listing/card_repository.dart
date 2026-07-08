import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/api_urls.dart';
import '../../shared/models/card_printing.dart';

abstract class CardRepository {
  Future<List<CardPrinting>> search(String query);
}

class ApiCardRepository implements CardRepository {
  final ApiClient _api;
  ApiCardRepository(this._api);

  @override
  Future<List<CardPrinting>> search(String query) async {
    if (query.length < 2) return [];
    final data = await _api.get('/cards/search', query: {'q': query});
    return (data as List).map((j) {
      final json = j as Map<String, dynamic>;
      // El backend manda image_url relativa (/card-images/...): la sirve él
      // mismo como proxy del CDN de Riot, que no habilita CORS.
      json['image_url'] =
          absoluteApiUrl(json['image_url'] as String?, _api.baseUrl);
      return CardPrinting.fromJson(json);
    }).toList();
  }
}

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => ApiCardRepository(ref.watch(apiClientProvider)),
);
