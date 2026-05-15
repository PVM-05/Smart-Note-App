import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../providers/sync_provider.dart';
import '../repositories/sync_repository.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Khởi tạo data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<NoteProvider>().fetchNotes(auth.userId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Note'),
        actions: [
          // Hiển thị trạng thái sync
          Consumer<SyncProvider>(
            builder: (context, sync, child) {
              return Tooltip(
                message: sync.statusLabel,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    sync.status == SyncStatus.syncing
                        ? Icons.sync
                        : sync.status == SyncStatus.error
                            ? Icons.sync_problem
                            : Icons.cloud_done,
                    color: sync.status == SyncStatus.error
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
            },
          ),
        ],
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          if (noteProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (noteProvider.notes.isEmpty) {
            return const Center(
              child: Text('Chưa có ghi chú nào. Hãy bấm + để thêm.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (auth.userId != null) {
                await noteProvider.fetchNotes(auth.userId!);
              }
            },
            child: ListView(
              children: [
                if (noteProvider.pinnedNotes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('📌 GHI CHÚ GHIM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ...noteProvider.pinnedNotes.map((note) => NoteCard(
                    title: note.title, content: note.content,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(note: note)))
                        .then((_) {
                          if (!mounted) return;
                          final auth = context.read<AuthProvider>();
                          if (auth.userId != null) {
                             context.read<NoteProvider>().fetchNotes(auth.userId!);
                          }
                          context.read<SyncProvider>().syncNow();
                        });
                    },
                  )),
                ],
                if (noteProvider.normalNotes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Tất cả ghi chú', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ...noteProvider.normalNotes.map((note) => NoteCard(
                    title: note.title, content: note.content,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(note: note)))
                        .then((_) {
                          if (!mounted) return;
                          final auth = context.read<AuthProvider>();
                          if (auth.userId != null) {
                             context.read<NoteProvider>().fetchNotes(auth.userId!);
                          }
                          context.read<SyncProvider>().syncNow();
                        });
                    },
                  )),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addNote() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    ).then((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<NoteProvider>().fetchNotes(auth.userId!);
      }
      context.read<SyncProvider>().syncNow();
    });
    }
}

