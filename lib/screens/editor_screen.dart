// lib/screens/editor_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

class EditorScreen extends StatefulWidget {
  final Note? note;

  const EditorScreen({super.key, this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String> _tags = [];

  late String _noteId;
  late DateTime _createdAt;
  late String _status;

  // Kiểm soát trạng thái ghi chú đã tồn tại thực sự dưới database hay chưa
  bool _hasBeenSavedInDb = false;

  Timer? _autoSaveTimer;

  static const _primary = Color(0xFF2E75B6);
  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _noteId = widget.note?.id ?? const Uuid().v4();
    _createdAt = widget.note?.createdAt ?? DateTime.now();
    _status = widget.note?.status ?? 'normal';

    // Nếu truyền vào một note khác null, nghĩa là note này ĐÃ TỒN TẠI dưới DB từ trước
    _hasBeenSavedInDb = widget.note != null;

    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tags = List.from(widget.note?.tags ?? []);

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _saveNote(isAutosave: true);
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

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
            _saveNote(isAutosave: false); // Chọn nhãn xong -> Lưu hoặc kiểm tra tạo ngay
          },
        ),
      ),
    );
  }

  // ── CORE AUTO-SAVE LUẬT GOOGLE KEEP ──
  Future<void> _saveNote({required bool isAutosave}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.userId ?? '';
    if (currentUserId.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);

    // CHUẨN GOOGLE KEEP LOGIC:
    // Nếu tất cả đều trống và ghi chú chưa từng được tạo thực sự ở DB -> KHÔNG LÀM GÌ CẢ
    if (title.isEmpty && content.isEmpty && _tags.isEmpty && !_hasBeenSavedInDb) {
      return;
    }

    // Nếu người dùng xóa sạch dữ liệu của một ghi chú ĐÃ TỒN TẠI dưới DB:
    if (title.isEmpty && content.isEmpty && _tags.isEmpty && _hasBeenSavedInDb) {
      // Nếu thoát trang bằng nút Back hành động thủ công, ta dọn dẹp xóa luôn bản ghi rỗng này dưới DB
      if (!isAutosave) {
        _autoSaveTimer?.cancel();
        await provider.deleteNote(_noteId);
        _hasBeenSavedInDb = false;
      }
      return;
    }

    // Khởi tạo thực thể Note hiện tại
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

    if (_hasBeenSavedInDb) {
      // Đã có trong DB -> Chỉ cập nhật biến động dữ liệu
      await provider.updateNote(noteToSave);
    } else {
      // Có dữ liệu thực sự lần đầu tiên -> INSERT mới vào cơ sở dữ liệu cục bộ
      await provider.addNote(noteToSave);
      _hasBeenSavedInDb = true; // Đóng băng trạng thái, chuyển sang chế độ Update
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
      _autoSaveTimer?.cancel();
      if (_hasBeenSavedInDb) {
        await Provider.of<NoteProvider>(context, listen: false).deleteNote(_noteId);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _togglePin() async {
    if (_hasBeenSavedInDb && widget.note != null) {
      await Provider.of<NoteProvider>(context, listen: false).togglePin(widget.note!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        _autoSaveTimer?.cancel();
        // Gọi hàm xử lý với isAutosave = false để thực hiện dọn dẹp ghi chú rỗng khẩn cấp
        await _saveNote(isAutosave: false);

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // title: Text(_isEditing ? 'Chỉnh sửa' : 'Ghi chú mới'),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_hasBeenSavedInDb)
              IconButton(
                icon: Icon(_status == 'pinned' ? Icons.push_pin : Icons.push_pin_outlined),
                tooltip: _status == 'pinned' ? 'Bỏ ghim' : 'Ghim',
                onPressed: _togglePin,
              ),
            if (_hasBeenSavedInDb)
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Xóa', onPressed: _delete),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET TRANG QUẢN LÝ NHÃN (Giữ nguyên cấu trúc của bạn)
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