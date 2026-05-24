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
import 'search_screen.dart';

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
  final _scrollController = ScrollController();
  bool _isGrid = false;
  SortType _sortType = SortType.updatedNewest;

  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (auth.isAuthenticated) {
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);

        // 1. Tải cực nhanh dữ liệu từ SQLite local lên UI trước để người dùng không phải chờ
        await noteProvider.fetchNotes(auth.userId!);
        await noteProvider.fetchTrashNotes(auth.userId!);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Khi cuộn cách đáy màn hình 200px, tự động trigger tải dữ liệu trang tiếp theo
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      if (auth.isAuthenticated && !noteProvider.isSearching) {
        noteProvider.fetchMoreNotes(auth.userId!);
      }
    }
  }

  void _showModernQuickMenu(BuildContext context, GlobalKey<OpenContainerState> openContainerKey) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {

          final List<Map<String, dynamic>> menuItems = [
            {'icon': Icons.mic_none_outlined, 'title': 'Âm thanh', 'action': () {
              // Mở EditorScreen với auto-start recording
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const EditorScreen(note: null, autoRecord: true),
              ));
            }},
            {'icon': Icons.image_outlined, 'title': 'Hình ảnh', 'action': () {
              // Mở EditorScreen với auto-pick image
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const EditorScreen(note: null, autoPickImage: true),
              ));
            }},
            {'icon': Icons.brush_outlined, 'title': 'Bản vẽ', 'action': () {}},
            {'icon': Icons.check_box_outlined, 'title': 'Danh sách', 'action': () {}},
            {'icon': Icons.text_fields_outlined, 'title': 'Văn bản', 'action': () => openContainerKey.currentState?.openContainer()},
          ];

          return Stack(
            children: [
              // 1. Lớp nền mờ kính chuyển động
              // Nền phủ tối nhẹ kiểu Google Keep
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withOpacity(
                      (animation.value * 0.5).clamp(0.0, 1.0),
                    ),
                  );
                },
              ),

              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),

              // 2. GIẢI PHÁP: Bọc SafeArea bảo vệ bên ngoài khu vực nút bấm
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 16, // Khoảng cách 16px an toàn từ đáy màn hình ứng dụng
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Các khối Option tách rời bo tròn
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(menuItems.length, (index) {
                              final item = menuItems[index];

                              final double startDelay = (menuItems.length - 1 - index) * 0.08;
                              final double endDelay = (startDelay + 0.5).clamp(0.0, 1.0);

                              final scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Interval(startDelay, endDelay, curve: Curves.easeOutBack),
                                ),
                              );

                              return ScaleTransition(
                                scale: scaleAnimation,
                                alignment: Alignment.bottomRight,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          Navigator.pop(context);
                                          (item['action'] as VoidCallback)();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item['title'] as String,
                                                style: GoogleFonts.roboto(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF3C4043),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Icon(item['icon'] as IconData, color: const Color(0xFF5F6368), size: 22),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 6),

                          // Nút FAB giả lập - chỉ xoay icon dấu cộng bên trong
                          FloatingActionButton(
                            elevation: 4,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: animation.value * 2.35619, // Xoay 135 độ chuẩn
                                  child: child,
                                );
                              },
                              child: const Icon(
                                Icons.add,
                                color: _primary,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Hoàn tác',
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
                            ScaffoldMessenger.of(context).clearSnackBars();
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
          drawer: MainDrawer(
            currentRoute: '/home',
            onLabelSelected: () {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (auth.isAuthenticated) {
                Provider.of<NoteProvider>(context, listen: false).refreshNotes(auth.userId!);
              }
            },
          ),
          endDrawer: const ProfileDrawer(),
          appBar: isSelectionMode ? _selectionAppBar(noteProvider) : _normalAppBar(),
          body: _buildBody(noteProvider),
          floatingActionButton: Consumer<NoteProvider>(
            builder: (context, provider, _) {
              final isSelectionMode = provider.isSelectionMode;
              final GlobalKey<OpenContainerState> openContainerKey = GlobalKey<OpenContainerState>();

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
                    closedColor: Colors.white,
                    openBuilder: (context, _) => const EditorScreen(note: null),
                    onClosed: (_) {
                      provider.notifyListeners();
                    },
                    closedBuilder: (context, openContainer) {
                      return FloatingActionButton(
                        elevation: 0,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onPressed: () {
                          // 🌟 ẤN NHANH: Mở thẳng trình tạo note văn bản
                          if (!isSelectionMode) {
                            openContainer();
                          }
                        },
                        child: const Icon(
                          Icons.add,
                          color: _primary,
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


  Widget _buildBody(NoteProvider noteProvider) {
    if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
      return ShimmerPlaceholder(
        child: _isGrid ? _buildSkeletonGrid() : _buildSkeletonList(),
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
                    color: Colors.grey[500],
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
                      color: Colors.grey[500],
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E75B6)),
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
    const Color selectBorderColor = Color(0xFF2E75B6);
    const Color selectBgColor = Color(0x0F2E75B6);

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
          transitionDuration: const Duration(milliseconds: 320), // Tốc độ Material 3 chuẩn (300-350ms)
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
                color: isSelected ? selectBgColor : Colors.white,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const SearchScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(opacity: animation, child: child);
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
                      color: const Color(0xFF64748B),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
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
          icon: const Icon(Icons.archive_outlined, color: Colors.black87),
          tooltip: 'Lưu trữ',
          onPressed: () => _archiveSelectedNotes(provider),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
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