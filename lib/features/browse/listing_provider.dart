import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/client.dart';
import '../../shared/models/listing.dart';
import 'listing_repository.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final listingsProvider = FutureProvider.autoDispose<List<Listing>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(listingRepositoryProvider).fetchActive(query: query);
});

final listingDetailProvider =
    FutureProvider.autoDispose.family<Listing, String>((ref, id) {
  return ref.watch(listingRepositoryProvider).fetchById(id);
});

final sellerContactsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, sellerId) async {
  final data = await supabase
      .from('contact_methods')
      .select('type, value')
      .eq('profile_id', sellerId);
  return (data as List).cast<Map<String, dynamic>>();
});
