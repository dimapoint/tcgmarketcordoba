/// Referencia de precio de un printing: mercado TCGplayer (USD y su
/// conversión a ARS blue) + listings activos en la app. Cualquier fuente
/// puede venir null si estaba caída o sin datos.
class PriceReference {
  final double? marketUsd;
  final double? marketArs;
  final double? fxRate;
  final bool isFoil;
  final int localActiveCount;
  final double? localMinPrice;

  const PriceReference({
    this.marketUsd,
    this.marketArs,
    this.fxRate,
    required this.isFoil,
    required this.localActiveCount,
    this.localMinPrice,
  });

  factory PriceReference.fromJson(Map<String, dynamic> j) => PriceReference(
        marketUsd: (j['market_usd'] as num?)?.toDouble(),
        marketArs: (j['market_ars'] as num?)?.toDouble(),
        fxRate: (j['fx_rate'] as num?)?.toDouble(),
        isFoil: j['is_foil'] as bool? ?? false,
        localActiveCount: j['local_active_count'] as int? ?? 0,
        localMinPrice: (j['local_min_price'] as num?)?.toDouble(),
      );

  bool get hasData => marketUsd != null || localActiveCount > 0;
}
