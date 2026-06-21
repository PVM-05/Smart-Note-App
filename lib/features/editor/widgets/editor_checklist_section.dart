import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';
import '../../../models/checklist_item.dart';

class EditorChecklistSection extends StatelessWidget {
  final List<ChecklistItem> checklistItems;
  final String? noteColor;
  final VoidCallback onAddChecklistItem;
  final ValueChanged<int> onAddChecklistItemAfter;
  final ValueChanged<int> onRemoveChecklistItem;
  final Function(int, String) onItemTextChanged;
  final Function(int, bool) onItemChecked;
  final void Function(int, int) onReorder;
  final VoidCallback onExitChecklistMode;

  const EditorChecklistSection({
    super.key,
    required this.checklistItems,
    required this.noteColor,
    required this.onAddChecklistItem,
    required this.onAddChecklistItemAfter,
    required this.onRemoveChecklistItem,
    required this.onItemTextChanged,
    required this.onItemChecked,
    required this.onReorder,
    required this.onExitChecklistMode,
  });

  Widget _buildChecklistTile(
      BuildContext context, ChecklistItem item, int index) {
    final isCustomColor = noteColor != null;
    final resolvedColor = noteColor != null ? AppColors.resolveNoteBackground(context, noteColor) : null;
    final onDarkNoteBg = resolvedColor != null && resolvedColor.computeLuminance() < 0.45;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    final Color textThemeColor = isCustomColor
        ? (onDarkNoteBg ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
        : (isDarkTheme ? const Color(0xFFFFFFFF) : const Color(0xFF000000));
        
    final Color hintColor = isCustomColor
        ? (onDarkNoteBg ? const Color(0xFFE2E8F0) : const Color(0xFF4A5568))
        : (isDarkTheme ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368));
        
    final Color itemIconColor = isCustomColor
        ? (onDarkNoteBg ? Colors.white54 : const Color(0xFF64748B))
        : (isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade500);

    const primaryColor = AppColors.primary;

    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.drag_indicator,
                color: itemIconColor,
                size: 20,
              ),
            ),
          ),
          // Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: item.checked,
              onChanged: (val) => onItemChecked(index, val ?? false),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              activeColor: primaryColor,
              side: BorderSide(
                color: isCustomColor
                    ? (onDarkNoteBg ? Colors.white70 : const Color(0xFF475569))
                    : (isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: TextField(
              controller: TextEditingController(text: item.text)
                ..selection = TextSelection.collapsed(offset: item.text.length),
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: item.checked
                    ? (onDarkNoteBg ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade500)
                    : textThemeColor,
                decoration: item.checked
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Mục danh sách',
                hintStyle: TextStyle(color: hintColor),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) => onItemTextChanged(index, val),
              onSubmitted: (_) => onAddChecklistItemAfter(index),
              textInputAction: TextInputAction.next,
            ),
          ),
          // Nút xóa item
          if (checklistItems.length > 1)
            GestureDetector(
              onTap: () => onRemoveChecklistItem(index),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.close,
                  color: itemIconColor,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustomColor = noteColor != null;
    final resolvedColor = noteColor != null ? AppColors.resolveNoteBackground(context, noteColor) : null;
    final onDarkNoteBg = resolvedColor != null && resolvedColor.computeLuminance() < 0.45;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    final Color headerIconColor = isCustomColor
        ? (onDarkNoteBg ? Colors.white70 : const Color(0xFF64748B))
        : (isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600);

    final Color hintColor = isCustomColor
        ? (onDarkNoteBg ? const Color(0xFFE2E8F0) : const Color(0xFF4A5568))
        : (isDarkTheme ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368));

    return Column(
      children: [
        // Header: Icon checklist + nút X để thoát checklist mode
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.drag_indicator,
                  color: headerIconColor.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 4),
              Icon(Icons.check_box_outline_blank,
                  color: headerIconColor, size: 20),
              const Spacer(),
              GestureDetector(
                onTap: onExitChecklistMode,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      Icon(Icons.close, color: headerIconColor, size: 22),
                ),
              ),
            ],
          ),
        ),
        // Checklist items
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: checklistItems.length + 1, // +1 cho nút "+ Mục danh sách"
          onReorderItem: (oldIndex, newIndex) => onReorder(oldIndex, newIndex),
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final elevation =
                    Tween<double>(begin: 0, end: 4).animate(animation).value;
                return Material(
                  elevation: elevation,
                  color: resolvedColor ?? AppColors.surface(context),
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              child: child,
            );
          },
          itemBuilder: (context, index) {
            // Nút "+ Mục danh sách" ở cuối
            if (index == checklistItems.length) {
              return Padding(
                key: const ValueKey('__add_item__'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GestureDetector(
                  onTap: onAddChecklistItem,
                  child: Row(
                    children: [
                      const SizedBox(width: 28), // Align với drag handle
                      Icon(Icons.add, color: hintColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Mục danh sách',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final item = checklistItems[index];
            return _buildChecklistTile(context, item, index);
          },
        ),
      ],
    );
  }
}
