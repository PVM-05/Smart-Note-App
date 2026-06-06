// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../core/design/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../providers/sync_provider.dart';
import '../models/note_model.dart';

import '../widgets/note_card.dart';
import 'editor_screen.dart';
import '../widgets/main_drawer.dart';
import '../widgets/profile_drawer.dart';
import '../widgets/note_card_shimmer.dart';
import '../widgets/empty_state.dart';
import 'search_screen.dart';
import '../features/home/sheets/sort_options_sheet.dart';
import '../features/home/widgets/home_quick_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  bool _isGrid = false;
  SortType _sortType = SortType.updatedNewest;
  StreamSubscription<void>? _syncNewDataSub; // Lắng nghe dữ liệu mới từ sync

  Timer? _syncBannerTimer;

  static const _primary = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Đọc tất cả provider TRƯỚC khi await để tránh context across async gaps
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      if (auth.isAuthenticated) {
        // 1. Tải cực nhanh dữ liệu từ SQLite local lên UI trước để người dùng không phải chờ
        await noteProvider.fetchNotes(auth.userId!);
        await noteProvider.fetchTrashNotes(auth.userId!);
      }

      // 2. Lắng nghe tín hiệu từ SyncProvider khi có dữ liệu mới từ cloud
      _syncNewDataSub = syncProvider.onSyncWithNewData.listen((_) async {
        if (!mounted) return;
        final currentAuth = Provider.of<AuthProvider>(context, listen: false);
        if (currentAuth.isAuthenticated && currentAuth.userId != null) {
          final currentNoteProvider =
              Provider.of<NoteProvider>(context, listen: false);
          await currentNoteProvider.refreshNotes(currentAuth.userId!);
          if (mounted) {
            // Đã ẩn SnackBar theo yêu cầu để giao diện gọn gàng hơn
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _syncNewDataSub?.cancel(); // Hủy subscription để tránh memory leak
    _syncBannerTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Khi cuộn cách đáy màn hình 200px, tự động trigger tải dữ liệu trang tiếp theo
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      if (auth.isAuthenticated && !noteProvider.isSearching) {
        noteProvider.fetchMoreNotes(auth.userId!);
      }
    }
  }

  void _showModernQuickMenu(
      BuildContext context, GlobalKey<OpenContainerState> openContainerKey) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return HomeQuickMenu(
            animation: animation,
            onTextNoteTap: () => openContainerKey.currentState?.openContainer(),
          );
        },
      ),
    );
  }


  // Giải pháp tối ưu cho hàm xóa tại home_screen.dart
  Future<void> _moveToTrashSelected(NoteProvider provider) async {
    final deletedIds = List<String>.from(provider.selectedNoteIds);
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
            label: 'Hoàn tác',
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
    }
  }

  void _showBatchTagDialog(BuildContext context, NoteProvider provider) {
    final labels = provider.allLabels;
    final TextEditingController newLabelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gán nhãn dán',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        contentPadding:
            const EdgeInsets.only(top: 12, left: 0, right: 0, bottom: 0),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: newLabelController,
                  decoration: InputDecoration(
                    hintText: 'Tạo nhãn mới...',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add_circle, color: _primary),
                      onPressed: () async {
                        final newTag = newLabelController.text.trim();
                        if (newTag.isNotEmpty) {
                          Navigator.pop(ctx);
                          provider.addLabel(newTag);
                          await provider.addLabelToSelectedNotes(newTag);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Đã tạo và gán nhãn "$newTag"')),
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        leading: const Icon(Icons.label_outline, size: 20),
                        title:
                            Text(label, style: const TextStyle(fontSize: 15)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await provider.addLabelToSelectedNotes(label);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
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

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SortOptionsSheet(
          currentSortType: _sortType,
          onSortTypeChanged: (type) {
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NoteProvider, SyncProvider>(
      builder: (context, noteProvider, syncProvider, child) {
        final isSelectionMode = noteProvider.isSelectionMode;

        return Scaffold(
          backgroundColor: AppColors.background(context),
          drawer: MainDrawer(
            currentRoute: '/home',
            onLabelSelected: () {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (auth.isAuthenticated) {
                Provider.of<NoteProvider>(context, listen: false)
                    .refreshNotes(auth.userId!);
              }
            },
          ),
          endDrawer: const ProfileDrawer(),
          appBar: isSelectionMode
              ? _selectionAppBar(noteProvider)
              : _normalAppBar(),
          body: Column(
            children: [
              _buildSyncStatusBanner(syncProvider, noteProvider),
              Expanded(child: _buildBody(noteProvider)),
            ],
          ),
          floatingActionButton: Consumer<NoteProvider>(
            builder: (context, provider, _) {
              final isSelectionMode = provider.isSelectionMode;
              final GlobalKey<OpenContainerState> openContainerKey =
                  GlobalKey<OpenContainerState>();

              return AnimatedScale(
                scale: isSelectionMode ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: GestureDetector(
                  onLongPress: () {
                    // 🌟 NHẤN GIỮ: Hiện menu nổi đè màn hình + Xoay FAB + Blur nền
                    _showModernQuickMenu(context, openContainerKey);
                  },
                  child: OpenContainer(
                    key: openContainerKey,
                    transitionType: ContainerTransitionType.fadeThrough,
                    transitionDuration: const Duration(milliseconds: 400),
                    closedElevation: 3,
                    openElevation: 0,
                    closedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    closedColor: AppColors.fabBackground(context),
                    openBuilder: (context, _) => const EditorScreen(note: null),
                    onClosed: (_) async {
                      // Refresh danh sách sau khi đóng editor
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      if (auth.isAuthenticated && auth.userId != null) {
                        Provider.of<NoteProvider>(context, listen: false)
                            .refreshNotes(auth.userId!);
                      }
                    },
                    closedBuilder: (context, openContainer) {
                      return FloatingActionButton(
                        elevation: 0,
                        backgroundColor: AppColors.fabBackground(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onPressed: () {
                          // 🌟 ẤN NHANH: Mở thẳng trình tạo note văn bản
                          if (!isSelectionMode) {
                            openContainer();
                          }
                        },
                        child: Icon(
                          Icons.add,
                          color: AppColors.fabForeground(context),
                          size: 28,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSyncStatusBanner(
      SyncProvider syncProvider, NoteProvider noteProvider) {
    return const SizedBox
        .shrink(); // Đã ẩn popup banner đồng bộ để gọn giao diện
  }

  Widget _buildBody(NoteProvider noteProvider) {
    if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
      return _isGrid
          ? MasonryGridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              itemCount: 6,
              itemBuilder: (context, index) =>
                  const NoteCardShimmer(isGrid: true),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: 6,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: NoteCardShimmer(isGrid: false),
              ),
            );
    }

    if (noteProvider.notes.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.note_add_outlined,
        title: noteProvider.selectedLabel != null
            ? 'Trống'
            : 'Chưa có ghi chú nào',
        subtitle: noteProvider.selectedLabel != null
            ? 'Không có ghi chú nào thuộc nhãn này'
            : 'Hãy nhấn + ở góc dưới để thêm ghi chú mới!',
      );
    }

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

    pinnedNotes.sort(sortCompare);
    normalNotes.sort(sortCompare);

    return RefreshIndicator(
      onRefresh: () async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await noteProvider.refreshNotes(auth.userId!);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── CÓ NOTE GHIM → HIỆN KHU VỰC "ĐƯỢC GHIM"
          if (pinnedNotes.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Được ghim',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMetadata(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            _buildNotesSliverSection(pinnedNotes, noteProvider),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (normalNotes.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Khác',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMetadata(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              _buildNotesSliverSection(normalNotes, noteProvider),
            ],
          ]
          // ── KHÔNG CÓ NOTE GHIM → HIỆN THẲNG NOTE THƯỜNG
          else ...[
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            _buildNotesSliverSection(normalNotes, noteProvider),
          ],

          // Progress Indicator load thêm dữ liệu
          if (noteProvider.isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildNoteItem(Note note, NoteProvider provider) {
    final isSelected = provider.selectedNoteIds.contains(note.id);
    final isSelectionMode = provider.isSelectionMode;

    // Định nghĩa tĩnh các hằng số màu sắc tránh gây rò rỉ bộ nhớ (memory allocation) khi render 60fps
    final Color selectBorderColor = _primary;
    final Color selectBgColor = _primary.withValues(alpha: 0.06);

    return Container(
      margin: _isGrid
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // ⚡ TỐI ƯU GPU: Đẩy AnimatedScale ra lớp ngoài cùng bọc OpenContainer để ép GPU xử lý độc lập
      child: AnimatedScale(
        scale: isSelected ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        child: OpenContainer(
          transitionType: ContainerTransitionType.fade,
          transitionDuration: const Duration(
              milliseconds: 320), // Tốc độ Material 3 chuẩn (300-350ms)
          closedElevation: 0,
          openElevation: 0,
          tappable: false,
          closedColor: Colors.transparent,
          middleColor: Colors.transparent,
          openColor: Theme.of(context).scaffoldBackgroundColor,
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          openBuilder: (context, _) => EditorScreen(note: note),
          onClosed: (_) {
            // Trì hoãn re-fetch data sau khi card đã thu nhỏ hoàn toàn
            Future.delayed(const Duration(milliseconds: 320), () async {
              if (!mounted) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (auth.isAuthenticated && auth.userId != null) {
                await provider.fetchNotes(auth.userId!);
              }
            });
          },
          closedBuilder: (context, openContainer) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? selectBorderColor : Colors.transparent,
                  width: 2,
                ),
                color: isSelected ? selectBgColor : AppColors.surface(context),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  splashColor: selectBgColor,
                  highlightColor: Colors.transparent,
                  onLongPress: () => provider.toggleSelection(note.id),
                  onTap: () {
                    if (isSelectionMode) {
                      provider.toggleSelection(note.id);
                    } else {
                      FocusManager.instance.primaryFocus?.unfocus();
                      openContainer();
                    }
                  },
                  child: NoteCard(
                    note: note,
                    searchQuery: null,
                    isGrid: _isGrid,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _archiveSelectedNotes(NoteProvider provider) async {
    final count = provider.selectedNoteIds.length;
    await provider.archiveSelectedNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu trữ $count ghi chú'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
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
          icon:
              Icon(Icons.menu, color: AppColors.textPrimary(context), size: 22),
          style: IconButton.styleFrom(
            hoverColor: AppColors.ripple(context),
            highlightColor: AppColors.divider(context),
            splashFactory: InkSparkle.splashFactory,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Builder(
        builder: (context) => Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.searchBarBackground(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary(context).withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SearchScreen(),
                        transitionsBuilder: (_, animation, __, child) {
                          return FadeTransition(
                              opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                  child: Container(
                    height: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tìm kiếm',
                      style: GoogleFonts.roboto(
                        color: AppColors.placeholder(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _isGrid
                      ? Icons.view_agenda_outlined
                      : Icons.grid_view_outlined,
                  size: 24,
                  color: AppColors.textPrimary(context),
                ),
                style: IconButton.styleFrom(
                  hoverColor: AppColors.ripple(context),
                  highlightColor: AppColors.divider(context),
                  splashFactory: InkSparkle.splashFactory,
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: () {
                  setState(() {
                    _isGrid = !_isGrid;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.swap_vert,
                  size: 24,
                  color: AppColors.textPrimary(context),
                ),
                style: IconButton.styleFrom(
                  hoverColor: AppColors.ripple(context),
                  highlightColor: AppColors.divider(context),
                  splashFactory: InkSparkle.splashFactory,
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: _showSortBottomSheet,
              ),
              const SizedBox(width: 6),
            ],
          ),
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
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkAccent
                            : AppColors.primary,
                    backgroundImage: (auth.userData?['photoUrl'] != null &&
                            auth.userData!['photoUrl'].toString().isNotEmpty)
                        ? NetworkImage(auth.userData!['photoUrl'])
                        : null,
                    child: (auth.userData?['photoUrl'] == null ||
                            auth.userData!['photoUrl'].toString().isEmpty)
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
      backgroundColor: AppColors.inputBackground(context),
      leading: IconButton(
        icon: Icon(Icons.close, color: AppColors.textPrimary(context)),
        tooltip: 'Hủy chọn',
        onPressed: () => provider.clearSelection(),
      ),
      title: Text(
        '${provider.selectedNoteIds.length} đã chọn',
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon:
              Icon(Icons.label_outline, color: AppColors.textPrimary(context)),
          tooltip: 'Thay đổi nhãn dán',
          onPressed: () => _showBatchTagDialog(context, provider),
        ),
        IconButton(
          icon: Icon(Icons.push_pin_outlined,
              color: AppColors.textPrimary(context)),
          tooltip: 'Ghim/Bỏ ghim hàng loạt',
          onPressed: () => provider.togglePinSelectedNotes(),
        ),
        IconButton(
          icon: Icon(Icons.archive_outlined,
              color: AppColors.textPrimary(context)),
          tooltip: 'Lưu trữ',
          onPressed: () => _archiveSelectedNotes(provider),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.error),
          tooltip: 'Chuyển vào thùng rác',
          onPressed: () => _moveToTrashSelected(provider),
        ),
      ],
    );
  }

  Widget _buildNotesSliverSection(List<Note> notes, NoteProvider noteProvider) {
    if (_isGrid) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          itemBuilder: (context, index) {
            return _buildNoteItem(notes[index], noteProvider);
          },
          childCount: notes.length,
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList.builder(
          itemCount: notes.length,
          itemBuilder: (context, index) {
            return _buildNoteItem(notes[index], noteProvider);
          },
        ),
      );
    }
  }
}
