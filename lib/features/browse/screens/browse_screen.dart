import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/max_width.dart';
import '../../../shared/widgets/scaffold_with_nav.dart';
import '../listing_provider.dart';
import '../widgets/listing_card.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(listingsProvider);
    final query = ref.watch(searchQueryProvider);
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
                  ],
                ),
              ),
              Expanded(
                child: listings.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (items) => items.isEmpty
                      ? (query.isEmpty
                          ? EmptyState(
                              icon: Icons.style_outlined,
                              message: 'Todavía no hay cartas publicadas',
                              actionLabel: 'Publicá la primera',
                              onAction: () => context.go('/post'),
                            )
                          // Nadie vende esa carta: el paso natural en un
                          // sitio nuevo es publicar la búsqueda, no vender.
                          : EmptyState(
                              icon: Icons.style_outlined,
                              message: 'No hay publicaciones de "$query"',
                              actionLabel: 'Publicar una búsqueda',
                              onAction: () => context.go(Uri(
                                path: '/wanted/new',
                                queryParameters: {'q': query},
                              ).toString()),
                              secondaryActionLabel: 'Vendela vos',
                              onSecondaryAction: () => context.go('/post'),
                            ))
                      : RefreshIndicator(
                          onRefresh: () async =>
                              ref.invalidate(listingsProvider),
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 230,
                              childAspectRatio: 0.62,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, i) =>
                                ListingCard(listing: items[i]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
