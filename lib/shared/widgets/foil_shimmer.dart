import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Firma visual de la app: las publicaciones foil llevan un borde dorado
/// con un brillo que se desplaza. Con animaciones deshabilitadas queda
/// un borde dorado estático.
class FoilBorder extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  const FoilBorder({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<FoilBorder> createState() => _FoilBorderState();
}

class _FoilBorderState extends State<FoilBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.of(context).disableAnimations;
    if (animate && !_controller.isAnimating) _controller.repeat();
    if (!animate && _controller.isAnimating) _controller.stop();

    final gold = AppColors.price(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * t, -1),
              end: Alignment(-0.5 + 3 * t, 1),
              colors: [
                gold.withValues(alpha: 0.45),
                gold,
                gold.withValues(alpha: 0.45),
              ],
            ),
          ),
          child: Padding(padding: const EdgeInsets.all(2), child: child),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.all(
          Radius.circular(widget.borderRadius.topLeft.x - 2),
        ),
        child: widget.child,
      ),
    );
  }
}
