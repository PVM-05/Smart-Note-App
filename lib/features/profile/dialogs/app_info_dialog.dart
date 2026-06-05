import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppInfoDialog extends StatelessWidget {
  const AppInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Về ứng dụng',
        style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Note Pro',
              style: GoogleFonts.roboto(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Phiên bản: 1.0.0', style: GoogleFonts.roboto()),
          const SizedBox(height: 12),
          Text(
              'Ứng dụng ghi chú thông minh cao cấp được phát triển bởi đội ngũ Smart Note. Toàn bộ dữ liệu được bảo mật và đồng bộ hóa đám mây an toàn.',
              style: GoogleFonts.roboto(
                  color: const Color(0xFF4B5563), fontSize: 14)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Đóng',
              style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
