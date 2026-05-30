import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import '../services/biometric_service.dart';
import '../core/app_colors.dart';
import '../core/app_strings.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // Trạng thái local cho các cấu hình cài đặt
  bool _isDarkMode = false;
  String _selectedLanguage = 'Tiếng Việt';
  bool _biometricEnabled = false;
  final BiometricService _biometricService = BiometricService();

  static const Color primaryColor = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('isBiometricEnabled') ?? false;
    });
  }

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
              });
              ScaffoldMessenger.of(context).clearSnackBars();
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
            secondary: const Icon(
              Icons.fingerprint,
              color: AppColors.primary,
            ),
            title: const Text(
              AppStrings.biometricLockTitle,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(AppStrings.biometricLockSubtitle),
            value: _biometricEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: (bool value) async {
              final localContext = context;
              final messenger = ScaffoldMessenger.of(localContext);
              if (value) {
                final available = await _biometricService.isAvailable();
                if (!available) {
                  if (localContext.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(AppStrings.biometricNotAvailable),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  return;
                }
                
                final enrolled = await _biometricService.isEnrolled();
                if (!enrolled) {
                  if (localContext.mounted) {
                    showDialog<void>(
                      context: localContext,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Chưa thiết lập sinh trắc học'),
                        content: const Text(
                          'Bạn cần thêm vân tay hoặc khuôn mặt trong cài đặt điện thoại để sử dụng tính năng khóa ghi chú.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Để sau'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              AppSettings.openAppSettings(
                                type: AppSettingsType.security,
                              );
                            },
                            child: const Text('Mở cài đặt'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }
              }
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isBiometricEnabled', value);
              if (localContext.mounted) {
                setState(() {
                  _biometricEnabled = value;
                });
              }
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