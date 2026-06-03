// lib/screens/editor_screen.dart
import 'dart:async';
import '../models/checklist_item.dart';
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
import 'drawing_screen.dart';
import '../services/biometric_service.dart';
import '../core/app_strings.dart';
import '../core/design/app_colors.dart';
import 'package:app_settings/app_settings.dart';

class EditorScreen extends StatefulWidget {
  final Note? note;
  final bool autoRecord;
  final bool autoPickImage;
  final bool autoOpenDrawing;
  final bool isChecklistMode;

  const EditorScreen({
    super.key,
    this.note,
    this.autoRecord = false,
    this.autoPickImage = false,
    this.autoOpenDrawing = false,
    this.isChecklistMode = false,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late QuillController _quillController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _editorFocusNode = FocusNode();
  bool _isDirty = false;
  bool _showFormattingToolbar = false;
  bool _isLocked = false;
  bool _isUnlocked = true;
  final BiometricService _biometricService = BiometricService();
  List<String> _tags = [];
  List<String> _imageUrls = [];
  List<String> _audioUrls = [];
  String? _noteColor;

  // Checklist mode
  bool _isChecklistMode = false;
  List<ChecklistItem> _checklistItems = [];
  List<ChecklistItem>? _originalChecklistItems;

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

  static const _primary = AppColors.primary;
  static const _recordColor = Color(0xFFEF4444);

  // ⚡ HÀM KIỂM TRA THAY ĐỔI: So sánh dữ liệu trên UI hiện tại với dữ liệu gốc của Note
  bool _hasChanges() {
    final originalTitle = widget.note?.title ?? '';
    final originalTags = widget.note?.tags ?? const [];
    final originalImages = widget.note?.imageUrls ?? const [];
    final originalAudios = widget.note?.audioUrls ?? const [];
    final originalColor = widget.note?.noteColor;

    final currentTitle = _titleController.text.trim();

    final titleChanged = originalTitle != currentTitle;
    final tagsChanged = !listEquals(originalTags, _tags);
    final imagesChanged = !listEquals(originalImages, _imageUrls);
    final audiosChanged = !listEquals(originalAudios, _audioUrls);
    final colorChanged = originalColor != _noteColor;

    // Checklist mode: so sánh items
    if (_isChecklistMode) {
      final checklistChanged = _hasChecklistChanged();
      return titleChanged || checklistChanged || tagsChanged || imagesChanged || audiosChanged || colorChanged;
    }

    final contentChanged = _isDirty;
    return titleChanged || contentChanged || tagsChanged || imagesChanged || audiosChanged || colorChanged;
  }

  bool _hasChecklistChanged() {
    if (_originalChecklistItems == null) {
      // Note mới: có items nghĩa là đã thay đổi
      return _checklistItems.any((item) => item.text.trim().isNotEmpty);
    }
    if (_originalChecklistItems!.length != _checklistItems.length) return true;
    for (int i = 0; i < _checklistItems.length; i++) {
      if (_checklistItems[i].text != _originalChecklistItems![i].text ||
          _checklistItems[i].checked != _originalChecklistItems![i].checked) {
        return true;
      }
    }
    return false;
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

    // Phát hiện checklist mode từ content hoặc constructor
    final isChecklistContent = widget.note?.isChecklist ?? false;
    _isChecklistMode = widget.isChecklistMode || isChecklistContent;

    if (_isChecklistMode && isChecklistContent) {
      // Parse existing checklist
      try {
        final decoded = jsonDecode(initialContent);
        final items = decoded['items'] as List? ?? [];
        _checklistItems = items.map((i) => ChecklistItem.fromJson(i as Map<String, dynamic>)).toList();
      } catch (_) {
        _checklistItems = [];
      }
      _originalChecklistItems = _checklistItems.map((i) => i.copyWith()).toList();
      _quillController = QuillController.basic();
    } else if (_isChecklistMode) {
      // New checklist note
      _checklistItems = [ChecklistItem()];
      _originalChecklistItems = null;
      _quillController = QuillController.basic();
    } else if (initialContent.isEmpty) {
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

    // Thêm item đầu tiên nếu checklist rỗng
    if (_isChecklistMode && _checklistItems.isEmpty) {
      _checklistItems.add(ChecklistItem());
    }

    _tags = List.from(widget.note?.tags ?? []);
    _imageUrls = List.from(widget.note?.imageUrls ?? []);
    _audioUrls = List.from(widget.note?.audioUrls ?? []);
    _noteColor = widget.note?.noteColor;

    _titleController.addListener(_onTextChanged);
    _titleFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _editorFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _quillController.document.changes.listen((_) {
      _isDirty = true;
      _onTextChanged();
    });

    // Tự động hiện thanh công cụ khi bôi đen chữ
    _quillController.addListener(() {
      final hasSelection = !_quillController.selection.isCollapsed;
      if (hasSelection && !_showFormattingToolbar) {
        setState(() {
          _showFormattingToolbar = true;
        });
      } else {
        // Luôn gọi setState để cập nhật trạng thái các nút định dạng khi con trỏ di chuyển/thay đổi style
        setState(() {});
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
      } else if (widget.autoOpenDrawing) {
        _openDrawingScreen();
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
    _titleFocusNode.dispose();
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
    final String content;
    final String plainText;

    if (_isChecklistMode) {
      // Serialize checklist items thành JSON
      final checklistJson = {
        'type': 'checklist',
        'items': _checklistItems.map((item) => item.toJson()).toList(),
      };
      content = jsonEncode(checklistJson);
      plainText = _checklistItems.map((i) => i.text).where((t) => t.trim().isNotEmpty).join(' ');
    } else {
      content = jsonEncode(_quillController.document.toDelta().toJson());
      plainText = _quillController.document.toPlainText().trim();
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.userId ?? '';
    if (currentUserId.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);
    final bool isEmpty;
    if (_isChecklistMode) {
      isEmpty = title.isEmpty && _checklistItems.every((i) => i.text.trim().isEmpty)
        && _tags.isEmpty && _imageUrls.isEmpty && _audioUrls.isEmpty && _noteColor == null && !_isRecording;
    } else {
      isEmpty = title.isEmpty && plainText.isEmpty && _tags.isEmpty
        && _imageUrls.isEmpty && _audioUrls.isEmpty && _noteColor == null && !_isRecording;
    }

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
      noteColor: _noteColor,
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

  Future<void> _uploadDrawing(File file) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _setUploadState(
      isUploading: true,
      message: 'Đang tải lên bản vẽ...',
      bannerColor: const Color(0xFFEFF6FF),
      bannerTextColor: const Color(0xFF1E40AF),
      statusIcon: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6)),
      ),
    );

    try {
      final url = await _cloudinary.uploadImage(file, auth.userId!);
      if (!mounted) return;

      if (url != null) {
        setState(() => _imageUrls.add(url));
        await _saveNote(isAutosave: true);
        _setUploadState(
          isUploading: false,
          message: 'Tải lên bản vẽ thành công!',
          bannerColor: const Color(0xFFECFDF5),
          bannerTextColor: const Color(0xFF065F46),
          statusIcon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          autoHide: true,
        );
      } else {
        _setUploadState(
          isUploading: false,
          message: 'Tải lên bản vẽ bị hủy hoặc thất bại.',
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
        message: 'Lỗi tải lên bản vẽ.',
        bannerColor: const Color(0xFFFEF2F2),
        bannerTextColor: const Color(0xFF991B1B),
        statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
        autoHide: true,
      );
    }
  }

  Future<void> _openDrawingScreen() async {
    final File? drawingFile = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DrawingScreen(noteColor: _noteColor)),
    );
    if (drawingFile != null) {
      _uploadDrawing(drawingFile);
    }
  }

  Future<void> _editDrawingScreen(String oldUrl) async {
    final File? drawingFile = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DrawingScreen(noteColor: _noteColor, initialImageUrl: oldUrl)),
    );
    if (drawingFile != null) {
      _replaceDrawing(oldUrl, drawingFile);
    }
  }

  Future<void> _replaceDrawing(String oldUrl, File file) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.userId == null) return;

