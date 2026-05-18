import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final String? searchQuery;
  final VoidCallback? onMenuPressed;
  final bool isGrid;

  const NoteCard({
    super.key,
    required this.note,
    this.searchQuery,
    this.onMenuPressed,
    this.isGrid = true,
  });

  String _formatDate(DateTime date) {
    final months = [
      'th 1', 'th 2', 'th 3', 'th 4', 'th 5', 'th 6',
      'th 7', 'th 8', 'th 9', 'th 10', 'th 11', 'th 12'
    ];
    return 'Ngày ${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  static Color getNoteColor(String id) {
    // Bảng màu sắp xếp tương phản (đối diện trên bánh xe màu)
    final colors = [
      const Color(0xFFEF9A9A), // Đỏ nhạt
      const Color(0xFF90CAF9), // Xanh dương nhạt (đối lập đỏ)
      const Color(0xFFFFE082), // Vàng nhạt
      const Color(0xFFA5D6A7), // Xanh lá nhạt (đối lập vàng/cam)
      const Color(0xFFFFAB91), // Cam nhạt (đối lập xanh dương)
    ];
    return colors[id.hashCode % colors.length];
  }

  Widget? _buildNoteImage(String content) {
    // 1. Tìm markdown image tag: ![...] (url hoặc path hoặc base64)
    final mdRegex = RegExp(r'!\[.*?\]\((.*?)\)');
    final mdMatch = mdRegex.firstMatch(content);
    String? path;
    if (mdMatch != null) {
      path = mdMatch.group(1);
    }

    // 2. Tìm link ảnh trực tiếp kết thúc bằng các đuôi ảnh phổ biến
    if (path == null) {
      final urlRegex = RegExp(
        r'(https?:\/\/[^\s\)]+\.(?:png|jpg|jpeg|gif|webp|bmp))',
        caseSensitive: false,
      );
      final urlMatch = urlRegex.firstMatch(content);
      if (urlMatch != null) {
        path = urlMatch.group(1);
      }
    }

    if (path == null) return null;

    // 3. Render tùy thuộc vào loại dữ liệu và bảo toàn nguyên vẹn tỉ lệ ảnh tự nhiên (aspect ratio)
    if (path.startsWith('data:image') && path.contains('base64,')) {
      try {
        final base64Str = path.split('base64,').last;
        final bytes = base64.decode(base64Str.trim());
        return Image.memory(
          bytes,
          fit: BoxFit.fitWidth,
          width: double.infinity,
        );
      } catch (_) {
        return null;
      }
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.fitWidth,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    } else {
      // Có thể là file path cục bộ từ thư viện vẽ phác thảo
      try {
        return Image.file(
          File(path),
          fit: BoxFit.fitWidth,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      } catch (_) {
        return null;
      }
    }
  }

  String _getDisplayContent(String content) {
    final mdRegex = RegExp(r'!\[.*?\]\((.*?)\)');
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s\)]+\.(?:png|jpg|jpeg|gif|webp|bmp))',
      caseSensitive: false,
    );
    // Loại bỏ hoàn toàn link hình ảnh khỏi chuỗi mô tả text
    return content.replaceAll(mdRegex, '').replaceAll(urlRegex, '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = getNoteColor(note.id);
    final imageWidget = _buildNoteImage(note.content);
    final displayContent = _getDisplayContent(note.content);

    if (isGrid) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              // Mép viền màu ở bên trái (stripe)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4.5,
                child: Container(color: cardColor),
              ),
              // Nội dung chính
              Padding(
                padding: const EdgeInsets.only(left: 4.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageWidget != null) imageWidget,
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── HEADER: TIÊU ĐỀ & MENU ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: note.title.isNotEmpty
                                    ? _buildHighlightedText(
                                        note.title,
                                        style: GoogleFonts.roboto(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1A202C),
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 2,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (onMenuPressed != null)
                                IconButton(
                                  icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                                  onPressed: onMenuPressed,
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                            ],
                          ),
                          
                          // ── NỘI DUNG ──
                          if (displayContent.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _buildHighlightedText(
                              displayContent,
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: const Color(0xFF475569).withValues(alpha: 0.85),
                                height: 1.5,
                              ),
                              maxLines: 5, // Tăng lên 5 dòng để hiển thị nhiều nội dung hơn trong grid staggered
                            ),
                          ],
                          
                          const SizedBox(height: 12),
                          // ── FOOTER: DATE & COLOR DOT ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(note.updatedAt),
                                style: GoogleFonts.roboto(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (note.status == 'pinned')
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4.0),
                                      child: Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFF2E75B6)),
                                    ),
                                  if (!note.isSynced)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4.0),
                                      child: Icon(Icons.cloud_upload_outlined, size: 12, color: Colors.grey.shade500),
                                    ),
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: getNoteColor(note.id),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // LIST VIEW
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // Mép viền màu ở bên trái (stripe)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4.5,
              child: Container(color: cardColor),
            ),
            // Nội dung chính
            Padding(
              padding: const EdgeInsets.only(left: 4.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageWidget != null) imageWidget,
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── HEADER: TIÊU ĐỀ & MENU ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (note.title.isNotEmpty)
                                    _buildHighlightedText(
                                      note.title,
                                      style: GoogleFonts.roboto(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1A202C),
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 2,
                                    ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDate(note.updatedAt),
                                    style: GoogleFonts.roboto(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (onMenuPressed != null)
                              IconButton(
                                icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: onMenuPressed,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),

                        if (note.title.isNotEmpty && displayContent.isNotEmpty)
                          const SizedBox(height: 10),

                        // ── NỘI DUNG ──
                        if (displayContent.isNotEmpty)
                          _buildHighlightedText(
                            displayContent,
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              color: const Color(0xFF475569).withValues(alpha: 0.85),
                              height: 1.55,
                            ),
                            maxLines: 6,
                          ),

                        // ── FOOTER: TRẠNG THÁI & COLOR DOT ──
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (note.status == 'pinned')
                                    const Icon(Icons.push_pin_rounded, size: 13, color: Color(0xFF2E75B6)),
                                  if (!note.isSynced)
                                    Padding(
                                      padding: EdgeInsets.only(left: note.status == 'pinned' ? 6.0 : 0.0),
                                      child: Icon(Icons.cloud_upload_outlined, size: 13, color: Colors.grey.shade500),
                                    ),
                                ],
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: getNoteColor(note.id),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
      String text, {
        required TextStyle style,
        int maxLines = 1,
      }) {
    final query = searchQuery?.trim() ?? '';

    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText  = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans      = <TextSpan>[];
    int start        = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: style,
        ));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: style,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: Colors.yellow.shade200,
          color: Colors.black87,
        ),
      ));
      start = index + query.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
