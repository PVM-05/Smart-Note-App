import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<NoteProvider>(context, listen: false)
            .fetchNotes(auth.userId!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Provider.of<NoteProvider>(context, listen: false)
        .search(query, auth.userId ?? '');
    setState(() {}); // Rebuild để cập nhật sự ẩn/hiện của nút xóa nhanh (X)
  }

  Future<void> _confirmDeleteSelected(NoteProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: Text(
            'Bạn có chắc muốn xóa ${provider.selectedNoteIds.length} ghi chú đã chọn?'),
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

    if (confirm == true) {
      await provider.deleteSelectedNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final isSelectionMode = noteProvider.isSelectionMode;

        return Scaffold(
          // Tự động hoán đổi giữa AppBar lựa chọn hàng loạt và AppBar thiết kế mới
          appBar: isSelectionMode
              ? _selectionAppBar(noteProvider)
              : _normalAppBar(),

          body: _buildBody(noteProvider),

          // Ẩn nút tạo mới khi đang chọn nhiều mục để tránh bấm nhầm
          floatingActionButton: isSelectionMode
              ? null
              : FloatingActionButton(
            onPressed: () => _openEditor(null),
            backgroundColor: _primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // ── PHẦN THÂN HIỂN THỊ (BODY) ──
  Widget _buildBody(NoteProvider noteProvider) {
    if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (noteProvider.isSearching && noteProvider.notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy ghi chú nào',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (noteProvider.notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Chưa có ghi chú nào. Hãy nhấn + để thêm!'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await noteProvider.fetchNotes(auth.userId!);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          if (noteProvider.isSearching) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${noteProvider.notes.length} kết quả tìm thấy',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            ...noteProvider.notes.map((note) => _buildNoteItem(note, noteProvider)),
          ] else ...[
            // Nhóm ghi chú được ghim
            if (noteProvider.pinnedNotes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '📌 GHI CHÚ GHIM',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              ...noteProvider.pinnedNotes.map((note) => _buildNoteItem(note, noteProvider)),
            ],

            // Nhóm ghi chú thông thường
            if (noteProvider.normalNotes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Tất cả ghi chú',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
              ...noteProvider.normalNotes.map((note) => _buildNoteItem(note, noteProvider)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNoteItem(Note note, NoteProvider provider) {
    final isSelected = provider.selectedNoteIds.contains(note.id);
    final isSelectionMode = provider.isSelectionMode;

    return GestureDetector(
      onLongPress: () {
        provider.toggleSelection(note.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? _primary : Colors.transparent,
            width: 2,
          ),
          color: isSelected ? _primary.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: NoteCard(
          note: note,
          searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
          onTap: () {
            if (isSelectionMode) {
              provider.toggleSelection(note.id);
            } else {
              _openEditor(note);
            }
          },
        ),
      ),
    );
  }

  // ── APP BAR THEO THIẾT KẾ MỚI (CỦA BẠN YÊU CẦU) ──
  // ── APP BAR THEO THIẾT KẾ MỚI ──
  AppBar _normalAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,

      // 1. GÓC TRÁI: Menu 3 chấm (Thùng rác, Cài đặt)
      leading: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.black87), // Dấu 3 chấm dọc
        tooltip: 'Menu',
        offset: const Offset(0, 40), // Đẩy menu đổ xuống dưới icon một chút
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          if (value == 'trash') {
            // TODO: Màn hình thùng rác
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng Thùng rác đang được phát triển')),
            );
          } else if (value == 'settings') {
            // TODO: Màn hình cài đặt
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng Cài đặt đang được phát triển')),
            );
          }
        },
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
            value: 'trash',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.black87, size: 20),
                SizedBox(width: 12),
                Text('Thùng rác'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings_outlined, color: Colors.black87, size: 20),
                SizedBox(width: 12),
                Text('Cài đặt'),
              ],
            ),
          ),
        ],
      ),

      // 2. CHÍNH GIỮ: Ô Tìm Kiếm (Search Box) tinh gọn
      title: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm ghi chú...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ),
      centerTitle: true,

      // 3. GÓC PHẢI: Hình đại diện Account phục vụ đăng xuất
      actions: [
        Consumer<AuthProvider>(
          builder: (context, auth, child) => PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Đăng xuất',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
            // Widget hiển thị bọc ngoài Account Hình tròn
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: _primary,
                child: Text(
                  auth.email?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── APP BAR KHI CHỌN MULTI-SELECT ──
  AppBar _selectionAppBar(NoteProvider provider) {
    return AppBar(
      backgroundColor: const Color(0xFFE2E8F0),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black87),
        tooltip: 'Hủy chọn',
        onPressed: () => provider.clearSelection(),
      ),
      title: Text(
        '${provider.selectedNoteIds.length} đã chọn',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.push_pin_outlined, color: Colors.black87),
          tooltip: 'Ghim/Bỏ ghim hàng loạt',
          onPressed: () => provider.togglePinSelectedNotes(),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Xóa hàng loạt',
          onPressed: () => _confirmDeleteSelected(provider),
        ),
      ],
    );
  }

  void _openEditor(Note? note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
    );
  }
}