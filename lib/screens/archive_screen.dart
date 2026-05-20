// lib/screens/archive_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import '../widgets/main_drawer.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userId != null) {
        Provider.of<NoteProvider>(context, listen: false)
            .fetchArchivedNotes(auth.userId!);
      }
    });
  }

  Future<void> _confirmUnarchiveSelected(NoteProvider provider) async {
    final count = provider.selectedArchiveNoteIds.length;
    await provider.unarchiveSelectedNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã khôi phục $count ghi chú về Tất cả ghi chú'),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  Future<void> _confirmDeleteSelected(NoteProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chuyển vào Thùng rác?'),
        content: Text(
          'Bạn có chắc muốn chuyển ${provider.selectedArchiveNoteIds.length} ghi chú vào Thùng rác không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Chuyển vào thùng rác'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.deleteSelectedArchiveNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, provider, child) {
        final isSelectionMode = provider.isArchiveSelectionMode;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          drawer: const MainDrawer(currentRoute: '/archive'),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.archivedNotes.isEmpty) {
      return _buildEmptyArchive();
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBDEFB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ghi chú đã lưu trữ sẽ không hiển thị ở Trang chủ.',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: const Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: MasonryGridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: provider.archivedNotes.length,
            itemBuilder: (context, index) {
              final note = provider.archivedNotes[index];
              return _buildArchiveNoteItem(note, provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveNoteItem(Note note, NoteProvider provider) {
    final isSelected = provider.selectedArchiveNoteIds.contains(note.id);
    final isSelectionMode = provider.isArchiveSelectionMode;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? _primary : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: isSelected
              ? _primary.withValues(alpha: 0.05)
              : Colors.white,
          child: InkWell(
            onLongPress: () => provider.toggleArchiveSelection(note.id),
            onTap: () {
              if (isSelectionMode) {
                provider.toggleArchiveSelection(note.id);
              } else {
                _showArchiveOptions(context, note, provider);
              }
            },
            child: NoteCard(note: note),
          ),
        ),
      ),
    );
  }

  AppBar _normalAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        'Lưu trữ',
        style: GoogleFonts.roboto(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  AppBar _selectionAppBar(NoteProvider provider) {
    return AppBar(
      backgroundColor: const Color(0xFFE2E8F0),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black87),
        onPressed: () => provider.clearArchiveSelection(),
      ),
      title: Text(
        '${provider.selectedArchiveNoteIds.length} đã chọn',
        style: GoogleFonts.roboto(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.unarchive_outlined, color: _primary),
          tooltip: 'Bỏ lưu trữ',
          onPressed: () => _confirmUnarchiveSelected(provider),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Chuyển vào thùng rác',
          onPressed: () => _confirmDeleteSelected(provider),
        ),
      ],
    );
  }

  void _showArchiveOptions(
      BuildContext context, Note note, NoteProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
              const Icon(Icons.unarchive_outlined, color: _primary),
              title: const Text('Bỏ lưu trữ'),
              subtitle: const Text('Khôi phục về Trang chủ'),
              onTap: () {
                provider.unarchiveNote(note.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã bỏ lưu trữ ghi chú'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Chuyển vào thùng rác',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                provider.moveArchivedNoteToTrash(note.id);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyArchive() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.archive_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chưa có ghi chú lưu trữ',
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vuốt trái ghi chú ở Trang chủ\nhoặc dùng menu để lưu trữ.',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}