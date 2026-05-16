import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../providers/sync_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';
import '../widgets/main_drawer.dart';
import 'login_screen.dart';
import '../repositories/sync_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  // Layout State
  bool _isGrid = true;
  double _turns = 0.0;

  // Premium Colors
  static const _primary = Color(0xFF2E75B6);
  static const _navy = Color(0xFF0D1B2A);
  static const _bgGray = Color(0xFFF5F5F7);
  static const _textGray = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        await noteProvider.fetchNotes(auth.userId!);
        if (!context.mounted) return;
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
    setState(() {});
  }

  // Effect: Rotate icon & Switch layout
  void _toggleLayout() {
    setState(() {
      _isGrid = !_isGrid;
      _turns += 0.5; // Xoay 180 độ
    });
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Huỷ',
            textColor: _primary,
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
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final isSelectionMode = noteProvider.isSelectionMode;

        return Scaffold(
          backgroundColor: Colors.white,
          drawer: const MainDrawer(currentRoute: '/home'),
          appBar: isSelectionMode
              ? _selectionAppBar(noteProvider)
              : _premiumHeader(),
          body: _buildBody(noteProvider),
          floatingActionButton: isSelectionMode
              ? null
              : FloatingActionButton(
                  onPressed: () => _openEditor(null),
                  backgroundColor: _primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
        );
      },
    );
  }

  // ── 1. PREMIUM BRAND HEADER ROW ──
  PreferredSizeWidget _premiumHeader() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userLetter = auth.email?.substring(0, 1).toUpperCase() ?? 'T';

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 20,
      automaticallyImplyLeading: false,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: _navy),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text(
        'Smart Note',
        style: TextStyle(
          color: _navy,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        // Sync Icon
        Consumer<SyncProvider>(
          builder: (context, syncProvider, child) {
            IconData icon = Icons.cloud_queue_rounded;
            Color iconColor = _navy;
            if (syncProvider.status == SyncStatus.syncing) {
              icon = Icons.cloud_sync_rounded;
              iconColor = _primary;
            } else if (syncProvider.status == SyncStatus.error) {
              icon = Icons.cloud_off_rounded;
              iconColor = Colors.red;
            } else if (syncProvider.status == SyncStatus.success) {
              icon = Icons.cloud_done_rounded;
              iconColor = Colors.green;
            }
            return IconButton(
              icon: Icon(icon, color: iconColor, size: 26),
              onPressed: () => syncProvider.syncNow(),
            );
          },
        ),
        const SizedBox(width: 8),

        // Grid/List Toggle with Rotation Animation
        AnimatedRotation(
          turns: _turns,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          child: IconButton(
            icon: Icon(
              _isGrid ? Icons.grid_view_rounded : Icons.view_agenda_rounded,
              color: _navy,
              size: 24,
            ),
            onPressed: _toggleLayout,
          ),
        ),
        const SizedBox(width: 8),

        // Circular Avatar
        PopupMenuButton<String>(
          offset: const Offset(0, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) async {
            if (value == 'logout') {
              final userId = auth.userId;
              await auth.signOut();
              if (context.mounted && userId != null) {
                if (!context.mounted) return;
                final np = Provider.of<NoteProvider>(context, listen: false);
                await np.clearLocalData(userId);
                if (!context.mounted) return;
                np.clearNotes();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Đăng xuất', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF007AFF), // Bright blue
              child: Text(
                userLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── APP BAR MULTI-SELECT ──
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
            color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
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

  // ── BODY ──
  Widget _buildBody(NoteProvider noteProvider) {
    if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await noteProvider.fetchNotes(auth.userId!);
      },
      color: _primary,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. SEARCH BAR ROW
            _buildSearchBar(),
            const SizedBox(height: 24),

            if (noteProvider.isSearching && noteProvider.notes.isEmpty) ...[
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Không tìm thấy ghi chú nào',
                        style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              )
            ] else if (noteProvider.notes.isEmpty) ...[
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.note_add_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    const Text('Chưa có ghi chú nào. Hãy nhấn + để thêm!'),
                  ],
                ),
              )
            ] else ...[
              // 3. CATEGORY LABEL & NOTES
              if (noteProvider.isSearching) ...[
                _buildCategoryLabel(
                    '${noteProvider.notes.length} KẾT QUẢ TÌM KIẾM'),
                _buildAnimatedLayout(noteProvider.notes, noteProvider),
              ] else ...[
                if (noteProvider.pinnedNotes.isNotEmpty) ...[
                  _buildCategoryLabel('📌 ĐƯỢC GHIM'),
                  _buildAnimatedLayout(noteProvider.pinnedNotes, noteProvider),
                  const SizedBox(height: 24),
                ],
                if (noteProvider.normalNotes.isNotEmpty) ...[
                  _buildCategoryLabel('TẤT CẢ GHI CHÚ'),
                  _buildAnimatedLayout(noteProvider.normalNotes, noteProvider),
                ],
              ],
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ── COMPONENTS ──
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _bgGray,
          borderRadius: BorderRadius.circular(26), // Bo góc mượt mà
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm ghi chú của bạn...',
            hintStyle: const TextStyle(color: _textGray, fontSize: 15),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12.0),
              child: Icon(Icons.search_rounded, size: 22, color: _textGray),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded,
                        size: 20, color: _textGray),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          style: const TextStyle(fontSize: 15, color: _navy),
        ),
      ),
    );
  }

  Widget _buildCategoryLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: _textGray,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ── ANIMATED LAYOUT ──
  Widget _buildAnimatedLayout(List<Note> notes, NoteProvider provider) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _isGrid
          ? _buildGridView(notes, provider, key: const ValueKey('grid'))
          : _buildListView(notes, provider, key: const ValueKey('list')),
    );
  }

  Widget _buildGridView(List<Note> notes, NoteProvider provider, {Key? key}) {
    return MasonryGridView.count(
      key: key,
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: notes.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return _buildNoteItem(notes[index], provider, index);
      },
    );
  }

  Widget _buildListView(List<Note> notes, NoteProvider provider, {Key? key}) {
    return ListView.separated(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildNoteItem(notes[index], provider, index);
      },
    );
  }

  Widget _buildNoteItem(Note note, NoteProvider provider, int index) {
    final isSelected = provider.selectedNoteIds.contains(note.id);
    final isSelectionMode = provider.isSelectionMode;

    // Design layout: List -> Viền trái, Grid -> Viền trên
    final borderStyle = _isGrid
        ? Border(
            top: BorderSide(
                color: isSelected ? _primary : const Color(0xFFE5E5EA),
                width: 5))
        : Border(
            left: BorderSide(
                color: isSelected ? _primary : const Color(0xFFE5E5EA),
                width: 5));

    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: borderStyle,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: isSelected
              ? _primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: InkWell(
            onLongPress: () => provider.toggleSelection(note.id),
            onTap: () {
              if (isSelectionMode) {
                provider.toggleSelection(note.id);
              } else {
                _openEditor(note);
              }
            },
            child: NoteCard(
              note: note,
              searchQuery: _searchController.text.isNotEmpty
                  ? _searchController.text
                  : null,
            ),
          ),
        ),
      ),
    );

    // Hiệu ứng Fade-In bay nhẹ lên
    return FadeInItem(
      delay: Duration(milliseconds: index * 40),
      child: card,
    );
  }

  void _openEditor(Note? note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
    );
  }
}

// ── CUSTOM FADE-IN ANIMATION WIDGET ──
class FadeInItem extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeInItem({super.key, required this.child, required this.delay});

  @override
  State<FadeInItem> createState() => _FadeInItemState();
}

class _FadeInItemState extends State<FadeInItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
