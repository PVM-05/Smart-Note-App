import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/app_localizations.dart';

class PersonalInfoSheet extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController bioController;
  final Future<void> Function() onSave;

  const PersonalInfoSheet({
    super.key,
    required this.nameController,
    required this.bioController,
    required this.onSave,
  });

  @override
  State<PersonalInfoSheet> createState() => _PersonalInfoSheetState();
}

class _PersonalInfoSheetState extends State<PersonalInfoSheet> {
  bool _isSavingProfile = false;

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.roboto(
          fontSize: 14, color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.roboto(
            color: AppColors.placeholder(context), fontSize: 14),
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
                AppLocalizations.translate(context, 'personalInfo'),
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
          Text(
            AppLocalizations.translate(context, 'displayName'),
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          _buildField(
            context: context,
            controller: widget.nameController,
            hint: AppLocalizations.translate(context, 'displayName'),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.translate(context, 'bio'),
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          _buildField(
            context: context,
            controller: widget.bioController,
            hint: AppLocalizations.translate(context, 'bioHint'),
            maxLines: 3,
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
                onPressed: _isSavingProfile
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        setState(() => _isSavingProfile = true);
                        await widget.onSave();
                        if (mounted) {
                          setState(() => _isSavingProfile = false);
                        }
                        navigator.pop();
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
                child: _isSavingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(AppLocalizations.translate(context, 'saveChanges'),
                        style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
