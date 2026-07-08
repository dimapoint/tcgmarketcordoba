import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/wanted_order.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/price_text.dart';

class WantedCard extends StatelessWidget {
  final WantedOrder order;
  const WantedCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = order.cardImageThumb(120);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/b/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  order.minCondition != null
                      ? ConditionBadge(condition: order.minCondition!)
                      : _AnyConditionChip(),
                  const Spacer(),
                  Text('Pago hasta ',
                      style: Theme.of(context).textTheme.bodySmall),
                  PriceText(price: order.maxPrice, fontSize: 15),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.format_list_numbered,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('Busco ${order.quantity}x',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  Icon(Icons.place_outlined,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(order.buyerCity,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnyConditionChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Cualquier condición',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
