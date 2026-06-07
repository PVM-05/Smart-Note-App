import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/app_localizations.dart';

class SecuritySheet extends StatefulWidget {
  final TextEditingController oldPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final Future<void> Function() onChangePassword;

  const SecuritySheet({
    super.key,
    required this.oldPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.onChangePassword,
  });

  @override
  State<SecuritySheet> createState() => _SecuritySheetState();
}

class _SecuritySheetState extends State<SecuritySheet> {
  bool _isChangingPassword = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: 1,
      style: GoogleFonts.roboto(
          fontSize: 14, color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.roboto(
            color: AppColors.placeholder(context), fontSize: 14),
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: AppColors.placeholder(context)),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.inputBackground(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.divider(context))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.divider(context))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.translate(context, 'changePassword'),
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textPrimary(context)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildField(
            context: context,
            controller: widget.oldPasswordController,
            hint: AppLocalizations.translate(context, 'currentPassword'),
            obscure: _obscureOld,
            onToggle: () => setState(() => _obscureOld = !_obscureOld),
          ),
          const SizedBox(height: 12),
          _buildField(
            context: context,
            controller: widget.newPasswordController,
            hint: AppLocalizations.translate(context, 'newPasswordHint'),
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 12),
          _buildField(
            context: context,
            controller: widget.confirmPasswordController,
            hint: AppLocalizations.translate(context, 'confirmNewPasswordHint'),
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.translate(context, 'cancel'),
                  style: GoogleFonts.roboto(
                      color: AppColors.textMetadata(context)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isChangingPassword
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        setState(() => _isChangingPassword = true);
                        await widget.onChangePassword();
                        if (mounted) {
                          setState(() => _isChangingPassword = false);
                        }
                        if (widget.oldPasswordController.text.isEmpty) {
                          // Đổi mật khẩu thành công sẽ tự động xóa text field
                          navigator.pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: _isChangingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(AppLocalizations.translate(context, 'update'),
                        style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
