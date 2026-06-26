import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';

abstract class PhotoRepository {
  Future<String> upload({
    required String listingId,
    required File file,
    required int order,
  });
}

class SupabasePhotoRepository implements PhotoRepository {
  final SupabaseClient _client;
  SupabasePhotoRepository(this._client);

  @override
  Future<String> upload({
    required String listingId,
    required File file,
    required int order,
  }) async {
    final ext = file.path.split('.').last;
    final path = 'listings/$listingId/$order.$ext';
    await _client.storage.from('listing-photos').upload(path, file);
    return _client.storage.from('listing-photos').getPublicUrl(path);
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => SupabasePhotoRepository(supabase),
);
