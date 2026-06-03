import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/design/app_colors.dart';

enum DrawingTool {
  eraser,
  pen,
  marker,
  highlighter,
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

  @override
  void initState() {
    super.initState();
    // Default setup
    _updateDrawingController();
  }

  void _updateDrawingController() {
    switch (_selectedTool) {
      case DrawingTool.eraser:
        _drawingController.setPaintContent(Eraser());
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
        _drawingController.setStyle(color: _currentColor.withValues(alpha: 0.4), strokeWidth: _highlighterStrokeWidth);
        break;
    }
  }

  void _onToolSelected(DrawingTool tool) {
    if (_selectedTool == tool && tool != DrawingTool.eraser) {
      // Show color/thickness picker on second tap
      _showToolSettingsBottomSheet(tool);
    } else {
      setState(() {
        _selectedTool = tool;
        _updateDrawingController();
      });
    }
  }

  void _showToolSettingsBottomSheet(DrawingTool tool) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colors = [
              const Color(0xFF000000), // Black
              const Color(0xFFEF4444), // Red
              const Color(0xFF3B82F6), // Blue
              const Color(0xFF10B981), // Green
              const Color(0xFFF59E0B), // Yellow
            ];

            return Container(
              padding: const EdgeInsets.all(24),
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Độ dày nét vẽ',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: tool == DrawingTool.pen ? _penStrokeWidth : (tool == DrawingTool.marker ? _markerStrokeWidth : _highlighterStrokeWidth),
                    min: 2,
                    max: 40,
                    activeColor: _currentColor,
                    onChanged: (val) {
                      setSheetState(() {
                        if (tool == DrawingTool.pen) _penStrokeWidth = val;
                        else if (tool == DrawingTool.marker) _markerStrokeWidth = val;
                        else if (tool == DrawingTool.highlighter) _highlighterStrokeWidth = val;
                      });
                      setState(() {
                        _updateDrawingController();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Màu sắc',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: colors.map((c) {
                      final isSelected = _currentColor.value == c.value;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() => _currentColor = c);
                          setState(() {
                            _updateDrawingController();
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.grey.shade400, width: 3) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  )
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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.resolveNoteBackground(context, widget.noteColor) ?? AppColors.background(context);
    final appBarColor = AppColors.resolveNoteBackground(context, widget.noteColor) ?? AppColors.surface(context);
    final isCustomColor = widget.noteColor != null && widget.noteColor!.isNotEmpty;

    return PopScope(
      canPop: _isPopping,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final file = await _saveDrawing();
        if (mounted) {
          setState(() => _isPopping = true);
          Navigator.pop(context, file);
        }
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
              if (_isPopping) return;
              final file = await _saveDrawing();
              if (mounted) {
                setState(() => _isPopping = true);
                Navigator.pop(context, file);
              }
            },
          ),
          title: const SizedBox.shrink(), // No title
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
                        tooltip: 'Hoàn tác',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.redo,
                          color: _drawingController.canRedo() ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                        ),
                        onPressed: _drawingController.canRedo() ? () => _drawingController.redo() : null,
                        tooltip: 'Làm lại',
                      ),
                    ],
                  );
                },
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
          child: Column(
            children: [
              Expanded(
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
              _buildBottomToolbar(appBarColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(Color backgroundColor) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolIcon(DrawingTool.eraser, Icons.cleaning_services_outlined),
          _buildToolIcon(DrawingTool.pen, Icons.edit),
          _buildToolIcon(DrawingTool.marker, Icons.brush),
          _buildToolIcon(DrawingTool.highlighter, Icons.border_color),
        ],
      ),
    );
  }

  Widget _buildToolIcon(DrawingTool tool, IconData icon) {
    final isSelected = _selectedTool == tool;
    final color = isSelected && tool != DrawingTool.eraser ? _currentColor : (isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B));
    
    return GestureDetector(
      onTap: () => _onToolSelected(tool),
      child: Container(
        width: 50,
        height: 50,
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
              size: 26,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
          ],
        ),
      ),
    );
  }
}
