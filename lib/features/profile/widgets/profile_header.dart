import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

class ProfileHeader extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  final String email;
  final bool isUploadingAvatar;
  final VoidCallback onTapAvatar;

  const ProfileHeader({
    super.key,
    required this.photoUrl,
    required this.displayName,
    required this.email,
    required this.isUploadingAvatar,
    required this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryVariant],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryVariant.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isUploadingAvatar ? null : onTapAvatar,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            AppColors.onPrimary.withValues(alpha: 0.2),
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: isUploadingAvatar
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppColors.onPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : (photoUrl.isEmpty
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : 'U',
                                    style: GoogleFonts.roboto(
                                      fontSize: 24,
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.onPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Icon(Icons.camera_alt,
                            size: 11, color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: GoogleFonts.roboto(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Smart Note Pro',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: AppColors.onPrimary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.onPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.onPrimary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '✨ Premium Member',
                            style: GoogleFonts.roboto(
                              fontSize: 10,
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
