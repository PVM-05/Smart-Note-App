// lib/screens/editor_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cloudinary_service.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/biometric_service.dart';
import '../core/app_strings.dart';
import '../core/app_colors.dart';
import 'package:app_settings/app_settings.dart';

class EditorScreen extends StatefulWidget {
  final Note? note;
  final bool autoRecord;
  final bool autoPickImage;

  const EditorScreen({
    super.key,
    this.note,
    this.autoRecord = false,
    this.autoPickImage = false,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();
  bool _isDirty = false;
  bool _showFormattingToolbar = false;
  bool _isLocked = false;
  bool _isUnlocked = true;
  final BiometricService _biometricService = BiometricService();
  List<String> _tags = [];
  List<String> _imageUrls = [];
  List<String> _audioUrls = [];

  late String _noteId;
  late DateTime _createdAt;
  late String _status;
  bool _hasBeenSavedInDb = false;

  Timer? _autoSaveTimer;
  bool _isUploading = false;
  String? _uploadMessage;
  bool _showUploadBanner = false;
  Color _bannerColor = const Color(0xFFEFF6FF); // Light blue for progress
  Color _bannerTextColor = const Color(0xFF1E40AF); // Dark blue text
  Widget _statusIcon = const SizedBox(
    width: 14,
    height: 14,
    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6)),
  );
  Timer? _bannerTimer;

