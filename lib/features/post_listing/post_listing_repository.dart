import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';

abstract class PostListingRepository {
  /// Crea la publicación y devuelve su id.
  Future<String> createListing({
    required String cardPrintingId,
    required String condition,
    required double price,
    String? description,
    String? cityId,
  });
}

class ApiPostListingRepository implements PostListingRepository {
  final ApiClient _api;
  ApiPostListingRepository(this._api);

  @override
  Future<String> createListing({
    required String cardPrintingId,
    required String condition,
    required double price,
    String? description,
    String? cityId,
  }) async {
    final data = await _api.post('/listings', auth: true, body: {
      'card_printing_id': cardPrintingId,
      'condition': condition,
      'price': price,
      'description': ?description,
      'city_id': ?cityId,
    });
    return (data as Map<String, dynamic>)['id'] as String;
  }
}

final postListingRepositoryProvider = Provider<PostListingRepository>(
  (ref) => ApiPostListingRepository(ref.watch(apiClientProvider)),
);
