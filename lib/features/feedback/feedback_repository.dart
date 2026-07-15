import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';

abstract class FeedbackRepository {
  Future<void> submit({required String category, required String message});
}

class ApiFeedbackRepository implements FeedbackRepository {
  final ApiClient _api;
  ApiFeedbackRepository(this._api);

  @override
  Future<void> submit({required String category, required String message}) =>
      _api.post('/feedback', auth: true, body: {
        'category': category,
        'message': message,
      });
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => ApiFeedbackRepository(ref.watch(apiClientProvider)),
);
