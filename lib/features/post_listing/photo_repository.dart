import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';

abstract class PhotoRepository {
  Future<String> upload({
    required String listingId,
    required File file,
    required int order,
  });
}

class ApiPhotoRepository implements PhotoRepository {
  final ApiClient _api;
  ApiPhotoRepository(this._api);

  @override
  Future<String> upload({
    required String listingId,
    required File file,
    required int order,
  }) async {
    final data = await _api.uploadFile(
      '/listings/$listingId/photos',
      filePath: file.path,
      fields: {'display_order': '$order'},
    );
    return (data as Map<String, dynamic>)['url'] as String;
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => ApiPhotoRepository(ref.watch(apiClientProvider)),
);
