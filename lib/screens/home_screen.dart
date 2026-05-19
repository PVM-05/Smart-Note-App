// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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

enum SortType {
  updatedNewest,
  createdNewest,
  titleAZ,
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _isGrid = false;
  SortType _sortType = SortType.updatedNewest;

  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (auth.isAuthenticated) {
        await auth.reloadUserData();
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
    setState(() {});
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

  void _showBatchTagDialog(BuildContext context, NoteProvider provider) {
    final labels = provider.allLabels;
    final TextEditingController newLabelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gán nhãn dán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.only(top: 12, left: 0, right: 0, bottom: 0),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: newLabelController,
                  decoration: InputDecoration(
                    hintText: 'Tạo nhãn mới...',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF2E75B6)),
                      onPressed: () async {
                        final newTag = newLabelController.text.trim();
                        if (newTag.isNotEmpty) {
                          Navigator.pop(ctx);
                          provider.addLabel(newTag);
                          await provider.addLabelToSelectedNotes(newTag);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã tạo và gán nhãn "$newTag"')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              if (labels.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: labels.length,
                    itemBuilder: (context, index) {
                      final label = labels[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        leading: const Icon(Icons.label_outline, size: 20),
                        title: Text(label, style: const TextStyle(fontSize: 15)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await provider.addLabelToSelectedNotes(label);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã gán nhãn "$label"')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  // ── HÀM HIỂN THỊ BOTTOM SHEET SẮP XẾP ĐƯỢC THÊM MỚI ──
  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Sắp xếp theo',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const Divider(),
              _buildSortOption(
                type: SortType.updatedNewest,
                icon: Icons.history,
                title: 'Mới chỉnh sửa gần đây',
              ),
              _buildSortOption(
                type: SortType.createdNewest,
                icon: Icons.access_time,
                title: 'Mới tạo gần đây',
              ),
              _buildSortOption(
                type: SortType.titleAZ,
                icon: Icons.sort_by_alpha,
                title: 'Tiêu đề A → Z',
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget con để dựng các dòng tùy chọn trong Bottom Sheet sắp xếp
  Widget _buildSortOption({
    required SortType type,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _sortType == type;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: isSelected ? _primary : const Color(0xFF64748B)),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? _primary : const Color(0xFF1E293B),
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: _primary, size: 20) : null,
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _sortType = type;
        });

        String message = '';
        switch (type) {
          case SortType.updatedNewest:
            message = 'Đang sắp xếp: Mới chỉnh sửa gần đây';
            break;
          case SortType.createdNewest:
            message = 'Đang sắp xếp: Mới tạo gần đây';
            break;
          case SortType.titleAZ:
            message = 'Đang sắp xếp: Tiêu đề A → Z';
            break;
        }

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.roboto()),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final isSelectionMode = noteProvider.isSelectionMode;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          drawer: const MainDrawer(currentRoute: '/home'),
          endDrawer: const ProfileDrawer(),
          appBar: isSelectionMode ? _selectionAppBar(noteProvider) : _normalAppBar(),
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
              closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                  elevation: 0,
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
      return ShimmerPlaceholder(
        child: _isGrid ? _buildSkeletonGrid() : _buildSkeletonList(),
      );
    }

    if (noteProvider.isSearching && noteProvider.notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Không tìm thấy ghi chú nào', style: TextStyle(color: Colors.grey[500])),
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
            Text(noteProvider.selectedLabel != null
                ? 'Không có ghi chú nào thuộc nhãn này'
                : 'Chưa có ghi chú nào. Hãy nhấn + để thêm!'),
          ],
        ),
      );
    }

    final List<Note> searchNotes = List<Note>.from(noteProvider.notes);
    final List<Note> pinnedNotes = List<Note>.from(noteProvider.pinnedNotes);
    final List<Note> normalNotes = List<Note>.from(noteProvider.normalNotes);

