import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';

abstract class PostWantedRepository {
  /// Crea la búsqueda y devuelve su id.
  Future<String> createWantedOrder({
    required String cardPrintingId,
    String? minCondition,
    required double maxPrice,
    required int quantity,
    String? description,
    String? cityId,
  });
}

class ApiPostWantedRepository implements PostWantedRepository {
  final ApiClient _api;
  ApiPostWantedRepository(this._api);

  @override
  Future<String> createWantedOrder({
    required String cardPrintingId,
    String? minCondition,
    required double maxPrice,
    required int quantity,
    String? description,
    String? cityId,
  }) async {
    final data = await _api.post('/buy-orders', auth: true, body: {
      'card_printing_id': cardPrintingId,
      'min_condition': ?minCondition,
      'max_price': maxPrice,
      'quantity': quantity,
      'description': ?description,
      'city_id': ?cityId,
    });
    return (data as Map<String, dynamic>)['id'] as String;
  }
}

final postWantedRepositoryProvider = Provider<PostWantedRepository>(
  (ref) => ApiPostWantedRepository(ref.watch(apiClientProvider)),
);
