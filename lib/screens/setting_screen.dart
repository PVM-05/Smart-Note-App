import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import '../core/design/app_colors.dart';
import '../core/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _biometricEnabled = false;
  final BiometricService _biometricService = BiometricService();

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
        title: Text(
          AppLocalizations.translate(context, 'settingsTitle'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background(context),
        foregroundColor: AppColors.textPrimary(context),
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 12),

          // ================= CHỨC NĂNG 1: ĐỔI THEME =================
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return SwitchListTile(
                secondary: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: AppColors.primary,
                ),
                title: Text(
                  AppLocalizations.translate(context, 'darkModeTitle'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(AppLocalizations.translate(context, 'darkModeSubtitle')),
                value: themeProvider.isDarkMode,
                activeThumbColor: AppColors.primary,
                onChanged: (bool value) async {
                  final localContext = context;
                  final messenger = ScaffoldMessenger.of(localContext);
                  final darkText = AppLocalizations.translate(localContext, 'toastThemeDark');
                  final lightText = AppLocalizations.translate(localContext, 'toastThemeLight');
                  await themeProvider.toggleDarkMode();
                  if (mounted) {
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(themeProvider.isDarkMode ? darkText : lightText),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              );
            },
          ),
          _buildDivider(),

          // ================= CHỨC NĂNG 2: ĐỔI NGÔN NGỮ =================
          ListTile(
            leading: const Icon(Icons.language, color: AppColors.primary),
            title: Text(
              AppLocalizations.translate(context, 'languageTitle'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppLocalizations.translate(context, 'languageSubtitle')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<LanguageProvider>(
                  builder: (context, langProvider, _) {
                    return Text(
                      langProvider.currentLanguageLabel,
                      style: TextStyle(color: AppColors.textMetadata(context), fontSize: 14),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMetadata(context)),
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
            title: Text(
              AppLocalizations.translate(context, 'settingsBiometricLockTitle'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppLocalizations.translate(context, 'biometricLockSubtitle')),
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
                      SnackBar(
                        content: Text(AppLocalizations.translate(localContext, 'biometricNotAvailable')),
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
                        title: Text(AppLocalizations.translate(localContext, 'notSetBiometricTitle')),
                        content: Text(
                          AppLocalizations.translate(localContext, 'notSetBiometricDesc'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(AppLocalizations.translate(localContext, 'notSetBiometricBtnLater')),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              AppSettings.openAppSettings(
                                type: AppSettingsType.security,
                              );
                            },
                            child: Text(AppLocalizations.translate(localContext, 'notSetBiometricBtnOpen')),
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
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      value 
                        ? AppLocalizations.translate(localContext, 'toastBiometricEnabled')
                        : AppLocalizations.translate(localContext, 'toastBiometricDisabled')
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          _buildDivider(),

          // ================= CHỨC NĂNG 4: THÔNG BÁO =================
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
            title: Text(
              AppLocalizations.translate(context, 'notificationsTitle'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppLocalizations.translate(context, 'notificationsSubtitle')),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.translate(context, 'featureInDevelopment'))),
              );
            },
          ),
          _buildDivider(),

          // ================= CHỨC NĂNG 5: TRỢ GIÚP =================
          ListTile(
            leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
            title: Text(
              AppLocalizations.translate(context, 'helpTitle'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppLocalizations.translate(context, 'helpSubtitle')),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.translate(context, 'featureInDevelopment'))),
              );
            },
          ),
          _buildDivider(),

          // ================= CHỨC NĂNG 6: VỀ ỨNG DỤNG =================
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            title: Text(
              AppLocalizations.translate(context, 'aboutTitle'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppLocalizations.translate(context, 'aboutSubtitle')),
            onTap: () => _showAppInfoDialog(),
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64, 
      color: AppColors.divider(context),
    );
  }

  void _showAppInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.translate(context, 'aboutTitle'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Smart Note Pro',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(AppLocalizations.translate(context, 'aboutSubtitle')),
            const SizedBox(height: 12),
            Text(
                AppLocalizations.translate(context, 'aboutDesc'),
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.translate(context, 'close'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<LanguageProvider>(
          builder: (context, langProvider, _) {
            final isVi = langProvider.languageCode == 'vi';
            return AlertDialog(
              title: Text(
                AppLocalizations.translate(context, 'languageSelectTitle'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Tiếng Việt'),
                    trailing: isVi
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      await langProvider.setLanguage('vi');
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('English'),
                    trailing: !isVi
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      await langProvider.setLanguage('en');
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}