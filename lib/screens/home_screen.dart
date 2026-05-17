import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isSearchFocused = false;

  // Premium Colors
  static const _primary = Color(0xFF2E75B6);
  static const _navy = Color(0xFF0D1B2A);
  static const _bgGray = Color(0xFFF5F5F7);
  static const _textGray = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    // Ngày search bar dược focus/unfocus
    _searchFocus.addListener(() {
      setState(() => _isSearchFocused = _searchFocus.hasFocus);
    });

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
          backgroundColor: const Color(0xFFF8FAFC), // Nền xám nhạt
          drawer: const MainDrawer(currentRoute: '/home'),
          appBar: isSelectionMode
              ? _selectionAppBar(noteProvider)
              : _premiumHeader(),
          body: _buildBody(noteProvider),
          floatingActionButton: isSelectionMode
              ? null
              : HoverFab(onPressed: () => _openEditor(null)),
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
          icon: const Icon(Icons.menu, color: Color(0xFF334155), size: 24),
          hoverColor: const Color(0xFFF1F5F9), // Light gray hover
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text(
        'Smart Note',
        style: TextStyle(
          color: Color(0xFF0F172A), // Slate 900
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        // Sync Icon
        Consumer<SyncProvider>(
          builder: (context, syncProvider, child) {
            // Theo UX, dùng nét Medium (cloud_outlined) để cân bằng với font Bold của tiêu đề.
            IconData icon = Icons.cloud_outlined; 
            Color iconColor = const Color(0xFF64748B); // Slate gray

            if (syncProvider.status == SyncStatus.syncing) {
              icon = Icons.cloud_sync_outlined;
              iconColor = _primary;
            } else if (syncProvider.status == SyncStatus.error) {
              icon = Icons.cloud_off_outlined;
              iconColor = const Color(0xFFEF4444); // Red
            } else if (syncProvider.status == SyncStatus.success) {
              icon = Icons.cloud_done_outlined;
              iconColor = const Color(0xFF10B981); // Emerald green (như ảnh reference)
            }
            return IconButton(
              icon: Icon(icon, color: iconColor, size: 24),
              hoverColor: const Color(0xFFF1F5F9), // Light gray hover
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => syncProvider.syncNow(),
            );
          },
        ),
        const SizedBox(width: 4),

        // Grid/List Toggle with Rotation Animation
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            final rotateAnim =
                Tween<double>(begin: -0.25, end: 0.0).animate(animation);
            return RotationTransition(
              turns: rotateAnim,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: IconButton(
            key: ValueKey(_isGrid),
            icon: Icon(
              _isGrid ? Icons.grid_view_outlined : Icons.format_list_bulleted_rounded,
              color: const Color(0xFF64748B), // Slate gray
              size: 24, 
            ),
            hoverColor: const Color(0xFFF1F5F9), // Light gray hover
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onPressed: _toggleLayout,
          ),
        ),
        const SizedBox(width: 12),

        // Circular Avatar
        PopupMenuButton<String>(
          offset: const Offset(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) async {
            if (value == 'logout') {
              final userId = auth.userId;
              await auth.signOut();
              if (mounted && userId != null) {
                final np = Provider.of<NoteProvider>(context, listen: false);
                await np.clearLocalData(userId);
                if (!mounted) return;
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
                  Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
                  SizedBox(width: 12),
                  Text('Đăng xuất', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: _primary.withValues(alpha: 0.15), // Soft pastel blue
              child: Text(
                userLetter,
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: _buildSearchBar(),
        ),
      ),
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
            const SizedBox(height: 12),

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
              const SizedBox(height: 80),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_document,
                        size: 64,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Chưa có ghi chú nào',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hãy tạo ghi chú đầu tiên của bạn\nđể bắt đầu quản lý công việc.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: const Color(0xFF94A3B8),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _openEditor(null),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Tạo ghi chú mới'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
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
    final hasText = _searchController.text.isNotEmpty;
    final isActive = _isSearchFocused || hasText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : _bgGray,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isActive
                ? _primary.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm ghi chú của bạn...',
            hintStyle: TextStyle(
              color: isActive ? const Color(0xFFAEB5BC) : _textGray,
              fontSize: 15,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.search_rounded,
                  key: ValueKey(isActive),
                  size: 22,
                  color: isActive ? _primary : _textGray,
                ),
              ),
            ),
            suffixIcon: hasText
                ? IconButton(
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 20,
                      color: isActive ? _primary.withValues(alpha: 0.6) : _textGray,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          style: const TextStyle(fontSize: 15, color: _navy),
        ),
      ),
    );
  }

  Widget _buildCategoryLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
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
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
    final noteColor = NoteCard.getNoteColor(note.id);

    // Grid: nền đậm hơn (28%) như Stickify | List: nền nhạt hơn (14%) thanh lịch
    final bgOpacity = _isGrid ? 0.28 : 0.14;
    final cardColor = isSelected
        ? _primary.withValues(alpha: 0.15)
        : noteColor.withValues(alpha: bgOpacity);

    final card = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? _primary.withValues(alpha: 0.6)
              : noteColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: noteColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => provider.toggleSelection(note.id),
            onTap: () {
              if (isSelectionMode) {
                provider.toggleSelection(note.id);
              } else {
                _openEditor(note);
              }
            },
            splashColor: noteColor.withValues(alpha: 0.3),
            highlightColor: noteColor.withValues(alpha: 0.15),
            child: NoteCard(
              note: note,
              searchQuery: _searchController.text.isNotEmpty
                  ? _searchController.text
                  : null,
              isGrid: _isGrid,
              onMenuPressed: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng này đang phát triển')),
                );
              },
            ),
          ),
        ),
      ),
    );

    return WaveStaggerItem(
      delay: Duration(milliseconds: index * 50),
      isGrid: _isGrid,
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

// ── HOVER FAB ──
class HoverFab extends StatefulWidget {
  final VoidCallback onPressed;
  const HoverFab({super.key, required this.onPressed});

  @override
  State<HoverFab> createState() => _HoverFabState();
}

class _HoverFabState extends State<HoverFab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: FloatingActionButton(
          onPressed: widget.onPressed,
          backgroundColor: _isHovered ? const Color(0xFF1E40AF) : const Color(0xFF2E75B6),
          elevation: _isHovered ? 6 : 2,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ── CUSTOM WAVE STAGGER ANIMATION WIDGET ──
class WaveStaggerItem extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool isGrid;

  const WaveStaggerItem(
      {super.key,
      required this.child,
      required this.delay,
      required this.isGrid});

  @override
  State<WaveStaggerItem> createState() => _WaveStaggerItemState();
}

class _WaveStaggerItemState extends State<WaveStaggerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final curve = Curves.easeOutCubic.transform(_ctrl.value);
        final opacity = Curves.easeOut.transform(_ctrl.value);

        double dx = 0;
        double dy = 0;
        double scale = 1.0;

        if (widget.isGrid) {
          dx = 20.0 * (1 - curve);
          scale = 0.8 + (0.2 * curve);
        } else {
          dy = 20.0 * (1 - curve); // Chỉ trượt từ dưới lên y như bản React
        }

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