  void _setUploadState({
    required bool isUploading,
    required String message,
    required Color bannerColor,
    required Color bannerTextColor,
    required Widget statusIcon,
    bool showBanner = true,
    bool autoHide = false,
  }) {
    _bannerTimer?.cancel();
    setState(() {
      _isUploading = isUploading;
      _uploadMessage = message;
      _showUploadBanner = showBanner;
      _bannerColor = bannerColor;
      _bannerTextColor = bannerTextColor;
      _statusIcon = statusIcon;
    });

    if (autoHide) {
      _bannerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showUploadBanner = false;
          });
        }
      });
    }
  }

  Future<bool?> _showUploadExitConfirmation() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Đang tải lên tệp tin'),
        content: const Text('Có tệp tin đang được tải lên. Nếu bạn thoát bây giờ, quá trình tải lên sẽ bị hủy và tệp tin sẽ không được lưu. Bạn có chắc chắn muốn thoát?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
  }

  // Audio Recorder
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  // Audio Playback
  String? _playingUrl;
  bool _isPlaying = false;
  Duration _playPosition = Duration.zero;
  Duration _playTotal = Duration.zero;

  final _cloudinary = CloudinaryService();

  static const _primary = Color(0xFF2E75B6);
  static const _recordColor = Color(0xFFEF4444);

  bool get _isEditing => widget.note != null;

  // ⚡ HÀM KIỂM TRA THAY ĐỔI: So sánh dữ liệu trên UI hiện tại với dữ liệu gốc của Note
  bool _hasChanges() {
    final originalTitle = widget.note?.title ?? '';
    final originalTags = widget.note?.tags ?? const [];
    final originalImages = widget.note?.imageUrls ?? const [];
    final originalAudios = widget.note?.audioUrls ?? const [];

    final currentTitle = _titleController.text.trim();

    final titleChanged = originalTitle != currentTitle;
    final contentChanged = _isDirty;
    final tagsChanged = !listEquals(originalTags, _tags);
    final imagesChanged = !listEquals(originalImages, _imageUrls);
    final audiosChanged = !listEquals(originalAudios, _audioUrls);

    return titleChanged || contentChanged || tagsChanged || imagesChanged || audiosChanged;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _noteId = widget.note?.id ?? const Uuid().v4();
    _createdAt = widget.note?.createdAt ?? DateTime.now();
    _status = widget.note?.status ?? 'normal';
    _isLocked = widget.note?.isLocked ?? false;
    _isUnlocked = !_isLocked;
    _hasBeenSavedInDb = widget.note != null;

    _titleController = TextEditingController(text: widget.note?.title ?? '');
    
    final initialContent = widget.note?.content ?? '';
    if (initialContent.isEmpty) {
      _quillController = QuillController.basic();
    } else {
      try {
        final json = jsonDecode(initialContent);
        _quillController = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        final doc = Document()..insert(0, initialContent);
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    }

    _tags = List.from(widget.note?.tags ?? []);
    _imageUrls = List.from(widget.note?.imageUrls ?? []);
    _audioUrls = List.from(widget.note?.audioUrls ?? []);

    _titleController.addListener(_onTextChanged);
    _quillController.document.changes.listen((_) {
      _isDirty = true;
      _onTextChanged();
    });

    // Tự động hiện thanh công cụ khi bôi đen chữ
    _quillController.addListener(() {
      final hasSelection = !_quillController.selection.isCollapsed;
      if (_showFormattingToolbar != hasSelection) {
        setState(() {
          _showFormattingToolbar = hasSelection;
        });
      }
    });

    _audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _playPosition = pos);
    });
    _audioPlayer.durationStream.listen((dur) {
      if (mounted) setState(() => _playTotal = dur ?? Duration.zero);
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() { _isPlaying = false; _playingUrl = null; });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoRecord) {
        _startRecording();
      } else if (widget.autoPickImage) {
        _pickImage(ImageSource.gallery);
      }
      if (_isLocked) {
        _authenticateNote();
      }
    });
  }

  void _onTextChanged() {
    if (_isLocked && !_isUnlocked) return;
    // Chỉ kích hoạt hẹn giờ tự động lưu nếu phát hiện thực sự có sự thay đổi nội dung văn bản
    if (!_hasChanges()) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _saveNote(isAutosave: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _recordTimer?.cancel();
    _bannerTimer?.cancel();
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _audioPlayer.stop();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Tự động khóa lại khi app vào background — KHÔNG gọi authenticate() tự động
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_isLocked && _isUnlocked) {
        setState(() => _isUnlocked = false);
      }
    }
  }

  Future<void> _authenticateNote() async {
    try {
      final authenticated = await _biometricService.authenticate(
        reason: AppStrings.biometricPromptReason,
      );
      if (authenticated) {
        setState(() {
          _isUnlocked = true;
        });
      } else {
        _showAuthFailedSnackBar();
      }
    } catch (e) {
      _showAuthFailedSnackBar(message: e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showAuthFailedSnackBar({String? message}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? AppStrings.biometricAuthFailed),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Thử lại',
          textColor: Colors.white,
          onPressed: _authenticateNote,
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // Hiện dialog hướng dẫn user mở Cài đặt để đăng ký sinh trắc học
  void _showEnrollBiometricDialog() {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              AppSettings.openAppSettings(type: AppSettingsType.security);
            },
            child: const Text('Mở cài đặt'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNote({required bool isAutosave}) async {
    if (!mounted) return;
    if (_isLocked && !_isUnlocked) return;
    // ⚡ CHẶN LƯU THỪA: Nếu không có bất kỳ thay đổi nào, bỏ qua không gọi Database / Cloud Provider
    if (!_hasChanges()) return;

    final title = _titleController.text.trim();
    final content = jsonEncode(_quillController.document.toDelta().toJson());
    final plainText = _quillController.document.toPlainText().trim();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.userId ?? '';
    if (currentUserId.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);
    final isEmpty = title.isEmpty && plainText.isEmpty && _tags.isEmpty
        && _imageUrls.isEmpty && _audioUrls.isEmpty && !_isRecording;

    if (isEmpty && !_hasBeenSavedInDb) return;

    if (isEmpty && _hasBeenSavedInDb) {
      if (!isAutosave) {
        _autoSaveTimer?.cancel();
        await provider.deleteNote(_noteId);
        _hasBeenSavedInDb = false;
      }
      return;
    }

    final noteToSave = Note(
      id: _noteId,
      userId: currentUserId,
      title: title,
      content: content,
      tags: _tags,
      imageUrls: _imageUrls,
      audioUrls: _audioUrls,
      status: _status,
      isSynced: false,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );

    if (_hasBeenSavedInDb) {
      await provider.updateNote(noteToSave);
    } else {
      await provider.addNote(noteToSave);
      _hasBeenSavedInDb = true;
    }
    _isDirty = false;
  }

  Future<void> _pickImage(ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _setUploadState(
      isUploading: true,
      message: 'Đang tải lên hình ảnh...',
      bannerColor: const Color(0xFFEFF6FF),
      bannerTextColor: const Color(0xFF1E40AF),
      statusIcon: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6)),
      ),
    );

    try {
      final url = source == ImageSource.gallery
          ? await _cloudinary.pickAndUploadImage(auth.userId!)
          : await _cloudinary.cameraAndUploadImage(auth.userId!);

      if (!mounted) return;

      if (url != null) {
        setState(() => _imageUrls.add(url));
        await _saveNote(isAutosave: true);
        _setUploadState(
          isUploading: false,
          message: 'Tải lên hình ảnh thành công!',
          bannerColor: const Color(0xFFECFDF5),
          bannerTextColor: const Color(0xFF065F46),
          statusIcon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          autoHide: true,
        );
      } else {
        _setUploadState(
          isUploading: false,
          message: 'Tải lên hình ảnh bị hủy hoặc thất bại.',
          bannerColor: const Color(0xFFFEF2F2),
          bannerTextColor: const Color(0xFF991B1B),
          statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
          autoHide: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _setUploadState(
        isUploading: false,
        message: 'Lỗi: Tải lên hình ảnh thất bại.',
        bannerColor: const Color(0xFFFEF2F2),
        bannerTextColor: const Color(0xFF991B1B),
        statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
        autoHide: true,
      );
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.photo_library_outlined, color: _primary)),
              title: const Text('Chọn từ thư viện'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.camera_alt_outlined, color: _primary)),
              title: const Text('Chụp ảnh'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: _recordingPath!,
    );

    _recordDuration = Duration.zero;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecordingAndUpload() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (path == null) {
      // Ghi âm thất bại - báo lỗi rõ ràng thay vì silent return
      if (mounted) {
        _setUploadState(
          isUploading: false,
          message: 'Ghi âm thất bại: Không lấy được file audio.',
          bannerColor: const Color(0xFFFEF2F2),
          bannerTextColor: const Color(0xFF991B1B),
          statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
          autoHide: true,
        );
      }
      return;
    }

    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _setUploadState(
      isUploading: true,
      message: 'Đang tải lên âm thanh...',
      bannerColor: const Color(0xFFEFF6FF),
      bannerTextColor: const Color(0xFF1E40AF),
      statusIcon: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6)),
      ),
    );

    try {
      final url = await _cloudinary.uploadAudio(File(path), auth.userId!);
      if (!mounted) return;

      if (url != null) {
        setState(() => _audioUrls.add(url));
        await _saveNote(isAutosave: true);
        _setUploadState(
          isUploading: false,
          message: 'Tải lên âm thanh thành công!',
          bannerColor: const Color(0xFFECFDF5),
          bannerTextColor: const Color(0xFF065F46),
          statusIcon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          autoHide: true,
        );
      } else {
        _setUploadState(
          isUploading: false,
          message: 'Tải lên âm thanh thất bại.',
          bannerColor: const Color(0xFFFEF2F2),
          bannerTextColor: const Color(0xFF991B1B),
          statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
          autoHide: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _setUploadState(
        isUploading: false,
        message: 'Lỗi: Tải lên âm thanh thất bại.',
        bannerColor: const Color(0xFFFEF2F2),
        bannerTextColor: const Color(0xFF991B1B),
        statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
        autoHide: true,
      );
    }
  }

  Future<void> _togglePlay(String url) async {
    if (_playingUrl == url && _isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_playingUrl != url) {
        await _audioPlayer.setUrl(url);
        setState(() { _playingUrl = url; _playPosition = Duration.zero; });
      }
      await _audioPlayer.play();
      setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: const Text('Ghi chú sẽ được chuyển vào Thùng rác và tự động xóa sau 7 ngày.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _autoSaveTimer?.cancel();

      if (_isPlaying) {
        await _audioPlayer.stop();
      }

      if (!mounted) return;

      if (_hasBeenSavedInDb) {
        await Provider.of<NoteProvider>(context, listen: false).deleteNote(_noteId);
      }

      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _togglePin() async {
    if (_hasBeenSavedInDb && widget.note != null) {
      await Provider.of<NoteProvider>(context, listen: false).togglePin(widget.note!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _toggleArchive() async {
    if (!_hasBeenSavedInDb) return;
    _autoSaveTimer?.cancel();

    final provider = Provider.of<NoteProvider>(context, listen: false);
    if (_status == 'archived') {
      await provider.unarchiveNote(_noteId);
      _status = 'normal';
    } else {
      await provider.archiveNote(_noteId);
      _status = 'archived';
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_status == 'archived' ? 'Đã chuyển vào kho lưu trữ' : 'Đã hủy lưu trữ ghi chú'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _openLabelSelectionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LabelSelectionScreen(
          initialTags: _tags,
          onTagsChanged: (updatedTags) {
            setState(() => _tags = updatedTags);
            _saveNote(isAutosave: true); // Chuyển thành true để thực hiện lưu thay đổi nhãn ngay lập tức
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isLocked && !_isUnlocked) {
          Navigator.of(context).pop();
          return;
        }
        if (_isUploading) {
          final confirmExit = await _showUploadExitConfirmation();
          if (confirmExit != true) return;
        }
        if (_isRecording) await _stopRecordingAndUpload();
        _autoSaveTimer?.cancel();

        // ⚡ CHỈ LƯU KHI POP NẾU CÓ CHỈNH SỬA
        if (_hasChanges()) {
          await _saveNote(isAutosave: false);
        }

        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              if (_isLocked && !_isUnlocked) {
                Navigator.of(context).pop();
                return;
              }
              if (_isUploading) {
                final confirmExit = await _showUploadExitConfirmation();
                if (confirmExit != true) return;
              }
              if (_isRecording) await _stopRecordingAndUpload();
              _autoSaveTimer?.cancel();

              // ⚡ CHỈ LƯU KHI CLICK BACK NẾU CÓ CHỈNH SỬA
              if (_hasChanges()) {
                await _saveNote(isAutosave: false);
              }

              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _primary, strokeWidth: 2))),
              ),
            if (_hasBeenSavedInDb)
              IconButton(
                icon: Icon(_isLocked ? Icons.lock : Icons.lock_open_outlined, color: Colors.black87),
                tooltip: _isLocked ? 'Mở khóa ghi chú' : 'Khóa ghi chú',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final provider = Provider.of<NoteProvider>(context, listen: false);
                  try {
                    final success = await provider.toggleLock(_noteId);
                    if (success) {
                      setState(() {
                        _isLocked = !_isLocked;
                        _isUnlocked = !_isLocked;
                      });
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(_isLocked ? '🔒 Đã khóa ghi chú' : '🔓 Đã mở khóa ghi chú'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  } catch (e) {
                    final msg = e.toString().replaceAll('Exception: ', '');
                    if (msg == AppStrings.biometricNotEnrolled) {
                      _showEnrollBiometricDialog();
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
            if (_hasBeenSavedInDb)
              IconButton(
                icon: Icon(_status == 'pinned' ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.black87),
                onPressed: _togglePin,
              ),
            if (_hasBeenSavedInDb)
              IconButton(
                icon: const Icon(Icons.notification_add_outlined, color: Colors.black87),
                onPressed: () {}, // TODO: Tính năng nhắc nhở
              ),
            if (_hasBeenSavedInDb)
              IconButton(
                icon: Icon(_status == 'archived' ? Icons.unarchive_outlined : Icons.archive_outlined, color: Colors.black87),
                tooltip: _status == 'archived' ? 'Hủy lưu trữ' : 'Lưu trữ',
                onPressed: _toggleArchive,
              ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (_showUploadBanner && _uploadMessage != null)
                  Container(
                    color: _bannerColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _statusIcon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _uploadMessage!,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: _bannerTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isUploading)
                  LinearProgressIndicator(backgroundColor: Colors.grey.shade100, color: _primary),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_imageUrls.isNotEmpty) _buildGoogleKeepImageSection(),
    
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _titleController,
                                autofocus: !_isEditing && !widget.autoRecord && !widget.autoPickImage && !_isLocked,
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                                decoration: const InputDecoration(
                                  hintText: 'Tiêu đề',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                                textCapitalization: TextCapitalization.sentences,
                                maxLines: null,
                              ),
                              const SizedBox(height: 4),
                                                        const SizedBox(height: 4),
                          QuillEditor.basic(
                            controller: _quillController,
                            focusNode: _editorFocusNode,
                            config: const QuillEditorConfig(
                              scrollable: false,
                              expands: false,
                              autoFocus: false,
                              padding: EdgeInsets.zero,
                            ),
                          ),

                          if (_audioUrls.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ..._audioUrls.asMap().entries.map((e) => _buildGoogleKeepAudioItem(e.value, e.key)),
                          ],

                          if (_isRecording) ...[
                            const SizedBox(height: 16),
                            _buildRecordingIndicator(),
                          ],

                          if (_tags.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8, runSpacing: 6,
                              children: _tags.map((tag) => Chip(
                                label: Text(tag, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569))),
                                backgroundColor: const Color(0xFFF1F5F9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: BorderSide(color: Colors.grey.shade200),
                              )).toList(),
                            ),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
            if (_isLocked)
              AnimatedOpacity(
                opacity: _isUnlocked ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: _isUnlocked,
                  child: Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0F0F0F)
                        : Colors.white,
                    width: double.infinity,
                    height: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _authenticateNote,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Ghi chú đã được khóa',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chạm để mở khóa bằng sinh trắc học',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _authenticateNote,
                          icon: const Icon(Icons.fingerprint, color: Colors.white),
                          label: Text(
                            'Xác thực ngay',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: (_isLocked && !_isUnlocked) ? null : _buildBottomToolbar(),
      ),
    );
  }

  Widget _buildGoogleKeepImageSection() {
    return Column(
      children: _imageUrls.map((url) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => _showFullImage(url),
              child: CachedNetworkImage(
                imageUrl: url,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: const Color(0xFFF8FAFC),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 100,
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 24),
                ),
              ),
            ),
            Positioned(
              top: 12, right: 12,
              child: GestureDetector(
                onTap: () async {
                  _setUploadState(
                    isUploading: true,
                    message: 'Đang xóa hình ảnh khỏi đám mây...',
                    bannerColor: const Color(0xFFEFF6FF),
                    bannerTextColor: const Color(0xFF1E40AF),
                    statusIcon: const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6)),
                    ),
                  );
                  try {
                    await _cloudinary.deleteFile(url, resourceType: 'image');
                    if (mounted) {
                      setState(() {
                        _imageUrls.remove(url);
                      });
                      await _saveNote(isAutosave: true);
                      _setUploadState(
                        isUploading: false,
                        message: 'Đã xóa hình ảnh thành công.',
                        bannerColor: const Color(0xFFECFDF5),
                        bannerTextColor: const Color(0xFF065F46),
                        statusIcon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        autoHide: true,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      _setUploadState(
                        isUploading: false,
                        message: 'Xóa hình ảnh thất bại.',
                        bannerColor: const Color(0xFFFEF2F2),
                        bannerTextColor: const Color(0xFF991B1B),
                        statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
                        autoHide: true,
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGoogleKeepAudioItem(String url, int index) {
    final isThisPlaying = _playingUrl == url && _isPlaying;
    final isThisLoaded = _playingUrl == url;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isThisPlaying ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isThisPlaying ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _togglePlay(url),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: isThisPlaying ? _primary : const Color(0xFFCBD5E1),
              child: Icon(isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ghi âm âm thanh ${index + 1}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(
                  isThisLoaded ? '${_formatDuration(_playPosition)} / ${_formatDuration(_playTotal)}' : '00:00',
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (isThisLoaded && _playTotal.inMilliseconds > 0)
            SizedBox(
              width: 80,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: Slider(
                  value: _playPosition.inMilliseconds.toDouble().clamp(0, _playTotal.inMilliseconds.toDouble()),
                  max: _playTotal.inMilliseconds.toDouble(),
                  activeColor: _primary, inactiveColor: Colors.grey.shade300,
                  onChanged: (val) => _audioPlayer.seek(Duration(milliseconds: val.toInt())),
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              if (_playingUrl == url) {
                _audioPlayer.stop();
                setState(() { _playingUrl = null; _isPlaying = false; });
              }
              _setUploadState(
                isUploading: true,
                message: 'Đang xóa âm thanh khỏi đám mây...',
                bannerColor: const Color(0xFFEFF6FF),
                bannerTextColor: const Color(0xFF1E40AF),
                statusIcon: const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6)),
                ),
              );
              try {
                await _cloudinary.deleteFile(url, resourceType: 'video');
                if (mounted) {
                  setState(() {
                    _audioUrls.removeAt(index);
                  });
                  await _saveNote(isAutosave: true);
                  _setUploadState(
                    isUploading: false,
                    message: 'Đã xóa âm thanh thành công.',
                    bannerColor: const Color(0xFFECFDF5),
                    bannerTextColor: const Color(0xFF065F46),
                    statusIcon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                    autoHide: true,
                  );
                }
              } catch (e) {
                if (mounted) {
                  _setUploadState(
                    isUploading: false,
                    message: 'Xóa âm thanh thất bại.',
                    bannerColor: const Color(0xFFFEF2F2),
                    bannerTextColor: const Color(0xFF991B1B),
                    statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
                    autoHide: true,
                  );
                }
              }
            },
            child: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade400, size: 20),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black, insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 40),
                  ),
                ),
              ),
            ),
            Positioned(top: 40, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _recordColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _recordColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1.0), duration: const Duration(milliseconds: 600),
            builder: (_, val, child) => Opacity(opacity: val, child: child),
            child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: _recordColor, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Đang ghi âm... ${_formatDuration(_recordDuration)}', style: GoogleFonts.outfit(color: _recordColor, fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: _stopRecordingAndUpload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: _recordColor, borderRadius: BorderRadius.circular(20)),
              child: const Text('Dừng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showFormattingToolbar)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: QuillSimpleToolbar(
              controller: _quillController,
              config: const QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showStrikeThrough: true,
                showInlineCode: false,
                showColorButton: true,
                showBackgroundColorButton: true,
                showClearFormat: false,
                showAlignmentButtons: false,
                showLeftAlignment: false,
                showCenterAlignment: false,
                showRightAlignment: false,
                showJustifyAlignment: false,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: true,
                showCodeBlock: false,
                showQuote: true,
                showIndent: false,
                showLink: true,
                showUndo: false,
                showRedo: false,
                showDirection: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
              ),
            ),
          ),
        BottomAppBar(
          color: const Color(0xFFF1F5F9), // Màu xám nhạt như yêu cầu
          elevation: 0,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                _toolbarButton(icon: Icons.add_box_outlined, tooltip: 'Thêm', onTap: _isUploading ? null : _showAddOptions),
                _toolbarButton(icon: Icons.palette_outlined, tooltip: 'Màu sắc', onTap: () {}),
                _toolbarButton(
                  icon: Icons.format_color_text,
                  tooltip: 'Định dạng',
                  color: _showFormattingToolbar ? _primary : null,
                  onTap: () {
                    if (_quillController.selection.isCollapsed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng bôi đen đoạn chữ để định dạng.')),
                      );
                    }
                  },
                ),
                const Spacer(),
                if (!_isUploading && _hasBeenSavedInDb)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text('Đã lưu cục bộ', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
                  ),
                _toolbarButton(icon: Icons.more_vert, tooltip: 'Thêm nữa', onTap: _showMoreOptions),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Colors.black54),
              title: const Text('Thêm ảnh'),
              onTap: () { Navigator.pop(context); _showImageSourceSheet(); },
            ),
            ListTile(
              leading: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic_none_outlined, color: _isRecording ? _recordColor : Colors.black54),
              title: Text(_isRecording ? 'Dừng ghi âm' : 'Ghi âm'),
              onTap: () { Navigator.pop(context); _isRecording ? _stopRecordingAndUpload() : _startRecording(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            if (_hasBeenSavedInDb)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.black54),
                title: const Text('Xóa ghi chú'),
                onTap: () {
                  Navigator.pop(context);
                  _delete();
                },
              ),
            ListTile(
              leading: const Icon(Icons.label_outline, color: Colors.black54),
              title: const Text('Nhãn'),
              onTap: () {
                Navigator.pop(context);
                _openLabelSelectionPage();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton({required IconData icon, required String tooltip, VoidCallback? onTap, Color? color}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Icon(icon, size: 22, color: onTap == null ? Colors.grey.shade300 : (color ?? Colors.black54))),
      ),
    );
  }
}

