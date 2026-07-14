import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/max_width.dart';
import '../../../shared/widgets/scaffold_with_nav.dart';
import '../../wanted/wanted_provider.dart';
import '../../wanted/widgets/wanted_card.dart';
import '../listing_provider.dart';
import '../widgets/listing_card.dart';

/// Ruta al wizard de publicar búsqueda, con la query prefillada si hay.
String _newWantedUri(String query) => Uri(
      path: '/wanted/new',
      queryParameters: query.isEmpty ? null : {'q': query},
    ).toString();

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final side = ref.watch(marketSideProvider);
    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint;

    return Scaffold(
      body: SafeArea(
        child: CenteredMaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, isWide ? 24 : 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isWide) ...[
                      const Wordmark(),
                      const SizedBox(height: 12),
                    ],
                    SearchBar(
                      hintText: 'Buscar carta...',
                      onChanged: (v) =>
                          ref.read(searchQueryProvider.notifier).state = v,
                      leading: const Icon(Icons.search),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<MarketSide>(
                      segments: const [
                        ButtonSegment(
                          value: MarketSide.selling,
                          label: Text('En venta'),
                          icon: Icon(Icons.style_outlined),
                        ),
                        ButtonSegment(
                          value: MarketSide.wanted,
                          label: Text('Se busca'),
                          icon: Icon(Icons.travel_explore_outlined),
                        ),
                      ],
                      selected: {side},
                      onSelectionChanged: (s) =>
                          ref.read(marketSideProvider.notifier).state =
                              s.first,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: side == MarketSide.selling
                    ? _SellingGrid(query: query)
                    : const _WantedBoard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellingGrid extends ConsumerWidget {
  final String query;
  const _SellingGrid({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(listingsProvider);

    return listings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (state) {
        final items = state.items;
        return items.isEmpty
            ? (query.isEmpty
                ? EmptyState(
                    icon: Icons.style_outlined,
                    message: 'Todavía no hay cartas publicadas',
                    actionLabel: 'Publicá la primera',
                    onAction: () => context.go('/post'),
                  )
                : EmptyState(
                    icon: Icons.style_outlined,
                    message: 'No hay publicaciones de "$query"',
                    actionLabel: 'Publicar una búsqueda',
                    onAction: () => context.go(_newWantedUri(query)),
                    secondaryActionLabel: 'Vendela vos',
                    onSecondaryAction: () => context.go('/post'),
                  ))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(listingsProvider),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 230,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == items.length) {
                      Future.microtask(() => ref.read(listingsProvider.notifier).loadMore());
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListingCard(listing: items[i]);
                  },
                ),
              );
      },
    );
  }
}

/// Tablero de demanda: búsquedas de otros compradores. Vive acá porque su
/// audiencia natural es el vendedor mirando el mercado, no el comprador en
/// "Busco" (esa pantalla es 100% personal).
class _WantedBoard extends ConsumerWidget {
  const _WantedBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(wantedOrdersProvider);
    final query = ref.watch(searchQueryProvider);

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (state) {
        final items = state.items;
        return items.isEmpty
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
                  itemCount: items.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i == items.length) {
                      Future.microtask(() => ref.read(wantedOrdersProvider.notifier).loadMore());
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return WantedCard(order: items[i]);
                  },
                ),
              );
      },
    );
  }
}
