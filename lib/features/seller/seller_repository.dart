import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
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
    return SellerPage.fromJson(data as Map<String, dynamic>);
  }
}

final sellerRepositoryProvider = Provider<SellerRepository>(
  (ref) => ApiSellerRepository(ref.watch(apiClientProvider)),
);
