import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/listing.dart';
import '../models/wanted_order.dart';
import '../widgets/price_text.dart';

/// Textos de compartir para grupos de WhatsApp/Facebook. Funciones puras
/// (testeables); la URL llega armada desde el caller con [currentOrigin].
/// Sin emoji: el share sheet de Windows / algunos clientes lo corrompen.
String listingShareText(Listing l, String url) {
  final cond = l.isFoil ? '(Foil, ${l.condition})' : '(${l.condition})';
  return 'Vendo ${l.cardName} $cond a ${PriceText.format(l.price)} '
      'en TCG Market Córdoba: $url';
}

String wantedShareText(WantedOrder o, String url) =>
    'Busco ${o.cardName} — pago hasta ${PriceText.format(o.maxPrice)} '
    '· TCG Market Córdoba: $url';

String binderShareText(String url) =>
    'Mis cartas en venta en TCG Market Córdoba: $url';

/// Origin actual en web ("https://tcgmarketcordoba.fly.dev"); '' fuera de
/// http(s) (tests, desktop) — el link queda relativo pero usable.
String currentOrigin() =>
    Uri.base.scheme.startsWith('http') ? Uri.base.origin : '';

/// Intenta el share nativo (Web Share API / share sheet del SO). Donde no
/// existe (Chrome desktop viejo, Linux), cae a un bottom sheet con WhatsApp
/// y "copiar link" — ese fallback no depende de nada del navegador.
Future<void> shareWithFallback(
  BuildContext context, {
  required String text,
  required String url,
}) async {
  try {
    final result = await SharePlus.instance.share(ShareParams(text: text));
    if (result.status != ShareResultStatus.unavailable) return;
  } catch (_) {
    // sin share nativo: cae al sheet
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
            title: const Text('Compartir por WhatsApp'),
            onTap: () {
              launchUrl(
                Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
              );
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Copiar link'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copiado')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}
