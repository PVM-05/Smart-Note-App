import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

class EditorFormatToolbar extends StatelessWidget {
  final QuillController quillController;
  final VoidCallback onClose;
  final bool isButtonsDisabled;

  const EditorFormatToolbar({
    super.key,
    required this.quillController,
    required this.onClose,
    required this.isButtonsDisabled,
  });

  bool _isAttributeActive(Attribute attr) {
    if (attr.key == Attribute.header.key) {
      final value = quillController
          .getSelectionStyle()
          .attributes[Attribute.header.key]
          ?.value;
      return value == attr.value;
    }
    if (attr.key == Attribute.list.key) {
      final value = quillController
          .getSelectionStyle()
          .attributes[Attribute.list.key]
          ?.value;
      return value == attr.value;
    }
    return quillController.getSelectionStyle().containsKey(attr.key);
  }

  bool _isNormalTextActive() {
    final headerValue = quillController
        .getSelectionStyle()
        .attributes[Attribute.header.key]
        ?.value;
    return headerValue == null;
  }

  void _toggleHeader(Attribute headerAttr) {
    final currentHeaderValue = quillController
        .getSelectionStyle()
        .attributes[Attribute.header.key]
        ?.value;
    if (currentHeaderValue == headerAttr.value) {
      quillController.formatSelection(Attribute.clone(Attribute.header, null));
    } else {
      // Apply header, but ensure it's not bold (use regular weight)
      quillController.formatSelection(headerAttr);
      // Remove bold if present so header text stays normal weight
      if (quillController.getSelectionStyle().containsKey(Attribute.bold.key)) {
        quillController.formatSelection(Attribute.clone(Attribute.bold, null));
      }
    }
  }

  void _clearHeader() {
    quillController.formatSelection(Attribute.clone(Attribute.header, null));
  }

  void _toggleList(Attribute listAttr) {
    final currentListValue = quillController
        .getSelectionStyle()
        .attributes[Attribute.list.key]
        ?.value;
    if (currentListValue == listAttr.value) {
      quillController.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      quillController.formatSelection(listAttr);
    }
  }

  void _toggleInline(Attribute inlineAttr) {
    final isApplied =
        quillController.getSelectionStyle().containsKey(inlineAttr.key);
    quillController.formatSelection(
      isApplied ? Attribute.clone(inlineAttr, null) : inlineAttr,
    );
  }

  void _clearInlineStyles() {
    final attrs = [
      Attribute.bold,
      Attribute.italic,
      Attribute.underline,
      Attribute.strikeThrough
    ];
    for (final a in attrs) {
      if (quillController.getSelectionStyle().containsKey(a.key)) {
        quillController.formatSelection(Attribute.clone(a, null));
      }
    }
  }

  Widget _formattingButton(
    BuildContext context, {
    String? text,
    IconData? icon,
    required bool isActive,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    final isTextButton = text != null;
    final activeBgColor = isTextButton
        ? AppColors.inputBackground(context)
        : AppColors.primary.withValues(alpha: 0.16);
    final inactiveBgColor = AppColors.inputBackground(context);
    final activeColor = isTextButton
        ? AppColors.textPrimary(context)
        : AppColors.primaryVariant;
    final inactiveColor = AppColors.textMetadata(context);
    final disabledColor =
        AppColors.textMetadata(context).withValues(alpha: 0.6);

    final bgColor = disabled
        ? inactiveBgColor
        : (isActive ? activeBgColor : inactiveBgColor);
    final contentColor =
        disabled ? disabledColor : (isActive ? activeColor : inactiveColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: text != null
                ? Text(
                    text,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: text == 'Aa' ? 18 : 16,
                      color: contentColor,
                    ),
                  )
                : Icon(
                    icon,
                    size: 24,
                    color: contentColor,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _formattingDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.divider(context),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _closeFormattingButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, left: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.close,
              size: 20,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 0,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Nhóm 1: Kiểu chữ (Header, Normal)
                    _formattingButton(
                      context,
                      text: 'H1',
                      isActive: _isAttributeActive(Attribute.h1),
                      onTap: () => _toggleHeader(Attribute.h1),
                      disabled: isButtonsDisabled,
                    ),
                    _formattingButton(
                      context,
                      text: 'H2',
                      isActive: _isAttributeActive(Attribute.h2),
                      onTap: () => _toggleHeader(Attribute.h2),
                      disabled: isButtonsDisabled,
                    ),
                    _formattingButton(
                      context,
                      text: 'Aa',
                      isActive: _isNormalTextActive(),
                      onTap: _clearHeader,
                      disabled: isButtonsDisabled,
                    ),
                    _formattingDivider(context),
                    // Nhóm 2: Định dạng inline (Bold, Italic,...)
                    _formattingButton(
                      context,
                      icon: Icons.format_bold,
                      isActive: _isAttributeActive(Attribute.bold),
                      onTap: () => _toggleInline(Attribute.bold),
                      disabled: isButtonsDisabled,
                    ),
                    _formattingButton(
                      context,
                      icon: Icons.format_italic,
                      isActive: _isAttributeActive(Attribute.italic),
                      onTap: () => _toggleInline(Attribute.italic),
                      disabled: isButtonsDisabled,
                    ),
                    _formattingButton(
                      context,
                      icon: Icons.format_underline,
                      isActive: _isAttributeActive(Attribute.underline),
                      onTap: () => _toggleInline(Attribute.underline),
                      disabled: isButtonsDisabled,
                    ),
                    _formattingButton(
                      context,
                      icon: Icons.strikethrough_s,
                      isActive: _isAttributeActive(Attribute.strikeThrough),
                      onTap: () => _toggleInline(Attribute.strikeThrough),
                      disabled: isButtonsDisabled,
                    ),
                    _formattingButton(
                      context,
                      icon: Icons.format_clear,
                      isActive: false,
                      onTap: _clearInlineStyles,
                      disabled: isButtonsDisabled,
                    ),
                    _formattingDivider(context),
                    // Nhóm 3: Kiểu danh sách (List)
                    _formattingButton(
                      context,
                      icon: Icons.format_list_bulleted,
                      isActive: _isAttributeActive(Attribute.ul),
                      onTap: () => _toggleList(Attribute.ul),
                      disabled: isButtonsDisabled,
                    ),
                    _formattingButton(
                      context,
                      icon: Icons.format_list_numbered,
                      isActive: _isAttributeActive(Attribute.ol),
                      onTap: () => _toggleList(Attribute.ol),
                      disabled: isButtonsDisabled,
                    ),
                    _formattingButton(
                      context,
                      icon: Icons.format_quote,
                      isActive: _isAttributeActive(Attribute.blockQuote),
                      onTap: () => _toggleInline(Attribute.blockQuote),
                      disabled: isButtonsDisabled,
                    ),
                  ],
                ),
              ),
            ),
            // Nhóm 4: Nút Đóng (Ghim cố định)
            _closeFormattingButton(context),
          ],
        ),
      ),
    );
  }
}
