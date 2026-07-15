import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String label, Color bg, Color fg) = switch (status) {
      'active' => ('Activa', scheme.primaryContainer, scheme.onPrimaryContainer),
      'removed' => ('Eliminada', scheme.errorContainer, scheme.onErrorContainer),
      'sold' => ('Vendida', scheme.secondaryContainer, scheme.onSecondaryContainer),
      'fulfilled' =>
        ('Cumplida', scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (status, scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.bold),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
