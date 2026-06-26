import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import '../../features/browse/listing_repository.dart';
import '../../shared/models/listing.dart';

abstract class MyListingsRepository {
  Future<List<Listing>> fetchMine({required String sellerId, required String status});
  Future<void> markSold(String listingId);
  Future<void> remove(String listingId);
}

class SupabaseMyListingsRepository implements MyListingsRepository {
  final SupabaseClient _client;
  SupabaseMyListingsRepository(this._client);

  @override
  Future<List<Listing>> fetchMine({
    required String sellerId,
    required String status,
  }) async {
    final data = await _client
        .from('listings')
        .select(listingSelect)
        .eq('seller_id', sellerId)
        .eq('status', status)
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => Listing.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markSold(String listingId) async {
    await _client.from('listings').update({'status': 'sold'}).eq('id', listingId);
  }

  @override
  Future<void> remove(String listingId) async {
    await _client.from('listings').update({'status': 'removed'}).eq('id', listingId);
  }
}

final myListingsRepositoryProvider = Provider<MyListingsRepository>(
  (ref) => SupabaseMyListingsRepository(supabase),
);
