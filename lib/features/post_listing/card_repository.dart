import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
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
    return (data as List)
        .map((j) => CardPrinting.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => ApiCardRepository(ref.watch(apiClientProvider)),
);
