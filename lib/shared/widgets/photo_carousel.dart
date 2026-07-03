import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/listing.dart';

class PhotoCarousel extends StatefulWidget {
  final List<ListingPhoto> photos;
  const PhotoCarousel({super.key, required this.photos});

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.style_outlined, size: 64, color: scheme.outline),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: widget.photos[i].url,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  ColoredBox(color: scheme.surfaceContainerHighest),
              errorWidget: (_, _, _) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined,
                    size: 40, color: scheme.outline),
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.photos.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i == _current ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
