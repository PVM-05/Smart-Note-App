import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../providers/sync_provider.dart';
import '../repositories/sync_repository.dart';
import 'note_detail_screen.dart';
import '../widgets/note_card.dart';

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

          return ListView.builder(
            itemCount: noteProvider.notes.length,
            itemBuilder: (context, i) {
              final note = noteProvider.notes[i];
              return NoteCard(
                title: note.title,
                content: note.content,
                onTap: () {
                  final auth = context.read<AuthProvider>();
                  final noteProvider = context.read<NoteProvider>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteDetailScreen(note: note),
                    ),
                  ).then((_) {
                    if (!mounted) return;
                    // Làm mới danh sách khi quay lại từ màn hình chi tiết
                    if (auth.userId != null) {
                      noteProvider.fetchNotes(auth.userId!);
                    }
                  });
                },

              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addNote() async {
    final noteProvider = context.read<NoteProvider>();
    final syncProvider = context.read<SyncProvider>();

    try {
      final note = Note(
        id: const Uuid().v4(),
        title: 'Ghi chú ${noteProvider.notes.length + 1}',
        content: 'Nội dung ghi chú mới...',
      );

      await noteProvider.addNote(note);

      // Kích hoạt đồng bộ ngay lập tức
      syncProvider.syncNow();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bị lỗi: $e')),
      );
    }
  }
}
