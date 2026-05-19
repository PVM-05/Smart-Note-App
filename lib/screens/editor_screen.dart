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
  List<String> _tags = []; // Quản lý danh sách tag ở local
  bool _hasChanges = false;

  static const _primary = Color(0xFF2E75B6);

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tags = List.from(widget.note?.tags ?? []); // Lấy danh sách tag từ note cũ nếu có

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  void _onChanged() {
    final changed = _isEditing
        ? (_titleController.text != widget.note!.title ||
        _contentController.text != widget.note!.content)
        : _titleController.text.isNotEmpty;

    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ── Bottom Sheet Thêm Nhãn (Google Keep Style) ──
  void _showTagBottomSheet() {
    final TextEditingController tagController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void addTag(String val) {
              final newTag = val.trim();
              if (newTag.isNotEmpty && !_tags.contains(newTag)) {
                setState(() {
                  _tags.add(newTag);
                  _hasChanges = true;
                });
                setModalState(() {});
                tagController.clear();
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16, left: 16, right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thêm nhãn',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Nhập tên nhãn...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, color: _primary),
                        onPressed: () => addTag(tagController.text),
                      ),
                      border: const UnderlineInputBorder(),
                    ),
                    onSubmitted: addTag,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags.map((tag) => InputChip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _tags.remove(tag);
                          _hasChanges = true;
                        });
                        setModalState(() {});
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: Colors.grey.shade300),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Lưu ghi chú ──
  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiêu đề không được để trống')),
      );
      return;
    }

    final provider = Provider.of<NoteProvider>(context, listen: false);

    if (_isEditing) {
      final updated = widget.note!.copyWith(
        title: title,
        content: _contentController.text.trim(),
        tags: _tags, // Truyền tags vào đây
        isSynced: false,
      );
      await provider.updateNote(updated);
    } else {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = auth.userId ?? '';

      if (currentUserId.isEmpty) return;

      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: currentUserId,
        title: title,
        content: _contentController.text.trim(),
        tags: _tags, // Truyền tags vào đây
        status: 'normal',
        isSynced: false,
      );
      await provider.addNote(newNote);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    // ... code cũ không đổi (có thể copy từ bản gốc nếu cần)
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
      await Provider.of<NoteProvider>(context, listen: false).deleteNote(widget.note!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _togglePin() async {
    await Provider.of<NoteProvider>(context, listen: false).togglePin(widget.note!);
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Thay đổi chưa được lưu sẽ bị mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tiếp tục sửa')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bỏ qua')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Chỉnh sửa' : 'Ghi chú mới'),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          actions: [
            if (_isEditing)
              IconButton(
                icon: Icon(widget.note!.status == 'pinned' ? Icons.push_pin : Icons.push_pin_outlined),
                tooltip: widget.note!.status == 'pinned' ? 'Bỏ ghim' : 'Ghim',
                onPressed: _togglePin,
              ),
            if (_isEditing)
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Xóa', onPressed: _delete),
            TextButton(
              onPressed: _hasChanges ? _save : null,
              child: Text(
                'Lưu',
                style: TextStyle(
                  color: _hasChanges ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold, fontSize: 16,
                ),
              ),
            ),
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

              // ── HIỂN THỊ DANH SÁCH NHÃN (Nếu có) ──
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    children: _tags.map((tag) => ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      onPressed: _showTagBottomSheet,
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),

        // ── THANH CÔNG CỤ DƯỚI CÙNG (Google Keep Style) ──
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
                      onPressed: _showTagBottomSheet,
                    ),
                  ],
                ),
                if (_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      'Sửa đổi ${_formatDate(widget.note!.updatedAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
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