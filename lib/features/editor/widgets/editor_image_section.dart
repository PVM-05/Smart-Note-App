import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/design/app_colors.dart';

class EditorImageSection extends StatelessWidget {
  final List<String> imageUrls;
  final List<File> uploadingFiles;
  final Set<String> deletingUrls;
  final String? noteColor;
  final ValueChanged<int> onOpenImage;
  final ValueChanged<String> onEditDrawing;

  const EditorImageSection({
    super.key,
    required this.imageUrls,
    required this.uploadingFiles,
    required this.deletingUrls,
    required this.noteColor,
    required this.onOpenImage,
    required this.onEditDrawing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...imageUrls.asMap().entries.map((entry) {
          final index = entry.key;
          final url = entry.value;
          final isDrawing = url.contains('/drawings/');
          final isDeleting = deletingUrls.contains(url);

          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: isDeleting
                      ? null
                      : (isDrawing
                          ? () => onEditDrawing(url)
                          : () => onOpenImage(index)),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: noteColor != null
                              ? AppColors.parseColor(noteColor!)
                              : AppColors.divider(context),
                          width: noteColor != null ? 2 : 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: const Color(0xFFF8FAFC),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 100,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.broken_image_outlined,
                              color: Color(0xFF94A3B8), size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isDeleting)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        ...uploadingFiles.map((file) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: noteColor != null
                            ? AppColors.parseColor(noteColor!)
                            : AppColors.divider(context),
                        width: noteColor != null ? 2 : 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      file,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
