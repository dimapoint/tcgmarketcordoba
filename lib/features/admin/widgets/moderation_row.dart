import 'package:flutter/material.dart';
import '../../../shared/format/relative_time.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/price_text.dart';
import 'status_badge.dart';

/// Fila de moderación compartida entre publicaciones y buscados: thumbnail
/// de la carta, nombre, quién la publicó, precio, cuándo, estado y la
/// acción de quitar/restaurar.
class ModerationRow extends StatelessWidget {
  final String? imageUrl;
  final String cardName;
  final String? condition;
  final String username;
  final String city;
  final double price;
  final String priceLabel;
  final DateTime createdAt;
  final String status;
  final VoidCallback onToggle;

  const ModerationRow({
    super.key,
    required this.imageUrl,
    required this.cardName,
    this.condition,
    required this.username,
    required this.city,
    required this.price,
    this.priceLabel = '',
    required this.createdAt,
    required this.status,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isRemoved = status == 'removed';
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl != null
                  ? Image.network(imageUrl!,
                      width: 48,
                      height: 66,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackIcon(scheme))
                  : _fallbackIcon(scheme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(cardName,
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (condition != null) ...[
                        const SizedBox(width: 8),
                        ConditionBadge(condition: condition!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$username · $city',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (priceLabel.isNotEmpty)
                        Text('$priceLabel ',
                            style: Theme.of(context).textTheme.bodySmall),
                      PriceText(price: price, fontSize: 14),
                      const SizedBox(width: 8),
                      Text('· ${relativeTime(createdAt)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.outline)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: status),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onToggle,
                  child: Text(isRemoved ? 'Restaurar' : 'Quitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon(ColorScheme scheme) => Container(
        width: 48,
        height: 66,
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.style, color: scheme.onSurfaceVariant, size: 20),
      );
}
