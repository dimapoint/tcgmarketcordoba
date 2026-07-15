import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'active' => (Colors.green.shade100, Colors.green.shade900),
      'removed' => (Colors.red.shade100, Colors.red.shade900),
      'sold' || 'fulfilled' => (Colors.blue.shade100, Colors.blue.shade900),
      _ => (Colors.grey.shade200, Colors.grey.shade800),
    };

    return Chip(
      label: Text(status),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.bold),
      side: BorderSide.none,
    );
  }
}
