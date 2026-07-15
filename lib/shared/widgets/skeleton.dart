import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Bloque fantasma con shimmer para estados de carga. Con animaciones
/// deshabilitadas (accesibilidad) queda un bloque estático, mismo criterio
/// que FoilBorder.
class Skeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.onSurface.withValues(alpha: 0.06);

    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: base, borderRadius: borderRadius),
    );

    if (MediaQuery.of(context).disableAnimations) return box;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: Color.alphaBlend(highlight, base).withValues(alpha: 1),
      period: const Duration(milliseconds: 1400),
      child: box,
    );
  }
}

/// Card fantasma con la silueta de ListingCard (imagen 3:4 + líneas + precio).
class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Skeleton(width: double.infinity, borderRadius: BorderRadius.zero),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(width: 120, height: 14),
                SizedBox(height: 6),
                Skeleton(width: 80, height: 11),
                SizedBox(height: 10),
                Row(
                  children: [
                    Skeleton(width: 42, height: 18),
                    Spacer(),
                    Skeleton(width: 56, height: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grilla fantasma que calca el grid de browse.
class SkeletonGrid extends StatelessWidget {
  final int count;
  const SkeletonGrid({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (_, _) => const ListingCardSkeleton(),
    );
  }
}

/// Card fantasma horizontal con la silueta de WantedCard.
class WantedCardSkeleton extends StatelessWidget {
  const WantedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: const [
            Skeleton(width: 48, height: 66),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 140, height: 14),
                  SizedBox(height: 6),
                  Skeleton(width: 90, height: 11),
                  SizedBox(height: 6),
                  Skeleton(width: 60, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista fantasma de WantedCards.
class WantedListSkeleton extends StatelessWidget {
  final int count;
  const WantedListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => const WantedCardSkeleton(),
    );
  }
}

/// Fila fantasma tipo ListTile (contactos, perfil, autocomplete).
class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          Skeleton(width: 40, height: 40,
              borderRadius: BorderRadius.all(Radius.circular(20))),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 160, height: 13),
                SizedBox(height: 6),
                Skeleton(width: 100, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Silueta de pantalla de detalle: imagen grande + título + filas.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Skeleton(
            width: double.infinity,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        SizedBox(height: 16),
        Skeleton(width: 200, height: 20),
        SizedBox(height: 8),
        Skeleton(width: 120, height: 14),
        SizedBox(height: 16),
        Skeleton(width: double.infinity, height: 48),
        SizedBox(height: 8),
        Skeleton(width: double.infinity, height: 48),
      ],
    );
  }
}
