import 'dart:convert';
import 'package:flutter/material.dart' hide Border, BorderSide, Alignment, AlignmentGeometry, Page, Image, Icon, IconData, TextSpan, RichText;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../models/note_model.dart';
import 'package:intl/intl.dart';
import '../core/app_localizations.dart';

class PdfExportService {
  /// Xuất ghi chú ra tệp PDF và mở hộp thoại chia sẻ/in của hệ thống
  static Future<void> exportNoteToPdf(BuildContext flutterContext, Note note) async {
    ScaffoldMessenger.of(flutterContext).showSnackBar(
      SnackBar(content: Text(AppLocalizations.translate(flutterContext, 'pdfInitializing'))),
    );

    try {
      final doc = pw.Document();

      // Tải font tiếng Việt Unicode (Roboto) từ Google Fonts
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      final fontItalic = await PdfGoogleFonts.robotoItalic();

      final pdfTheme = pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      );

      // Tải các ảnh đính kèm (nếu có)
      final List<pw.MemoryImage> pdfImages = [];
      if (note.imageUrls.isNotEmpty) {
        if (flutterContext.mounted) {
          ScaffoldMessenger.of(flutterContext).showSnackBar(
            SnackBar(content: Text(AppLocalizations.translate(flutterContext, 'pdfDownloadingImages'))),
          );
        }
        for (final url in note.imageUrls) {
          try {
            final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              pdfImages.add(pw.MemoryImage(response.bodyBytes));
            }
          } catch (e) {
            debugPrint("Lỗi tải ảnh đính kèm cho PDF: $e");
          }
        }
      }

      // Thêm trang vào tài liệu PDF
      doc.addPage(
        pw.MultiPage(
          theme: pdfTheme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Smart Note App',
                    style: pw.TextStyle(
                      color: PdfColors.blue700,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Cập nhật: ${DateFormat('dd/MM/yyyy HH:mm').format(note.updatedAt)}',
                    style: const pw.TextStyle(
                      color: PdfColors.grey500,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 16),

              // Tiêu đề note
              pw.Text(
                note.title.isNotEmpty ? note.title : AppLocalizations.translate(flutterContext, 'pdfUntitledNote'),
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 8),

              // Tags
              if (note.tags.isNotEmpty) ...[
                pw.Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: note.tags.map((tag) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        '#$tag',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    );
                  }).toList(),
                ),
                pw.SizedBox(height: 16),
              ],

              // Nội dung ghi chú (Checklist hoặc Văn bản Rich Text)
              if (note.isChecklist)
                _buildChecklistPdf(note)
              else
                _buildRichTextPdf(note),

              pw.SizedBox(height: 20),

              // Hình ảnh đính kèm (nếu có)
              if (pdfImages.isNotEmpty) ...[
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 12),
                pw.Text(
                  AppLocalizations.translate(flutterContext, 'pdfAttachedImages'),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: pdfImages.map((img) {
                    return pw.Container(
                      width: 230,
                      height: 170,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 1),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.ClipRect(
                        child: pw.Image(img, fit: pw.BoxFit.contain),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ];
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                AppLocalizations.translate(flutterContext, 'pdfPageCount')
                    .replaceAll('{page}', '${context.pageNumber}')
                    .replaceAll('{total}', '${context.pagesCount}'),
                style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
              ),
            );
          },
        ),
      );

      // Lưu tài liệu và mở popup chia sẻ/lưu
      final pdfBytes = await doc.save();
      final sanitizedTitle = note.title.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
      final filename = sanitizedTitle.isNotEmpty ? 'SmartNote_$sanitizedTitle.pdf' : 'SmartNote_${note.id}.pdf';

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: filename,
      );

      if (flutterContext.mounted) {
        ScaffoldMessenger.of(flutterContext).showSnackBar(
          SnackBar(content: Text(AppLocalizations.translate(flutterContext, 'pdfExportSuccess'))),
        );
      }
    } catch (e) {
      debugPrint("Lỗi xuất PDF: $e");
      if (flutterContext.mounted) {
        ScaffoldMessenger.of(flutterContext).showSnackBar(
          SnackBar(content: Text(AppLocalizations.translate(flutterContext, 'pdfExportError').replaceAll('{error}', '$e'))),
        );
      }
    }
  }

  /// Dựng widget Checklist trong PDF
  static pw.Widget _buildChecklistPdf(Note note) {
    try {
      final decoded = jsonDecode(note.content);
      final items = decoded['items'] as List? ?? [];
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items.map((i) {
          final bool checked = i['checked'] == true;
          final text = i['text'] as String? ?? '';
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 10,
                  height: 10,
                  margin: const pw.EdgeInsets.only(right: 8, top: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600, width: 1),
                    color: checked ? PdfColors.grey300 : null,
                  ),
                  alignment: pw.Alignment.center,
                  child: checked
                      ? pw.Text(
                          'x',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                pw.Expanded(
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: checked ? PdfColors.grey500 : PdfColors.grey800,
                      decoration: checked ? pw.TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } catch (_) {
      return pw.Text(note.plainTextContent, style: const pw.TextStyle(fontSize: 11));
    }
  }

  /// Dựng RichText (parse Quill Delta) trong PDF
  static pw.Widget _buildRichTextPdf(Note note) {
    try {
      final decoded = jsonDecode(note.content);
      if (decoded is List) {
        final List<pw.InlineSpan> spans = [];
        for (final item in decoded) {
          if (item is Map && item.containsKey('insert')) {
            final text = item['insert'];
            if (text is String) {
              final attrs = item['attributes'] as Map? ?? {};
              final bool bold = attrs['bold'] == true;
              final bool italic = attrs['italic'] == true;
              final bool underline = attrs['underline'] == true;
              final bool strike = attrs['strike'] == true;

              pw.TextDecoration? decoration;
              if (underline && strike) {
                decoration = pw.TextDecoration.combine([
                  pw.TextDecoration.underline,
                  pw.TextDecoration.lineThrough,
                ]);
              } else if (underline) {
                decoration = pw.TextDecoration.underline;
              } else if (strike) {
                decoration = pw.TextDecoration.lineThrough;
              }

              spans.add(
                pw.TextSpan(
                  text: text,
                  style: pw.TextStyle(
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
                    decoration: decoration,
                    fontSize: 11,
                    color: PdfColors.grey800,
                  ),
                ),
              );
            }
          }
        }

        return pw.RichText(
          text: pw.TextSpan(children: spans),
        );
      }
    } catch (_) {}

    return pw.Text(
      note.plainTextContent,
      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
    );
  }
}
