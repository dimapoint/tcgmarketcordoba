import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/format/relative_time.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/foil_shimmer.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/skeleton.dart';

class ListingCard extends StatefulWidget {
  final Listing listing;
  const ListingCard({super.key, required this.listing});

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final card = _CardBody(listing: widget.listing);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => context.push('/l/${widget.listing.id}'),
        child: AnimatedScale(
          scale: _hovering ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.listing.isFoil ? FoilBorder(child: card) : card,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  final Listing listing;
  const _CardBody({required this.listing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstPhoto = listing.photos.isNotEmpty ? listing.photos.first : null;
    // Sin fotos del vendedor se muestra la imagen de catálogo de la carta.
    final imageUrl = firstPhoto?.url ?? listing.cardImageThumb(400);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: imageUrl != null
                ? Hero(
                    tag: 'listing-photo-${listing.id}',
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        fadeInDuration: const Duration(milliseconds: 250),
                        placeholder: (_, _) => const Skeleton(
                          width: double.infinity,
                          borderRadius: BorderRadius.zero,
                        ),
                        errorWidget: (_, _, _) => _Placeholder(scheme: scheme),
                      ),
                    ),
                  )
                : _Placeholder(scheme: scheme),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${listing.isFoil ? '✦ ' : ''}${listing.cardName}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 15),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    ConditionBadge(condition: listing.condition),
                    const Spacer(),
                    PriceText(price: listing.price, fontSize: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (listing.quantity > 1) ...[
                      Icon(Icons.format_list_numbered,
                          size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text('${listing.quantity}x',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.place_outlined,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        listing.sellerCity,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      relativeTime(listing.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ColorScheme scheme;
  const _Placeholder({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.style_outlined, size: 40, color: scheme.outline),
      ),
    );
  }
}
