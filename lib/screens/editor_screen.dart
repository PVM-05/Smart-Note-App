// lib/screens/editor_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cloudinary_service.dart';
import 'package:uuid/uuid.dart';

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

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String> _tags = [];
  List<String> _imageUrls = [];
  List<String> _audioUrls = [];

  late String _noteId;
  late DateTime _createdAt;
  late String _status;
  bool _hasBeenSavedInDb = false;

  Timer? _autoSaveTimer;
  bool _isUploading = false;
  String _uploadingLabel = '';

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
  static const _danger = Color(0xFFDC2626);
  static const _recordColor = Color(0xFFEF4444);

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _noteId = widget.note?.id ?? const Uuid().v4();
    _createdAt = widget.note?.createdAt ?? DateTime.now();
    _status = widget.note?.status ?? 'normal';
    _hasBeenSavedInDb = widget.note != null;

    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tags = List.from(widget.note?.tags ?? []);
    _imageUrls = List.from(widget.note?.imageUrls ?? []);
    _audioUrls = List.from(widget.note?.audioUrls ?? []);

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // Lắng nghe luồng phát Audio
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

    // Kích hoạt tự động hành động nhanh sau khi UI dựng xong frame đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoRecord) {
        _startRecording();
      } else if (widget.autoPickImage) {
        _pickImage(ImageSource.gallery);
      }
    });
  }

  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _saveNote(isAutosave: true);
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _recordTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();

    // Tắt trình phát nhạc ngay lập tức để giải phóng RAM phần cứng phần cứng
    _audioPlayer.stop();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // SAVE NOTE
  // ══════════════════════════════════════════════
  Future<void> _saveNote({required bool isAutosave}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.userId ?? '';
    if (currentUserId.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);

    // Kiểm tra Note trống (bọc thêm điều kiện !_isRecording để tránh tự hủy Note khi đang thu âm)
    final isEmpty = title.isEmpty && content.isEmpty && _tags.isEmpty
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
  }

  // ══════════════════════════════════════════════
  // UPLOAD ẢNH
  // ══════════════════════════════════════════════
  Future<void> _pickImage(ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() { _isUploading = true; _uploadingLabel = 'Đang tải ảnh...'; });

    final url = source == ImageSource.gallery
        ? await _cloudinary.pickAndUploadImage(auth.userId!)
        : await _cloudinary.cameraAndUploadImage(auth.userId!);

    setState(() => _isUploading = false);

    if (url != null) {
      setState(() => _imageUrls.add(url));
      await _saveNote(isAutosave: true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload thất bại. Kiểm tra preset Unsigned chưa?'),
            backgroundColor: _danger,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.photo_library_outlined, color: _primary),
              ),
              title: const Text('Chọn từ thư viện'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.camera_alt_outlined, color: _primary),
              ),
              title: const Text('Chụp ảnh'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // GHI ÂM
  // ══════════════════════════════════════════════
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần quyền microphone để ghi âm')),
      );
      return;
    }

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

    if (path == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() { _isUploading = true; _uploadingLabel = 'Đang tải âm thanh...'; });

    final url = await _cloudinary.uploadAudio(File(path), auth.userId!);
    setState(() => _isUploading = false);

    if (url != null) {
      setState(() => _audioUrls.add(url));
      await _saveNote(isAutosave: true);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload âm thanh thất bại'), backgroundColor: _danger),
      );
    }
  }

  // ══════════════════════════════════════════════
  // PHÁT ÂM THANH
  // ══════════════════════════════════════════════
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

  // ══════════════════════════════════════════════
  // DELETE / PIN
  // ══════════════════════════════════════════════
  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: const Text('Hành động này sẽ xóa ghi chú và toàn bộ tệp đính kèm.'),
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

      // Dọn sạch tệp tin realtime trên hệ thống Cloudinary
      for (String url in _imageUrls) {
        await _cloudinary.deleteFile(url, resourceType: 'image');
      }
      for (String url in _audioUrls) {
        await _cloudinary.deleteFile(url, resourceType: 'video');
      }

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

  void _openLabelSelectionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LabelSelectionScreen(
          initialTags: _tags,
          onTagsChanged: (updatedTags) {
            setState(() => _tags = updatedTags);
            _saveNote(isAutosave: false);
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Giữ chặn sự kiện đóng tự động
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isRecording) await _stopRecordingAndUpload();
        _autoSaveTimer?.cancel();
        await _saveNote(isAutosave: false);

        // Thoát trang an toàn thông qua bộ điều hướng vùng chứa
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // Đồng bộ hóa: Lưu toàn bộ dữ liệu trước khi đóng màn hình
              if (_isRecording) await _stopRecordingAndUpload();
              _autoSaveTimer?.cancel();
              await _saveNote(isAutosave: false);

              if (mounted) {
                Navigator.of(context).pop(); // Thực thi lệnh quay lại trang trước
              }
            },
          ),
          actions: [
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            if (_hasBeenSavedInDb)
              IconButton(
                icon: Icon(_status == 'pinned'
                    ? Icons.push_pin : Icons.push_pin_outlined),
                tooltip: _status == 'pinned' ? 'Bỏ ghim' : 'Ghim',
                onPressed: _togglePin,
              ),
            if (_hasBeenSavedInDb)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Xóa',
                onPressed: _delete,
              ),
          ],
        ),

        body: Column(
          children: [
            // ── LOADING BANNER ──
            if (_isUploading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: _primary.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                    ),
                    const SizedBox(width: 12),
                    Text(_uploadingLabel,
                        style: const TextStyle(fontSize: 13, color: _primary)),
                  ],
                ),
              ),

            // ── NỘI DUNG CHÍNH ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề
                    TextField(
                      controller: _titleController,
                      autofocus: !_isEditing && !widget.autoRecord && !widget.autoPickImage,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'Tiêu đề...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                    ),

                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Nội dung chữ
                    TextField(
                      controller: _contentController,
                      style: const TextStyle(fontSize: 16, height: 1.6),
                      decoration: const InputDecoration(
                        hintText: 'Viết ghi chú...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    // ── LƯỚI HIỂN THỊ HÌNH ẢNH ──
                    if (_imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildImageGrid(),
                    ],

                    // ── DANH SÁCH AUDIO TRÌNH PHÁT ──
                    if (_audioUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._audioUrls.asMap().entries.map((e) =>
                          _buildAudioItem(e.value, e.key)),
                    ],

                    // ── THANH TRẠNG THÁI GHI ÂM DỰNG SẴN ──
                    if (_isRecording) ...[
                      const SizedBox(height: 12),
                      _buildRecordingIndicator(),
                    ],

                    // ── HIỂN THỊ NHÃN (TAGS) ──
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 4,
                        children: _tags.map((tag) => ActionChip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          onPressed: _openLabelSelectionPage,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(color: Colors.grey.shade300),
                        )).toList(),
                      ),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── BOTTOM BAR TOOLBAR ──
        bottomNavigationBar: _buildBottomToolbar(),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // WIDGETS CON PHỤ TRỢ UI
  // ══════════════════════════════════════════════

  Widget _buildImageGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _imageUrls.map((url) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => _showFullImage(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  width: 110, height: 110,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorBuilder: (_, __, ___) => Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.grey),
                  ),
                ),
              ),
            ),
            // Nút xóa ảnh dạng dấu X tròn
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () async {
                  setState(() { _isUploading = true; _uploadingLabel = 'Đang xóa ảnh trên cloud...'; });
                  await _cloudinary.deleteFile(url, resourceType: 'image');

                  setState(() {
                    _imageUrls.remove(url);
                    _isUploading = false;
                  });
                  await _saveNote(isAutosave: true);
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40, right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioItem(String url, int index) {
    final isThisPlaying = _playingUrl == url && _isPlaying;
    final isThisLoaded = _playingUrl == url;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Nút khởi chạy play/pause audio
          GestureDetector(
            onTap: () => _togglePlay(url),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isThisPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Thanh trượt tiến trình bài ghi âm
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghi âm ${index + 1}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12),
                  ),
                  child: Slider(
                    value: isThisLoaded
                        ? _playPosition.inMilliseconds
                        .toDouble()
                        .clamp(0, _playTotal.inMilliseconds.toDouble())
                        : 0,
                    max: isThisLoaded && _playTotal.inMilliseconds > 0
                        ? _playTotal.inMilliseconds.toDouble()
                        : 1,
                    activeColor: _primary,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: isThisLoaded
                        ? (val) {
                      _audioPlayer.seek(
                          Duration(milliseconds: val.toInt()));
                    }
                        : null,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isThisLoaded
                          ? _formatDuration(_playPosition)
                          : '00:00',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      isThisLoaded
                          ? _formatDuration(_playTotal)
                          : '--:--',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Nút bấm xóa Audio cục bộ và đồng bộ lên đám mây Cloudinary
          GestureDetector(
            onTap: () async {
              if (_playingUrl == url) {
                _audioPlayer.stop();
                setState(() { _playingUrl = null; _isPlaying = false; });
              }

              setState(() { _isUploading = true; _uploadingLabel = 'Đang xóa âm thanh trên cloud...'; });
              await _cloudinary.deleteFile(url, resourceType: 'video');

              setState(() {
                _audioUrls.removeAt(index);
                _isUploading = false;
              });
              await _saveNote(isAutosave: true);
            },
            child: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _recordColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _recordColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Chấm tròn đỏ nhấp nháy chuyển động trạng thái
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1.0),
            duration: const Duration(milliseconds: 600),
            builder: (_, val, child) => Opacity(opacity: val, child: child),
            child: Container(
              width: 12, height: 12,
              decoration: const BoxDecoration(
                color: _recordColor, shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Đang ghi âm... ${_formatDuration(_recordDuration)}',
              style: const TextStyle(
                  color: _recordColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
          // Nút dừng ghi âm nhanh
          GestureDetector(
            onTap: _stopRecordingAndUpload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _recordColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Dừng',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return BottomAppBar(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            _toolbarButton(
              icon: Icons.image_outlined,
              tooltip: 'Thêm ảnh',
              onTap: _isUploading ? null : _showImageSourceSheet,
            ),
            _toolbarButton(
              icon: _isRecording ? Icons.stop_circle_outlined : Icons.mic_outlined,
              tooltip: _isRecording ? 'Dừng ghi âm' : 'Ghi âm',
              color: _isRecording ? _recordColor : null,
              onTap: _isUploading
                  ? null
                  : (_isRecording ? _stopRecordingAndUpload : _startRecording),
            ),
            _toolbarButton(
              icon: Icons.label_outline,
              tooltip: 'Thêm nhãn',
              onTap: _openLabelSelectionPage,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _isUploading ? _uploadingLabel : (_hasBeenSavedInDb ? 'Đã lưu' : ''),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Icon(
            icon,
            size: 24,
            color: onTap == null ? Colors.grey.shade300 : (color ?? Colors.black54),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LABEL SELECTION (Giữ nguyên cấu trúc lọc)
// ══════════════════════════════════════════════════════════════
class _LabelSelectionScreen extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  const _LabelSelectionScreen({
    required this.initialTags,
    required this.onTagsChanged,
  });

  @override
  State<_LabelSelectionScreen> createState() => _LabelSelectionScreenState();
}

class _LabelSelectionScreenState extends State<_LabelSelectionScreen> {
  late List<String> _selectedTags;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NoteProvider>(context);
    final allLabels = provider.allLabels;
    final filteredLabels = allLabels
        .where((l) => l.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    final isExactMatch = allLabels.any(
            (l) => l.toLowerCase() == _searchQuery.trim().toLowerCase());
    final showCreate = _searchQuery.trim().isNotEmpty && !isExactMatch;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập tên nhãn',
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            )
                : null,
          ),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
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
                    title: Text('Tạo "${_searchQuery.trim()}"',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    onTap: () {
                      final newTag = _searchQuery.trim();
                      provider.addLabel(newTag);
                      setState(() {
                        if (!_selectedTags.contains(newTag)) {
                          _selectedTags.add(newTag);
                        }
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      widget.onTagsChanged(_selectedTags);
                    },
                  ),
                ...filteredLabels.map((label) {
                  final isChecked = _selectedTags.contains(label);
                  return CheckboxListTile(
                    title: Text(label, style: const TextStyle(fontSize: 15)),
                    value: isChecked,
                    activeColor: _primary,
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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