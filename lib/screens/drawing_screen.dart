import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../core/design/app_colors.dart';
import '../core/app_localizations.dart';
import '../core/drawing/arrow_content.dart';

enum DrawingTool {
  eraser,
  pen,
  marker,
  highlighter,
  straightLine,
  arrow,
  rectangle,
  circle,
}

enum PaperStyle {
  plain,
  ruled,
  grid,
}

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
  bool _isPopping = false;

  DrawingTool _selectedTool = DrawingTool.pen;
  Color _currentColor = const Color(0xFFEF4444); // Default to Red like screenshot
  
  double _penStrokeWidth = 4.0;
  double _markerStrokeWidth = 12.0;
  double _highlighterStrokeWidth = 24.0;
  double _eraserStrokeWidth = 15.0;

  File? _backgroundImageFile;
  PaperStyle _selectedPaperStyle = PaperStyle.plain;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _updateDrawingController();
  }

  void _updateDrawingController() {
    switch (_selectedTool) {
      case DrawingTool.eraser:
        _drawingController.setPaintContent(Eraser());
        _drawingController.setStyle(color: Colors.transparent, strokeWidth: _eraserStrokeWidth);
        break;
      case DrawingTool.pen:
        _drawingController.setPaintContent(SimpleLine());
        _drawingController.setStyle(color: _currentColor, strokeWidth: _penStrokeWidth);
        break;
      case DrawingTool.marker:
        _drawingController.setPaintContent(SimpleLine());
        _drawingController.setStyle(color: _currentColor, strokeWidth: _markerStrokeWidth);
        break;
      case DrawingTool.highlighter:
        _drawingController.setPaintContent(SimpleLine());
        _drawingController.setStyle(
          color: _currentColor.withValues(alpha: 0.4),
          strokeWidth: _highlighterStrokeWidth,
        );
        break;
      case DrawingTool.straightLine:
        _drawingController.setPaintContent(StraightLine());
        _drawingController.setStyle(color: _currentColor, strokeWidth: _penStrokeWidth);
        break;
      case DrawingTool.arrow:
        _drawingController.setPaintContent(Arrow());
        _drawingController.setStyle(color: _currentColor, strokeWidth: _penStrokeWidth);
        break;
      case DrawingTool.rectangle:
        _drawingController.setPaintContent(Rectangle());
        _drawingController.setStyle(color: _currentColor, strokeWidth: _penStrokeWidth);
        break;
      case DrawingTool.circle:
        _drawingController.setPaintContent(Circle());
        _drawingController.setStyle(color: _currentColor, strokeWidth: _penStrokeWidth);
        break;
    }
  }

  void _onToolSelected(DrawingTool tool) {
    if (_selectedTool == tool) {
      // Show color/thickness picker on second tap
      _showToolSettingsBottomSheet(tool);
    } else {
      setState(() {
        _selectedTool = tool;
        _updateDrawingController();
      });
    }
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _backgroundImageFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.translate(context, 'drawingBackgroundError').replaceAll('{error}', '$e'))),
        );
      }
    }
  }

  void _showColorPickerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = _currentColor;
        return AlertDialog(
          title: Text(
            AppLocalizations.translate(context, 'selectColorWheel'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (Color color) {
                tempColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.translate(context, 'cancel'),
                style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentColor = tempColor;
                  _updateDrawingController();
                });
                Navigator.pop(context);
              },
              child: Text(
                AppLocalizations.translate(context, 'select'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showToolSettingsBottomSheet(DrawingTool tool) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colors = [
              const Color(0xFF000000), // Black
              const Color(0xFF475569), // Dark Grey
              const Color(0xFF94A3B8), // Light Grey
              const Color(0xFFEF4444), // Red
              const Color(0xFFF43F5E), // Pink
              const Color(0xFFEC4899), // Hot Pink
              const Color(0xFF8B5CF6), // Purple
              const Color(0xFF3B82F6), // Blue
              const Color(0xFF0EA5E9), // Light Blue
              const Color(0xFF14B8A6), // Teal
              const Color(0xFF10B981), // Green
              const Color(0xFF22C55E), // Light Green
              const Color(0xFFEAB308), // Yellow
              const Color(0xFFF97316), // Orange
              const Color(0xFFD97706), // Brown
            ];

            final isEraser = tool == DrawingTool.eraser;
            double currentStrokeWidth = 4.0;
            if (tool == DrawingTool.pen ||
                tool == DrawingTool.straightLine ||
                tool == DrawingTool.arrow ||
                tool == DrawingTool.rectangle ||
                tool == DrawingTool.circle) {
              currentStrokeWidth = _penStrokeWidth;
            } else if (tool == DrawingTool.marker) {
              currentStrokeWidth = _markerStrokeWidth;
            } else if (tool == DrawingTool.highlighter) {
              currentStrokeWidth = _highlighterStrokeWidth;
            } else if (tool == DrawingTool.eraser) {
              currentStrokeWidth = _eraserStrokeWidth;
            }

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.translate(context, 'thickness').replaceAll('{val}', '${currentStrokeWidth.round()}'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Container(
                          width: currentStrokeWidth,
                          height: currentStrokeWidth,
                          decoration: BoxDecoration(
                            color: isEraser ? Colors.grey : _currentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: currentStrokeWidth,
                    min: 2,
                    max: tool == DrawingTool.highlighter ? 65 : 40,
                    activeColor: isEraser ? Colors.grey : _currentColor,
                    inactiveColor: (isEraser ? Colors.grey : _currentColor).withValues(alpha: 0.2),
                    onChanged: (val) {
                      setSheetState(() {
                        if (tool == DrawingTool.pen ||
                            tool == DrawingTool.straightLine ||
                            tool == DrawingTool.arrow ||
                            tool == DrawingTool.rectangle ||
                            tool == DrawingTool.circle) {
                          _penStrokeWidth = val;
                        } else if (tool == DrawingTool.marker) {
                          _markerStrokeWidth = val;
                        } else if (tool == DrawingTool.highlighter) {
                          _highlighterStrokeWidth = val;
                        } else if (tool == DrawingTool.eraser) {
                          _eraserStrokeWidth = val;
                        }
                      });
                      setState(() {
                        _updateDrawingController();
                      });
                    },
                  ),
                  if (!isEraser) ...[
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.translate(context, 'colorPalette'),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.start,
                      children: [
                        ...colors.map((c) {
                          final isSelected = _currentColor.toARGB32() == c.toARGB32();
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() => _currentColor = c);
                              setState(() {
                                _updateDrawingController();
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: AppColors.textPrimary(context), width: 3)
                                    : Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: c.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _showColorPickerDialog();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.amber,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.purple,
                                  Colors.red,
                                ],
                              ),
                            ),
                            child: const Icon(Icons.colorize, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _drawingController.dispose();
    super.dispose();
  }

  Future<File?> _saveDrawing() async {
    if (!mounted) return null;
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

      return file;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu bản vẽ: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    final bool hasChanges = _drawingController.canUndo() || _backgroundImageFile != null;
    if (!hasChanges) {
      if (mounted) {
        Navigator.pop(context, null);
      }
      return false;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.translate(context, 'drawingSaveConfirmTitle'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(AppLocalizations.translate(context, 'drawingSaveConfirmDesc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(
              AppLocalizations.translate(context, 'discardExit'),
              style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: Text(
              AppLocalizations.translate(context, 'keepDrawing'),
              style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(
              AppLocalizations.translate(context, 'saveDrawing'),
              style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return false;

    if (result == 'save') {
      final file = await _saveDrawing();
      if (mounted) {
        Navigator.pop(context, file);
      }
      return false;
    } else if (result == 'cancel') {
      if (mounted) {
        Navigator.pop(context, null);
      }
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.resolveNoteBackground(context, widget.noteColor) ?? AppColors.background(context);
    final appBarColor = AppColors.resolveNoteBackground(context, widget.noteColor) ?? AppColors.surface(context);

    return PopScope(
      canPop: _isPopping,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
            onPressed: () async {
              await _onWillPop();
            },
          ),
          title: const SizedBox.shrink(),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF64748B)),
              onPressed: _pickBackgroundImage,
              tooltip: AppLocalizations.translate(context, 'insertBackgroundImage'),
            ),
            PopupMenuButton<PaperStyle>(
              icon: const Icon(Icons.layers_outlined, color: Color(0xFF64748B)),
              tooltip: AppLocalizations.translate(context, 'paperTemplateStyle'),
              onSelected: (PaperStyle style) {
                setState(() {
                  _selectedPaperStyle = style;
                });
              },
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem(
                    value: PaperStyle.plain,
                    child: Row(
                      children: [
                        const Icon(Icons.crop_free, size: 20),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.translate(context, 'paperPlain')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: PaperStyle.ruled,
                    child: Row(
                      children: [
                        const Icon(Icons.notes, size: 20),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.translate(context, 'paperRuled')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: PaperStyle.grid,
                    child: Row(
                      children: [
                        const Icon(Icons.grid_on, size: 20),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.translate(context, 'paperGrid')),
                      ],
                    ),
                  ),
                ];
              },
            ),
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
            else ...[
              ListenableBuilder(
                listenable: _drawingController,
                builder: (context, _) {
                  return Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.undo,
                          color: _drawingController.canUndo() ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                        ),
                        onPressed: _drawingController.canUndo() ? () => _drawingController.undo() : null,
                        tooltip: AppLocalizations.translate(context, 'undoTooltip'),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.redo,
                          color: _drawingController.canRedo() ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                        ),
                        onPressed: _drawingController.canRedo() ? () => _drawingController.redo() : null,
                        tooltip: AppLocalizations.translate(context, 'redoTooltip'),
                      ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.check, color: AppColors.primary),
                onPressed: () async {
                  if (_isSaving) return;
                  final navigator = Navigator.of(context);
                  final file = await _saveDrawing();
                  if (mounted) {
                    setState(() => _isPopping = true);
                    navigator.pop(file);
                  }
                },
                tooltip: AppLocalizations.translate(context, 'saveDrawing'),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                onSelected: (value) {
                  if (value == 'clear') {
                    _drawingController.clear();
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Xóa toàn bộ bản vẽ', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final lineColor = Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.blue.withValues(alpha: 0.08);

                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: DrawingBoard(
                        controller: _drawingController,
                        background: CustomPaint(
                          painter: PaperBackgroundPainter(
                            style: _selectedPaperStyle,
                            backgroundColor: backgroundColor,
                            lineColor: lineColor,
                          ),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: _backgroundImageFile != null
                                ? Image.file(_backgroundImageFile!, fit: BoxFit.contain)
                                : (widget.initialImageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: widget.initialImageUrl!,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      )
                                    : null),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildFloatingToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface(context).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.textPrimary(context).withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToolIcon(DrawingTool.eraser, Icons.cleaning_services_outlined, "Tẩy"),
                    const SizedBox(width: 8),
                    _buildToolIcon(DrawingTool.pen, Icons.edit, "Bút"),
                    const SizedBox(width: 8),
                    _buildToolIcon(DrawingTool.marker, Icons.brush, "Marker"),
                    const SizedBox(width: 8),
                    _buildToolIcon(DrawingTool.highlighter, Icons.border_color, "Dạ quang"),
                    const SizedBox(width: 8),
                    _buildToolIcon(DrawingTool.straightLine, Icons.linear_scale, "Đoạn thẳng"),
                    const SizedBox(width: 8),
                    _buildToolIcon(DrawingTool.arrow, Icons.trending_flat, "Mũi tên"),
                    const SizedBox(width: 8),
                    _buildToolIcon(DrawingTool.rectangle, Icons.crop_square, "Chữ nhật"),
                    const SizedBox(width: 8),
                    _buildToolIcon(DrawingTool.circle, Icons.radio_button_unchecked, "Tròn"),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolIcon(DrawingTool tool, IconData icon, String tooltip) {
    final isSelected = _selectedTool == tool;
    final color = isSelected && tool != DrawingTool.eraser ? _currentColor : (isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B));
    
    return GestureDetector(
      onTap: () => _onToolSelected(tool),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  height: 3,
                  width: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}

class PaperBackgroundPainter extends CustomPainter {
  final PaperStyle style;
  final Color backgroundColor;
  final Color lineColor;

  PaperBackgroundPainter({
    required this.style,
    required this.backgroundColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    if (style == PaperStyle.plain) return;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    const double spacing = 28.0;

    if (style == PaperStyle.ruled) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else if (style == PaperStyle.grid) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaperBackgroundPainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.lineColor != lineColor;
  }
}
