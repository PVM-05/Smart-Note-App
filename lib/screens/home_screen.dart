import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // HOME: KHỞI TẠO DỮ LIỆU
  // Data Flow: Auth Check -> NoteProvider -> SQLite Fetch -> UI Update
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<NoteProvider>(
          context,
          listen: false,
        ).fetchNotes(auth.userId!);
      }
    });
  }

  // UI: GIAO DIỆN CHÍNH (PINTEREST GRID)
  // Data Flow: NestedScrollView -> SliverAppBar -> Consumer (Note List) -> MasonryGrid
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'My Notes',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              actions: [_buildUserAvatar(context), const SizedBox(width: 16)],
            ),
          ],
          body: Consumer<NoteProvider>(
            builder: (context, noteProvider, child) {
              if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2E75B6)),
                );
              }

              if (noteProvider.notes.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                color: const Color(0xFF2E75B6),
                onRefresh: () async {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await noteProvider.fetchNotes(auth.userId!);
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (noteProvider.pinnedNotes.isNotEmpty) ...[
                        _buildSectionHeader('📌 PINNED'),
                        _buildMasonryGrid(noteProvider.pinnedNotes),
                      ],

                      _buildSectionHeader('ALL NOTES'),
                      _buildMasonryGrid(noteProvider.normalNotes),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateNoteDialog(context),
        backgroundColor: const Color(0xFF2E75B6),
        label: Text(
          'New Note',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return GestureDetector(
          onTap: () async {
            await auth.signOut();
            // Đăng xuất và quay về màn hình đăng nhập
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2E75B6),
            child: Text(
              auth.email?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMasonryGrid(List<Note> notes) {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: notes.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return NoteCard(note: notes[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No notes yet',
            style: GoogleFonts.outfit(fontSize: 20, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // CRUD: TẠO GHI CHÚ MỚI
  // Data Flow: Input Field -> Note Model -> Local Save -> Sync Trigger -> Cloud Push
  void _showCreateNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
              ),
              TextField(
                controller: contentController,
                style: GoogleFonts.outfit(),
                decoration: const InputDecoration(
                  hintText: 'Content',
                  border: InputBorder.none,
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isEmpty) return;
                  final noteProvider = Provider.of<NoteProvider>(
                    context,
                    listen: false,
                  );
                  final newNote = Note(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    content: contentController.text,
                    status: 'normal',
                    isSynced: false,
                  );
                  noteProvider.addNote(newNote);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E75B6),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Create',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
