import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import '../../shared/models/listing.dart';

// Package-level so my_listings_repository.dart can import it
const listingSelect = '''
  id, seller_id, condition, price, description, status, created_at,
  card_printings (
    is_foil,
    cards ( name ),
    sets ( name )
  ),
  profiles (
    username,
    cities ( name )
  ),
  listing_photos ( storage_path, display_order )
''';

abstract class ListingRepository {
  Future<List<Listing>> fetchActive({String? query});
  Future<Listing> fetchById(String id);
}

class SupabaseListingRepository implements ListingRepository {
  final SupabaseClient _client;
  SupabaseListingRepository(this._client);

  @override
  Future<List<Listing>> fetchActive({String? query}) async {
    var filterReq = _client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active');

    if (query != null && query.isNotEmpty) {
      filterReq = filterReq.ilike(
        'card_printings.cards.name',
        '%$query%',
      );
    }

    final data = await filterReq.order('created_at', ascending: false);
    return (data as List)
        .map((j) => Listing.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Listing> fetchById(String id) async {
    final data = await _client
        .from('listings')
        .select(listingSelect)
        .eq('id', id)
        .single();
    return Listing.fromJson(data);
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => SupabaseListingRepository(supabase),
);
