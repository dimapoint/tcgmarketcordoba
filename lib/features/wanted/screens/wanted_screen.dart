import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/my_wanted/my_wanted_provider.dart';
import '../../../shared/models/wanted_order.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/max_width.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/scaffold_with_nav.dart';
import '../wanted_provider.dart';
import '../widgets/wanted_card.dart';

/// Ruta al wizard de publicar búsqueda, con la query prefillada si hay.
String _newWantedUri(String query) => Uri(
      path: '/wanted/new',
      queryParameters: query.isEmpty ? null : {'q': query},
    ).toString();

class WantedScreen extends ConsumerWidget {
  const WantedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Publicar búsqueda'),
          onPressed: () =>
              context.go(_newWantedUri(ref.read(wantedSearchQueryProvider))),
        ),
        body: SafeArea(
          child: CenteredMaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isWide)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Wordmark(),
                  ),
                const TabBar(
                  tabs: [Tab(text: 'Tablero'), Tab(text: 'Mis búsquedas')],
                ),
                const Expanded(
                  child: TabBarView(children: [
                    _BoardTab(),
                    _MyWantedTab(),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardTab extends ConsumerWidget {
  const _BoardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(wantedOrdersProvider);
    final query = ref.watch(wantedSearchQueryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchBar(
            hintText: 'Buscar carta...',
            onChanged: (v) =>
                ref.read(wantedSearchQueryProvider.notifier).state = v,
            leading: const Icon(Icons.search),
          ),
        ),
        Expanded(
          child: orders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => items.isEmpty
                ? (query.isEmpty
                    ? EmptyState(
                        icon: Icons.travel_explore_outlined,
                        message: 'Todavía nadie publicó qué está buscando',
                        actionLabel: 'Publicar una búsqueda',
                        onAction: () => context.go('/wanted/new'),
                      )
                    : EmptyState(
                        icon: Icons.travel_explore_outlined,
                        message: 'Nadie está buscando "$query" todavía',
                        actionLabel: 'Publicar búsqueda de "$query"',
                        onAction: () => context.go(_newWantedUri(query)),
                      ))
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(wantedOrdersProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => WantedCard(order: items[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _MyWantedTab extends ConsumerWidget {
  const _MyWantedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    if (session == null) {
      return EmptyState(
        icon: Icons.login,
        message: 'Iniciá sesión para ver tus búsquedas',
        actionLabel: 'Iniciar sesión',
        onAction: () => context.push('/sign-in'),
      );
    }

    final orders = ref.watch(myWantedProvider('active'));

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) => items.isEmpty
          ? EmptyState(
              icon: Icons.travel_explore_outlined,
              message: 'No tenés búsquedas activas',
              actionLabel: 'Publicar una búsqueda',
              onAction: () => context.go('/wanted/new'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _MyWantedTile(order: items[i]),
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
