import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../core/design/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import '../core/app_strings.dart';
import '../widgets/note_card_shimmer.dart';
import '../widgets/empty_state.dart';
import '../widgets/main_drawer.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userId != null) {
        Provider.of<NoteProvider>(context, listen: false)
            .fetchTrashNotes(auth.userId!);
      }
    });
  }

  Future<void> _confirmDeleteSelected(NoteProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa vĩnh viễn?'),
        content: Text(
            'Hành động này không thể hoàn tác. Bạn có chắc muốn xóa vĩnh viễn ${provider.selectedTrashNoteIds.length} ghi chú đã chọn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.deleteForeverSelectedTrashNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, provider, child) {
        final isSelectionMode = provider.isTrashSelectionMode;

        return Scaffold(
          backgroundColor: AppColors.background(context),
          drawer: const MainDrawer(currentRoute: '/trash'),

          // Chuyển mạch AppBar tùy theo trạng thái chọn
          appBar: isSelectionMode
              ? _selectionAppBar(provider)
              : _normalAppBar(context),

          body: _buildBody(provider),
        );
      },
    );
  }

  Widget _buildBody(NoteProvider provider) {
    if (provider.isLoading && provider.trashNotes.isEmpty) {
      return MasonryGridView.count(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: 6,
        itemBuilder: (context, index) => const NoteCardShimmer(isGrid: true),
      );
    }

    if (provider.trashNotes.isEmpty) {
      return _buildEmptyTrash();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Ghi chú trong Thùng rác sẽ bị xóa tự động sau 7 ngày.',
            style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textMetadata(context)),
          ),
        ),
        Expanded(
          child: MasonryGridView.count(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: provider.trashNotes.length,
            itemBuilder: (context, index) {
              final note = provider.trashNotes[index];
              return _buildTrashNoteItem(note, provider);
            },
          ),
        ),
      ],
    );
  }

  // WIDGET XỬ LÝ CHẠM VÀ CHỌN (MULTI-SELECT)
  Widget _buildTrashNoteItem(Note note, NoteProvider provider) {
    final isSelected = provider.selectedTrashNoteIds.contains(note.id);
    final isSelectionMode = provider.isTrashSelectionMode;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface(context),
          child: InkWell(
            // NHẤN GIỮ: Bật chế độ chọn
            onLongPress: () {
              provider.toggleTrashSelection(note.id);
            },
            // CHẠM NHẸ: Tích chọn hoặc mở Menu tùy chọn dưới đáy
            onTap: () {
              if (isSelectionMode) {
                provider.toggleTrashSelection(note.id);
              } else {
                _showTrashOptions(context, note);
              }
            },
            child: Opacity(
              opacity: 0.7, // Làm mờ ghi chú đi một chút để phân biệt với Home
              child: NoteCard(note: note),
            ),
          ),
        ),
      ),
    );
  }

  // APPBAR BÌNH THƯỜNG
  AppBar _normalAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background(context),
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: AppColors.textPrimary(context)),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        'Thùng rác',
        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18),
      ),
      actions: [
        // Thêm nút Xóa toàn bộ Thùng rác nhanh (Tùy chọn)
        IconButton(
          icon: Icon(Icons.delete_sweep, color: AppColors.textPrimary(context)),
          tooltip: 'Dọn sạch thùng rác',
          onPressed: () {
            if (Provider.of<NoteProvider>(context, listen: false).trashNotes.isNotEmpty) {
              // Bạn có thể viết thêm 1 hàm clearTrash() trong Provider nếu muốn
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng dọn sạch đang phát triển')),
              );
            }
          },
        ),
      ],
    );
  }

  // APPBAR KHI CHỌN NHIỀU
  AppBar _selectionAppBar(NoteProvider provider) {
    return AppBar(
      backgroundColor: AppColors.inputBackground(context),
      leading: IconButton(
        icon: Icon(Icons.close, color: AppColors.textPrimary(context)),
        onPressed: () => provider.clearTrashSelection(),
      ),
      title: Text(
        '${provider.selectedTrashNoteIds.length} đã chọn',
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.restore, color: AppColors.primary),
          tooltip: 'Khôi phục',
          onPressed: () => provider.restoreSelectedTrashNotes(),
        ),
        IconButton(
          icon: const Icon(Icons.delete_forever, color: AppColors.error),
          tooltip: 'Xóa vĩnh viễn',
          onPressed: () => _confirmDeleteSelected(provider),
        ),
      ],
    );
  }

  // BOTTOM SHEET KHI CHẠM NHẸ VÀO 1 NOTE (BÌNH THƯỜNG)
  // Tìm đến hàm _showTrashOptions ở cuối file lib/screens/trash_screen.dart
  // và sửa lại nút ListTile Xóa vĩnh viễn:

  void _showTrashOptions(BuildContext context, Note note) { // Nhớ ép kiểu 'Note' cho tham số truyền vào
    final provider = Provider.of<NoteProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore, color: AppColors.primary),
              title: const Text('Khôi phục ghi chú'),
              onTap: () {
                provider.restoreNote(note.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã khôi phục ghi chú')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.error),
              title: Text('Xóa vĩnh viễn', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context); // Đóng BottomSheet trước

                // Hiển thị thông báo trạng thái dọn dẹp ngầm
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang xóa vĩnh viễn tài liệu đám mây...'), duration: Duration(seconds: 2)),
                );

                // Gọi hàm xử lý dọn sạch cả DB lẫn tệp tin đính kèm Cloudinary
                await provider.deleteNoteForever(note.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTrash() {
    return const EmptyStateWidget(
      icon: Icons.delete_outline,
      title: AppStrings.emptyTrashTitle,
      subtitle: AppStrings.emptyTrashSubtitle,
    );
  }
}