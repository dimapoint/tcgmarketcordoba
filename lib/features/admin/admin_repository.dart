import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/api_urls.dart';
import '../../core/api/paginated.dart';
import '../../shared/models/listing.dart';
import '../../shared/models/wanted_order.dart';
import 'admin_models.dart';

abstract class AdminRepository {
  Future<AdminStats> fetchStats();
  Future<PaginatedList<Listing>> fetchListingsPage(
      {String status = '', String query = '', String? cursor, int limit = 20});
  Future<void> setListingStatus(String id, String status);
  Future<PaginatedList<WantedOrder>> fetchBuyOrdersPage(
      {String status = '', String query = '', String? cursor, int limit = 20});
  Future<void> setBuyOrderStatus(String id, String status);
  Future<void> startSync();
  Future<SyncStatus> fetchSyncStatus();
  Future<List<FeedbackItem>> fetchFeedback();
}

class ApiAdminRepository implements AdminRepository {
  final ApiClient _api;
  ApiAdminRepository(this._api);

  @override
  Future<AdminStats> fetchStats() async {
    final data = await _api.get('/admin/stats', auth: true);
    return AdminStats.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<PaginatedList<Listing>> fetchListingsPage(
      {String status = '',
      String query = '',
      String? cursor,
      int limit = 20}) async {
    final data = await _api.get('/admin/listings',
        auth: true, query: _pageParams(status, query, cursor, limit));
    return PaginatedList.fromJson(
      data as Map<String, dynamic>,
      (j) => Listing.fromJson(_withAbsoluteImage(j)),
    );
  }

  @override
  Future<void> setListingStatus(String id, String status) =>
      _api.patch('/admin/listings/$id', auth: true, body: {'status': status});

  @override
  Future<PaginatedList<WantedOrder>> fetchBuyOrdersPage(
      {String status = '',
      String query = '',
      String? cursor,
      int limit = 20}) async {
    final data = await _api.get('/admin/buy-orders',
        auth: true, query: _pageParams(status, query, cursor, limit));
    return PaginatedList.fromJson(
      data as Map<String, dynamic>,
      (j) => WantedOrder.fromJson(_withAbsoluteImage(j)),
    );
  }

  @override
  Future<void> setBuyOrderStatus(String id, String status) =>
      _api.patch('/admin/buy-orders/$id', auth: true, body: {'status': status});

  @override
  Future<void> startSync() => _api.post('/admin/sync-cards', auth: true);

  @override
  Future<SyncStatus> fetchSyncStatus() async {
    final data = await _api.get('/admin/sync-cards', auth: true);
    return SyncStatus.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<FeedbackItem>> fetchFeedback() async {
    final data = await _api.get('/admin/feedback', auth: true);
    return (data as List)
        .map((j) => FeedbackItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Map<String, String> _pageParams(
      String status, String query, String? cursor, int limit) {
    return {
      if (status.isNotEmpty) 'status': status,
      if (query.isNotEmpty) 'q': query,
      'limit': limit.toString(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
  }

  // El backend manda card_image_url relativa (/card-images/...): la sirve él
  // mismo como proxy del CDN de Riot, que no habilita CORS.
  Map<String, dynamic> _withAbsoluteImage(dynamic json) {
    final map = json as Map<String, dynamic>;
    map['card_image_url'] =
        absoluteApiUrl(map['card_image_url'] as String?, _api.baseUrl);
    return map;
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => ApiAdminRepository(ref.watch(apiClientProvider)),
);
