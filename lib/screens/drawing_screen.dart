import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/design/app_colors.dart';

class DrawingScreen extends StatefulWidget {
  final String? noteColor;
  final String? initialImageUrl;

  const DrawingScreen({super.key, this.noteColor, this.initialImageUrl});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final DrawingController _drawingController = DrawingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _drawingController.dispose();
    super.dispose();
  }

  Future<void> _saveDrawing() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final ByteData? imageData = await _drawingController.getImageData();
      if (imageData == null) {
        throw Exception("Không thể trích xuất hình ảnh");
      }

      final buffer = imageData.buffer;
      final Directory tempDir = await getTemporaryDirectory();
      final File file = File('${tempDir.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(
          buffer.asUint8List(imageData.offsetInBytes, imageData.lengthInBytes));

      if (mounted) {
        Navigator.pop(context, file); // Trả file về cho EditorScreen xử lý upload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu bản vẽ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.resolveNoteBackground(context, widget.noteColor) ?? AppColors.background(context);
    final appBarColor = AppColors.resolveNoteBackground(context, widget.noteColor) ?? AppColors.surface(context);
    final isCustomColor = widget.noteColor != null && widget.noteColor!.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bảng vẽ',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isCustomColor ? const Color(0xFF1E293B) : AppColors.textPrimary(context),
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveDrawing,
              child: Text(
                'Lưu',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: DrawingBoard(
                controller: _drawingController,
                background: Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  color: Colors.white,
                  child: widget.initialImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.initialImageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
