import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Precio en ARS con separador de miles estilo es_AR: `$ 4.500`.
class PriceText extends StatelessWidget {
  final double price;
  final double fontSize;
  const PriceText({super.key, required this.price, this.fontSize = 16});

  static String format(double price) {
    final digits = price.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return '\$ $buf';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      format(price),
      style: priceStyle(context, fontSize: fontSize),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
