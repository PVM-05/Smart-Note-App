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
import '../utils/math_parser.dart';
import '../models/note_model.dart';
import '../features/editor/widgets/editor_upload_banner.dart';
import '../features/editor/widgets/editor_image_section.dart';
import '../features/editor/widgets/editor_audio_section.dart';
import '../features/editor/widgets/editor_checklist_section.dart';
import '../features/editor/widgets/editor_format_toolbar.dart';
import '../features/editor/sheets/editor_add_options_sheet.dart';
import '../features/editor/sheets/editor_more_options_sheet.dart';
import '../features/editor/sheets/editor_color_picker_sheet.dart';
import '../providers/note_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cloudinary_service.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'drawing_screen.dart';
import '../services/biometric_service.dart';
import '../core/app_strings.dart';
import '../core/app_localizations.dart';
import '../core/design/app_colors.dart';
import 'package:app_settings/app_settings.dart';
import '../services/gemini_ai_service.dart';
import '../services/reminder_service.dart';
import '../services/pdf_export_service.dart';

part 'editor_screen_ai.dart';

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

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late QuillController _quillController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _editorFocusNode = FocusNode();
  bool _isDirty = false;
  bool _showFormattingToolbar = false;
  bool _titleHasFocus = false;
  bool _editorHasFocus = false;
  bool _isLocked = false;
  bool _isUnlocked = true;
  final BiometricService _biometricService = BiometricService();
  final GeminiAiService _geminiAiService = GeminiAiService();
  bool _isAiLoading = false;
  List<String> _tags = [];
  List<String> _imageUrls = [];
  final List<File> _uploadingFiles = [];
  final Set<String> _deletingUrls = {};
  List<String> _audioUrls = [];
  String? _noteColor;
  DateTime? _reminder; // [Hạ tầng Bản 2]

  // Checklist mode
  bool _isChecklistMode = false;
  List<ChecklistItem> _checklistItems = [];
  List<ChecklistItem>? _originalChecklistItems;

  // Math Suggestion State [MERGE từ Bản 1]
  String? _mathSuggestionResult;
  int _mathSuggestionOffset = -1;
  int? _mathSuggestionChecklistIndex;

  late String _noteId;
  late DateTime _createdAt;
  late String _status;
  bool _hasBeenSavedInDb = false;

  Timer? _autoSaveTimer;
  bool _isUploading = false;
  String? _uploadMessage;
  bool _showUploadBanner = false;
  Color _bannerColor = const Color(0xFFEFF6FF);
  Color _bannerTextColor = const Color(0xFF1E40AF);
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
    final l = AppLocalizations.translate;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l(context, 'uploadingFilesTitle')),
        content: Text(l(context, 'uploadingFilesConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l(context, 'stay')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l(context, 'exit')),
          ),
        ],
      ),
    );
  }

  // Audio Configuration
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  String? _playingUrl;
  bool _isPlaying = false;
  Duration _playPosition = Duration.zero;
  Duration _playTotal = Duration.zero;

  final _cloudinary = CloudinaryService();
  static const _primary = AppColors.primary;

  // Hàm kiểm tra thay đổi thực tế trên UI (Gộp cả kiểm tra Reminder)
  bool _hasChanges() {
    final originalTitle = widget.note?.title ?? '';
    final originalTags = widget.note?.tags ?? const [];
    final originalImages = widget.note?.imageUrls ?? const [];
    final originalAudios = widget.note?.audioUrls ?? const [];
    final originalColor = widget.note?.noteColor;
    final originalReminder = widget.note?.reminder;

    final currentTitle = _titleController.text.trim();

    final titleChanged = originalTitle != currentTitle;
    final tagsChanged = !listEquals(originalTags, _tags);
    final imagesChanged = !listEquals(originalImages, _imageUrls);
    final audiosChanged = !listEquals(originalAudios, _audioUrls);
    final colorChanged = originalColor != _noteColor;
    final reminderChanged = originalReminder != _reminder;

    if (_isChecklistMode) {
      final checklistChanged = _hasChecklistChanged();
      return titleChanged || checklistChanged || tagsChanged || imagesChanged || audiosChanged || colorChanged || reminderChanged;
    }

    final contentChanged = _isDirty;
    return titleChanged || contentChanged || tagsChanged || imagesChanged || audiosChanged || colorChanged || reminderChanged;
  }

  bool _hasChecklistChanged() {
    if (_originalChecklistItems == null) {
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

    final isChecklistContent = widget.note?.isChecklist ?? false;
    _isChecklistMode = widget.isChecklistMode || isChecklistContent;

    if (_isChecklistMode && isChecklistContent) {
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

    if (_isChecklistMode && _checklistItems.isEmpty) {
      _checklistItems.add(ChecklistItem());
    }

    _tags = List.from(widget.note?.tags ?? []);
    _imageUrls = List.from(widget.note?.imageUrls ?? []);
    _audioUrls = List.from(widget.note?.audioUrls ?? []);
    _noteColor = widget.note?.noteColor;
    _reminder = widget.note?.reminder;

    _titleController.addListener(_onTextChanged);
    _titleFocusNode.addListener(() {
      if (mounted && _titleHasFocus != _titleFocusNode.hasFocus) {
        setState(() => _titleHasFocus = _titleFocusNode.hasFocus);
      }
    });
    _editorFocusNode.addListener(() {
      if (mounted && _editorHasFocus != _editorFocusNode.hasFocus) {
        setState(() => _editorHasFocus = _editorFocusNode.hasFocus);
      }
    });
    _quillController.document.changes.listen((_) {
      _isDirty = true;
      _onTextChanged();
    });

    _quillController.addListener(() {
      final hasSelection = !_quillController.selection.isCollapsed;
      if (hasSelection && !_showFormattingToolbar) {
        setState(() => _showFormattingToolbar = true);
      } else if (!hasSelection && _showFormattingToolbar) {
        setState(() => _showFormattingToolbar = false);
      }
    });

    _audioPlayer.positionStream.listen((pos) {
      if (mounted && (pos - _playPosition).abs() > const Duration(milliseconds: 200)) {
        setState(() => _playPosition = pos);
      }
    });
    _audioPlayer.durationStream.listen((dur) {
      if (mounted) setState(() => _playTotal = dur ?? Duration.zero);
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() {
          _isPlaying = false;
          _playingUrl = null;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoRecord) _startRecording();
      if (widget.autoPickImage) _pickImage(ImageSource.gallery);
      if (widget.autoOpenDrawing) _openDrawingScreen();
      if (_isLocked) _authenticateNote();
    });
  }

  void _onTextChanged() {
    if (_isLocked && !_isUnlocked) return;

    // [MERGE từ Bản 1] Quét kiểm tra phép tính toán học thời gian thực
    _checkMathSuggestion();

    if (!_hasChanges()) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _saveNote(isAutosave: true);
    });
  }

  // [MERGE từ Bản 1] Xử lý thuật toán gợi ý toán học cục bộ
  void _checkMathSuggestion() {
    if (!_isChecklistMode) {
      int cursor = _quillController.selection.baseOffset;
      if (cursor > 0) {
        String fullText = _quillController.document.toPlainText();
        if (cursor <= fullText.length) {
          String textBeforeCursor = fullText.substring(0, cursor);
          String? result = MathParser.evaluate(textBeforeCursor);
          if (_mathSuggestionResult != result) {
            setState(() {
              _mathSuggestionResult = result;
              _mathSuggestionOffset = cursor;
              _mathSuggestionChecklistIndex = null;
            });
          }
        }
      } else if (_mathSuggestionResult != null) {
        setState(() => _mathSuggestionResult = null);
      }
    } else {
      bool found = false;
      for (int i = 0; i < _checklistItems.length; i++) {
        String text = _checklistItems[i].text;
        String? result = MathParser.evaluate(text);
        if (result != null) {
          if (_mathSuggestionResult != result || _mathSuggestionChecklistIndex != i) {
            setState(() {
              _mathSuggestionResult = result;
              _mathSuggestionChecklistIndex = i;
            });
          }
          found = true;
          break;
        }
      }
      if (!found && _mathSuggestionResult != null) {
        setState(() => _mathSuggestionResult = null);
      }
    }
  }

  // [MERGE từ Bản 1] Chèn kết quả phép tính tự động vào vị trí con trỏ
  void _insertMathSuggestion() {
    if (_mathSuggestionResult == null) return;
    final resultText = ' $_mathSuggestionResult';
    if (!_isChecklistMode && _mathSuggestionOffset >= 0) {
      _quillController.document.insert(_mathSuggestionOffset, resultText);
      _quillController.updateSelection(
        TextSelection.collapsed(offset: _mathSuggestionOffset + resultText.length),
        ChangeSource.local,
      );
    } else if (_isChecklistMode && _mathSuggestionChecklistIndex != null) {
      int index = _mathSuggestionChecklistIndex!;
      setState(() {
        _checklistItems[index].text += resultText;
      });
    }
    setState(() => _mathSuggestionResult = null);
    _onTextChanged();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      if (_isLocked && _isUnlocked) {
        setState(() => _isUnlocked = false);
      }
    }
  }

  Future<void> _authenticateNote() async {
    try {
      final authenticated = await _biometricService.authenticate(reason: AppStrings.biometricPromptReason);
      if (authenticated) {
        setState(() => _isUnlocked = true);
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
          label: AppLocalizations.translate(context, 'biometricRetry'),
          textColor: Colors.white,
          onPressed: _authenticateNote,
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showEnrollBiometricDialog() {
    if (!context.mounted) return;
    final l = AppLocalizations.translate;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l(context, 'notSetBiometricTitle')),
        content: Text(l(context, 'notSetBiometricDesc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l(context, 'notSetBiometricBtnLater')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppSettings.openAppSettings(type: AppSettingsType.security);
            },
            child: Text(l(context, 'notSetBiometricBtnOpen')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNote({required bool isAutosave}) async {
    if (!mounted) return;
    if (_isLocked && !_isUnlocked) return;
    if (!_hasChanges()) return;

    final title = _titleController.text.trim();
    final String content;
    final String plainText;

    if (_isChecklistMode) {
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
      isEmpty = title.isEmpty && _checklistItems.every((i) => i.text.trim().isEmpty) && _tags.isEmpty && _imageUrls.isEmpty && _audioUrls.isEmpty && _noteColor == null && !_isRecording;
    } else {
      isEmpty = title.isEmpty && plainText.isEmpty && _tags.isEmpty && _imageUrls.isEmpty && _audioUrls.isEmpty && _noteColor == null && !_isRecording;
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
      reminder: _reminder, // Lưu thông tin nhắc nhở đám mây
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => _uploadingFiles.add(file));

    try {
      final url = await _cloudinary.uploadImage(file, auth.userId!);
      if (!mounted) return;
      setState(() {
        _uploadingFiles.remove(file);
        if (url != null) _imageUrls.add(url);
      });
      if (url != null) await _saveNote(isAutosave: true);
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingFiles.remove(file));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.translate(context, 'uploadImageError'))));
      }
    }
  }

  Future<void> _uploadDrawing(File file) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _uploadingFiles.add(file));

    try {
      final url = await _cloudinary.uploadImage(file, auth.userId!, isDrawing: true);
      if (!mounted) return;
      setState(() {
        _uploadingFiles.remove(file);
        if (url != null) _imageUrls.add(url);
      });
      if (url != null) await _saveNote(isAutosave: true);
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingFiles.remove(file));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.translate(context, 'uploadDrawingError'))));
      }
    }
  }

  Future<void> _openDrawingScreen() async {
    final File? drawingFile = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DrawingScreen(noteColor: _noteColor)),
    );
    if (drawingFile != null) _uploadDrawing(drawingFile);
  }

  Future<void> _editDrawingScreen(String oldUrl) async {
    final File? drawingFile = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DrawingScreen(noteColor: _noteColor, initialImageUrl: oldUrl)),
    );
    if (drawingFile != null) _replaceDrawing(oldUrl, drawingFile);
  }

  Future<void> _replaceDrawing(String oldUrl, File file) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.userId == null) return;

    setState(() {
      _uploadingFiles.add(file);
      _deletingUrls.add(oldUrl);
    });

    try {
      final url = await _cloudinary.uploadImage(file, auth.userId!, isDrawing: true);
      if (!mounted) return;

      setState(() {
        _uploadingFiles.remove(file);
        _deletingUrls.remove(oldUrl);
        if (url != null) {
          final index = _imageUrls.indexOf(oldUrl);
          if (index != -1) {
            _imageUrls[index] = url;
          } else {
            _imageUrls.add(url);
          }
        }
      });
      if (url != null) await _saveNote(isAutosave: true);
      _cloudinary.deleteFile(oldUrl, resourceType: 'image').catchError((_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingFiles.remove(file);
        _deletingUrls.remove(oldUrl);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.translate(context, 'updateDrawingError'))));
    }
  }

  void _showImageSourceSheet() {
    final l = AppLocalizations.translate;
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
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.photo_library_outlined, color: _primary)),
              title: Text(l(context, 'pickFromGallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.camera_alt_outlined, color: _primary)),
              title: Text(l(context, 'takePhoto')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
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
      if (mounted) {
        _setUploadState(
          isUploading: false,
          message: AppLocalizations.translate(context, 'recordFailed'),
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
    final msgUploading = AppLocalizations.translate(context, 'uploadingAudio');
    final msgSuccess = AppLocalizations.translate(context, 'uploadAudioSuccess');
    final msgFail = AppLocalizations.translate(context, 'uploadAudioFail');
    final msgError = AppLocalizations.translate(context, 'uploadAudioError');
    _setUploadState(
      isUploading: true,
      message: msgUploading,
      bannerColor: const Color(0xFFEFF6FF),
      bannerTextColor: const Color(0xFF1E40AF),
      statusIcon: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6))),
    );

    try {
      final url = await _cloudinary.uploadAudio(File(path), auth.userId!);
      if (!mounted) return;
      if (url != null) {
        setState(() => _audioUrls.add(url));
        await _saveNote(isAutosave: true);
        _setUploadState(
          isUploading: false,
          message: msgSuccess,
          bannerColor: const Color(0xFFECFDF5),
          bannerTextColor: const Color(0xFF065F46),
          statusIcon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          autoHide: true,
        );
      } else {
        _setUploadState(
          isUploading: false,
          message: msgFail,
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
        message: msgError,
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
        setState(() {
          _playingUrl = url;
          _playPosition = Duration.zero;
        });
      }
      await _audioPlayer.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.translate;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l(context, 'deleteNoteTitle')),
        content: Text(l(context, 'deleteNoteConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l(context, 'cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l(context, 'delete')),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _autoSaveTimer?.cancel();
      if (_isPlaying) await _audioPlayer.stop();
      if (!mounted) return;
      if (_hasBeenSavedInDb) await Provider.of<NoteProvider>(context, listen: false).deleteNote(_noteId);
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
      final l = AppLocalizations.translate;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_status == 'archived'
              ? l(context, 'archivedNote')
              : l(context, 'unarchivedNoteMsg')),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _openLabelSelectionPage() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _LabelSelectionScreen(initialTags: _tags, onTagsChanged: (updatedTags) {
      setState(() => _tags = updatedTags);
      _saveNote(isAutosave: true);
    })));
  }

  // [Hạ tầng Bản 2] Định dạng hiển thị chuỗi thời gian nhắc nhở
  String _formatReminderTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dtDay = DateTime(dt.year, dt.month, dt.day);

    final l = AppLocalizations.translate;
    String timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dtDay == today) {
      return l(context, 'reminderToday').replaceAll('{time}', timeStr);
    } else if (dtDay == tomorrow) {
      return l(context, 'reminderTomorrow').replaceAll('{time}', timeStr);
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $timeStr';
    }
  }

  // [Hạ tầng Bản 2] Cấu hình giao diện lựa chọn thời gian nhắc nhở nhanh
  void _showReminderSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        final now = DateTime.now();
        final today18 = DateTime(now.year, now.month, now.day, 18, 0);
        final tomorrow8 = DateTime(now.year, now.month, now.day).add(const Duration(days: 1)).add(const Duration(hours: 8));
        int daysUntilMonday = ((7 - now.weekday) % 7) + 1;
        final nextMonday8 = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilMonday)).add(const Duration(hours: 8));

        return Container(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.translate(context, 'reminderSheetTitle'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (_reminder != null) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.alarm, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(
                    AppLocalizations.translate(context, 'scheduledTime'),
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w400),
                  ),
                  subtitle: Text(
                    _formatReminderTime(_reminder!),
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  trailing: TextButton.icon(
                    onPressed: () { Navigator.pop(context); _cancelReminder(); },
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    label: Text(
                      AppLocalizations.translate(context, 'cancel'),
                      style: GoogleFonts.outfit(color: Colors.red),
                    ),
                  ),
                ),
                const Divider(),
              ],
              if (now.isBefore(today18))
                ListTile(
                  leading: const Icon(Icons.wb_twighlight),
                  title: Text(AppLocalizations.translate(context, 'todayAt18'), style: GoogleFonts.outfit(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(context);
                    _setReminder(today18);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: Text(AppLocalizations.translate(context, 'tomorrowAt8'), style: GoogleFonts.outfit(fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  _setReminder(tomorrow8);
                },
              ),
              ListTile(
                leading: const Icon(Icons.next_week_outlined),
                title: Text(AppLocalizations.translate(context, 'nextMondayAt8'), style: GoogleFonts.outfit(fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  _setReminder(nextMonday8);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range_outlined),
                title: Text(AppLocalizations.translate(context, 'pickDateTime'), style: GoogleFonts.outfit(fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  _selectCustomDateTime();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationPermissionDialog() {
    final l = AppLocalizations.translate;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.notifications_off_outlined, color: Colors.amber.shade700, size: 28),
            const SizedBox(width: 12),
            Text(l(context, 'notifPermissionTitle')),
          ],
        ),
        content: Text(l(context, 'notifPermissionDesc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l(context, 'notifPermissionLater'),
              style: GoogleFonts.outfit(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              l(context, 'notifPermissionOpen'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setReminder(DateTime dt) async {
    final granted = await ReminderService().requestPermissions();
    if (!granted) { if (mounted) _showNotificationPermissionDialog(); return; }
    setState(() => _reminder = dt);
    await _saveNote(isAutosave: false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.translate(context, 'reminderSet').replaceAll('{time}', _formatReminderTime(dt))),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelReminder() async {
    setState(() => _reminder = null);
    await _saveNote(isAutosave: false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.translate(context, 'reminderCancelled')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectCustomDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('vi', 'VN'),
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pickedTime == null) return;

    final selectedDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    if (selectedDateTime.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.translate(context, 'reminderPastError')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    _setReminder(selectedDateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isCustomColor = _noteColor != null;
    final onDarkNoteBg = isCustomColor && _isNoteBackgroundDark(context);
    final textColor = isCustomColor ? (onDarkNoteBg ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)) : null;
    final placeholderColor = isCustomColor ? (onDarkNoteBg ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)) : null;

    final quillBaseStyles = DefaultStyles.getInstance(context);
    final quillCustomStyles = DefaultStyles(
      h1: quillBaseStyles.h1?.copyWith(style: quillBaseStyles.h1!.style.copyWith(fontWeight: FontWeight.w400, color: textColor)),
      h2: quillBaseStyles.h2?.copyWith(style: quillBaseStyles.h2!.style.copyWith(fontWeight: FontWeight.w400, color: textColor)),
      paragraph: quillBaseStyles.paragraph?.copyWith(style: quillBaseStyles.paragraph!.style.copyWith(color: textColor)),
      bold: quillBaseStyles.bold?.copyWith(color: textColor),
      italic: quillBaseStyles.italic?.copyWith(color: textColor),
      underline: quillBaseStyles.underline?.copyWith(color: textColor),
      placeHolder: quillBaseStyles.placeHolder?.copyWith(style: quillBaseStyles.placeHolder!.style.copyWith(color: placeholderColor)),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_showFormattingToolbar) { setState(() => _showFormattingToolbar = false); return; }
        if (_isLocked && !_isUnlocked) { Navigator.of(context).pop(); return; }
        if (_isUploading) { final confirmExit = await _showUploadExitConfirmation(); if (confirmExit != true) return; }
        if (_isRecording) await _stopRecordingAndUpload();
        _autoSaveTimer?.cancel();
        if (_hasChanges()) await _saveNote(isAutosave: false);
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: _noteBackgroundColor(context) ?? AppColors.background(context),
        appBar: AppBar(
          backgroundColor: _noteBackgroundColor(context) ?? AppColors.background(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isCustomColor ? (onDarkNoteBg ? Colors.white : const Color(0xFF1E293B)) : AppColors.textPrimary(context)),
            onPressed: () async {
              if (_showFormattingToolbar) { setState(() => _showFormattingToolbar = false); return; }
              if (_isLocked && !_isUnlocked) { Navigator.of(context).pop(); return; }
              if (_isUploading) { final confirmExit = await _showUploadExitConfirmation(); if (confirmExit != true) return; }
              if (_isRecording) await _stopRecordingAndUpload();
              _autoSaveTimer?.cancel();
              if (_hasChanges()) await _saveNote(isAutosave: false);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            if (_isUploading) const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _primary, strokeWidth: 2)))),
            Tooltip(
              message: AppLocalizations.translate(context, 'aiTooltip'),
              child: GestureDetector(
                onTap: _isAiLoading ? null : _showAiOptions,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40, height: 40,
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899)]).createShader(bounds),
                      child: const Icon(Icons.auto_awesome, size: 22, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            _buildAppBarRoundBtn(
              icon: _isLocked ? Icons.lock : Icons.lock_open_outlined,
              tooltip: _isLocked ? AppLocalizations.translate(context, 'unlockNoteTooltip') : AppLocalizations.translate(context, 'lockNoteTooltip'),
              onTap: () async {
                if (!_hasBeenSavedInDb) {
                  _showRequiresSaveMessage(AppLocalizations.translate(context, 'lockNoteTooltip').toLowerCase());
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final provider =
                    Provider.of<NoteProvider>(context, listen: false);
                final msgLocked = AppLocalizations.translate(context, 'lockedNote');
                final msgUnlocked = AppLocalizations.translate(context, 'unlockedNote');
                try {
                  final success = await provider.toggleLock(_noteId);
                  if (success) {
                    setState(() {
                      _isLocked = !_isLocked;
                      _isUnlocked = !_isLocked;
                    });
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(_isLocked ? msgLocked : msgUnlocked),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
            ),
            _buildAppBarRoundBtn(
              icon: _status == 'pinned'
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              tooltip: _status == 'pinned' ? AppLocalizations.translate(context, 'unpinTooltip') : AppLocalizations.translate(context, 'pinTooltip'),
              onTap: () {
                if (!_hasBeenSavedInDb) {
                  _showRequiresSaveMessage(AppLocalizations.translate(context, 'pinTooltip').toLowerCase());
                  return;
                }
                _togglePin();
              },
            ),
            _buildAppBarRoundBtn(
              icon: _reminder != null ? Icons.notifications_active : Icons.notification_add_outlined,
              tooltip: AppLocalizations.translate(context, 'reminderTooltip'),
              onTap: () {
                if (!_hasBeenSavedInDb) {
                  _showRequiresSaveMessage(AppLocalizations.translate(context, 'reminderTooltip').toLowerCase());
                  return;
                }
                _showReminderSettingsSheet();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                EditorUploadBanner(showBanner: _showUploadBanner, message: _uploadMessage, bannerColor: _bannerColor, bannerTextColor: _bannerTextColor, statusIcon: _statusIcon, isUploading: _isUploading),

                // [MERGE UI từ Bản 1] Thanh hiển thị kết quả phân tích toán học thông minh
                if (_mathSuggestionResult != null)
                  Container(
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.calculate_outlined, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text('Gợi ý tính toán: $_mathSuggestionResult', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                        const Spacer(),
                        TextButton(onPressed: _insertMathSuggestion, child: const Text('Chấp nhận')),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_imageUrls.isNotEmpty || _uploadingFiles.isNotEmpty) EditorImageSection(imageUrls: _imageUrls, uploadingFiles: _uploadingFiles, deletingUrls: _deletingUrls, noteColor: _noteColor, onOpenImage: _openImageViewer, onEditDrawing: _editDrawingScreen),
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
                                  ? (onDarkNoteBg
                                      ? Colors.white
                                      : const Color(0xFF0F172A))
                                  : AppColors.textSecondary(context),
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.translate(context, 'titleHint'),
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: isCustomColor
                                    ? (onDarkNoteBg
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF64748B))
                                    : AppColors.placeholder(context),
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: null,
                          ),
                        ),

                        // [Hạ tầng Bản 2] Chip Hiển thị thời gian nhắc nhở đã hẹn ngầm
                        if (_reminder != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Material(
                                color: isCustomColor ? (onDarkNoteBg ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05)) : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: _showReminderSettingsSheet,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.alarm, size: 16, color: isCustomColor ? (onDarkNoteBg ? Colors.white70 : Colors.black87) : Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          AppLocalizations.translate(context, 'reminderPrefix').replaceAll('{time}', _formatReminderTime(_reminder!)),
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: isCustomColor
                                                ? (onDarkNoteBg ? Colors.white70 : Colors.black87)
                                                : Theme.of(context).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(onTap: _cancelReminder, child: Icon(Icons.close, size: 14, color: isCustomColor ? (onDarkNoteBg ? Colors.white60 : Colors.black54) : Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_isChecklistMode)
                          _buildChecklistEditor()
                        else
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _editorFocusNode.requestFocus();
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
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
                                      placeholder: AppLocalizations.translate(context, 'notePlaceholder'),
                                      customStyles: quillCustomStyles,
                                    ),
                                  ),
                                  if (_audioUrls.isNotEmpty ||
                                      _isRecording) ...[
                                    const SizedBox(height: 16),
                                    EditorAudioSection(
                                      audioUrls: _audioUrls,
                                      isRecording: _isRecording,
                                      recordDuration: _recordDuration,
                                      playingUrl: _playingUrl,
                                      isPlaying: _isPlaying,
                                      playPosition: _playPosition,
                                      playTotal: _playTotal,
                                      noteColor: _noteColor,
                                      onTogglePlay: _togglePlay,
                                      onSeek: (val) => _audioPlayer.seek(
                                          Duration(milliseconds: val.toInt())),
                                      onDeleteAudio: _deleteAudio,
                                      onStopRecording: _stopRecordingAndUpload,
                                    ),
                                  ],
                                  if (_tags.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: _tags
                                          .map((tag) => Chip(
                                                label: Text(
                                                  tag,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: _noteColor != null
                                                        ? const Color(
                                                            0xFF1E293B)
                                                        : AppColors
                                                            .textSecondary(
                                                                context),
                                                  ),
                                                ),
                                                backgroundColor: _noteColor !=
                                                        null
                                                    ? Colors.black
                                                        .withValues(alpha: 0.05)
                                                    : AppColors.inputBackground(
                                                        context),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                side: BorderSide(
                                                    color: _noteColor != null
                                                        ? Colors.black
                                                            .withValues(
                                                                alpha: 0.08)
                                                        : AppColors.divider(
                                                            context)),
                                              ))
                                          .toList(),
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
                    width: double.infinity, height: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(onTap: _authenticateNote, child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.lock_outline, size: 64, color: AppColors.primary))),
                        const SizedBox(height: 24),
                        Text(
                          AppLocalizations.translate(context, 'noteLockedTitle'),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.translate(context, 'noteLockedSubtitle'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textMetadata(context),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _authenticateNote,
                          icon: const Icon(Icons.fingerprint,
                              color: Colors.white),
                          label: Text(
                            AppLocalizations.translate(context, 'authenticateNow'),
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
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

  Future<void> _deleteAudio(String url, int index) async {
    final msgDeleting = AppLocalizations.translate(context, 'deletingAudio');
    final msgSuccess = AppLocalizations.translate(context, 'deleteAudioSuccess');
    final msgFail = AppLocalizations.translate(context, 'deleteAudioFail');
    if (_playingUrl == url) {
      await _audioPlayer.stop();
      setState(() {
        _playingUrl = null;
        _isPlaying = false;
      });
    }
    _setUploadState(
      isUploading: true,
      message: msgDeleting,
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
          message: msgSuccess,
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
          message: msgFail,
          bannerColor: const Color(0xFFFEF2F2),
          bannerTextColor: const Color(0xFF991B1B),
          statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
          autoHide: true,
        );
      }
    }
  }

  void _openImageViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewer(
          imageUrls: _imageUrls,
          initialIndex: initialIndex,
          onEditDrawing: (url) {
            Navigator.pop(context);
            _editDrawingScreen(url);
          },
          onDuplicate: (url) async {
            setState(() => _imageUrls.add(url));
            await _saveNote(isAutosave: true);
          },
          onDelete: (url) {
            Navigator.pop(context);
            _setUploadState(
              isUploading: true,
              message: AppLocalizations.translate(context, 'deletingImage'),
              bannerColor: const Color(0xFFEFF6FF),
              bannerTextColor: const Color(0xFF1E40AF),
              statusIcon: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E75B6)),
              ),
            );
            _cloudinary.deleteFile(url, resourceType: 'image').then((_) {
              if (mounted) {
                setState(() => _imageUrls.remove(url));
                _saveNote(isAutosave: true);
                _setUploadState(
                  isUploading: false,
                  message: AppLocalizations.translate(context, 'deleteImageSuccess'),
                  bannerColor: const Color(0xFFECFDF5),
                  bannerTextColor: const Color(0xFF065F46),
                  statusIcon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                  autoHide: true,
                );
              }
            }).catchError((_) {
              if (mounted) {
                _setUploadState(
                  isUploading: false,
                  message: AppLocalizations.translate(context, 'deleteImageFail'),
                  bannerColor: const Color(0xFFFEF2F2),
                  bannerTextColor: const Color(0xFF991B1B),
                  statusIcon: const Icon(Icons.error, color: Color(0xFFEF4444), size: 16),
                  autoHide: true,
                );
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildChecklistEditor() {
    return Column(
      children: [
        EditorChecklistSection(
          checklistItems: _checklistItems,
          noteColor: _noteColor,
          onAddChecklistItem: _addChecklistItem,
          onAddChecklistItemAfter: _addChecklistItemAfter,
          onRemoveChecklistItem: (index) {
            setState(() => _checklistItems.removeAt(index));
            _onTextChanged();
          },
          onItemTextChanged: (index, val) {
            _checklistItems[index].text = val;
            _onTextChanged();
          },
          onItemChecked: (index, val) {
            setState(() => _checklistItems[index].checked = val);
            _onTextChanged();
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _checklistItems.removeAt(oldIndex);
              _checklistItems.insert(newIndex, item);
            });
            _onTextChanged();
          },
          onExitChecklistMode: _exitChecklistMode,
        ),
        if (_audioUrls.isNotEmpty || _isRecording || _tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_audioUrls.isNotEmpty || _isRecording) ...[
                  const SizedBox(height: 8),
                  EditorAudioSection(
                    audioUrls: _audioUrls,
                    isRecording: _isRecording,
                    recordDuration: _recordDuration,
                    playingUrl: _playingUrl,
                    isPlaying: _isPlaying,
                    playPosition: _playPosition,
                    playTotal: _playTotal,
                    noteColor: _noteColor,
                    onTogglePlay: _togglePlay,
                    onSeek: (val) => _audioPlayer.seek(Duration(milliseconds: val.toInt())),
                    onDeleteAudio: _deleteAudio,
                    onStopRecording: _stopRecordingAndUpload,
                  ),
                ],
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _tags
                        .map((tag) => Chip(
                      label: Text(tag, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569))),
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: Colors.grey.shade200),
                    ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
      ],
    );
  }

  void _addChecklistItem() {
    setState(() { _checklistItems.add(ChecklistItem()); });
    _onTextChanged();
  }

  void _addChecklistItemAfter(int index) {
    setState(() { _checklistItems.insert(index + 1, ChecklistItem()); });
    _onTextChanged();
  }

  void _exitChecklistMode() {
    final text = _checklistItems.map((i) => i.text).where((t) => t.trim().isNotEmpty).join('\n');
    setState(() {
      _isChecklistMode = false;
      _checklistItems = [];
      if (text.isNotEmpty) {
        final doc = Document()..insert(0, text);
        _quillController = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      } else {
        _quillController = QuillController.basic();
      }
      _isDirty = true;
    });
    _quillController.document.changes.listen((_) { _isDirty = true; _onTextChanged(); });
  }

  void _switchToChecklistMode() {
    final plainText = _quillController.document.toPlainText().trim();
    setState(() {
      _isChecklistMode = true;
      if (plainText.isNotEmpty) {
        _checklistItems = plainText.split('\n').where((line) => line.trim().isNotEmpty).map((line) => ChecklistItem(text: line)).toList();
      }
      if (_checklistItems.isEmpty) { _checklistItems = [ChecklistItem()]; }
      _originalChecklistItems = null;
      _isDirty = true;
    });
  }

  Widget _buildBottomToolbar() {
    if (_showFormattingToolbar && !_isChecklistMode) {
      return EditorFormatToolbar(
        quillController: _quillController,
        onClose: () { setState(() { _showFormattingToolbar = false; }); },
        isButtonsDisabled: _isChecklistMode || _titleFocusNode.hasFocus || !_editorFocusNode.hasFocus,
      );
    }

    return BottomAppBar(
      color: _noteBackgroundColor(context) ?? AppColors.toolbarBackground(context),
      elevation: 0,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _toolbarButton(
                      icon: Icons.add_box_outlined,
                      tooltip: AppLocalizations.translate(context, 'toolbarAdd'),
                      onTap: _isUploading ? null : _showAddOptions),
                  _toolbarButton(
                    icon: Icons.palette_outlined,
                    tooltip: AppLocalizations.translate(context, 'toolbarColor'),
                    onTap: _showColorPicker,
                  ),
                  if (!_isChecklistMode)
                    _toolbarButton(
                      icon: Icons.format_color_text,
                      tooltip: AppLocalizations.translate(context, 'toolbarFormat'),
                      color: _showFormattingToolbar ? _primary : null,
                      onTap: () { setState(() { _showFormattingToolbar = true; }); },
                    ),
                ],
              ),
              const Spacer(),
              if (!_isChecklistMode)
                ListenableBuilder(
                  listenable: _quillController,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _toolbarButton(
                          icon: Icons.undo,
                          tooltip: AppLocalizations.translate(context, 'toolbarUndo'),
                          onTap: _quillController.hasUndo
                              ? () => _quillController.undo()
                              : null,
                        ),
                        _toolbarButton(
                          icon: Icons.redo,
                          tooltip: AppLocalizations.translate(context, 'toolbarRedo'),
                          onTap: _quillController.hasRedo
                              ? () => _quillController.redo()
                              : null,
                        ),
                      ],
                    );
                  },
                ),

              // 📦 BỌC CỤM ICON BÊN PHẢI: Chỉ gồm duy nhất nút 3 chấm More dọc
              _toolbarButton(
                  icon: Icons.more_vert,
                  tooltip: AppLocalizations.translate(context, 'toolbarMore'),
                  onTap: _showMoreOptions),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => EditorAddOptionsSheet(
        isRecording: _isRecording,
        isChecklistMode: _isChecklistMode,
        onAddImage: _showImageSourceSheet,
        onAddDrawing: _openDrawingScreen,
        onToggleRecording: () { _isRecording ? _stopRecordingAndUpload() : _startRecording(); },
        onSwitchToChecklistMode: _switchToChecklistMode,
      ),
    );
  }

  Note _getCurrentNoteObject() {
    String finalContent = '';
    if (_isChecklistMode) {
      finalContent = jsonEncode({
        'type': 'checklist',
        'items': _checklistItems.map((item) => item.toJson()).toList(),
      });
    } else {
      finalContent = jsonEncode(_quillController.document.toDelta().toJson());
    }

    return Note(
      id: _noteId,
      userId: widget.note?.userId ?? '',
      title: _titleController.text.trim(),
      content: finalContent,
      status: _status,
      noteColor: _noteColor,
      tags: _tags,
      imageUrls: _imageUrls,
      audioUrls: _audioUrls,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      reminder: _reminder,
    );
  }

  void _exportToPdf() {
    final currentNote = _getCurrentNoteObject();
    PdfExportService.exportNoteToPdf(context, currentNote);
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => EditorMoreOptionsSheet(
        hasBeenSavedInDb: _hasBeenSavedInDb,
        status: _status,
        onDelete: _delete,
        onLabelSelection: _openLabelSelectionPage,
        onToggleArchive: _toggleArchive,
        onExportPdf: _exportToPdf,
      ),
    );
  }

  void _showRequiresSaveMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.translate(context, 'requiresSaveMsg').replaceAll('{action}', action)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _buildAppBarRoundBtn({required IconData icon, required String tooltip, required VoidCallback? onTap}) {
    final isCustomColor = _noteColor != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 40, height: 40,
          child: Center(child: Icon(icon, size: 22, color: isCustomColor ? const Color(0xFF1E293B) : AppColors.textMetadata(context))),
        ),
      ),
    );
  }

  Widget _toolbarButton({required IconData icon, required String tooltip, VoidCallback? onTap, Color? color}) {
    final isCustomColor = _noteColor != null;
    final defaultIconColor = isCustomColor ? const Color(0xFF1E293B) : AppColors.textPrimary(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: SizedBox(
            width: 40, height: 40,
            child: Center(child: Icon(icon, size: 22, color: onTap == null ? (isCustomColor ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.3)) : (color ?? defaultIconColor))),
          ),
        ),
      ),
    );
  }

  Color? _noteBackgroundColor(BuildContext context) => AppColors.resolveNoteBackground(context, _noteColor);

  bool _isNoteBackgroundDark(BuildContext context) {
    final bg = _noteBackgroundColor(context);
    if (bg == null) return false;
    return bg.computeLuminance() < 0.45;
  }

  void _showColorPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return EditorColorPickerSheet(
          noteColor: _noteColor,
          onColorSelected: (newColor) {
            setState(() => _noteColor = newColor);
            _saveNote(isAutosave: true);
          },
        );
      },
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
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.inter(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: AppLocalizations.translate(context, 'labelSearchHint'),
            border: InputBorder.none,
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
                    title: Text(
                        AppLocalizations.translate(context, 'createLabelOption').replaceAll('{name}', _searchQuery.trim()),
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary(context))),
                    onTap: () {
                      final newTag = _searchQuery.trim();
                      provider.addLabel(newTag);
                      setState(() {
                        if (!_selectedTags.contains(newTag)) _selectedTags.add(newTag);
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      widget.onTagsChanged(_selectedTags);
                    },
                  ),
                ...filteredLabels.map((label) {
                  final isChecked = _selectedTags.contains(label);
                  return CheckboxListTile(
                    title: Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary(context))),
                    value: isChecked,
                    activeColor: AppColors.primary,
                    checkColor: AppColors.onPrimary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTags.add(label);
                        } else {
                          _selectedTags.remove(label);
                        }
                      });
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

