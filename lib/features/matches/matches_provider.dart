import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/match_item.dart';
import '../auth/auth_provider.dart';
import 'matches_repository.dart';

/// Cantidad de novedades no vistas — alimenta el badge de "Busco" en la nav.
/// No es autoDispose: la nav lo observa durante toda la sesión. Se invalida
/// al marcar visto (al abrir Busco).
final unseenMatchesProvider = FutureProvider<int>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return 0;
  return ref.watch(matchesRepositoryProvider).unseenCount();
});

/// Novedades: listings de otros que matchean búsquedas activas propias y
/// aparecieron después de la última visita a Busco.
final newMatchesProvider =
    FutureProvider.autoDispose<List<MatchItem>>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return const [];
  final all = await ref.watch(matchesRepositoryProvider).fetchMatches();
  return all.where((m) => m.isNew).toList();
});
