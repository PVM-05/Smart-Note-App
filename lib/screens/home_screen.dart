import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    // Load notes ngay khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<NoteProvider>(context, listen: false).fetchNotes(auth.userId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Note'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 20),
                        const SizedBox(width: 8),
                        Text('Đăng xuất (${auth.email ?? ''})'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (noteProvider.notes.isEmpty) {
            return const Center(
              child: Text('Chưa có ghi chú nào. Hãy nhấn + để thêm!'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await noteProvider.fetchNotes(auth.userId!);
            },
            child: ListView(
              children: [
                // Ghi chú đã ghim
                if (noteProvider.pinnedNotes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '📌 GHI CHÚ GHIM',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  ...noteProvider.pinnedNotes.map((note) => NoteCard(note: note)),
                ],
                
                // Ghi chú bình thường
                if (noteProvider.normalNotes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Tất cả ghi chú',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                  ),
                  ...noteProvider.normalNotes.map((note) => NoteCard(note: note)),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateNoteDialog(context),
        backgroundColor: const Color(0xFF2E75B6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showCreateNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ghi chú mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'Tiêu đề...'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(hintText: 'Nội dung...'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isEmpty) return;
              
              final noteProvider = Provider.of<NoteProvider>(context, listen: false);
              
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
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}
