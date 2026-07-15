import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/profile/profile_provider.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/share/share.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/price_text.dart';
import '../my_listings_provider.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mis publicaciones',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          tooltip: 'Compartir mi carpeta',
                          onPressed: () async {
                            final profile =
                                await ref.read(profileProvider.future);
                            final username = profile?.username;
                            if (username == null ||
                                username.isEmpty ||
                                !context.mounted) {
                              return;
                            }
                            final url = '${currentOrigin()}/u/$username';
                            await shareWithFallback(
                              context,
                              text: binderShareText(url),
                              url: url,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const TabBar(
                    tabs: [Tab(text: 'Activas'), Tab(text: 'Vendidas')],
                  ),
                  const Expanded(
                    child: TabBarView(children: [
                      _ListingsList(status: 'active'),
                      _ListingsList(status: 'sold'),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListingsList extends ConsumerWidget {
  final String status;
  const _ListingsList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider(status));

    return listings.when(
      loading: () => const WantedListSkeleton(),
      error: (e, _) =>
          ErrorState(onRetry: () => ref.invalidate(myListingsProvider(status))),
      data: (items) => items.isEmpty
          ? (status == 'active'
              ? EmptyState(
                  icon: Icons.storefront_outlined,
                  message: 'No tenés publicaciones activas',
                  actionLabel: 'Publicar una carta',
                  onAction: () => context.go('/post'),
                )
              : const EmptyState(
                  icon: Icons.sell_outlined,
                  message: 'Todavía no vendiste ninguna carta',
                ))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(myListingsProvider(status)),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ListingTile(listing: items[i]),
              ),
            ),
    );
  }
}

class _ListingTile extends ConsumerWidget {
  final Listing listing;
  const _ListingTile({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final firstPhoto = listing.photos.isNotEmpty ? listing.photos.first : null;
    final thumb = firstPhoto?.url ?? listing.cardImageThumb(120);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/l/${listing.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: thumb != null
                      ? ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.contain,
                            fadeInDuration: const Duration(milliseconds: 250),
                            placeholder: (_, _) => const Skeleton(
                                borderRadius: BorderRadius.zero),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(Icons.style_outlined,
                                  size: 22, color: scheme.outline),
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.style_outlined,
                              size: 22, color: scheme.outline),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${listing.isFoil ? '✦ ' : ''}${listing.cardName}',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      listing.setName,
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
                        ConditionBadge(condition: listing.condition),
                        const SizedBox(width: 8),
                        PriceText(price: listing.price, fontSize: 15),
                      ],
                    ),
                  ],
                ),
              ),
              if (listing.status == 'active')
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    switch (action) {
                      case 'sold':
                        await ref
                            .read(myListingsActionsProvider.notifier)
                            .markSold(listing.id);
                        if (context.mounted) {
                          showAppSnackBar(context, 'Marcada como vendida',
                              type: AppSnackBarType.success);
                        }
                      case 'remove':
                        final confirmed = await confirmDestructive(
                          context,
                          title: 'Eliminar publicación',
                          message:
                              '¿Eliminar esta publicación? No se puede deshacer.',
                        );
                        if (!confirmed) return;
                        await ref
                            .read(myListingsActionsProvider.notifier)
                            .remove(listing.id);
                        if (context.mounted) {
                          showAppSnackBar(context, 'Publicación eliminada',
                              type: AppSnackBarType.success);
                        }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'sold', child: Text('Marcar como vendida')),
                    PopupMenuItem(value: 'remove', child: Text('Eliminar')),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Vendida',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
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
