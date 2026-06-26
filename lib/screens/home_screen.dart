// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:reorderables/reorderables.dart';
import '../core/design/app_colors.dart';
import '../core/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/note_provider.dart';
import '../providers/sync_provider.dart';
import '../models/note_model.dart';

import '../widgets/note_card.dart';
import 'editor_screen.dart';
import 'label_selection_screen.dart';
import '../widgets/main_drawer.dart';
import '../widgets/profile_drawer.dart';
import '../widgets/note_card_shimmer.dart';
import '../widgets/empty_state.dart';
import 'search_screen.dart';
import '../features/home/sheets/sort_options_sheet.dart';
import '../features/home/widgets/home_quick_menu.dart';
import '../services/reminder_service.dart';
import '../services/pdf_export_service.dart';
import 'package:app_settings/app_settings.dart';
import '../features/editor/sheets/editor_color_picker_sheet.dart';

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

        // 3. Kiểm tra xem app được mở qua Click thông báo (Cold Start) không
        final launchPayload = ReminderService().consumeColdStartPayload();
        if (launchPayload != null && launchPayload.isNotEmpty) {
          ReminderService.navigateToNote(launchPayload);
        }
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
    _syncNewDataSub?.cancel();
    _syncBannerTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
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
          content: Text(AppLocalizations.translate(context, 'movedNotesToTrash').replaceAll('{count}', '$count')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: AppLocalizations.translate(context, 'undo'),
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

  void _openBatchTagScreen(BuildContext context, NoteProvider provider) {
    final selectedNotes = provider.notes.where((n) => provider.selectedNoteIds.contains(n.id)).toList();
    final Set<String> unionTags = {};
    for (final note in selectedNotes) {
      unionTags.addAll(note.tags);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LabelSelectionScreen(
          initialTags: unionTags.toList(),
          onTagsChanged: (updatedTags) async {
            await provider.updateTagsForSelectedNotes(updatedTags);
          },
        ),
      ),
    );
  }

  void _showNotificationPermissionDialog(BuildContext context) {
    final l = AppLocalizations.translate;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.notifications_off_outlined, color: Colors.amber.shade700, size: 28),
            const SizedBox(width: 12),
            Text(l(context, 'notifPermissionTitle')),
          ],
        ),
        content: Text(l(context, 'notifPermissionDesc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l(context, 'notifPermissionLater'),
              style: GoogleFonts.outfit(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l(context, 'notifPermissionSettings')),
          ),
        ],
      ),
    );
  }

  Future<void> _setBatchReminder(BuildContext context, NoteProvider provider) async {
    final granted = await ReminderService().requestPermissions();
    if (!granted) {
      if (context.mounted) {
        _showNotificationPermissionDialog(context);
      }
      return;
    }
    if (!context.mounted) return;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('vi', 'VN'),
    );
    if (pickedDate == null || !context.mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null || !context.mounted) return;

    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (selectedDateTime.isBefore(DateTime.now())) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.translate(context, 'reminderPastError')),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await provider.setReminderForSelectedNotes(selectedDateTime);
    provider.clearSelection();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.translate(context, 'reminderSet')
              .replaceAll('{time}', '${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')} ${selectedDateTime.day.toString().padLeft(2, '0')}/${selectedDateTime.month.toString().padLeft(2, '0')}')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showBatchColorPicker(BuildContext context, NoteProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return EditorColorPickerSheet(
          noteColor: null,
          onColorSelected: (newColor) async {
            Navigator.pop(ctx);
            await provider.updateColorForSelectedNotes(newColor);
            provider.clearSelection();
          },
        );
      },
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
                message = AppLocalizations.translate(context, 'sortUpdatedNewest');
                break;
              case SortType.createdNewest:
                message = AppLocalizations.translate(context, 'sortCreatedNewest');
                break;
              case SortType.custom:
                message = 'Thứ tự tùy chỉnh';
                break;
            }

            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message, style: GoogleFonts.outfit()),
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
    Provider.of<LanguageProvider>(context); // Listen to LanguageProvider for real-time rebuilds
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
              : _normalAppBar(noteProvider),
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

    final List<Note> pinnedNotes = List<Note>.from(noteProvider.pinnedNotes);
    final List<Note> normalNotes = List<Note>.from(noteProvider.normalNotes);

    if (pinnedNotes.isEmpty && normalNotes.isEmpty) {
      IconData emptyIcon = Icons.note_add_outlined;
      String emptyTitle = AppLocalizations.translate(context, 'emptyHomeTitle');
      String emptySubtitle = AppLocalizations.translate(context, 'emptyHomeSubtitle');

      if (noteProvider.showOnlyReminders) {
        emptyIcon = Icons.notifications_none_outlined;
        emptyTitle = AppLocalizations.translate(context, 'emptyRemindersTitle');
        emptySubtitle = AppLocalizations.translate(context, 'emptyRemindersSubtitle');
      } else if (noteProvider.selectedLabel != null) {
        emptyIcon = Icons.label_outline;
        emptyTitle = AppLocalizations.translate(context, 'emptyLabelTitle');
        emptySubtitle = AppLocalizations.translate(context, 'emptyLabelSubtitle');
      }

      return EmptyStateWidget(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    int sortCompare(Note a, Note b) {
      switch (_sortType) {
        case SortType.updatedNewest:
          return b.updatedAt.compareTo(a.updatedAt);
        case SortType.createdNewest:
          return b.createdAt.compareTo(a.createdAt);
        case SortType.custom:
          return a.sortOrder.compareTo(b.sortOrder);
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
                  AppLocalizations.translate(context, 'pinnedSection'),
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMetadata(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            _buildNotesSliverSection(pinnedNotes, noteProvider, isPinned: true),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (normalNotes.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    AppLocalizations.translate(context, 'othersSection'),
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMetadata(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              _buildNotesSliverSection(normalNotes, noteProvider, isPinned: false),
            ],
          ]
          // ── KHÔNG CÓ NOTE GHIM → HIỆN THẲNG NOTE THƯỜNG
          else ...[
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            _buildNotesSliverSection(normalNotes, noteProvider, isPinned: false),
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
                  onLongPress: _sortType == SortType.custom ? null : () => provider.toggleSelection(note.id),
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
          content: Text(AppLocalizations.translate(context, 'archivedNotesCount').replaceAll('{count}', '$count')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  AppBar _normalAppBar(NoteProvider noteProvider) {
    String searchPlaceholder = AppLocalizations.translate(context, 'searchPlaceholder');
    if (noteProvider.showOnlyReminders) {
      searchPlaceholder = AppLocalizations.translate(context, 'searchRemindersPlaceholder');
    } else if (noteProvider.selectedLabel != null) {
      searchPlaceholder = AppLocalizations.translate(context, 'searchInLabelPlaceholder')
          .replaceAll('{label}', noteProvider.selectedLabel!);
    }

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
                      searchPlaceholder,
                      style: GoogleFonts.outfit(
                        color: AppColors.placeholder(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    _isGrid ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
                    key: ValueKey<bool>(_isGrid),
                    size: 24,
                    color: AppColors.textPrimary(context),
                  ),
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
        tooltip: AppLocalizations.translate(context, 'cancelSelection'),
        onPressed: () => provider.clearSelection(),
      ),
      title: Text(
        AppLocalizations.translate(context, 'selectedCount').replaceAll('{count}', '${provider.selectedNoteIds.length}'),
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.push_pin_outlined,
              color: AppColors.textPrimary(context)),
          tooltip: AppLocalizations.translate(context, 'pinUnpinBatch'),
          onPressed: () => provider.togglePinSelectedNotes(),
        ),
        IconButton(
          icon: Icon(Icons.notification_add_outlined,
              color: AppColors.textPrimary(context)),
          tooltip: AppLocalizations.translate(context, 'reminderTooltip'),
          onPressed: () => _setBatchReminder(context, provider),
        ),
        IconButton(
          icon: Icon(Icons.palette_outlined,
              color: AppColors.textPrimary(context)),
          tooltip: AppLocalizations.translate(context, 'toolbarColor'),
          onPressed: () => _showBatchColorPicker(context, provider),
        ),
        IconButton(
          icon:
              Icon(Icons.label_outline, color: AppColors.textPrimary(context)),
          tooltip: AppLocalizations.translate(context, 'changeLabel'),
          onPressed: () => _openBatchTagScreen(context, provider),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.textPrimary(context)),
          onSelected: (value) async {
            if (value == 'archive') {
              _archiveSelectedNotes(provider);
            } else if (value == 'delete') {
              _moveToTrashSelected(provider);
            } else if (value == 'duplicate') {
              await provider.duplicateNotes(provider.selectedNoteIds.toList());
              provider.clearSelection();
            } else if (value == 'send') {
              final selectedNotes = provider.notes
                  .where((n) => provider.selectedNoteIds.contains(n.id))
                  .toList();
              if (selectedNotes.isNotEmpty) {
                await PdfExportService.exportMultipleNotesToPdf(context, selectedNotes);
              }
              provider.clearSelection();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'archive',
              child: Text(AppLocalizations.translate(context, 'archive')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(AppLocalizations.translate(context, 'delete')),
            ),
            PopupMenuItem(
              value: 'duplicate',
              child: Text(AppLocalizations.translate(context, 'makeCopy')),
            ),
            PopupMenuItem(
              value: 'send',
              child: Text(AppLocalizations.translate(context, 'sendNote')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSliverSection(List<Note> notes, NoteProvider noteProvider, {bool isPinned = false}) {
    final isCustomSort = _sortType == SortType.custom;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverToBoxAdapter(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: _isGrid
              ? _buildGridSection(notes, noteProvider, isPinned, isCustomSort)
              : _buildListSection(notes, noteProvider, isPinned, isCustomSort),
        ),
      ),
    );
  }

  Widget _buildGridSection(List<Note> notes, NoteProvider noteProvider, bool isPinned, bool isCustomSort) {
    if (isCustomSort) {
      return LayoutBuilder(
        key: ValueKey('grid_custom_${isPinned ? "pinned" : "normal"}'),
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 8) / 2;
          return ReorderableWrap(
            spacing: 8.0,
            runSpacing: 8.0,
            controller: _scrollController,
            onReorder: (oldIndex, newIndex) {
              int adjustedNewIndex = newIndex;
              if (newIndex > oldIndex) {
                adjustedNewIndex -= 1;
              }
              final note = notes[oldIndex];
              if (!noteProvider.selectedNoteIds.contains(note.id)) {
                noteProvider.toggleSelection(note.id);
              }
              noteProvider.reorderNotes(oldIndex, adjustedNewIndex, isPinned: isPinned);
            },
            onNoReorder: (index) {
              final note = notes[index];
              if (!noteProvider.selectedNoteIds.contains(note.id)) {
                noteProvider.toggleSelection(note.id);
              }
            },
            children: notes.map((note) {
              return SizedBox(
                key: ValueKey('${isPinned ? "pinned_wrap" : "normal_wrap"}_${note.id}'),
                width: cardWidth,
                child: _buildNoteItem(note, noteProvider),
              );
            }).toList(),
          );
        },
      );
    }

    return MasonryGridView.count(
      key: ValueKey('grid_normal_${isPinned ? "pinned" : "normal"}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: notes.length,
      itemBuilder: (context, index) {
        return _buildNoteItem(notes[index], noteProvider);
      },
    );
  }

  Widget _buildListSection(List<Note> notes, NoteProvider noteProvider, bool isPinned, bool isCustomSort) {
    if (isCustomSort) {
      return ReorderableListView.builder(
        key: ValueKey('list_custom_${isPinned ? "pinned" : "normal"}'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: notes.length,
        onReorderItem: (oldIndex, newIndex) {
          final note = notes[oldIndex];
          if (!noteProvider.selectedNoteIds.contains(note.id)) {
            noteProvider.toggleSelection(note.id);
          }
          noteProvider.reorderNotes(oldIndex, newIndex, isPinned: isPinned);
        },
        onReorderStart: (index) {
          final note = notes[index];
          if (!noteProvider.selectedNoteIds.contains(note.id)) {
            noteProvider.toggleSelection(note.id);
          }
        },
        itemBuilder: (context, index) {
          return ReorderableDelayedDragStartListener(
            key: ValueKey('${isPinned ? "pinned" : "normal"}_${notes[index].id}'),
            index: index,
            child: _buildNoteItem(notes[index], noteProvider),
          );
        },
      );
    }

    return ListView.builder(
      key: ValueKey('list_normal_${isPinned ? "pinned" : "normal"}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        return _buildNoteItem(notes[index], noteProvider);
      },
    );
  }
}
