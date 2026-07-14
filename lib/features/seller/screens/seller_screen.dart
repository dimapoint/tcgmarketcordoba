import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/seller_page.dart';
import '../../../shared/models/wanted_order.dart';
import '../../../shared/share/share.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/max_width.dart';
import '../../../shared/widgets/price_text.dart';
import '../seller_provider.dart';

/// Página pública de un vendedor ("su carpeta"): todo lo que vende y busca,
/// pensada para compartirse como un solo link en grupos de WhatsApp.
class SellerScreen extends ConsumerWidget {
  final String username;
  const SellerScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(sellerPageProvider(username));

    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Ir al inicio',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir carpeta',
            onPressed: () {
              final url = '${currentOrigin()}/u/$username';
              shareWithFallback(
                context,
                text: binderShareText(url),
                url: url,
              );
            },
          ),
        ],
      ),
      body: pageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar el vendedor'),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
        data: (page) => _Body(page: page),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final SellerPage page;
  const _Body({required this.page});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = page.listings.isEmpty && page.buyOrders.isEmpty;

    return SingleChildScrollView(
      child: CenteredMaxWidth(
        maxWidth: 800,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      page.profile.username.isNotEmpty
                          ? page.profile.username[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          page.profile.username,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (page.profile.city != null)
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                page.profile.city!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (empty)
                const EmptyState(
                  icon: Icons.storefront_outlined,
                  message: 'Todavía no publicó nada',
                ),
              if (page.listings.isNotEmpty) ...[
                Text('Vende', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...page.listings.map((l) => _ListingTile(listing: l)),
                const SizedBox(height: 16),
              ],
              if (page.buyOrders.isNotEmpty) ...[
                Text('Busca', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...page.buyOrders.map((o) => _WantedTile(order: o)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingTile extends StatelessWidget {
  final Listing listing;
  const _ListingTile({required this.listing});

  @override
  Widget build(BuildContext context) {
    final firstPhoto =
        listing.photos.isNotEmpty ? listing.photos.first.url : null;
    final thumb = firstPhoto ?? listing.cardImageThumb(120);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push('/l/${listing.id}'),
        leading: thumb == null
            ? const Icon(Icons.style_outlined)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: thumb,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(listing.cardName),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConditionBadge(condition: listing.condition),
            if (listing.isFoil) ...[
              const SizedBox(width: 6),
              const Text('✦ Foil'),
            ],
          ],
        ),
        trailing: PriceText(price: listing.price),
      ),
    );
  }
}

class _WantedTile extends StatelessWidget {
  final WantedOrder order;
  const _WantedTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final thumb = order.cardImageThumb(120);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push('/b/${order.id}'),
        leading: thumb == null
            ? const Icon(Icons.search_outlined)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: thumb,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(order.cardName),
        subtitle: Text('hasta ${PriceText.format(order.maxPrice)}'),
      ),
    );
  }
}
