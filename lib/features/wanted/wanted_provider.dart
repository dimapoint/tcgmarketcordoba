import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/wanted_order.dart';
import '../browse/listing_provider.dart';
import 'wanted_repository.dart';

/// Comparte el buscador de Explorar: el tablero "Se busca" filtra con la
/// misma query que la grilla de "En venta".
final wantedOrdersProvider = FutureProvider.autoDispose<List<WantedOrder>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(wantedRepositoryProvider).fetchActive(query: query);
});

final wantedDetailProvider =
    FutureProvider.autoDispose.family<WantedOrder, String>((ref, id) {
  return ref.watch(wantedRepositoryProvider).fetchById(id);
});
