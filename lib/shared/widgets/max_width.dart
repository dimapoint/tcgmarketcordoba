import 'package:flutter/material.dart';

/// Centra el contenido con un ancho máximo — evita líneas kilométricas en PC.
class CenteredMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const CenteredMaxWidth({super.key, required this.child, this.maxWidth = 1100});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
