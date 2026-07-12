import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/api_urls.dart';
import '../../shared/models/match_item.dart';

abstract class MatchesRepository {
  Future<List<MatchItem>> fetchMatches();
  Future<int> unseenCount();
  Future<void> markSeen();
}

class ApiMatchesRepository implements MatchesRepository {
  final ApiClient _api;
  ApiMatchesRepository(this._api);

  @override
  Future<List<MatchItem>> fetchMatches() async {
    final data = await _api.get('/me/matches', auth: true);
    return (data as List).map((j) {
      final json = j as Map<String, dynamic>;
      json['card_image_url'] =
          absoluteApiUrl(json['card_image_url'] as String?, _api.baseUrl);
      return MatchItem.fromJson(json);
    }).toList();
  }

  @override
  Future<int> unseenCount() async {
    final data = await _api.get('/me/matches/count', auth: true);
    return (data as Map<String, dynamic>)['count'] as int;
  }

  @override
  Future<void> markSeen() => _api.post('/me/matches/seen', auth: true);
}

final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => ApiMatchesRepository(ref.watch(apiClientProvider)),
);
