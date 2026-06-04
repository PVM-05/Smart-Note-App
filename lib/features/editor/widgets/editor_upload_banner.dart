import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

class EditorUploadBanner extends StatelessWidget {
  final bool showBanner;
  final String? message;
  final Color bannerColor;
  final Color bannerTextColor;
  final Widget statusIcon;
  final bool isUploading;

  const EditorUploadBanner({
    super.key,
    required this.showBanner,
    required this.message,
    required this.bannerColor,
    required this.bannerTextColor,
    required this.statusIcon,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBanner && message != null)
          Container(
            color: bannerColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                statusIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message!,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: bannerTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (isUploading)
          LinearProgressIndicator(
            backgroundColor: AppColors.divider(context),
            color: AppColors.primary,
          ),
      ],
    );
  }
}
