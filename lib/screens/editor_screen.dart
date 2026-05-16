import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../providers/auth_provider.dart';

class EditorScreen extends StatefulWidget {
  final Note? note; // null = tạo mới, có giá trị = chỉnh sửa

  const EditorScreen({super.key, this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasChanges = false;

  static const _primary = Color(0xFF2E75B6);

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController   = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');

    // Theo dõi thay đổi để bật/tắt nút lưu
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

  // ── Lưu ghi chú ──
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
        title:   title,
        content: _contentController.text.trim(),
        isSynced: false,
      );
      await provider.updateNote(updated);
    } else {
      // 1. Lấy thông tin tài khoản đang hoạt động từ AuthProvider
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = auth.userId ?? '';

      // Phòng trường hợp hy hữu session bị mất đột ngột
      if (currentUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Phiên đăng nhập hết hạn. Vui lòng thử lại.')),
        );
        return;
      }

      // 2. Đóng gói dữ liệu với đầy đủ thông tin chủ sở hữu
      final newNote = Note(
        id:      DateTime.now().millisecondsSinceEpoch.toString(),
        userId:  currentUserId, // Vá lỗ hổng userId bị rỗng tại đây
        title:   title,
        content: _contentController.text.trim(),
        status:  'normal',
        isSynced: false,
      );
      await provider.addNote(newNote);
    }

    if (mounted) Navigator.pop(context);
  }

  // ── Xóa ghi chú (chỉ khi đang edit) ──
  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Provider.of<NoteProvider>(context, listen: false)
          .deleteNote(widget.note!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Pin/Unpin (chỉ khi đang edit) ──
  Future<void> _togglePin() async {
    await Provider.of<NoteProvider>(context, listen: false)
        .togglePin(widget.note!);
    if (mounted) Navigator.pop(context); // quay về HomeScreen sau khi pin
  }

  // ── Hỏi trước khi thoát nếu có thay đổi chưa lưu ──
  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Thay đổi chưa được lưu sẽ bị mất.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục sửa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ qua'),
          ),
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
            // Nút pin (chỉ hiện khi đang edit)
            if (_isEditing)
              IconButton(
                icon: Icon(
                  widget.note!.status == 'pinned'
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                ),
                tooltip: widget.note!.status == 'pinned' ? 'Bỏ ghim' : 'Ghim',
                onPressed: _togglePin,
              ),

            // Nút xóa (chỉ hiện khi đang edit)
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Xóa',
                onPressed: _delete,
              ),

            // Nút lưu
            TextButton(
              onPressed: _hasChanges ? _save : null,
              child: Text(
                'Lưu',
                style: TextStyle(
                  color: _hasChanges ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Tiêu đề
              TextField(
                controller: _titleController,
                autofocus: !_isEditing,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tiêu đề...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null, // tự xuống dòng nếu dài
              ),

              const Divider(height: 1),
              const SizedBox(height: 8),

              // Nội dung — chiếm phần còn lại của màn hình
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
            ],
          ),
        ),

        // Thanh dưới hiển thị metadata khi đang edit
        bottomNavigationBar: _isEditing
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Text(
            'Cập nhật lúc ${_formatDate(widget.note!.updatedAt)}  •  '
                '${widget.note!.isSynced ? "☁️ Đã đồng bộ" : "⏳ Chờ đồng bộ"}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        )
            : null,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}