    _setUploadState(
      isUploading: true,
      message: 'Đang cập nhật bản vẽ...',
      bannerColor: const Color(0xFFEFF6FF),
      bannerTextColor: const Color(0xFF1E40AF),
      statusIcon: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6)),
      ),
    );

    try {
      final url = await _cloudinary.uploadImage(file, auth.userId!);
      if (!mounted) return;

      if (url != null) {
        setState(() {
          final index = _imageUrls.indexOf(oldUrl);
          if (index != -1) {
            _imageUrls[index] = url;
          } else {
            _imageUrls.add(url);
          }
        });
        await _saveNote(isAutosave: true);
        
        // Background deletion of old image
        _cloudinary.deleteFile(oldUrl, resourceType: 'image').catchError((_) {});

        _setUploadState(
          isUploading: false,
          message: 'Cập nhật bản vẽ thành công!',
          bannerColor: const Color(0xFFECFDF5),
          bannerTextColor: const Color(0xFF065F46),
          statusIcon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          autoHide: true,
        );
      } else {
        _setUploadState(
          isUploading: false,
          message: 'Cập nhật bản vẽ bị hủy hoặc thất bại.',
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
        message: 'Lỗi cập nhật bản vẽ.',
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
    final isCustomColor = _noteColor != null;
    final onDarkNoteBg = isCustomColor && _isNoteBackgroundDark(context);
    final textColor = isCustomColor
        ? (onDarkNoteBg ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B))
        : null;
    final placeholderColor = isCustomColor
        ? (onDarkNoteBg ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))
        : null;

    final quillBaseStyles = DefaultStyles.getInstance(context);
    final quillCustomStyles = DefaultStyles(
      h1: quillBaseStyles.h1?.copyWith(
        style: quillBaseStyles.h1!.style.copyWith(
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
      ),
      h2: quillBaseStyles.h2?.copyWith(
        style: quillBaseStyles.h2!.style.copyWith(
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
      ),
      h3: quillBaseStyles.h3?.copyWith(
        style: quillBaseStyles.h3!.style.copyWith(color: textColor),
      ),
      h4: quillBaseStyles.h4?.copyWith(
        style: quillBaseStyles.h4!.style.copyWith(color: textColor),
      ),
      h5: quillBaseStyles.h5?.copyWith(
        style: quillBaseStyles.h5!.style.copyWith(color: textColor),
      ),
      h6: quillBaseStyles.h6?.copyWith(
        style: quillBaseStyles.h6!.style.copyWith(color: textColor),
      ),
      paragraph: quillBaseStyles.paragraph?.copyWith(
        style: quillBaseStyles.paragraph!.style.copyWith(color: textColor),
      ),
      lineHeightNormal: quillBaseStyles.lineHeightNormal,
      lineHeightTight: quillBaseStyles.lineHeightTight,
      lineHeightOneAndHalf: quillBaseStyles.lineHeightOneAndHalf,
      lineHeightDouble: quillBaseStyles.lineHeightDouble,
      bold: quillBaseStyles.bold?.copyWith(color: textColor),
      subscript: quillBaseStyles.subscript,
      superscript: quillBaseStyles.superscript,
      italic: quillBaseStyles.italic?.copyWith(color: textColor),
      small: quillBaseStyles.small,
      underline: quillBaseStyles.underline?.copyWith(color: textColor),
      strikeThrough: quillBaseStyles.strikeThrough?.copyWith(color: textColor),
      inlineCode: quillBaseStyles.inlineCode,
      link: quillBaseStyles.link,
      color: quillBaseStyles.color,
      placeHolder: quillBaseStyles.placeHolder?.copyWith(
        style: quillBaseStyles.placeHolder!.style.copyWith(color: placeholderColor),
      ),
      lists: quillBaseStyles.lists,
      quote: quillBaseStyles.quote?.copyWith(
        style: quillBaseStyles.quote!.style.copyWith(color: textColor),
      ),
      code: quillBaseStyles.code,
      indent: quillBaseStyles.indent,
      align: quillBaseStyles.align,
      leading: quillBaseStyles.leading,
      sizeSmall: quillBaseStyles.sizeSmall,
      sizeLarge: quillBaseStyles.sizeLarge,
      sizeHuge: quillBaseStyles.sizeHuge,
      palette: quillBaseStyles.palette,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_showFormattingToolbar) {
          setState(() {
            _showFormattingToolbar = false;
          });
          return;
        }
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
        backgroundColor: _noteBackgroundColor(context) ?? AppColors.background(context),
        appBar: AppBar(
          backgroundColor: _noteBackgroundColor(context) ?? AppColors.background(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isCustomColor
                  ? (onDarkNoteBg ? Colors.white : const Color(0xFF1E293B))
                  : AppColors.textPrimary(context),
            ),
            onPressed: () async {
              if (_showFormattingToolbar) {
                setState(() {
                  _showFormattingToolbar = false;
                });
                return;
              }
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
            _buildAppBarRoundBtn(
              icon: _isLocked ? Icons.lock : Icons.lock_open_outlined,
              tooltip: _isLocked ? 'Mở khóa ghi chú' : 'Khóa ghi chú',
              onTap: () async {
                if (!_hasBeenSavedInDb) {
                  _showRequiresSaveMessage('khóa');
                  return;
                }
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
            _buildAppBarRoundBtn(
              icon: _status == 'pinned' ? Icons.push_pin : Icons.push_pin_outlined,
              tooltip: _status == 'pinned' ? 'Bỏ ghim' : 'Ghim',
              onTap: () {
                if (!_hasBeenSavedInDb) {
                  _showRequiresSaveMessage('ghim');
                  return;
                }
                _togglePin();
              },
            ),
            _buildAppBarRoundBtn(
              icon: Icons.notification_add_outlined,
              tooltip: 'Nhắc nhở',
              onTap: () {
                if (!_hasBeenSavedInDb) {
                  _showRequiresSaveMessage('nhắc nhở');
                  return;
                }
              },
            ),
            const SizedBox(width: 8),
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
                  LinearProgressIndicator(backgroundColor: AppColors.divider(context), color: _primary),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_imageUrls.isNotEmpty) _buildGoogleKeepImageSection(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          autofocus: false,
                          style: GoogleFonts.outfit(
                            fontSize: 27, 
                            fontWeight: FontWeight.w400, 
                            color: isCustomColor
                                ? (onDarkNoteBg ? Colors.white : const Color(0xFF0F172A))
                                : AppColors.textSecondary(context),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tiêu đề',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: isCustomColor
                                  ? (onDarkNoteBg ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))
                                  : AppColors.placeholder(context),
                            ),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isChecklistMode)
                        _buildChecklistEditor()
                      else
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _editorFocusNode.requestFocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                QuillEditor.basic(
                                  controller: _quillController,
                                  focusNode: _editorFocusNode,
                                  config: QuillEditorConfig(
                                    scrollable: false,
                                    expands: false,
                                          autoFocus: false,
                                          padding: EdgeInsets.zero,
                                          placeholder: 'Ghi chú',
                                          customStyles: quillCustomStyles,
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
                                            label: Text(
                                              tag, 
                                              style: GoogleFonts.outfit(
                                                fontSize: 12, 
                                                color: _noteColor != null ? const Color(0xFF1E293B) : AppColors.textSecondary(context),
                                              ),
                                            ),
                                            backgroundColor: _noteColor != null ? Colors.black.withValues(alpha: 0.05) : AppColors.inputBackground(context),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            side: BorderSide(color: _noteColor != null ? Colors.black.withValues(alpha: 0.08) : AppColors.divider(context)),
                                          )).toList(),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
                if (!(_isLocked && !_isUnlocked) && !_titleFocusNode.hasFocus) _buildBottomToolbar(),
          ],
        ),
            if (_isLocked)
              AnimatedOpacity(
                opacity: _isUnlocked ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: _isUnlocked,
                  child: Container(
                    color: AppColors.background(context),
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
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chạm để mở khóa bằng sinh trắc học',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textMetadata(context),
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
      ),
    );
  }

  Widget _buildGoogleKeepImageSection() {
    return Column(
      children: _imageUrls.map((url) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => _editDrawingScreen(url),
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

    final isCustomColor = _noteColor != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isThisPlaying 
            ? (isCustomColor ? const Color(0xFFBFDBFE).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
            : (isCustomColor ? Colors.black.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isThisPlaying 
              ? const Color(0xFFBFDBFE)
              : (isCustomColor ? Colors.black.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
        ),
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
                Text(
                  'Ghi âm âm thanh ${index + 1}', 
                  style: GoogleFonts.outfit(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600, 
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isThisLoaded ? '${_formatDuration(_playPosition)} / ${_formatDuration(_playTotal)}' : '00:00',
                  style: GoogleFonts.outfit(
                    fontSize: 11, 
                    color: isCustomColor ? const Color(0xFF64748B) : Colors.grey.shade500,
                  ),
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
                  await _audioPlayer.stop();
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

  // ── CHECKLIST EDITOR ──
  Widget _buildChecklistEditor() {
    return Column(
      children: [
        // Header: Icon checklist + nút X để thoát checklist mode
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, color: Color(0xFF94A3B8), size: 20),
              const SizedBox(width: 4),
              Icon(Icons.check_box_outline_blank, color: Colors.grey.shade600, size: 20),
              const Spacer(),
              GestureDetector(
                onTap: _exitChecklistMode,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.close, color: Colors.grey.shade700, size: 22),
                ),
              ),
            ],
          ),
        ),
        // Checklist items
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _checklistItems.length + 1, // +1 cho nút "+ Mục danh sách"
            onReorder: (oldIndex, newIndex) {
              if (oldIndex >= _checklistItems.length || newIndex > _checklistItems.length) return;
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _checklistItems.removeAt(oldIndex);
                _checklistItems.insert(newIndex, item);
              });
              _onTextChanged();
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final elevation = Tween<double>(begin: 0, end: 4).animate(animation).value;
                  return Material(
                    elevation: elevation,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: child,
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              // Nút "+ Mục danh sách" ở cuối
              if (index == _checklistItems.length) {
                return Padding(
                  key: const ValueKey('__add_item__'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GestureDetector(
                    onTap: _addChecklistItem,
                    child: Row(
                      children: [
                        const SizedBox(width: 28), // Align với drag handle
                        Icon(Icons.add, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Mục danh sách',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = _checklistItems[index];
              return _buildChecklistTile(item, index);
            },
          ),
        // Audio + Recording + Tags phía dưới checklist
        if (_audioUrls.isNotEmpty || _isRecording || _tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_audioUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._audioUrls.asMap().entries.map((e) => _buildGoogleKeepAudioItem(e.value, e.key)),
                ],
                if (_isRecording) ...[
                  const SizedBox(height: 8),
                  _buildRecordingIndicator(),
                ],
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                const SizedBox(height: 12),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChecklistTile(ChecklistItem item, int index) {
    final isCustomColor = _noteColor != null;
    final textThemeColor = isCustomColor ? const Color(0xFF1E293B) : AppColors.textSecondary(context);
    final hintColor = isCustomColor ? const Color(0xFF64748B) : AppColors.placeholder(context);

    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.drag_indicator, 
                color: isCustomColor ? const Color(0xFF64748B) : Colors.grey.shade500, 
                size: 20,
              ),
            ),
          ),
          // Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: item.checked,
              onChanged: (val) {
                setState(() => item.checked = val ?? false);
                _onTextChanged();
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: _primary,
              side: BorderSide(
                color: isCustomColor ? const Color(0xFF475569) : Colors.grey.shade600, 
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: TextField(
              controller: TextEditingController(text: item.text)
                ..selection = TextSelection.collapsed(offset: item.text.length),
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: item.checked ? Colors.grey.shade400 : textThemeColor,
                decoration: item.checked ? TextDecoration.lineThrough : TextDecoration.none,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Mục danh sách',
                hintStyle: TextStyle(color: hintColor),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) {
                item.text = val;
                _onTextChanged();
              },
              onSubmitted: (_) {
                // Nhấn Enter → thêm item mới ngay sau item hiện tại
                _addChecklistItemAfter(index);
              },
              textInputAction: TextInputAction.next,
            ),
          ),
          // Nút xóa item
          if (_checklistItems.length > 1)
            GestureDetector(
              onTap: () {
                setState(() => _checklistItems.removeAt(index));
                _onTextChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.close, 
                  color: isCustomColor ? const Color(0xFF64748B) : Colors.grey.shade500, 
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addChecklistItem() {
    setState(() {
      _checklistItems.add(ChecklistItem());
    });
    _onTextChanged();
  }

  void _addChecklistItemAfter(int index) {
    setState(() {
      _checklistItems.insert(index + 1, ChecklistItem());
    });
    _onTextChanged();
  }

  void _exitChecklistMode() {
    // Convert checklist items thành plain text trong Quill editor
    final text = _checklistItems
        .map((i) => i.text)
        .where((t) => t.trim().isNotEmpty)
        .join('\n');
    setState(() {
      _isChecklistMode = false;
      _checklistItems = [];
      if (text.isNotEmpty) {
        final doc = Document()..insert(0, text);
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _quillController = QuillController.basic();
      }
      _isDirty = true;
    });
    _quillController.document.changes.listen((_) {
      _isDirty = true;
      _onTextChanged();
    });
  }

  void _switchToChecklistMode() {
    // Convert current Quill text to checklist items
    final plainText = _quillController.document.toPlainText().trim();
    setState(() {
      _isChecklistMode = true;
      if (plainText.isNotEmpty) {
        _checklistItems = plainText.split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => ChecklistItem(text: line))
            .toList();
      }
      if (_checklistItems.isEmpty) {
        _checklistItems = [ChecklistItem()];
      }
      _originalChecklistItems = null; // Treat as new for change detection
      _isDirty = true;
    });
  }


  Widget _buildBottomToolbar() {
    if (_showFormattingToolbar && !_isChecklistMode) {
      return BottomAppBar(
        color: Colors.white,
        elevation: 0,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // Nhóm 1: Kiểu chữ (Header, Normal)
                      _formattingButton(text: 'H1', isActive: _isAttributeActive(Attribute.h1), onTap: () => _toggleHeader(Attribute.h1), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingButton(text: 'H2', isActive: _isAttributeActive(Attribute.h2), onTap: () => _toggleHeader(Attribute.h2), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingButton(text: 'Aa', isActive: _isNormalTextActive(), onTap: _clearHeader, disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingDivider(),
                      // Nhóm 2: Định dạng inline (Bold, Italic,...)
                      _formattingButton(icon: Icons.format_bold, isActive: _isAttributeActive(Attribute.bold), onTap: () => _toggleInline(Attribute.bold), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingButton(icon: Icons.format_italic, isActive: _isAttributeActive(Attribute.italic), onTap: () => _toggleInline(Attribute.italic), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingButton(icon: Icons.format_underline, isActive: _isAttributeActive(Attribute.underline), onTap: () => _toggleInline(Attribute.underline), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingButton(icon: Icons.strikethrough_s, isActive: _isAttributeActive(Attribute.strikeThrough), onTap: () => _toggleInline(Attribute.strikeThrough), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingButton(icon: Icons.format_clear, isActive: false, onTap: _clearInlineStyles, disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingDivider(),
                      // Nhóm 3: Kiểu danh sách (List)
                      _formattingButton(icon: Icons.format_list_bulleted, isActive: _isAttributeActive(Attribute.ul), onTap: () => _toggleList(Attribute.ul), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingButton(icon: Icons.format_list_numbered, isActive: _isAttributeActive(Attribute.ol), onTap: () => _toggleList(Attribute.ol), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                      _formattingButton(icon: Icons.format_quote, isActive: _isAttributeActive(Attribute.blockQuote), onTap: () => _toggleInline(Attribute.blockQuote), disabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus),
                    ],
                  ),
                ),
              ),
              // Nhóm 4: Nút Đóng (Ghim cố định)
              _closeFormattingButton(),
            ],
          ),
        ),
      );
    }

    return BottomAppBar(
      color: _noteBackgroundColor(context) ?? AppColors.toolbarBackground(context),
      elevation: 0,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4), // Tạo khoảng cách viền nhẹ
          child: Row(
            children: [
              // 📦 BỌC CỤM ICON BÊN TRÁI: Thêm, Bảng màu, Định dạng văn bản
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _toolbarButton(icon: Icons.add_box_outlined, tooltip: 'Thêm', onTap: _isUploading ? null : _showAddOptions),
                  _toolbarButton(
                    icon: Icons.palette_outlined,
                    tooltip: 'Màu sắc',
                    onTap: _showColorPicker,
                  ),
                  if (!_isChecklistMode)
                    _toolbarButton(
                      icon: Icons.format_color_text,
                      tooltip: 'Định dạng',
                      color: _showFormattingToolbar ? _primary : null,
                      onTap: () {
                        setState(() {
                          _showFormattingToolbar = true;
                        });
                      },
                    ),
                  if (!_isChecklistMode)
                    ListenableBuilder(
                      listenable: _quillController,
                      builder: (context, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _toolbarButton(
                              icon: Icons.undo,
                              tooltip: 'Hoàn tác',
                              onTap: _quillController.hasUndo
                                  ? () => _quillController.undo()
                                  : null,
                            ),
                            _toolbarButton(
                              icon: Icons.redo,
                              tooltip: 'Làm lại',
                              onTap: _quillController.hasRedo
                                  ? () => _quillController.redo()
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
              
              const Spacer(),


                
              // 📦 BỌC CỤM ICON BÊN PHẢI: Chỉ gồm duy nhất nút 3 chấm More dọc
              _toolbarButton(icon: Icons.more_vert, tooltip: 'Thêm nữa', onTap: _showMoreOptions),
            ],
          ),
        ),
      ),
    );
  }

  bool _isAttributeActive(Attribute attr) {
    if (attr.key == Attribute.header.key) {
      final value = _quillController.getSelectionStyle().attributes[Attribute.header.key]?.value;
      return value == attr.value;
    }
    if (attr.key == Attribute.list.key) {
      final value = _quillController.getSelectionStyle().attributes[Attribute.list.key]?.value;
      return value == attr.value;
    }
    return _quillController.getSelectionStyle().containsKey(attr.key);
  }

  bool _isNormalTextActive() {
    final headerValue = _quillController.getSelectionStyle().attributes[Attribute.header.key]?.value;
    return headerValue == null;
  }

  void _toggleHeader(Attribute headerAttr) {
    final currentHeaderValue = _quillController.getSelectionStyle().attributes[Attribute.header.key]?.value;
    if (currentHeaderValue == headerAttr.value) {
      _quillController.formatSelection(Attribute.clone(Attribute.header, null));
    } else {
      // Apply header, but ensure it's not bold (use regular weight)
      _quillController.formatSelection(headerAttr);
      // Remove bold if present so header text stays normal weight
      if (_quillController.getSelectionStyle().containsKey(Attribute.bold.key)) {
        _quillController.formatSelection(Attribute.clone(Attribute.bold, null));
      }
    }
  }

  void _clearHeader() {
    _quillController.formatSelection(Attribute.clone(Attribute.header, null));
  }

  void _toggleList(Attribute listAttr) {
    final currentListValue = _quillController.getSelectionStyle().attributes[Attribute.list.key]?.value;
    if (currentListValue == listAttr.value) {
      _quillController.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      _quillController.formatSelection(listAttr);
    }
  }

  void _toggleInline(Attribute inlineAttr) {
    final isApplied = _quillController.getSelectionStyle().containsKey(inlineAttr.key);
    _quillController.formatSelection(
      isApplied ? Attribute.clone(inlineAttr, null) : inlineAttr,
    );
  }

  void _clearInlineStyles() {
    final attrs = [Attribute.bold, Attribute.italic, Attribute.underline, Attribute.strikeThrough];
    for (final a in attrs) {
      if (_quillController.getSelectionStyle().containsKey(a.key)) {
        _quillController.formatSelection(Attribute.clone(a, null));
      }
    }
  }

  Widget _formattingButton({
    String? text,
    IconData? icon,
    required bool isActive,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    final isTextButton = text != null;
    final activeBgColor = isTextButton
        ? AppColors.inputBackground(context)
        : AppColors.primary.withValues(alpha: 0.16);
    final inactiveBgColor = AppColors.inputBackground(context);
    final activeColor = isTextButton
        ? AppColors.textPrimary(context)
        : AppColors.primaryVariant;
    final inactiveColor = AppColors.textMetadata(context);
    final disabledColor = AppColors.textMetadata(context).withValues(alpha: 0.6);

    final bgColor = disabled ? inactiveBgColor : (isActive ? activeBgColor : inactiveBgColor);
    final contentColor = disabled ? disabledColor : (isActive ? activeColor : inactiveColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: text != null
                ? Text(
                    text,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: text == 'Aa' ? 18 : 16,
                      color: contentColor,
                    ),
                  )
                : Icon(
                    icon,
                    size: 24,
                    color: contentColor,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _formattingDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.divider(context),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _closeFormattingButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 6, left: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _showFormattingToolbar = false;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.close,
              size: 20,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      ),
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.image_outlined, color: AppColors.textSecondary(context)),
              title: const Text('Thêm hình ảnh'),
              onTap: () { Navigator.pop(context); _showImageSourceSheet(); },
            ),
            ListTile(
              leading: Icon(Icons.brush_outlined, color: AppColors.textSecondary(context)),
              title: const Text('Bản vẽ'),
              onTap: () {
                Navigator.pop(context);
                _openDrawingScreen();
              },
            ),
            ListTile(
              leading: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic_none_outlined, color: _isRecording ? _recordColor : AppColors.textSecondary(context)),
              title: Text(_isRecording ? 'Dừng ghi âm' : 'Ghi âm'),
              onTap: () { Navigator.pop(context); _isRecording ? _stopRecordingAndUpload() : _startRecording(); },
            ),
            if (!_isChecklistMode)
              ListTile(
                leading: Icon(Icons.check_box_outlined, color: AppColors.textSecondary(context)),
                title: const Text('Danh sách'),
                onTap: () { Navigator.pop(context); _switchToChecklistMode(); },
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            if (_hasBeenSavedInDb)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.textSecondary(context)),
                title: const Text('Xóa ghi chú'),
                onTap: () {
                  Navigator.pop(context);
                  _delete();
                },
              ),
            ListTile(
              leading: Icon(Icons.label_outline, color: AppColors.textSecondary(context)),
              title: const Text('Nhãn'),
              onTap: () {
                Navigator.pop(context);
                _openLabelSelectionPage();
              },
            ),
            if (_hasBeenSavedInDb)
              ListTile(
                leading: Icon(_status == 'archived' ? Icons.unarchive_outlined : Icons.archive_outlined, color: AppColors.textSecondary(context)),
                title: Text(_status == 'archived' ? 'Hủy lưu trữ' : 'Lưu trữ'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleArchive();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRequiresSaveMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Vui lòng nhập nội dung để có thể $action ghi chú này'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _buildAppBarRoundBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final isCustomColor = _noteColor != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: isCustomColor ? const Color(0xFF1E293B) : AppColors.textMetadata(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarButton({required IconData icon, required String tooltip, VoidCallback? onTap, Color? color}) {
    final isCustomColor = _noteColor != null;
    final defaultIconColor = isCustomColor ? const Color(0xFF1E293B) : AppColors.textPrimary(context);
    final metadataIconColor = isCustomColor ? const Color(0xFF64748B) : AppColors.textMetadata(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap, 
        // Đổi bo góc thành hình tròn cho hiệu ứng gợn sóng khi chạm (Ripple Effect)
        customBorder: const CircleBorder(), 
        child: Padding(
          // Tạo khoảng cách (Gap) giữa các vòng tròn icon với nhau
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), 

          // 📦 ĐÂY CHÍNH LÀ BỌC CONTAINER ĐỂ TẠO VÒNG TRÒN NỀN:
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              // Đặt Icon vào chính giữa vòng tròn nền vừa tạo
              child: Center( 
                child: Icon(
                  icon, 
                  size: 22, 
                  color: onTap == null ? metadataIconColor : (color ?? defaultIconColor),
                ),
              ),
          ),
        ),
      ),
    );
  }

  Color? _noteBackgroundColor(BuildContext context) =>
      AppColors.resolveNoteBackground(context, _noteColor);

  bool _isNoteBackgroundDark(BuildContext context) {
    final bg = _noteBackgroundColor(context);
    if (bg == null) return false;
    return bg.computeLuminance() < 0.45;
  }

  void _showColorPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final palette = AppColors.noteBackgroundPalette(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn màu ghi chú',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(ctx),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: palette.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _noteColorSwatch(
                          context: ctx,
                          tooltip: 'Mặc định',
                          fillColor: AppColors.notePickerClearSwatch(ctx),
                          isClear: true,
                          isSelected: _noteColor == null,
                          onTap: () {
                            setState(() => _noteColor = null);
                            Navigator.pop(ctx);
                            _saveNote(isAutosave: true);
                          },
                        );
                      }
                      final entry = palette[index - 1];
                      final isSelected =
                          AppColors.isNotePaletteColorSelected(_noteColor, entry);
                      return _noteColorSwatch(
                        context: ctx,
                        tooltip: entry.label,
                        fillColor: entry.displayColor(ctx),
                        isClear: false,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _noteColor = entry.storageHex);
                          Navigator.pop(ctx);
                          _saveNote(isAutosave: true);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _noteColorSwatch({
    required BuildContext context,
    required String tooltip,
    required Color fillColor,
    required bool isClear,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final accent = AppColors.notePickerAccent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      preferBelow: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: fillColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accent : AppColors.divider(context),
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: isClear
                    ? (isDark
                        ? const Icon(Icons.water_drop_outlined, size: 18, color: Colors.white70)
                        : CustomPaint(
                            painter: _NoColorSlashPainter(
                              color: AppColors.textMetadata(context),
                            ),
                          ))
                    : null,
              ),
              if (isSelected)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoColorSlashPainter extends CustomPainter {
  _NoColorSlashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.78),
      Offset(size.width * 0.78, size.height * 0.22),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NoColorSlashPainter oldDelegate) => oldDelegate.color != color;
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
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController, autofocus: true,
          style: GoogleFonts.inter(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: 'Nhập tên nhãn', border: InputBorder.none,
            hintStyle: GoogleFonts.inter(color: AppColors.placeholder(context)),
            suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear, size: 20, color: AppColors.textSecondary(context)), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
      body: Column(
        children: [
          Divider(height: 1, color: AppColors.divider(context)),
          Expanded(
            child: ListView(
              children: [
                if (showCreate)
                  ListTile(
                    leading: const Icon(Icons.add, color: AppColors.primary),
                    title: Text('Tạo "${_searchQuery.trim()}"', style: GoogleFonts.inter(color: AppColors.textPrimary(context))),
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
                    title: Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary(context))), value: isChecked, activeColor: AppColors.primary,
                    checkColor: AppColors.onPrimary,
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