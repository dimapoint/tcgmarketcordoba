import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/post_listing/card_repository.dart';
import '../models/price_reference.dart';
import 'price_text.dart';

/// Hint de referencia de precio bajo los campos de precio de Busco y
/// Vender: listings activos locales + market price de TCGplayer. Tocar la
/// línea de mercado autocompleta el campo con el valor en ARS. Sin datos
/// (o con la API caída) no renderiza nada: el form queda como hoy.
class PriceReferenceHint extends ConsumerWidget {
  final String printingId;

  /// Cuando se pasa, la línea de mercado es tappable y autocompleta el
  /// campo de precio (formularios de Vender/Busco). Sin callback queda
  /// como texto de referencia para el comprador (detalle de publicación).
  final ValueChanged<double>? onSuggest;

  const PriceReferenceHint({
    super.key,
    required this.printingId,
    this.onSuggest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(priceReferenceProvider(printingId));
    final reference = async.value;
    if (reference == null || !reference.hasData) {
      return const SizedBox.shrink();
    }

    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reference.localActiveCount > 0)
            Text(_localLine(reference), style: style),
          if (reference.marketUsd != null)
            InkWell(
              onTap: onSuggest == null || reference.marketArs == null
                  ? null
                  : () => onSuggest!(reference.marketArs!),
              child: Text(
                _marketLine(reference),
                style: onSuggest != null && reference.marketArs != null
                    ? style?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : style,
              ),
            ),
        ],
      ),
    );
  }

  String _localLine(PriceReference ref) {
    var line = '${ref.localActiveCount} en venta acá';
    if (ref.localMinPrice != null) {
      line += ' desde ${PriceText.format(ref.localMinPrice!)}';
    }
    return line;
  }

  String _marketLine(PriceReference ref) {
    final usd = 'US\$ ${ref.marketUsd!.toStringAsFixed(2)}';
    if (ref.marketArs == null) return 'Mercado TCGplayer: $usd';
    final suffix = onSuggest != null ? ' — tocá para usar' : '';
    return 'Mercado TCGplayer: $usd (~${PriceText.format(ref.marketArs!)})$suffix';
  }
}
