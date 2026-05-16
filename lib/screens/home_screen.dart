import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSearch = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<NoteProvider>(context, listen: false)
            .fetchNotes(auth.userId!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _showSearch = true);
    Future.delayed(
      const Duration(milliseconds: 100),
          () => _searchFocus.requestFocus(),
    );
  }

  void _closeSearch() {
    setState(() => _showSearch = false);
    _searchController.clear();
    Provider.of<NoteProvider>(context, listen: false).clearSearch();
  }

  void _onSearchChanged(String query) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Provider.of<NoteProvider>(context, listen: false)
        .search(query, auth.userId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showSearch ? _searchAppBar() : _normalAppBar(),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          // Loading
          if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Không có kết quả search
          if (noteProvider.isSearching && noteProvider.notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Không tìm thấy ghi chú nào',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Danh sách rỗng
          if (noteProvider.notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_add_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Chưa có ghi chú nào. Hãy nhấn + để thêm!'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final auth =
              Provider.of<AuthProvider>(context, listen: false);
              await noteProvider.fetchNotes(auth.userId!);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                // Kết quả search — hiện flat list không phân nhóm
                if (noteProvider.isSearching) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '${noteProvider.notes.length} kết quả',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                  ...noteProvider.notes.map(
                        (note) => NoteCard(
                      note: note,
                      searchQuery: _searchController.text, // highlight
                      onTap: () => _openEditor(note),
                    ),
                  ),
                ] else ...[
                  // Ghi chú ghim
                  if (noteProvider.pinnedNotes.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        '📌 GHI CHÚ GHIM',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    ...noteProvider.pinnedNotes.map(
                          (note) => NoteCard(
                        note: note,
                        onTap: () => _openEditor(note),
                      ),
                    ),
                  ],

                  // Ghi chú bình thường
                  if (noteProvider.normalNotes.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'Tất cả ghi chú',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                    ...noteProvider.normalNotes.map(
                          (note) => NoteCard(
                        note: note,
                        onTap: () => _openEditor(note),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: _showSearch
          ? null // ẩn FAB khi đang search
          : FloatingActionButton(
        onPressed: () => _openEditor(null),
        backgroundColor: _primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── AppBar bình thường ──
  AppBar _normalAppBar() {
    return AppBar(
      title: const Text('Smart Note'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Tìm kiếm',
          onPressed: _openSearch,
        ),
        Consumer<AuthProvider>(
          builder: (context, auth, child) => PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
            itemBuilder: (_) => [
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
          ),
        ),
      ],
    );
  }

  // ── AppBar search mode ──
  AppBar _searchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Tìm kiếm ghi chú...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey),
        ),
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
              _searchFocus.requestFocus();
            },
          ),
      ],
    );
  }

  void _openEditor(Note? note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
    );
  }
}