class _LabelSelectionScreen extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;
  const _LabelSelectionScreen({required this.initialTags, required this.onTagsChanged});
  @override
  State<_LabelSelectionScreen> createState() => _LabelSelectionScreenState();
}

class _LabelSelectionScreenState extends State<_LabelSelectionScreen> {
  late List<String> _selectedTags;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() { super.initState(); _selectedTags = List.from(widget.initialTags); }
  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NoteProvider>(context);
    final allLabels = provider.allLabels;
    final filteredLabels = allLabels.where((l) => l.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final showCreate = _searchQuery.trim().isNotEmpty && !allLabels.any((l) => l.toLowerCase() == _searchQuery.trim().toLowerCase());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController, autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập tên nhãn', border: InputBorder.none,
            suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                if (showCreate)
                  ListTile(
                    leading: const Icon(Icons.add, color: _primary),
                    title: Text('Tạo "${_searchQuery.trim()}"'),
                    onTap: () {
                      final newTag = _searchQuery.trim();
                      provider.addLabel(newTag);
                      setState(() { if (!_selectedTags.contains(newTag)) _selectedTags.add(newTag); _searchQuery = ''; _searchController.clear(); });
                      widget.onTagsChanged(_selectedTags);
                    },
                  ),
                ...filteredLabels.map((label) {
                  final isChecked = _selectedTags.contains(label);
                  return CheckboxListTile(
                    title: Text(label), value: isChecked, activeColor: _primary,
                    onChanged: (val) {
                      setState(() { if (val == true) { _selectedTags.add(label); } else { _selectedTags.remove(label); } });
                      widget.onTagsChanged(_selectedTags);
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}