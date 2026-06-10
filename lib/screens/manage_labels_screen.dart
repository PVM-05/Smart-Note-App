// lib/screens/manage_labels_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/note_provider.dart';
import '../core/design/app_colors.dart';
import '../core/app_localizations.dart';

class ManageLabelsScreen extends StatefulWidget {
  const ManageLabelsScreen({super.key});

  @override
  State<ManageLabelsScreen> createState() => _ManageLabelsScreenState();
}

class _ManageLabelsScreenState extends State<ManageLabelsScreen> {
  final _createController = TextEditingController();
  bool _isWritingNew = false;

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  void _createNewLabel(NoteProvider provider) {
    final text = _createController.text.trim();
    if (text.isNotEmpty) {
      provider.addLabel(text);
      _createController.clear();
      FocusScope.of(context).unfocus();
    }
    setState(() => _isWritingNew = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NoteProvider>(context);
    final labels = provider.allLabels;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(AppLocalizations.translate(context, 'editLabelsTitle'), style: GoogleFonts.spaceGrotesk(fontSize: 18, color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary(context),
      ),
      body: Column(
        children: [
          // ── Ô TẠO NHÃN MỚI TRÊN CÙNG ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider(context))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isWritingNew ? Icons.close : Icons.add, color: AppColors.textSecondary(context)),
                  onPressed: () {
                    if (_isWritingNew) {
                      _createController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() => _isWritingNew = false);
                    } else {
                      setState(() => _isWritingNew = true);
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _createController,
                    onChanged: (val) {
                      if ((val.isNotEmpty) != _isWritingNew) {
                        setState(() => _isWritingNew = val.isNotEmpty);
                      }
                    },
                    style: GoogleFonts.inter(color: AppColors.textPrimary(context), fontSize: 15),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.translate(context, 'createNewLabel'),
                      border: InputBorder.none,
                      hintStyle: GoogleFonts.inter(color: AppColors.placeholder(context)),
                    ),
                    onSubmitted: (_) => _createNewLabel(provider),
                  ),
                ),
                if (_isWritingNew)
                  IconButton(
                    icon: const Icon(Icons.check, color: AppColors.primary),
                    onPressed: () => _createNewLabel(provider),
                  ),
              ],
            ),
          ),

          // ── DANH SÁCH CÁC NHÃN ĐANG CÓ ──
          Expanded(
            child: ListView.builder(
              itemCount: labels.length,
              itemBuilder: (context, index) {
                return _EditableLabelRow(labelName: labels[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Widget dòng nhãn riêng biệt hỗ trợ đổi hiệu ứng Icon động khi Focus giống Keep
class _EditableLabelRow extends StatefulWidget {
  final String labelName;
  const _EditableLabelRow({required this.labelName});

  @override
  State<_EditableLabelRow> createState() => _EditableLabelRowState();
}

class _EditableLabelRowState extends State<_EditableLabelRow> {
  late TextEditingController _editController;
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.labelName);
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveRename(NoteProvider provider) {
    if (_editController.text.trim() != widget.labelName) {
      provider.renameLabel(widget.labelName, _editController.text.trim());
    }
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NoteProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Icon Trái: Bình thường hiện nhãn, khi focus biến thành Thùng rác xóa nhanh
          IconButton(
            icon: Icon(
              _hasFocus ? Icons.delete_outline : Icons.label_outline,
              color: _hasFocus ? AppColors.error : AppColors.textSecondary(context),
            ),
            onPressed: () {
              if (_hasFocus) {
                provider.deleteLabel(widget.labelName);
              } else {
                _focusNode.requestFocus();
              }
            },
          ),
          Expanded(
            child: TextField(
              controller: _editController,
              focusNode: _focusNode,
              decoration: const InputDecoration(border: InputBorder.none),
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary(context)),
              onSubmitted: (_) => _saveRename(provider),
            ),
          ),
          // Icon Phải: Bình thường hiện cây bút, khi chỉnh sửa biến thành dấu Tích hoàn tất
          IconButton(
            icon: Icon(
              _hasFocus ? Icons.check : Icons.edit_outlined,
              color: _hasFocus ? AppColors.primary : AppColors.textMetadata(context),
              size: 20,
            ),
            onPressed: () {
              if (_hasFocus) {
                _saveRename(provider);
              } else {
                _focusNode.requestFocus();
              }
            },
          ),
        ],
      ),
    );
  }
}