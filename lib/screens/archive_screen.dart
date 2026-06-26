// lib/screens/archive_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/design/app_colors.dart';
import '../core/app_localizations.dart';
import '../models/note_model.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../widgets/note_card_shimmer.dart';
import '../widgets/empty_state.dart';
import '../widgets/main_drawer.dart';
import '../widgets/note_card.dart';
import 'package:animations/animations.dart';
import 'editor_screen.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  bool _isGrid = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(
        context,
        listen: false,
      );

      if (auth.userId != null) {
        Provider.of<NoteProvider>(
          context,
          listen: false,
        ).fetchArchivedNotes(auth.userId!);
      }
    });
  }

  Future<void> _confirmUnarchiveSelected(
      NoteProvider provider,
      ) async {
    final count = provider.selectedArchiveNoteIds.length;

    await provider.unarchiveSelectedNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.translate(context, 'restoredNotesCount').replaceAll('{count}', '$count'),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  Future<void> _deleteSelectedNotes(
      NoteProvider provider,
      ) async {
    final count = provider.selectedArchiveNoteIds.length;
    final deletedIds = List<String>.from(provider.selectedArchiveNoteIds);

    await provider.deleteSelectedArchiveNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.translate(context, 'movedNotesToTrash').replaceAll('{count}', '$count'),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: AppLocalizations.translate(context, 'undo'),
            textColor: AppColors.primary,
            onPressed: () async {
              for (final id in deletedIds) {
                await provider.restoreNote(id);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, provider, child) {
        final isSelectionMode =
            provider.isArchiveSelectionMode;

        return Scaffold(
          backgroundColor: AppColors.background(context),

          drawer: const MainDrawer(
            currentRoute: '/archive',
          ),

          appBar: isSelectionMode
              ? _selectionAppBar(provider)
              : _normalAppBar(context),

          body: _buildBody(provider),
        );
      },
    );
  }

  Widget _buildBody(NoteProvider provider) {
    if (provider.isLoading && provider.archivedNotes.isEmpty) {
      return _isGrid
          ? MasonryGridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              itemCount: 6,
              itemBuilder: (context, index) => const NoteCardShimmer(isGrid: true),
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

    if (provider.archivedNotes.isEmpty) {
      return _buildEmptyArchive();
    }

    return RefreshIndicator(
      onRefresh: () async {
        final auth = Provider.of<AuthProvider>(
          context,
          listen: false,
        );

        if (auth.userId != null) {
          await provider.fetchArchivedNotes(
            auth.userId!,
          );
        }
      },

      child: AnimatedSwitcher(
        duration: const Duration(
          milliseconds: 350,
        ),

        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,

        transitionBuilder: (
            child,
            animation,
            ) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.96,
                end: 1,
              ).animate(animation),
              child: child,
            ),
          );
        },

        child: _isGrid
            ? MasonryGridView.count(
          key: const ValueKey('grid'),

          padding:
          const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),

          crossAxisCount: 2,

          mainAxisSpacing: 8,
          crossAxisSpacing: 8,

          itemCount:
          provider.archivedNotes.length,

          itemBuilder: (context, index) {
            final note =
            provider.archivedNotes[index];

            return _buildArchiveNoteItem(
              note,
              provider,
            );
          },
        )
            : ListView.builder(
          key: const ValueKey('list'),

          padding:
          const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),

          itemCount:
          provider.archivedNotes.length,

          itemBuilder: (context, index) {
            final note =
            provider.archivedNotes[index];

            return Padding(
              padding:
              const EdgeInsets.symmetric(
                vertical: 4,
              ),

              child: _buildArchiveNoteItem(
                note,
                provider,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildArchiveNoteItem(
      Note note,
      NoteProvider provider,
      ) {
    final isSelected =
    provider.selectedArchiveNoteIds
        .contains(note.id);

    final isSelectionMode =
        provider.isArchiveSelectionMode;
    final selectBgColor = AppColors.primary.withValues(alpha: 0.05);

    return Container(
      margin: _isGrid
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: AnimatedScale(
        scale: isSelected ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        child: OpenContainer(
          transitionType: ContainerTransitionType.fade,
          transitionDuration: const Duration(milliseconds: 320),
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
                  color: isSelected ? AppColors.primary : Colors.transparent,
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
                  onLongPress: () {
                    provider.toggleArchiveSelection(note.id);
                  },
                  onTap: () {
                    if (isSelectionMode) {
                      provider.toggleArchiveSelection(note.id);
                    } else {
                      FocusManager.instance.primaryFocus?.unfocus();
                      openContainer();
                    }
                  },
                  child: NoteCard(
                    note: note,
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

  AppBar _normalAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background(context),

      elevation: 0,
      scrolledUnderElevation: 0,

      automaticallyImplyLeading: false,

      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu,
            color: AppColors.textPrimary(context),
          ),

          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),

      title: Text(
        AppLocalizations.translate(context, 'archiveTitle'),

        style: GoogleFonts.outfit(
          color: AppColors.textPrimary(context),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),

      actions: [
        IconButton(
          icon: Icon(
            _isGrid
                ? Icons.view_agenda_outlined
                : Icons.grid_view_outlined,

            color: AppColors.textPrimary(context),
          ),

          tooltip: AppLocalizations.translate(context, 'changeLayout'),

          onPressed: () {
            setState(() {
              _isGrid = !_isGrid;
            });
          },
        ),

        const SizedBox(width: 4),
      ],
    );
  }

  AppBar _selectionAppBar(
      NoteProvider provider,
      ) {
    return AppBar(
      backgroundColor: AppColors.inputBackground(context),

      elevation: 0,

      leading: IconButton(
        icon: Icon(
          Icons.close,
          color: AppColors.textPrimary(context),
        ),

        onPressed: () {
          provider.clearArchiveSelection();
        },
      ),

      title: Text(
        AppLocalizations.translate(context, 'selectedCount').replaceAll('{count}', '${provider.selectedArchiveNoteIds.length}'),

        style: GoogleFonts.outfit(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: -0.2,
        ),
      ),

      actions: [
        IconButton(
          icon: Icon(
            Icons.unarchive_outlined,
            color: AppColors.textPrimary(context),
          ),

          tooltip: AppLocalizations.translate(context, 'unarchive'),

          onPressed: () {
            _confirmUnarchiveSelected(
              provider,
            );
          },
        ),

        IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: AppColors.textPrimary(context),
          ),

          tooltip: AppLocalizations.translate(context, 'moveToTrash'),

          onPressed: () {
            _deleteSelectedNotes(
              provider,
            );
          },
        ),
      ],
    );
  }



  Widget _buildEmptyArchive() {
    return EmptyStateWidget(
      icon: Icons.archive_outlined,
      title: AppLocalizations.translate(context, 'emptyArchiveTitle'),
      subtitle: AppLocalizations.translate(context, 'emptyArchiveSubtitle'),
    );
  }
}