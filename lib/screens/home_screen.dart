import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart'; // THÊM IMPORT NÀY
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';
import '../widgets/main_drawer.dart';
import '../widgets/profile_drawer.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (auth.isAuthenticated) {
        // 1. Kéo dữ liệu Profile (Tên, Ảnh đại diện) về trước
        await auth.reloadUserData();

        // 2. Sau đó mới ra lệnh kéo Note để không bị xung đột màn hình
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        await noteProvider.fetchNotes(auth.userId!);
        await noteProvider.fetchTrashNotes(auth.userId!);
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

  Future<void> _moveToTrashSelected(NoteProvider provider) async {
    final deletedIds = provider.selectedNoteIds.toList();
    final count = deletedIds.length;

    await provider.deleteSelectedNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển $count ghi chú vào thùng rác'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Huỷ',
            textColor: const Color(0xFF2E75B6),
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              for (final id in deletedIds) {
                await provider.restoreNote(id);
              }
            },
          ),
        ),
      );

      Timer(const Duration(seconds: 4), () {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final isSelectionMode = noteProvider.isSelectionMode;

        return Scaffold(
          drawer: const MainDrawer(currentRoute: '/home'),
          endDrawer: const ProfileDrawer(),

          appBar: isSelectionMode
              ? _selectionAppBar(noteProvider)
              : _normalAppBar(),

          body: _buildBody(noteProvider),

          floatingActionButton: AnimatedScale(
            scale: isSelectionMode ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: OpenContainer(
              transitionType: ContainerTransitionType.fade,
              transitionDuration: const Duration(milliseconds: 400),
              closedElevation: 6,
              openElevation: 0,
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // Bo góc cho giống Keep
              ),
              closedColor: _primary,
              openBuilder: (context, _) => const EditorScreen(note: null),
              onClosed: (_) async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (auth.isAuthenticated && auth.userId != null) {
                  await Provider.of<NoteProvider>(context, listen: false).fetchNotes(auth.userId!);
                }
              },
              closedBuilder: (context, openContainer) {
                return FloatingActionButton(
                  elevation: 0, // Elevation đã được OpenContainer quản lý
                  backgroundColor: Colors.transparent,
                  onPressed: () {
                    if (!isSelectionMode) openContainer();
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                );
              },
            ),
          ),
        );
      },
    );
  }

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
            if (noteProvider.pinnedNotes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Được ghim',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              ...noteProvider.pinnedNotes.map((note) => _buildNoteItem(note, noteProvider)),
            ],
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuint,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? _primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        // SỬ DỤNG OPENCONTAINER Ở ĐÂY
        child: OpenContainer(
          transitionType: ContainerTransitionType.fade,
          transitionDuration: const Duration(milliseconds: 400),
          closedElevation: 0,
          openElevation: 0,
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          closedColor: isSelected ? _primary.withOpacity(0.05) : Colors.white,
          middleColor: Colors.white,
          openColor: Theme.of(context).scaffoldBackgroundColor,
          // Màn hình mở ra
          openBuilder: (context, _) => EditorScreen(note: note),
          // Hàm chạy khi đóng (quay lại từ EditorScreen)
          onClosed: (_) async {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            if (auth.isAuthenticated && auth.userId != null) {
              await provider.fetchNotes(auth.userId!);
            }
          },
          // Card hiển thị khi đóng
          closedBuilder: (context, openContainer) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onLongPress: () => provider.toggleSelection(note.id),
                onTap: () {
                  if (isSelectionMode) {
                    provider.toggleSelection(note.id);
                  } else {
                    openContainer(); // Gọi hàm này để kích hoạt animation Mở
                  }
                },
                child: NoteCard(
                  note: note,
                  searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  AppBar _normalAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
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
      actions: [
        Consumer<AuthProvider>(
          builder: (context, auth, child) => Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                Scaffold.of(context).openEndDrawer();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2E75B6),
                  backgroundImage: (auth.userData?['photoUrl'] != null && auth.userData!['photoUrl'].toString().isNotEmpty)
                      ? NetworkImage(auth.userData!['photoUrl'])
                      : null,
                  child: (auth.userData?['photoUrl'] == null || auth.userData!['photoUrl'].toString().isEmpty)
                      ? Text(
                    auth.email?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
          tooltip: 'Chuyển vào thùng rác',
          onPressed: () => _moveToTrashSelected(provider),
        ),
      ],
    );
  }
}