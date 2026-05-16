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
  bool _showSearch = false;
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

  // ── XỬ LÝ TÌM KIẾM ──
  void _openSearch() {
    setState(() => _showSearch = true);
    Future.delayed(
      const Duration(milliseconds: 100),
          () => _searchFocus.requestFocus(),
    );
  }

  void _closeSearch() {
    setState(() => _showSearch = false);
    _searchController.clear();
    Provider.of<NoteProvider>(context, listen: false).clearSearch();
  }

  void _onSearchChanged(String query) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Provider.of<NoteProvider>(context, listen: false)
        .search(query, auth.userId ?? '');
  }

  // ── XÓA NHIỀU GHI CHÚ ──
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
          // 1. CHUYỂN MẠCH APPBAR TÙY TRẠNG THÁI
          appBar: isSelectionMode
              ? _selectionAppBar(noteProvider)
              : (_showSearch ? _searchAppBar() : _normalAppBar()),

          body: _buildBody(noteProvider),

          // 2. ẨN NÚT TẠO MỚI KHI ĐANG TÌM KIẾM HOẶC CHỌN NHIỀU
          floatingActionButton: (_showSearch || isSelectionMode)
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

  // ── PHẦN THÂN (BODY) ──
  Widget _buildBody(NoteProvider noteProvider) {
    // Loading
    if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Không có kết quả search
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

    // Danh sách rỗng
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
          // Kết quả search — hiện flat list không phân nhóm
          if (noteProvider.isSearching) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${noteProvider.notes.length} kết quả',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            ...noteProvider.notes.map((note) => _buildNoteItem(note, noteProvider)),
          ] else ...[
            // Ghi chú ghim
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

            // Ghi chú bình thường
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

  // ── WIDGET BAO BỌC NOTECARD ĐỂ XỬ LÝ CHỌN (MULTI-SELECT) ──
  Widget _buildNoteItem(Note note, NoteProvider provider) {
    final isSelected = provider.selectedNoteIds.contains(note.id);
    final isSelectionMode = provider.isSelectionMode;

    return GestureDetector(
      // BẤM GIỮ: Kích hoạt chế độ chọn nhiều
      onLongPress: () {
        provider.toggleSelection(note.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          // Hiển thị viền và nền màu xanh nhạt nếu đang được chọn
          border: Border.all(
            color: isSelected ? _primary : Colors.transparent,
            width: 2,
          ),
          color: isSelected ? _primary.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: NoteCard(
          note: note,
          searchQuery: _showSearch ? _searchController.text : null,
          // BẤM CHẠM:
          onTap: () {
            if (isSelectionMode) {
              // Đang ở chế độ chọn -> tích thêm hoặc bỏ tích
              provider.toggleSelection(note.id);
            } else {
              // Bình thường -> Mở Note ra sửa
              _openEditor(note);
            }
          },
        ),
      ),
    );
  }

  // ── 1. AppBar Bình thường ──
  AppBar _normalAppBar() {
    return AppBar(
      title: const Text('Smart Note'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Tìm kiếm',
          onPressed: _openSearch,
        ),
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
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20),
                    const SizedBox(width: 8),
                    Text('Đăng xuất (${auth.email ?? ''})'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 2. AppBar Search Mode ──
  AppBar _searchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Tìm kiếm ghi chú...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey),
        ),
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
              _searchFocus.requestFocus();
            },
          ),
      ],
    );
  }

  // ── 3. AppBar Selection Mode ──
  AppBar _selectionAppBar(NoteProvider provider) {
    return AppBar(
      backgroundColor: const Color(0xFFE2E8F0), // Đổi màu nền để user nhận biết
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