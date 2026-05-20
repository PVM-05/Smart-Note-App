// lib/screens/editor_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../providers/auth_provider.dart';

class EditorScreen extends StatefulWidget {
  final Note? note;

  const EditorScreen({super.key, this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String> _tags = []; // Quản lý danh sách tag của Note hiện tại

  // Các biến cố định cấu trúc Note phục vụ tính năng Auto-save
  late String _noteId;
  late DateTime _createdAt;
  late String _status;
  bool _hasBeenSavedInSession = false; // Đánh dấu để biết lúc nào addNote, lúc nào updateNote

  Timer? _autoSaveTimer; // Bộ đếm thời gian debounce để lưu ngầm

  static const _primary = Color(0xFF2E75B6);
  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    // Khởi tạo các giá trị cố định ngay từ đầu để tránh trùng lặp ghi chú khi tự động lưu
    _noteId = widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _createdAt = widget.note?.createdAt ?? DateTime.now();
    _status = widget.note?.status ?? 'normal';
    _hasBeenSavedInSession = widget.note != null;

    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tags = List.from(widget.note?.tags ?? []);

    // Đăng ký bộ lắng nghe thay đổi ký tự
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  // Khởi chạy đếm ngược 1000ms (1 giây) sau khi người dùng dừng nhập liệu để lưu ngầm
  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _saveNote();
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel(); // Hủy bộ đếm tránh rò rỉ bộ nhớ
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ── MỞ TRANG QUẢN LÝ NHÃN ──
  void _openLabelSelectionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LabelSelectionScreen(
          initialTags: _tags,
          onTagsChanged: (updatedTags) {
            setState(() {
              _tags = updatedTags;
            });
            _saveNote(); // Lưu ngay lập tức khi thay đổi nhãn dán
          },
        ),
      ),
    );
  }

  // ── HÀM TỰ ĐỘNG LƯU GHI CHÚ (Auto-save Core) ──
  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.userId ?? '';
    if (currentUserId.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);

    // Luật Google Keep: Nếu ghi chú trống rỗng hoàn toàn và chưa từng được tạo, không lưu gì cả
    if (title.isEmpty && content.isEmpty && _tags.isEmpty && !_hasBeenSavedInSession) {
      return;
    }

    final noteToSave = Note(
      id: _noteId,
      userId: currentUserId,
      title: title,
      content: content,
      tags: _tags,
      status: _status,
      isSynced: false,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );

    if (_hasBeenSavedInSession) {
      // Nếu đã được lưu ít nhất 1 lần trong phiên này -> Gọi lệnh cập nhật
      await provider.updateNote(noteToSave);
    } else {
      // Nếu là lần đầu tiên lưu mảnh ghi chú mới -> Gọi lệnh tạo mới
      await provider.addNote(noteToSave);
      _hasBeenSavedInSession = true; // Chuyển trạng thái sang chỉnh sửa cho các lần gõ kế tiếp
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _autoSaveTimer?.cancel(); // Ngắt auto save nếu thực hiện hành động xóa
      await Provider.of<NoteProvider>(context, listen: false).deleteNote(_noteId);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _togglePin() async {
    if (widget.note != null) {
      await Provider.of<NoteProvider>(context, listen: false).togglePin(widget.note!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Chặn đóng màn hình mặc định để xử lý việc lưu khẩn cấp trước khi thoát
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        _autoSaveTimer?.cancel(); // Hủy hẹn giờ lưu ngầm
        await _saveNote(); // Ép hệ thống thực hiện lưu dữ liệu cuối cùng lập tức

        if (context.mounted) {
          Navigator.pop(context); // Sau khi lưu xong thì đóng trang an toàn
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Chỉnh sửa' : 'Ghi chú mới'),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context), // Kích hoạt sự kiện PopScope để tự lưu
          ),
          actions: [
            if (_isEditing)
              IconButton(
                icon: Icon(_status == 'pinned' ? Icons.push_pin : Icons.push_pin_outlined),
                tooltip: _status == 'pinned' ? 'Bỏ ghim' : 'Ghim',
                onPressed: _togglePin,
              ),
            if (_isEditing)
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Xóa', onPressed: _delete),

            // XÓA BỎ NÚT CHỮ "LƯU" THỦ CÔNG CHUẨN GOOGLE KEEP STYLE
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                autofocus: !_isEditing,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Tiêu đề...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                  decoration: const InputDecoration(
                    hintText: 'Viết ghi chú...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),

              // ── HIỂN THỊ DANH SÁCH NHÃN ĐÃ CHỌN ──
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: _tags.map((tag) => ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      onPressed: _openLabelSelectionPage,
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Colors.grey.shade300),
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),

        // ── THANH CÔNG CỤ Ở DƯỚI CÙNG ──
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.label_outline, color: Colors.black54),
                      tooltip: 'Thêm nhãn',
                      onPressed: _openLabelSelectionPage,
                    ),
                  ],
                ),
                // if (_isEditing)
                //   Padding(
                //     padding: const EdgeInsets.only(right: 16),
                //     child: Text(
                //       'Sửa đổi ${_formatDate(widget.note!.updatedAt)}',
                //       style: const TextStyle(fontSize: 11, color: Colors.grey),
                //     ),
                //   ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// WIDGET TRANG QUẢN LÝ NHÃN (FULL SCREEN PAGE)
// ============================================================================
class _LabelSelectionScreen extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  const _LabelSelectionScreen({
    required this.initialTags,
    required this.onTagsChanged,
  });

  @override
  State<_LabelSelectionScreen> createState() => _LabelSelectionScreenState();
}

class _LabelSelectionScreenState extends State<_LabelSelectionScreen> {
  late List<String> _selectedTags;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NoteProvider>(context);
    final allLabels = provider.allLabels;

    final filteredLabels = allLabels
        .where((l) => l.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
        .toList();

    final isExactMatch = allLabels.any((l) => l.toLowerCase() == _searchQuery.trim().toLowerCase());
    final showCreateOption = _searchQuery.trim().isNotEmpty && !isExactMatch;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập tên nhãn',
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            )
                : null,
          ),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          onChanged: (val) {
            setState(() => _searchQuery = val);
          },
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                if (showCreateOption)
                  ListTile(
                    leading: const Icon(Icons.add, color: _primary),
                    title: Text(
                      'Tạo "${_searchQuery.trim()}"',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      final newTag = _searchQuery.trim();
                      provider.addLabel(newTag);

                      setState(() {
                        if (!_selectedTags.contains(newTag)) {
                          _selectedTags.add(newTag);
                        }
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      widget.onTagsChanged(_selectedTags);
                    },
                  ),

                ...filteredLabels.map((label) {
                  final isChecked = _selectedTags.contains(label);
                  return CheckboxListTile(
                    title: Text(label, style: const TextStyle(fontSize: 15)),
                    value: isChecked,
                    activeColor: _primary,
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    onChanged: (bool? val) {
                      setState(() {
                        if (val == true) {
                          _selectedTags.add(label);
                        } else {
                          _selectedTags.remove(label);
                        }
                      });
                      widget.onTagsChanged(_selectedTags);
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}