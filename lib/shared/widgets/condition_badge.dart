import 'package:flutter/material.dart';

/// Nombres legibles de condición, mismo vocabulario que el formulario de
/// publicar (post_listing_screen._conditionNames).
const conditionNames = {
  'NM': 'Nueva',
  'LP': 'Poco jugada',
  'MP': 'Jugada',
  'HP': 'Muy usada',
  'D': 'Dañada',
};

class ConditionBadge extends StatelessWidget {
  final String condition;
  const ConditionBadge({super.key, required this.condition});

  static const _colors = {
    'NM': Color(0xFF2E7D32),
    'LP': Color(0xFF558B2F),
    'MP': Color(0xFFF9A825),
    'HP': Color(0xFFE65100),
    'D': Color(0xFFC62828),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[condition] ?? Colors.grey;
    return Tooltip(
      message: conditionNames[condition] ?? condition,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          condition,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
