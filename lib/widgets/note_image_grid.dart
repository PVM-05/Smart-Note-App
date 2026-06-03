import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class NoteImageGrid extends StatelessWidget {
  final List<String> imageUrls;
  final Function(int)? onImageTap;
  final List<int> deletingIndices;

  const NoteImageGrid({
    super.key,
    required this.imageUrls,
    this.onImageTap,
    this.deletingIndices = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final count = imageUrls.length;

    if (count == 1) {
      return _buildImage(imageUrls[0], 0, height: 200, fit: BoxFit.cover);
    } else if (count == 2) {
      return SizedBox(
        height: 150,
        child: Row(
          children: [
            Expanded(child: _buildImage(imageUrls[0], 0)),
            const SizedBox(width: 2),
            Expanded(child: _buildImage(imageUrls[1], 1)),
          ],
        ),
      );
    } else if (count == 3) {
      return SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(child: _buildImage(imageUrls[0], 0)),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildImage(imageUrls[1], 1)),
                  const SizedBox(height: 2),
                  Expanded(child: _buildImage(imageUrls[2], 2)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox(
        height: 240,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildImage(imageUrls[0], 0)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildImage(imageUrls[1], 1)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildImage(imageUrls[2], 2)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildImage(
                      imageUrls[3],
                      3,
                      extraCount: count > 4 ? count - 4 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildImage(String url, int index, {double? height, BoxFit fit = BoxFit.cover, int extraCount = 0}) {
    final imageWidget = Stack(
      children: [
        Container(
          width: double.infinity,
          height: height,
          color: const Color(0xFFF1F5F9), // Placeholder color
          child: CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            placeholder: (context, url) => const Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
              ),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
            ),
          ),
        ),
        if (extraCount > 0)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Text(
                  '+$extraCount',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (deletingIndices.contains(index))
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (onImageTap != null && !deletingIndices.contains(index)) {
      return GestureDetector(
        onTap: () => onImageTap!(index),
        child: imageWidget,
      );
    }
    return imageWidget;
  }
}
