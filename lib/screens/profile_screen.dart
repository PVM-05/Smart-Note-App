import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import '../core/design/app_colors.dart';
import '../core/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/note_provider.dart';
import 'login_screen.dart';
import '../features/profile/widgets/profile_header.dart';
import '../features/profile/widgets/profile_menu_tile.dart';
import '../features/profile/sheets/personal_info_sheet.dart';
import '../features/profile/sheets/security_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isUploadingAvatar = false;
  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.userData?['displayName'] ?? '';
    _bioController.text = auth.userData?['bio'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack(AppLocalizations.translate(context, 'nameEmptyError'), isError: true);
      return;
    }
    final successMsg = AppLocalizations.translate(context, 'updateNameSuccess');
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .update({'displayName': name});
      await auth.user!.updateDisplayName(name);
      await auth.reloadUserData();
      if (!mounted) return;
      _showSnack(successMsg);
    } catch (e) {
      _showSnack('Lỗi: $e', isError: true);
    }
  }

  Future<void> _saveBio() async {
    final successMsg = AppLocalizations.translate(context, 'updateBioSuccess');
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .update({'bio': _bioController.text.trim()});
      await auth.reloadUserData();
      if (!mounted) return;
      _showSnack(successMsg);
    } catch (e) {
      _showSnack('Lỗi: $e', isError: true);
    }
  }

  Future<void> _changePassword() async {
    final oldPw = _oldPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;
    if (oldPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
      _showSnack(AppLocalizations.translate(context, 'fillAllFieldsError'), isError: true);
      return;
    }
    if (newPw.length < 6) {
      _showSnack(AppLocalizations.translate(context, 'passwordLengthError'), isError: true);
      return;
    }
    if (newPw != confirmPw) {
      _showSnack(AppLocalizations.translate(context, 'passwordMismatchError'), isError: true);
      return;
    }
    final successMsg = AppLocalizations.translate(context, 'passwordChangeSuccess');
    final oldPasswordIncorrectMsg = AppLocalizations.translate(context, 'oldPasswordIncorrectError');
    final user = FirebaseAuth.instance.currentUser!;
    try {
      final credential =
          EmailAuthProvider.credential(email: user.email!, password: oldPw);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPw);
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      _showSnack(successMsg);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(
          e.code == 'wrong-password'
              ? oldPasswordIncorrectMsg
              : 'Lỗi: ${e.message}',
          isError: true);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider(ctx),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.translate(ctx, 'changeAvatarTitle'),
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(ctx),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: Text(
                AppLocalizations.translate(ctx, 'pickFromGallery'),
                style: GoogleFonts.roboto(color: AppColors.textPrimary(ctx)),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.success),
              title: Text(
                AppLocalizations.translate(ctx, 'takePhoto'),
                style: GoogleFonts.roboto(color: AppColors.textPrimary(ctx)),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80);
    if (picked == null) return;
    setState(() => _isUploadingAvatar = true);
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final successMsg = AppLocalizations.translate(context, 'avatarUpdateSuccess');
    final uploadErrorTemplate = AppLocalizations.translate(context, 'uploadError');
    try {
      final ref =
          FirebaseStorage.instance.ref().child('avatars/${auth.user!.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .update({'photoUrl': url});
      await auth.user!.updatePhotoURL(url);
      await auth.reloadUserData();
      if (!mounted) return;
      _showSnack(successMsg);
    } catch (e) {
      if (!mounted) return;
      _showSnack(uploadErrorTemplate.replaceAll('{error}', '$e'), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.roboto()),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── PERSONAL INFO BOTTOM SHEET ──
  void _showPersonalInfoBottomSheet(BuildContext context, AuthProvider auth) {
    _nameController.text = auth.userData?['displayName'] ?? '';
    _bioController.text = auth.userData?['bio'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return PersonalInfoSheet(
          nameController: _nameController,
          bioController: _bioController,
          onSave: () async {
            await _saveName();
            await _saveBio();
          },
        );
      },
    );
  }

  // ── SECURITY BOTTOM SHEET ──
  void _showSecurityBottomSheet(BuildContext context) {
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SecuritySheet(
          oldPasswordController: _oldPasswordController,
          newPasswordController: _newPasswordController,
          confirmPasswordController: _confirmPasswordController,
          onChangePassword: _changePassword,
        );
      },
    );
  }


  Future<void> _signOut(BuildContext context, AuthProvider auth) async {
    final navigator = Navigator.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final userId = auth.userId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.translate(context, 'logoutConfirmTitle'),
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
        content: Text(AppLocalizations.translate(context, 'logoutConfirmDesc'),
            style: GoogleFonts.roboto()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.translate(context, 'cancel'), style: GoogleFonts.roboto())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.translate(context, 'logout'),
                style: GoogleFonts.roboto(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await auth.signOut();

    if (userId != null) {
      noteProvider.clearLocalData(userId);
      noteProvider.clearNotes();
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageProvider>(context); // Listen to LanguageProvider for real-time rebuilds
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final photoUrl = auth.userData?['photoUrl'] ?? '';
        final displayName = auth.userData?['displayName'] ?? AppLocalizations.translate(context, 'userName');
        final email = auth.email ?? '';
        final isEmailProvider =
            auth.user?.providerData.any((p) => p.providerId == 'password') ??
                false;

        return Scaffold(
          backgroundColor: AppColors.background(context),
          appBar: AppBar(
            backgroundColor: AppColors.background(context),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: AppColors.textSecondary(context)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              AppLocalizations.translate(context, 'profileTitle'),
              style: GoogleFonts.roboto(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppColors.divider(context), height: 1),
            ),
          ),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // ── 1. USER PROFILE CARD (GRADIENT) ──
              ProfileHeader(
                photoUrl: photoUrl,
                displayName: displayName,
                email: email,
                isUploadingAvatar: _isUploadingAvatar,
                onTapAvatar: _pickAndUploadAvatar,
              ),

              // ── 2. SECTIONS ──
              _buildSectionTitle(context, AppLocalizations.translate(context, 'accountTitle')),
              _buildSectionCard(context, [
                ProfileMenuTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.primaryVariant,
                  iconBg: AppColors.primary.withValues(alpha: 0.12),
                  label: AppLocalizations.translate(context, 'personalInfo'),
                  description: AppLocalizations.translate(context, 'manageAccountInfo'),
                  onTap: () => _showPersonalInfoBottomSheet(context, auth),
                ),
                if (isEmailProvider)
                  ProfileMenuTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: AppColors.success,
                    iconBg: AppColors.success.withValues(alpha: 0.1),
                    label: AppLocalizations.translate(context, 'securityTitle'),
                    description: AppLocalizations.translate(context, 'passwordAndAuth'),
                    onTap: () => _showSecurityBottomSheet(context),
                  ),
              ]),

              const SizedBox(height: 32),

              // ── 3. LOGOUT BUTTON ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _signOut(context, auth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.translate(context, 'logout'),
                              style: GoogleFonts.roboto(
                                color: AppColors.error,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textMetadata(context),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, List<Widget> children) {
    List<Widget> dividedChildren = [];
    for (int i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i != children.length - 1) {
        dividedChildren.add(Divider(
          height: 1,
          thickness: 1,
          indent: 68,
          color: AppColors.divider(context),
        ));
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: dividedChildren,
        ),
      ),
    );
  }
}