class _ImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Function(String) onEditDrawing;
  final Function(String) onDuplicate;
  final Function(String) onDelete;

  const _ImageViewer({required this.imageUrls, required this.initialIndex, required this.onEditDrawing, required this.onDuplicate, required this.onDelete});
  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() { super.initState(); _currentIndex = widget.initialIndex; _pageController = PageController(initialPage: _currentIndex); }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.pop(context); });
      return const Scaffold(backgroundColor: Colors.white);
    }
    if (_currentIndex >= widget.imageUrls.length) { _currentIndex = widget.imageUrls.length - 1; }
    final currentUrl = widget.imageUrls[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            AppLocalizations.translate(context, 'imageCountTitle')
                .replaceAll('{current}', '${_currentIndex + 1}')
                .replaceAll('{total}', '${widget.imageUrls.length}'),
            style:
                GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.brush),
            tooltip: AppLocalizations.translate(context, 'drawOnImageTooltip'),
            onPressed: () => widget.onEditDrawing(currentUrl),
          ),
          PopupMenuButton<String>(
            tooltip: AppLocalizations.translate(context, 'imageOptionsTooltip'),
            onSelected: (value) {
              if (value == 'duplicate') { widget.onDuplicate(currentUrl); setState(() {}); }
              else if (value == 'delete') { widget.onDelete(currentUrl); setState(() {}); }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'duplicate', child: Text(AppLocalizations.translate(context, 'duplicateImage'))),
              PopupMenuItem(
                  value: 'delete',
                  child: Text(AppLocalizations.translate(context, 'deleteImage'), style: const TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) { setState(() => _currentIndex = index); },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: widget.imageUrls[index],
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary))),
              errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)),
            ),
          );
        },
      ),
    );
  }
}