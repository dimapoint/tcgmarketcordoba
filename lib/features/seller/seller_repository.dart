import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/api_urls.dart';
import '../../shared/models/seller_page.dart';

abstract class SellerRepository {
  Future<SellerPage> fetch(String username);
}

class ApiSellerRepository implements SellerRepository {
  final ApiClient _api;
  ApiSellerRepository(this._api);

  @override
  Future<SellerPage> fetch(String username) async {
    final data = await _api.get('/sellers/$username');
    final json = data as Map<String, dynamic>;
    // card_image_url viene relativa (/card-images/...) en listings y busco.
    for (final key in ['listings', 'buy_orders']) {
      for (final item in json[key] as List<dynamic>? ?? []) {
        final j = item as Map<String, dynamic>;
        j['card_image_url'] =
            absoluteApiUrl(j['card_image_url'] as String?, _api.baseUrl);
      }
    }
    return SellerPage.fromJson(json);
  }
}

final sellerRepositoryProvider = Provider<SellerRepository>(
  (ref) => ApiSellerRepository(ref.watch(apiClientProvider)),
);
