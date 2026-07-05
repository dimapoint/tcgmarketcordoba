class CardPrinting {
  final String id;
  final String cardId;
  final String cardName;
  final String setName;
  final String setCode;
  final String cardNumber;
  final bool isFoil;
  final String? imageUrl;
  final int wantedCount;

  const CardPrinting({
    required this.id,
    required this.cardId,
    required this.cardName,
    required this.setName,
    required this.setCode,
    required this.cardNumber,
    required this.isFoil,
    this.imageUrl,
    this.wantedCount = 0,
  });

  factory CardPrinting.fromJson(Map<String, dynamic> j) => CardPrinting(
        id: j['id'] as String,
        cardId: j['card_id'] as String,
        cardName: j['card_name'] as String,
        setName: j['set_name'] as String,
        setCode: j['set_code'] as String,
        cardNumber: j['card_number'] as String,
        isFoil: j['is_foil'] as bool,
        imageUrl: j['image_url'] as String?,
        wantedCount: j['wanted_count'] as int? ?? 0,
      );

  String get displayName =>
      '${isFoil ? "✦ " : ""}$cardName — $setCode #$cardNumber';

  /// Variante chica para los pickers: el proxy del backend (/card-images)
  /// redimensiona server-side con ?w=, ~50 KB en vez del PNG completo.
  String? get thumbnailUrl {
    final url = imageUrl;
    if (url == null || url.contains('?')) return url;
    return '$url?w=120';
  }
}
