// lib/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../core/design/app_colors.dart';
import '../models/note_model.dart';
import '../core/app_localizations.dart';

// ─── Radius Design Tokens ───────────────────────────────────────────────────
// card = 14 | badge/chip/tag = 20 (pill) | inner-clip = 13.5
// This scale is locked across the whole app — do not deviate.
// ────────────────────────────────────────────────────────────────────────────

class NoteCard extends StatelessWidget {
  final Note note;
  final String? searchQuery;
  final VoidCallback? onMenuPressed;
  final bool isGrid;

  // Khuyến khích sử dụng const constructor để Flutter đưa vào bộ nhớ cache hệ thống
  const NoteCard({
    super.key,
    required this.note,
    this.searchQuery,
    this.onMenuPressed,
    this.isGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    Color cardColor = _resolveCardColor(context);
    final bool hasCustomColor = note.noteColor != null && note.noteColor!.isNotEmpty;
    bool onDarkNoteBg = hasCustomColor && cardColor.computeLuminance() < 0.45;

    final bool isLocked = note.isLocked;
    final hasImages = !isLocked && note.imageUrls.isNotEmpty;
    final hasAudio = !isLocked && note.audioUrls.isNotEmpty;
    final hasTags = !isLocked && note.tags.isNotEmpty;
    final hasReminder = !isLocked && note.reminder != null;

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // ── Border strategy: light shadow > thin border ──────────────────────
    // Light mode: very thin 0.6px border + subtle tinted shadow
    // Dark mode: 1px border only (shadow invisible on dark backgrounds)
    final defaultBorderColor = isDarkTheme
        ? const Color(0xFF42454D)
        : const Color(0xFFD1D5DB); // softer than before
    BorderSide borderSide = BorderSide.none;
    List<BoxShadow> cardShadows = [];

    if (hasImages) {
      cardColor = AppColors.surface(context);
      onDarkNoteBg = false;
      borderSide = BorderSide(
        color: hasCustomColor ? AppColors.parseColor(note.noteColor!) : defaultBorderColor,
        width: hasCustomColor ? 1.5 : 0.6,
      );
    } else if (!hasCustomColor) {
      borderSide = BorderSide(color: defaultBorderColor, width: isDarkTheme ? 1.0 : 0.6);
      if (!isDarkTheme) {
        // Soft tinted shadow replaces harsh border weight in light mode
        cardShadows = [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ];
      }
    }

    final Color titleColor;
    final Color contentColor;
    final Color metadataColor;

    if (hasCustomColor) {
      if (onDarkNoteBg) {
        titleColor = Colors.white;
        contentColor = Colors.white.withValues(alpha: 0.92);
        metadataColor = const Color(0xFFE2E8F0);
      } else {
        titleColor = Colors.black;
        contentColor = const Color(0xFF1C1E21);
        metadataColor = const Color(0xFF4A5568);
      }
    } else {
      if (isDarkTheme) {
        titleColor = Colors.white;
        contentColor = const Color(0xFFE8EAED);
        metadataColor = const Color(0xFF9AA0A6);
      } else {
        titleColor = Colors.black;
        contentColor = const Color(0xFF202124);
        metadataColor = const Color(0xFF5F6368);
      }
    }

    final String displayTitle = isLocked ? 'Ghi chú đã khóa' : note.title;
    final bool isChecklist = !isLocked && note.isChecklist;
    final String displayContent = isLocked
        ? 'Nội dung đã được bảo vệ'
        : (isChecklist ? '' : _getPlainText(note.content));

    final cardBody = _buildCardBody(
      context,
      titleColor: titleColor,
      contentColor: contentColor,
      metadataColor: metadataColor,
      displayTitle: displayTitle,
      displayContent: displayContent,
      isChecklist: isChecklist,
      hasImages: hasImages,
      hasAudio: hasAudio,
      hasTags: hasTags,
      hasReminder: hasReminder,
    );

    final Border? cardBorder = borderSide == BorderSide.none
        ? null
        : Border.all(color: borderSide.color, width: borderSide.width);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14), // 🔒 Locked: card radius = 14
        border: cardBorder,
        boxShadow: cardShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.5),
        child: cardBody,
      ),
    );
  }

  Widget _buildCardBody(
    BuildContext context, {
    required Color titleColor,
    required Color contentColor,
    required Color metadataColor,
    required String displayTitle,
    required String displayContent,
    required bool isChecklist,
    required bool hasImages,
    required bool hasAudio,
    required bool hasTags,
    required bool hasReminder,
  }) {
    final bool hasCustomColor = note.noteColor != null && note.noteColor!.isNotEmpty;
    final bool onDarkNoteBg = hasCustomColor && (_resolveCardColor(context).computeLuminance() < 0.45);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── 1. HÌNH ẢNH TOÀN BỘ (GOOGLE KEEP STYLE) ──
          if (hasImages)
            CachedNetworkImage(
              imageUrl: note.imageUrls.first,
              fit: BoxFit.fitWidth,
              placeholder: (context, url) => Container(
                height: 120,
                color: AppColors.surface(context),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.placeholder(context)),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 60,
                color: AppColors.inputBackground(context),
                child: Icon(Icons.broken_image_outlined, color: AppColors.placeholder(context), size: 20),
              ),
            ),

          // Phần thân chứa Tiêu đề, Nội dung văn bản, Thông tin file ghi âm và Chân thẻ
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── 2. HEADER: TIÊU ĐỀ & MENU ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (displayTitle.isNotEmpty)
                            _buildHighlightedText(
                              context,
                              displayTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600, // w700→w600: less heavy, more editorial
                                color: titleColor,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                            ),
                        ],
                      ),
                    ),
                    if (onMenuPressed != null)
                      IconButton(
                        icon: Icon(Icons.more_vert, size: 18, color: metadataColor),
                        onPressed: onMenuPressed,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),

                if (displayTitle.isNotEmpty && displayContent.isNotEmpty)
                  const SizedBox(height: 6),

                if (displayContent.isNotEmpty)
                  _buildHighlightedText(
                    context,
                    displayContent,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: contentColor,
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 6,
                  ),

                // ── 3b. PREVIEW CHECKLIST ──
                if (isChecklist)
                  _buildChecklistPreview(context),

                // ── 4. BADGE ROW: AUDIO + REMINDER ──
                if (hasAudio || hasReminder) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (hasAudio)
                        _buildAudioFileAttachment(context, note.audioUrls.first, onDarkNoteBg: onDarkNoteBg, hasCustomColor: hasCustomColor, isDarkTheme: isDarkTheme),
                      if (hasReminder)
                        _buildReminderBadge(context, onDarkNoteBg: onDarkNoteBg, hasCustomColor: hasCustomColor, isDarkTheme: isDarkTheme),
                    ],
                  ),
                ],

                // ── 5. FOOTER: DANH SÁCH THẺ (TAGS) ──
                if (hasTags)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Wrap(
                      spacing: 5.0,
                      runSpacing: 5.0,
                      children: note.tags.map((tag) {
                        final Color tagBgColor;
                        final Color tagTextColor;
                        if (hasCustomColor) {
                          if (onDarkNoteBg) {
                            tagBgColor = Colors.white.withValues(alpha: 0.14);
                            tagTextColor = Colors.white;
                          } else {
                            tagBgColor = Colors.black.withValues(alpha: 0.07);
                            tagTextColor = const Color(0xFF202124);
                          }
                        } else {
                          tagBgColor = isDarkTheme
                              ? Colors.white.withValues(alpha: 0.09)
                              : Colors.black.withValues(alpha: 0.05);
                          tagTextColor = isDarkTheme
                              ? const Color(0xFFE8EAED)
                              : const Color(0xFF374151);
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: tagBgColor,
                            borderRadius: BorderRadius.circular(20), // 🔒 pill = 20
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: tagTextColor,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
  }

  Color _resolveCardColor(BuildContext context) {
    final resolved = AppColors.resolveNoteBackground(context, note.noteColor);
    if (resolved != null) return resolved;
    return AppColors.surface(context);
  }

  // Widget hiển thị Biểu tượng Micro + Tên file âm thanh gọn gàng — pill badge
  Widget _buildAudioFileAttachment(
    BuildContext context,
    String audioUrl, {
    required bool onDarkNoteBg,
    required bool hasCustomColor,
    required bool isDarkTheme,
  }) {
    final String fileName = AppLocalizations.translate(context, 'voiceNote');

    final Color audioBgColor;
    final Color audioTextColor;
    if (hasCustomColor) {
      if (onDarkNoteBg) {
        audioBgColor = Colors.white.withValues(alpha: 0.12);
        audioTextColor = Colors.white;
      } else {
        audioBgColor = Colors.black.withValues(alpha: 0.07);
        audioTextColor = const Color(0xFF202124);
      }
    } else {
      audioBgColor = isDarkTheme
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      audioTextColor = isDarkTheme
          ? const Color(0xFFE8EAED)
          : const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: audioBgColor,
        borderRadius: BorderRadius.circular(20), // 🔒 pill = 20
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: 13,
            color: audioTextColor,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              fileName,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: audioTextColor,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị preview các mục checklist với checkbox icons
  Widget _buildChecklistPreview(BuildContext context) {
    try {
      final decoded = jsonDecode(note.content);
      final items = (decoded['items'] as List? ?? []).take(6).toList();
      if (items.isEmpty) return const SizedBox.shrink();

      final bool hasCustomColor = note.noteColor != null && note.noteColor!.isNotEmpty;
      final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
      final cardBgColor = _resolveCardColor(context);
      final bool onDarkNoteBg = hasCustomColor && (cardBgColor.computeLuminance() < 0.45);

      final Color checkedColor;
      final Color uncheckedColor;
      if (hasCustomColor) {
        if (onDarkNoteBg) {
          checkedColor = Colors.white.withValues(alpha: 0.5);
          uncheckedColor = Colors.white;
        } else {
          checkedColor = const Color(0xFF6B7280);
          uncheckedColor = const Color(0xFF202124);
        }
      } else {
        if (isDarkTheme) {
          checkedColor = const Color(0xFF9AA0A6);
          uncheckedColor = const Color(0xFFE8EAED);
        } else {
          checkedColor = const Color(0xFF6B7280);
          uncheckedColor = const Color(0xFF202124);
        }
      }

      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map<Widget>((item) {
            final checked = item['checked'] == true;
            final text = item['text'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    // 🔒 Icon consistency: always use outlined variants
                    checked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                    size: 15,
                    color: checked ? checkedColor : uncheckedColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: checked ? checkedColor : uncheckedColor,
                        decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
                        height: 1.4,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  // ⚡ SIÊU TỐI ƯU CPU: Giải thuật so khớp chuỗi tĩnh không dùng vòng lặp vô hạn
  Widget _buildHighlightedText(
      BuildContext context,
      String text, {
        required TextStyle style,
        int maxLines = 1,
      }) {
    final query = note.isLocked ? '' : (searchQuery?.trim() ?? '');

    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: AppColors.warning.withValues(alpha: 0.22),
          color: AppColors.textPrimary(context),
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

  String _getPlainText(String content) {
    if (content.isEmpty) return '';
    try {
      final decoded = jsonDecode(content);
      // Checklist content → trả rỗng vì đã render bằng _buildChecklistPreview
      if (decoded is Map && decoded['type'] == 'checklist') return '';
      if (decoded is List) {
        final buffer = StringBuffer();
        for (final item in decoded) {
          if (item is Map && item.containsKey('insert')) {
            final val = item['insert'];
            if (val is String) {
              buffer.write(val);
            }
          }
        }
        return buffer.toString().trim();
      }
    } catch (_) {}
    return content.trim();
  }

  // Widget badge nhắc nhở — pill-shaped, outlined alarm icon
  Widget _buildReminderBadge(
    BuildContext context, {
    required bool onDarkNoteBg,
    required bool hasCustomColor,
    required bool isDarkTheme,
  }) {
    final DateTime dt = note.reminder!;
    final now = DateTime.now();
    final isExpired = dt.isBefore(now);

    String reminderText = '';
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dtDay = DateTime(dt.year, dt.month, dt.day);
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (dtDay == today) {
      reminderText = 'Hôm nay, $timeStr';
    } else if (dtDay == tomorrow) {
      reminderText = 'Ngày mai, $timeStr';
    } else {
      reminderText = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $timeStr';
    }

    final Color badgeBgColor;
    final Color badgeTextColor;
    if (hasCustomColor) {
      if (onDarkNoteBg) {
        badgeBgColor = Colors.white.withValues(alpha: 0.12);
        badgeTextColor = Colors.white.withValues(alpha: 0.9);
      } else {
        badgeBgColor = Colors.black.withValues(alpha: 0.07);
        badgeTextColor = const Color(0xFF202124);
      }
    } else {
      badgeBgColor = isDarkTheme
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      badgeTextColor = isDarkTheme
          ? const Color(0xFFE8EAED)
          : const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withValues(alpha: isDarkTheme ? 0.18 : 0.08)
            : badgeBgColor,
        borderRadius: BorderRadius.circular(20), // 🔒 pill = 20
        border: isExpired
            ? Border.all(color: Colors.red.withValues(alpha: 0.35), width: 0.8)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alarm_outlined, // 🔒 Icon consistency: always outlined
            size: 12,
            color: isExpired ? Colors.red.shade400 : badgeTextColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              reminderText,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: isExpired ? Colors.red.shade400 : badgeTextColor,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                decoration: isExpired ? TextDecoration.lineThrough : TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}