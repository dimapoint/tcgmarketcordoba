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
    if (widget.photos.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: Colors.grey,
          child: Icon(Icons.image, size: 64, color: Colors.white),
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
            itemBuilder:
                (_, i) => CachedNetworkImage(
                  imageUrl: widget.photos[i].url,
                  fit: BoxFit.cover,
                ),
          ),
        ),
        if (widget.photos.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.photos.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      i == _current
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
