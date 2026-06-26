import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import '../../shared/models/card_printing.dart';

abstract class CardRepository {
  Future<List<CardPrinting>> search(String query);
}

class SupabaseCardRepository implements CardRepository {
  final SupabaseClient _client;
  SupabaseCardRepository(this._client);

  @override
  Future<List<CardPrinting>> search(String query) async {
    if (query.length < 2) return [];
    final data = await _client
        .from('card_printings')
        .select(
            'id, card_id, card_number, is_foil, image_url, cards(name), sets(name, code)')
        .ilike('cards.name', '%$query%')
        .limit(20);
    return (data as List)
        .map((j) => CardPrinting.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => SupabaseCardRepository(supabase),
);
