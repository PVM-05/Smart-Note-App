import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

class ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String description;
  final VoidCallback onTap;

  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: AppColors.textMetadata(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textMetadata(context),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
