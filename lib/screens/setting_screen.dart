import 'package:flutter/material.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // Trạng thái local cho các cấu hình cài đặt
  bool _isDarkMode = false;
  bool _biometricAuth = false;
  String _selectedLanguage = 'Tiếng Việt';

  static const Color primaryColor = Color(0xFF2E75B6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 12),

          // ================= CHỨC NĂNG 1: ĐỔI THEME =================
          SwitchListTile(
            secondary: Icon(
              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: primaryColor,
            ),
            title: const Text(
              'Chế độ tối (Dark Mode)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Thay đổi giao diện sáng hoặc tối cho ứng dụng'),
            value: _isDarkMode,
            activeThumbColor: primaryColor,
            onChanged: (bool value) {
              setState(() {
                _isDarkMode = value;
                // TODO: Kết nối với ThemeProvider / Cubit thay đổi theme toàn cục của bạn tại đây
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isDarkMode ? '🌙 Đã chuyển sang giao diện tối' : '☀️ Đã chuyển sang giao diện sáng'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildDivider(),

          // ================= CHỨC NĂNG 2: ĐỔI NGÔN NGỮ =================
          ListTile(
            leading: const Icon(Icons.language, color: primaryColor),
            title: const Text(
              'Ngôn ngữ',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Lựa chọn ngôn ngữ hiển thị hệ thống'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedLanguage,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
            onTap: () => _showLanguageDialog(),
          ),
          _buildDivider(),

          // ================= CHỨC NĂNG 3: BIOMETRIC =================
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint, color: primaryColor),
            title: const Text(
              'Khóa bảo mật (Biometric)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Sử dụng Vân tay hoặc Khuôn mặt để mở ứng dụng'),
            value: _biometricAuth,
            activeThumbColor: primaryColor,
            onChanged: (bool value) {
              setState(() {
                _biometricAuth = value;
                // TODO: Tích hợp gói `local_auth` để xử lý xác thực vân tay thực tế tại đây
              });
            },
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  // Đường gạch chia dòng tinh giản
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64, // Lùi đầu dòng để thẳng hàng với text bên cạnh icon
      color: Colors.grey.shade200,
    );
  }

  // Hộp thoại lựa chọn ngôn ngữ hiển thị nhanh
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn ngôn ngữ', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Tiếng Việt'),
              trailing: _selectedLanguage == 'Tiếng Việt' ? const Icon(Icons.check_circle, color: primaryColor) : null,
              onTap: () {
                setState(() => _selectedLanguage = 'Tiếng Việt');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Tiếng Anh'),
              trailing: _selectedLanguage == 'English' ? const Icon(Icons.check_circle, color: primaryColor) : null,
              onTap: () {
                setState(() => _selectedLanguage = 'English');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}