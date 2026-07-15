import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/api_urls.dart';
import '../../shared/models/listing.dart';
import '../../shared/models/wanted_order.dart';
import 'admin_models.dart';

abstract class AdminRepository {
  Future<AdminStats> fetchStats();
  Future<List<Listing>> fetchListings({String status = '', String query = ''});
  Future<void> setListingStatus(String id, String status);
  Future<List<WantedOrder>> fetchBuyOrders(
      {String status = '', String query = ''});
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
  Future<List<Listing>> fetchListings(
      {String status = '', String query = ''}) async {
    final data = await _api.get('/admin/listings',
        auth: true, query: _filters(status, query));
    return (data as List)
        .map((j) => Listing.fromJson(_withAbsoluteImage(j)))
        .toList();
  }

  @override
  Future<void> setListingStatus(String id, String status) =>
      _api.patch('/admin/listings/$id', auth: true, body: {'status': status});

  @override
  Future<List<WantedOrder>> fetchBuyOrders(
      {String status = '', String query = ''}) async {
    final data = await _api.get('/admin/buy-orders',
        auth: true, query: _filters(status, query));
    return (data as List)
        .map((j) => WantedOrder.fromJson(_withAbsoluteImage(j)))
        .toList();
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

  Map<String, String>? _filters(String status, String query) {
    final params = {
      if (status.isNotEmpty) 'status': status,
      if (query.isNotEmpty) 'q': query,
    };
    return params.isEmpty ? null : params;
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
