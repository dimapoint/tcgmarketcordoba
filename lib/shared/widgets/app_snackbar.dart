import 'package:flutter/material.dart';

enum AppSnackBarType { info, success, error }

/// Punto único para toasts: mismo estilo (snackBarTheme del tema) con
/// variantes de ícono/acento según resultado.
void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackBarType type = AppSnackBarType.info,
}) {
  final (icon, color) = switch (type) {
    AppSnackBarType.success => (
        Icons.check_circle_outline,
        const Color(0xFF7BD88F),
      ),
    AppSnackBarType.error => (
        Icons.error_outline,
        const Color(0xFFF28B82),
      ),
    AppSnackBarType.info => (null, null),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