    int sortCompare(Note a, Note b) {
      switch (_sortType) {
        case SortType.updatedNewest:
          return b.updatedAt.compareTo(a.updatedAt);
        case SortType.createdNewest:
          return b.createdAt.compareTo(a.createdAt);
        case SortType.titleAZ:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    }

    searchNotes.sort(sortCompare);
    pinnedNotes.sort(sortCompare);
    normalNotes.sort(sortCompare);

    return RefreshIndicator(
      onRefresh: () async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await noteProvider.fetchNotes(auth.userId!);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (noteProvider.isSearching) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '${searchNotes.length} KẾT QUẢ TÌM THẤY',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _buildNotesSection(searchNotes, noteProvider),
          ] else ...[
            if (pinnedNotes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Được ghim',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildNotesSection(pinnedNotes, noteProvider),
              const SizedBox(height: 16),
            ],
            if (normalNotes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Khác',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildNotesSection(normalNotes, noteProvider),
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
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: _isGrid ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? _primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: OpenContainer(
          transitionType: ContainerTransitionType.fade,
          transitionDuration: const Duration(milliseconds: 400),
          closedElevation: 0,
          openElevation: 0,
          closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          closedColor: isSelected ? _primary.withValues(alpha: 0.05) : Colors.white,
          middleColor: Colors.white,
          openColor: Theme.of(context).scaffoldBackgroundColor,
          openBuilder: (context, _) => EditorScreen(note: note),
          onClosed: (_) async {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            if (auth.isAuthenticated && auth.userId != null) {
              await provider.fetchNotes(auth.userId!);
            }
          },
          closedBuilder: (context, openContainer) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onLongPress: () => provider.toggleSelection(note.id),
                onTap: () {
                  if (isSelectionMode) {
                    provider.toggleSelection(note.id);
                  } else {
                    openContainer();
                  }
                },
                child: NoteCard(
                  note: note,
                  searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
                  isGrid: _isGrid,
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
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      titleSpacing: 0,
      leadingWidth: 56,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF1E293B), size: 22),
          style: IconButton.styleFrom(
            hoverColor: const Color(0xFFE2E8F0),
            highlightColor: const Color(0xFFCBD5E1),
            splashFactory: InkSparkle.splashFactory,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm trên Smart Note...',
                  hintStyle: GoogleFonts.roboto(color: const Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w400),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: GoogleFonts.roboto(fontSize: 14, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                style: IconButton.styleFrom(
                  hoverColor: const Color(0xFFE2E8F0),
                  highlightColor: const Color(0xFFCBD5E1),
                  splashFactory: InkSparkle.splashFactory,
                ),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                _isGrid ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
                size: 24,
                color: const Color(0xFF1E293B),
              ),
              style: IconButton.styleFrom(
                hoverColor: const Color(0xFFE2E8F0),
                highlightColor: const Color(0xFFCBD5E1),
                splashFactory: InkSparkle.splashFactory,
                padding: const EdgeInsets.all(8),
              ),
              onPressed: () {
                setState(() {
                  _isGrid = !_isGrid;
                });
              },
            ),

            // ── ĐÃ THAY THẾ POPUMENUBUTTON THÀNH ICONBUTTON GỌI BOTTOM SHEET ──
            IconButton(
              icon: const Icon(
                Icons.swap_vert,
                size: 24,
                color: Color(0xFF1E293B),
              ),
              style: IconButton.styleFrom(
                hoverColor: const Color(0xFFE2E8F0),
                highlightColor: const Color(0xFFCBD5E1),
                splashFactory: InkSparkle.splashFactory,
                padding: const EdgeInsets.all(8),
              ),
              onPressed: _showSortBottomSheet,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
      centerTitle: false,
      actions: [
        SizedBox(
          width: 56,
          child: Center(
            child: Consumer<AuthProvider>(
              builder: (context, auth, child) => Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF2563EB),
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
          icon: const Icon(Icons.label_outline, color: Colors.black87),
          tooltip: 'Thay đổi nhãn dán',
          onPressed: () => _showBatchTagDialog(context, provider),
        ),
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

  Widget _buildNotesSection(List<Note> notes, NoteProvider noteProvider) {
    if (_isGrid) {
      return MasonryGridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return _buildNoteItem(note, noteProvider);
        },
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return _buildNoteItem(note, noteProvider);
        },
      );
    }
  }

  Widget _buildSkeletonGrid() {
    final heights = [140.0, 180.0, 160.0, 200.0, 150.0, 170.0];
    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        final height = heights[index % heights.length];
        return Container(
          height: height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 14,
                    width: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 12,
                    width: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 10,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 14,
                    width: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 16,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 18,
                    width: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 12,
                width: MediaQuery.of(context).size.width * 0.6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 16,
                    width: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ShimmerPlaceholder extends StatefulWidget {
  final Widget child;
  const ShimmerPlaceholder({super.key, required this.child});

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: widget.child,
        );
      },
    );
  }
}