import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/matches/matches_provider.dart';
import '../../../features/matches/matches_repository.dart';
import '../../../features/my_wanted/my_wanted_provider.dart';
import '../../../shared/models/match_item.dart';
import '../../../shared/models/wanted_order.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/max_width.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/scaffold_with_nav.dart';

/// "Busco": pantalla 100% personal con las búsquedas propias del usuario y
/// sus matches. El tablero de demanda de otros compradores vive en Explorar
/// (toggle "En venta" / "Se busca"), no acá.
class WantedScreen extends ConsumerWidget {
  const WantedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint;

    return Scaffold(
      floatingActionButton: session == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Publicar búsqueda'),
              onPressed: () => context.go('/wanted/new'),
            ),
      body: SafeArea(
        child: CenteredMaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isWide)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Wordmark(),
                ),
              Expanded(
                child: session == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ScreenTitle('Tus búsquedas'),
                          Expanded(
                            child: EmptyState(
                              icon: Icons.login,
                              message: 'Iniciá sesión para ver tus búsquedas',
                              actionLabel: 'Iniciar sesión',
                              onAction: () => context.push('/sign-in'),
                            ),
                          ),
                        ],
                      )
                    : const _MyWantedList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título de sección con el padding de la pantalla (fuera del ListView).
class _ScreenTitle extends StatelessWidget {
  final String text;
  const _ScreenTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
      );
}

class _MyWantedList extends ConsumerWidget {
  const _MyWantedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Al llegar novedades se marcan vistas: el badge de la nav se apaga, pero
    // la sección queda visible durante esta visita (newMatchesProvider es
    // autoDispose y recién se refetchea al volver a entrar a la pantalla).
    ref.listen(newMatchesProvider, (_, next) {
      final matches = next.valueOrNull;
      if (matches == null || matches.isEmpty) return;
      () async {
        try {
          await ref.read(matchesRepositoryProvider).markSeen();
          ref.invalidate(unseenMatchesProvider);
        } catch (_) {
          // Sin red no se marca visto: el badge queda prendido y se
          // reintenta en la próxima visita.
        }
      }();
    });

    final orders = ref.watch(myWantedProvider('active'));
    final newMatches =
        ref.watch(newMatchesProvider).valueOrNull ?? const <MatchItem>[];

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty && newMatches.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ScreenTitle('Tus búsquedas'),
              Expanded(
                child: EmptyState(
                  icon: Icons.travel_explore_outlined,
                  message: 'No tenés búsquedas activas',
                  actionLabel: 'Publicar una búsqueda',
                  onAction: () => context.go('/wanted/new'),
                ),
              ),
            ],
          );
        }
        final titleStyle = Theme.of(context).textTheme.headlineSmall;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (newMatches.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Novedades', style: titleStyle),
              ),
              for (final m in newMatches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MatchTile(match: m),
                ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Tus búsquedas', style: titleStyle),
            ),
            for (final o in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MyWantedTile(order: o),
              ),
          ],
        );
      },
    );
  }
}

/// Un listing nuevo que matchea una búsqueda del usuario. Tap → detalle de la
/// publicación (/l/:id).
class _MatchTile extends StatelessWidget {
  final MatchItem match;
  const _MatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = match.cardImageThumb(120);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/l/${match.listingId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (thumb != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: thumb,
                    width: 40,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.isFoil ? '✦ ' : ''}${match.cardName}',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${match.setName} · ${match.sellerUsername}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ConditionBadge(condition: match.condition),
                        const SizedBox(width: 8),
                        PriceText(price: match.price, fontSize: 15),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Nuevo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyWantedTile extends ConsumerWidget {
  final WantedOrder order;
  const _MyWantedTile({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = order.cardImageThumb(120);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/b/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (thumb != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: thumb,
                    width: 40,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.isFoil ? '✦ ' : ''}${order.cardName}',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      order.setName,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (order.minCondition != null)
                          ConditionBadge(condition: order.minCondition!),
                        const SizedBox(width: 8),
                        PriceText(price: order.maxPrice, fontSize: 15),
                      ],
                    ),
                    if (order.matchingListingsCount > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${order.matchingListingsCount} '
                          '${order.matchingListingsCount == 1 ? "publicación matchea" : "publicaciones matchean"}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (action) => switch (action) {
                  'fulfilled' => ref
                      .read(myWantedActionsProvider.notifier)
                      .markFulfilled(order.id),
                  'remove' =>
                    ref.read(myWantedActionsProvider.notifier).remove(order.id),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'fulfilled', child: Text('Marcar como conseguida')),
                  PopupMenuItem(value: 'remove', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
