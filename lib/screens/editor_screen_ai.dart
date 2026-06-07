// lib/screens/editor_screen_ai.dart
// Phần mở rộng AI của EditorScreen, sử dụng `part of`.
// Extension này dùng `setState` của State — được suppress bằng
// ignore_for_file vì đây là pattern hợp lệ trong cặp part/part-of.
// ignore_for_file: invalid_use_of_protected_member
part of 'editor_screen.dart';

extension _EditorScreenAi on _EditorScreenState {
  // ── BOTTOM SHEET CHỌN TÍNH NĂNG AI ──
  void _showAiOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider(context),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF3B82F6),
                        Color(0xFF8B5CF6),
                        Color(0xFFEC4899),
                      ],
                    ).createShader(bounds),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.translate(context, 'aiAssistantTitle'),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.title, color: AppColors.primary),
              ),
              title: Text(AppLocalizations.translate(context, 'aiGenerateTitle')),
              subtitle: Text(AppLocalizations.translate(context, 'aiGenerateTitleSub')),
              onTap: () {
                Navigator.pop(context);
                _generateTitleFromContent();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.summarize_outlined, color: AppColors.primary),
              ),
              title: Text(AppLocalizations.translate(context, 'aiSummarize')),
              subtitle: Text(AppLocalizations.translate(context, 'aiSummarizeSub')),
              onTap: () {
                Navigator.pop(context);
                _summarizeCurrentNote();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.checklist_rounded, color: AppColors.primary),
              ),
              title: Text(AppLocalizations.translate(context, 'aiMakeChecklist')),
              subtitle: Text(AppLocalizations.translate(context, 'aiMakeChecklistSub')),
              onTap: () {
                Navigator.pop(context);
                _makeChecklistFromCurrentNote();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.label_outline, color: AppColors.primary),
              ),
              title: Text(AppLocalizations.translate(context, 'aiSuggestLabels')),
              subtitle: Text(AppLocalizations.translate(context, 'aiSuggestLabelsSub')),
              onTap: () {
                Navigator.pop(context);
                _suggestTagsForCurrentNote();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── TÓM TẮT GHI CHÚ ──
  void _summarizeCurrentNote() async {
    final String contentText;

    if (_isChecklistMode) {
      contentText = _checklistItems
          .map((item) => item.text)
          .where((text) => text.trim().isNotEmpty)
          .join('\n');
    } else {
      contentText = _quillController.document.toPlainText().trim();
    }

    if (contentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hãy nhập nội dung trước khi dùng AI'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isAiLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final summary = await _geminiAiService.summarizeNote(
        title: _titleController.text.trim(),
        content: contentText,
      );

      if (mounted) Navigator.pop(context);

      if (summary.isEmpty) {
        throw Exception('Không nhận được bản tóm tắt từ AI.');
      }

      if (mounted) _showAiSummaryPreviewDialog(summary);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyAiError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  // ── DIALOG PREVIEW TÓM TẮT ──
  void _showAiSummaryPreviewDialog(String summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                ],
              ).createShader(bounds),
              child: const Icon(Icons.summarize_outlined,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.translate(context, 'aiSummaryTitle'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            summary,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.translate(context, 'close'),
              style: GoogleFonts.inter(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _insertAiSummary(summary);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              AppLocalizations.translate(context, 'aiSummaryInsert'),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CHÈN TÓM TẮT VÀO GHI CHÚ ──
  void _insertAiSummary(String summary) {
    if (_isChecklistMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.translate(context, 'aiCannotInsertInChecklist')),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
      return;
    }

    final insertText = AppLocalizations.translate(context, 'aiSummaryInsertText') + summary;
    final documentLength = _quillController.document.length;
    final insertIndex = documentLength > 0 ? documentLength - 1 : 0;

    _quillController.document.insert(insertIndex, insertText);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: insertIndex + insertText.length),
      ChangeSource.local,
    );

    _onTextChanged();
  }

  // ── CHUYỂN THÀNH CHECKLIST ──
  void _makeChecklistFromCurrentNote() async {
    if (_isChecklistMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.translate(context, 'aiAlreadyChecklist')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final contentText = _quillController.document.toPlainText().trim();

    if (contentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.translate(context, 'aiNeedContent')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isAiLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final checklistText = await _geminiAiService.makeChecklist(contentText);

      if (mounted) Navigator.pop(context);

      if (checklistText.trim().isEmpty) {
        throw Exception('Không nhận được checklist từ AI.');
      }

      if (mounted) _showChecklistPreviewDialog(checklistText);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyAiError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  // ── DIALOG PREVIEW CHECKLIST ──
  void _showChecklistPreviewDialog(String checklistText) {
    final items = _parseAiChecklistItems(checklistText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.checklist_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.translate(context, 'aiChecklistTitle'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: items.isEmpty
              ? Text(
                  checklistText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textPrimary(context),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_box_outline_blank,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            items[index].text,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.translate(context, 'close'),
              style: GoogleFonts.inter(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyAiChecklist(items);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              AppLocalizations.translate(context, 'aiUseChecklist'),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PARSE KẾT QUẢ AI THÀNH CHECKLIST ITEMS ──
  List<ChecklistItem> _parseAiChecklistItems(String text) {
    final lines = text.split('\n');
    final items = <ChecklistItem>[];

    for (final line in lines) {
      var value = line.trim();
      if (value.isEmpty) continue;

      value = value
          .replaceFirst(RegExp(r'^[-*•]\s*'), '')
          .replaceFirst(RegExp(r'^\d+[.)\s]\s*'), '')
          .trim();

      if (value.isEmpty) continue;

      items.add(ChecklistItem(text: value));
    }

    return items;
  }

  // ── ÁP DỤNG CHECKLIST VÀO NOTE ──
  void _applyAiChecklist(List<ChecklistItem> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.translate(context, 'aiNoChecklist')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isChecklistMode = true;
      _checklistItems = items;
    });

    _onTextChanged();
  }

  // ── TẠO TIÊU ĐỀ TỪ NỘI DUNG ──
  void _generateTitleFromContent() async {
    final String contentText;
    if (_isChecklistMode) {
      contentText = _checklistItems
          .map((item) => item.text)
          .where((text) => text.trim().isNotEmpty)
          .join(' ');
    } else {
      contentText = _quillController.document.toPlainText().trim();
    }

    if (contentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hãy nhập nội dung trước khi dùng AI'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isAiLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(width: 20),
              Text(
                AppLocalizations.translate(context, 'aiProcessing'),
                style: GoogleFonts.inter(color: AppColors.textPrimary(context)),
              ),
            ],
          ),
        );
      },
    );

    try {
      final suggestedTitle = await _geminiAiService.suggestTitle(contentText);

      if (mounted) Navigator.of(context).pop();

      if (suggestedTitle.isEmpty) {
        throw Exception('Không nhận được tiêu đề gợi ý từ AI.');
      }

      if (mounted) _showTitlePreviewDialog(suggestedTitle);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyAiError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  // ── DIALOG PREVIEW TIÊU ĐỀ ──
  void _showTitlePreviewDialog(String suggestedTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                ],
              ).createShader(bounds),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.translate(context, 'aiTitleSuggestTitle'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.translate(context, 'aiTitleProposed'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBackground(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider(context)),
              ),
              child: Text(
                suggestedTitle,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.translate(context, 'cancel'),
              style: GoogleFonts.inter(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _titleController.text = suggestedTitle);
              _onTextChanged();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              AppLocalizations.translate(context, 'aiUseTitle'),
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── GỢI Ý NHÃN ──
  void _suggestTagsForCurrentNote() async {
    final String titleText = _titleController.text.trim();
    final String contentText;

    if (_isChecklistMode) {
      contentText = _checklistItems
          .map((item) => item.text)
          .where((text) => text.trim().isNotEmpty)
          .join(' ');
    } else {
      contentText = _quillController.document.toPlainText().trim();
    }

    if (titleText.isEmpty && contentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.translate(context, 'aiNeedTitleOrContent')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isAiLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final tagsText = await _geminiAiService.suggestTags(
        title: titleText,
        content: contentText,
      );

      if (mounted) Navigator.pop(context);

      if (tagsText.trim().isEmpty) {
        throw Exception('Không nhận được gợi ý nhãn từ AI.');
      }

      final suggestedTags = _parseAiTags(tagsText);

      if (suggestedTags.isEmpty) {
        throw Exception('Không tìm thấy nhãn hợp lệ từ gợi ý của AI.');
      }

      if (mounted) _showTagsPreviewDialog(suggestedTags);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyAiError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  // ── PARSE KẾT QUẢ AI THÀNH NHÃN ──
  List<String> _parseAiTags(String text) {
    final delimiters = RegExp(r'[,;\n]');
    return text
        .split(delimiters)
        .map((tag) {
          var cleanTag = tag.trim();
          cleanTag = cleanTag
              .replaceAll(RegExp(r'^[-*•"\x27]\s*'), '')
              .replaceAll(RegExp(r'["\x27]$'), '')
              .trim();
          return cleanTag;
        })
        .where((tag) => tag.isNotEmpty && tag.length <= 20)
        .toList();
  }

  // ── DIALOG CHỌN NHÃN GỢI Ý ──
  void _showTagsPreviewDialog(List<String> suggestedTags) {
    final List<String> selectedTags = List.from(suggestedTags);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF3B82F6),
                        Color(0xFF8B5CF6),
                        Color(0xFFEC4899),
                      ],
                    ).createShader(bounds),
                    child: const Icon(Icons.label_outline,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.translate(context, 'aiTagsTitle'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.translate(context, 'aiTagsDesc'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestedTags.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return FilterChip(
                          label: Text(
                            tag,
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary(context),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: isDark
                              ? const Color(0xFF2E303D)
                              : const Color(0xFFF1F5F9),
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider(context),
                            ),
                          ),
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.translate(context, 'cancel'),
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary(context)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (selectedTags.isNotEmpty) {
                      _applySuggestedTags(selectedTags);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.translate(context, 'aiAddLabels'),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── THÊM NHÃN ĐÃ CHỌN VÀO GHI CHÚ ──
  void _applySuggestedTags(List<String> selectedTags) {
    setState(() {
      for (final tag in selectedTags) {
        if (!_tags.contains(tag)) {
          _tags.add(tag);
        }
      }
    });
    _onTextChanged();
  }

  // ── PHƯƠNG THỨC XỬ LÝ LỖI AI THÂN THIỆN ──
  String _friendlyAiError(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('socket') ||
        message.contains('host lookup') ||
        message.contains('failed host lookup') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('no address associated with hostname')) {
      return AppLocalizations.translate(context, 'aiNetworkError');
    }

    if (message.contains('high demand') ||
        message.contains('try again later') ||
        message.contains('server error') ||
        message.contains('500')) {
      return AppLocalizations.translate(context, 'aiOverloadError');
    }

    if (message.contains('permission') ||
        message.contains('unauthorized') ||
        message.contains('403')) {
      return AppLocalizations.translate(context, 'aiPermissionError');
    }

    return AppLocalizations.translate(context, 'aiGenericError');
  }
}
