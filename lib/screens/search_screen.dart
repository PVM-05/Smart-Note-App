// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

// Class lưu trữ thông tin của một bộ lọc (Bao gồm Tên hiển thị và Mã Token để gửi xuống DB)
class FilterToken {
  final String label;
  final String token;
  FilterToken(this.label, this.token);
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isGrid = false;

  // Danh sách quản lý các "Từ nền / Chip" đang được chọn
  final List<FilterToken> _activeFilters = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 50), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Hàm tổng hợp query và gửi lệnh tìm kiếm
  void _triggerSearch() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Ghép tất cả token (has:image, label:"...") thành một chuỗi
    final tokenQuery = _activeFilters.map((f) => f.token).join(' ');
    final textQuery = _searchController.text.trim();

    // Câu lệnh gửi xuống DB = Tổng hợp Chip + Text đang gõ
    final combinedQuery = '$tokenQuery $textQuery'.trim();

    Provider.of<NoteProvider>(context, listen: false).search(combinedQuery, auth.userId ?? '');
    setState(() {}); // Cập nhật lại UI
  }

  void _onSearchChanged(String query) {
    _triggerSearch();
  }

  // Khi bấm vào 1 khối Lọc ở dưới -> Thêm thành dạng Chip
  void _onFilterTap(String label, String token) {
    // Kiểm tra tránh trùng lặp Chip
    if (!_activeFilters.any((f) => f.token == token)) {
      setState(() {
        _activeFilters.add(FilterToken(label, token));
      });
      // Xóa chữ đang gõ dở nếu muốn, hoặc cứ giữ nguyên để cộng dồn
      _searchController.clear();
      _triggerSearch();
    }
    _focusNode.requestFocus(); // Mở bàn phím để gõ tiếp
  }

  // Xóa một Chip
  void _removeFilter(FilterToken filter) {
    setState(() {
      _activeFilters.remove(filter);
    });
    _triggerSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: Consumer<NoteProvider>(
                builder: (context, noteProvider, child) {
                  // Không có kết quả
                  if (noteProvider.isSearching && noteProvider.notes.isEmpty) {
                    return _buildEmptyResult();
                  }

                  // Đang gõ chữ HOẶC đang có Chip lọc -> Hiện list note
                  if (_searchController.text.isNotEmpty || _activeFilters.isNotEmpty || noteProvider.isSearching) {
                    return _buildSearchResults(noteProvider);
                  }

                  // Mặc định -> Hiện nút lọc gợi ý
                  return _buildPredefinedFilters(noteProvider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      constraints: const BoxConstraints(minHeight: 48), // Dùng constraints để dãn linh hoạt
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
            onPressed: () {
              Provider.of<NoteProvider>(context, listen: false).clearSearch();
              Navigator.pop(context);
            },
          ),

          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: _activeFilters.isEmpty ? 'Tìm kiếm' : '',
                hintStyle: GoogleFonts.roboto(color: const Color(0xFF64748B), fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),

                // --- VẼ CHIP BÊN TRONG TEXTFIELD ---
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                prefixIcon: _activeFilters.isEmpty
                    ? const SizedBox(width: 4) // Đệm nhẹ nếu không có chip
                    : Container(
                  // Khóa maxWidth khoảng 55% màn hình để phần text luôn có không gian gõ
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
                  margin: const EdgeInsets.only(left: 4, right: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal, // Kéo ngang nếu có quá nhiều Chip
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _activeFilters.map((f) => _buildChip(f)).toList(),
                    ),
                  ),
                ),
              ),
              style: GoogleFonts.roboto(fontSize: 15, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
            ),
          ),

          // Nút Clear (X) sẽ xuất hiện nếu có gõ chữ HOẶC đang có gắn Chip
          if (_searchController.text.isNotEmpty || _activeFilters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20, color: Color(0xFF64748B)),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _activeFilters.clear();
                });
                _triggerSearch();
                _focusNode.requestFocus();
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // Giao diện của viên Chip từ nền (Background Token)
  Widget _buildChip(FilterToken filter) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.12), // Nền xanh nhạt chuẩn Google Keep
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            filter.label,
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: Colors.blue[800],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeFilter(filter),
            child: Icon(Icons.cancel, size: 16, color: Colors.blue[600]),
          ),
        ],
      ),
    );
  }

  // KHU VỰC HIỂN THỊ CÁC BỘ LỌC GỢI Ý
  Widget _buildPredefinedFilters(NoteProvider noteProvider) {
    final labels = noteProvider.allLabels;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 20, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // LOẠI
            // =========================
            Text('Loại', style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 20,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                _buildFilterIconItem(Icons.check_box_outlined, 'Danh sách', () => _onFilterTap('Danh sách', 'has:list')),
                _buildFilterIconItem(Icons.image_outlined, 'Hình ảnh', () => _onFilterTap('Hình ảnh', 'has:image')),
                _buildFilterIconItem(Icons.link, 'URL', () => _onFilterTap('URL', 'has:url')),
              ],
            ),

            const SizedBox(height: 36),

            // =========================
            // NHÃN
            // =========================
            if (labels.isNotEmpty) ...[
              Text('Nhãn', style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 18,
                runSpacing: 20,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: labels.map((label) {
                  return _buildFilterIconItem(Icons.label_outline, label, () => _onFilterTap(label, 'label:"$label"'));
                }).toList(),
              ),
              const SizedBox(height: 36),
            ],

            // =========================
            // TRẠNG THÁI
            // =========================
            Text('Trạng thái', style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 20,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                _buildFilterIconItem(Icons.push_pin_outlined, 'Được ghim', () => _onFilterTap('Được ghim', 'is:pinned')),
                _buildFilterIconItem(Icons.archive_outlined, 'Lưu trữ', () => _onFilterTap('Lưu trữ', 'is:archived')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterIconItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1.4),
                color: Colors.transparent,
              ),
              child: Icon(icon, color: const Color(0xFF1E293B), size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResult() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy ghi chú khớp',
            style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(NoteProvider provider) {
    final notes = provider.notes;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              '${notes.length} KẾT QUẢ TÌM THẤY',
              style: GoogleFonts.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        if (_isGrid)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              itemBuilder: (context, index) => _buildNoteItem(notes[index], provider),
              childCount: notes.length,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) => _buildNoteItem(notes[index], provider),
            ),
          ),
      ],
    );
  }

  Widget _buildNoteItem(Note note, NoteProvider provider) {
    return Container(
      margin: _isGrid ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
          ).then((_) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            provider.refreshNotes(auth.userId!);
          });
        },
        child: NoteCard(
          note: note,
          searchQuery: _searchController.text,
          isGrid: _isGrid,
        ),
      ),
    );
  }
}