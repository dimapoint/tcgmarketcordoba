import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/widgets/condition_badge.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;
  const ListingCard({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final firstPhoto = listing.photos.isNotEmpty ? listing.photos.first : null;

    return GestureDetector(
      onTap: () => context.push('/listings/${listing.id}'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  firstPhoto != null
                      ? CachedNetworkImage(
                        imageUrl: firstPhoto.storagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                      : const ColoredBox(
                        color: Colors.grey,
                        child: Center(
                          child: Icon(Icons.image, color: Colors.white),
                        ),
                      ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.cardName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ConditionBadge(condition: listing.condition),
                      const Spacer(),
                      Text(
                        '\$${listing.price.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listing.sellerCity,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
