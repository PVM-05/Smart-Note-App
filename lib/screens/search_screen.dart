// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import '../core/app_strings.dart';
import '../core/design/app_colors.dart';
import '../widgets/empty_state.dart';
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
  final bool _isGrid = false; // Mặc định hiển thị danh sách dọc trực quan chuẩn Keep style

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

    // Ghép tất cả token (has:image, has:audio, has:url, label:"...") thành một chuỗi query hoàn chỉnh
    final tokenQuery = _activeFilters.map((f) => f.token).join(' ');
    final textQuery = _searchController.text.trim();

    // Câu lệnh gửi xuống DB = Tổng hợp mã Token của Chip + Văn bản đang gõ
    final combinedQuery = '$tokenQuery $textQuery'.trim();

    Provider.of<NoteProvider>(context, listen: false).search(combinedQuery, auth.userId ?? '');
    setState(() {}); // Cập nhật lại giao diện UI
  }

  void _onSearchChanged(String query) {
    _triggerSearch();
  }

  // Khi bấm vào 1 khối Lọc ở dưới -> Thêm thành dạng Chip bám vào thanh tìm kiếm
  void _onFilterTap(String label, String token) {
    // Kiểm tra tránh trùng lặp Chip lọc cùng loại
    if (!_activeFilters.any((f) => f.token == token)) {
      setState(() {
        _activeFilters.add(FilterToken(label, token));
      });
      // Xóa văn bản đang gõ để tập trung hiển thị bộ lọc danh mục vừa chọn
      _searchController.clear();
      _triggerSearch();
    }
    _focusNode.requestFocus(); // Tự động lấy lại tiêu điểm mở bàn phím
  }

  // Xóa một viên Chip lọc
  void _removeFilter(FilterToken filter) {
    setState(() {
      _activeFilters.remove(filter);
    });
    _triggerSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(context),
            Expanded(
              child: Consumer<NoteProvider>(
                builder: (context, noteProvider, child) {
                  // Không tìm thấy kết quả phù hợp
                  if (noteProvider.isSearching && noteProvider.notes.isEmpty) {
                    return _buildEmptyResult();
                  }

                  // Đang gõ chữ HOẶC đang kích hoạt Chip lọc đa phương tiện -> Hiện danh sách Note kết quả
                  if (_searchController.text.isNotEmpty || _activeFilters.isNotEmpty || noteProvider.isSearching) {
                    return _buildSearchResults(context, noteProvider);
                  }

                  // Trạng thái mặc định ban đầu -> Hiện menu các bộ lọc gợi ý
                  return _buildPredefinedFilters(context, noteProvider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: AppColors.searchBarBackground(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary(context).withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
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
                hintText: _activeFilters.isEmpty ? 'Tìm kiếm ghi chú của bạn' : '',
                hintStyle: GoogleFonts.outfit(color: AppColors.textMetadata(context).withValues(alpha: 0.6), fontSize: 15, fontWeight: FontWeight.w300,),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),

                // --- VẼ VIÊN CHIP LỌC ĐỘNG NẰM TRONG THANH SEARCH ---
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                prefixIcon: _activeFilters.isEmpty
                    ? const SizedBox(width: 8) // Khoảng cách đệm tinh tế nếu trống chip
                    : Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
                  margin: const EdgeInsets.only(left: 4, right: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal, // Cuộn ngang mượt mà nếu chọn đồng thời nhiều loại bộ lọc
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _activeFilters.map((f) => _buildChip(context, f)).toList(),
                    ),
                  ),
                ),
              ),
              style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500),
            ),
          ),

          if (_searchController.text.isNotEmpty || _activeFilters.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, size: 20, color: AppColors.textMetadata(context)),
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

  // Thiết kế giao diện viên Chip lọc đa phương tiện
  Widget _buildChip(BuildContext context, FilterToken filter) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.filterChipBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            filter.label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.filterChipForeground(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeFilter(filter),
            child: Icon(Icons.cancel, size: 16, color: AppColors.filterChipForeground(context)),
          ),
        ],
      ),
    );
  }

  // KHU VỰC HIỂN THỊ CÁC BỘ LỌC ĐA PHƯƠNG TIỆN GỢI Ý (Đầy đủ Hình ảnh, Âm thanh, URL, Nhãn dán)
  Widget _buildPredefinedFilters(BuildContext context, NoteProvider noteProvider) {
    final labels = noteProvider.allLabels;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===================================
            // DANH MỤC LOẠI ĐA PHƯƠNG TIỆN (MEDIA FILTERS)
            // ===================================
            Text('Loại ghi chú', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMetadata(context), letterSpacing: 0.8)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 20,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                _buildFilterIconItem(context, Icons.check_box_outlined, 'Danh sách', () => _onFilterTap('Danh sách', 'has:list')),
                _buildFilterIconItem(context, Icons.image_outlined, 'Hình ảnh', () => _onFilterTap('Hình ảnh', 'has:image')),
                _buildFilterIconItem(context, Icons.mic_none_rounded, 'Âm thanh', () => _onFilterTap('Âm thanh', 'has:audio')),
                _buildFilterIconItem(context, Icons.link_rounded, 'URL', () => _onFilterTap('URL', 'has:url')),
              ],
            ),

            const SizedBox(height: 36),

            // ===================================
            // DANH MỤC NHÃN DÁN (TAGS)
            // ===================================
            if (labels.isNotEmpty) ...[
              Text('Nhãn dán', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMetadata(context), letterSpacing: 0.8)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 20,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: labels.map((label) {
                  return _buildFilterIconItem(context, Icons.label_outline_rounded, label, () => _onFilterTap(label, 'label:"$label"'));
                }).toList(),
              ),
              const SizedBox(height: 36),
            ],

            // ===================================
            // DANH MỤC TRẠNG THÁI GHI CHÚ
            // ===================================
            Text('Trạng thái', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMetadata(context), letterSpacing: 0.8)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 20,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                _buildFilterIconItem(context, Icons.push_pin_outlined, 'Được ghim', () => _onFilterTap('Được ghim', 'is:pinned')),
                _buildFilterIconItem(context, Icons.archive_outlined, 'Kho Lưu trữ', () => _onFilterTap('Lưu trữ', 'is:archived')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterIconItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.filterIconCircleBackground(context),
                border: Border.all(
                  color: isDark
                      ? AppColors.divider(context)
                      : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Icon(icon, color: AppColors.filterIconColor(context), size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textPrimary(context), fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResult() {
    return EmptyStateWidget(
      icon: Icons.search_off_rounded,
      title: AppStrings.emptySearchTitle,
      subtitle: AppStrings.emptySearchSubtitle,
      actionLabel: AppStrings.emptySearchAction,
      onAction: () {
        _searchController.clear();
        setState(() {
          _activeFilters.clear();
        });
        _triggerSearch();
        _focusNode.requestFocus();
      },
    );
  }

  Widget _buildSearchResults(BuildContext context, NoteProvider provider) {
    final notes = provider.notes;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text(
              'TÌM THẤY ${notes.length} GHI CHÚ KHỚP',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMetadata(context),
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        if (_isGrid)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              itemBuilder: (context, index) => _buildNoteItem(notes[index], provider),
              childCount: notes.length,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
      // ⚡ LOẠI BỎ BOXDECORATION VIỀN XÁM THỪA để NoteCard hiển thị phẳng hoàn toàn đồng bộ với Keep View
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
          ).then((_) {
            if (!mounted) return;
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