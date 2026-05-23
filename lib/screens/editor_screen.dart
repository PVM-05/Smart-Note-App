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
    _audioPlayer.stop();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveNote({required bool isAutosave}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.userId ?? '';
    if (currentUserId.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);
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

  Future<void> _pickImage(ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Đánh dấu trạng thái bắt đầu để giao diện hiển thị ProgressBar nếu người dùng thực sự chọn file
    setState(() { _isUploading = true; _uploadingLabel = 'Đang tải ảnh...'; });

    final url = source == ImageSource.gallery
        ? await _cloudinary.pickAndUploadImage(auth.userId!)
        : await _cloudinary.cameraAndUploadImage(auth.userId!);

    if (!mounted) return;
    setState(() => _isUploading = false);

    // Chỉ thực hiện xử lý lưu và update nếu có dữ liệu URL trả về (người dùng thực sự chọn ảnh)
    if (url != null) {
      setState(() => _imageUrls.add(url));
      await _saveNote(isAutosave: true);
    }
    // LOẠI BỎ TOÀN BỘ PHẦN ELSE SHOW SNACKBAR LỖI THỪA KHI KHÔNG CHỌN ẢNH
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
    if (path == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() { _isUploading = true; _uploadingLabel = 'Đang tải âm thanh...'; });

    final url = await _cloudinary.uploadAudio(File(path), auth.userId!);
    setState(() => _isUploading = false);

    if (url != null) {
      setState(() => _audioUrls.add(url));
      await _saveNote(isAutosave: true);
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

  // ── KHÔI PHỤC CHỨC NĂNG ARCHIVE (LƯU TRỮ) CHO CƠ SỞ DỮ LIỆU ──
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
      Navigator.of(context).pop(); // Thoát về màn hình trước đó giống như khi bấm Xóa/Ghim
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isRecording) await _stopRecordingAndUpload();
        _autoSaveTimer?.cancel();
        await _saveNote(isAutosave: false);
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
              if (_isRecording) await _stopRecordingAndUpload();
              _autoSaveTimer?.cancel();
              await _saveNote(isAutosave: false);
              if (mounted) Navigator.of(context).pop();
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
                icon: Icon(_status == 'pinned' ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.black87),
                onPressed: _togglePin,
              ),
            // Nút Lưu trữ động bám sát thanh chức năng hệ thống
            if (_hasBeenSavedInDb)
              IconButton(
                icon: Icon(_status == 'archived' ? Icons.unarchive_outlined : Icons.archive_outlined, color: Colors.black87),
                tooltip: _status == 'archived' ? 'Hủy lưu trữ' : 'Lưu trữ',
                onPressed: _toggleArchive,
              ),
            if (_hasBeenSavedInDb)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.black87),
                onPressed: _delete,
              ),
          ],
        ),
        body: Column(
          children: [
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
                            autofocus: !_isEditing && !widget.autoRecord && !widget.autoPickImage,
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
                          TextField(
                            controller: _contentController,
                            style: GoogleFonts.outfit(fontSize: 16, height: 1.6, color: const Color(0xFF334155)),
                            decoration: const InputDecoration(
                              hintText: 'Ghi chú',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
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
        bottomNavigationBar: _buildBottomToolbar(),
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
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
            Positioned(
              top: 12, right: 12,
              child: GestureDetector(
                onTap: () async {
                  setState(() { _isUploading = true; _uploadingLabel = 'Đang xóa ảnh...'; });
                  await _cloudinary.deleteFile(url, resourceType: 'image');
                  setState(() { _imageUrls.remove(url); _isUploading = false; });
                  await _saveNote(isAutosave: true);
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
                Text('Ghi âm ${index + 1}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
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
              setState(() { _isUploading = true; _uploadingLabel = 'Đang xóa âm thanh...'; });
              await _cloudinary.deleteFile(url, resourceType: 'video');
              setState(() { _audioUrls.removeAt(index); _isUploading = false; });
              await _saveNote(isAutosave: true);
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
            Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
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
        color: _recordColor.withOpacity(0.08), borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _recordColor.withOpacity(0.3)),
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
    return BottomAppBar(
      color: Colors.white,
      elevation: 0,
      child: Container(
        height: 50,
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
        child: Row(
          children: [
            _toolbarButton(icon: Icons.image_outlined, tooltip: 'Thêm ảnh', onTap: _isUploading ? null : _showImageSourceSheet),
            _toolbarButton(
              icon: _isRecording ? Icons.stop_circle_outlined : Icons.mic_none_outlined,
              tooltip: _isRecording ? 'Dừng ghi âm' : 'Ghi âm',
              color: _isRecording ? _recordColor : null,
              onTap: _isUploading ? null : (_isRecording ? _stopRecordingAndUpload : _startRecording),
            ),
            _toolbarButton(icon: Icons.label_outline_rounded, tooltip: 'Thêm nhãn', onTap: _openLabelSelectionPage),
            const Spacer(),
            if (!_isUploading && _hasBeenSavedInDb)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('Đã lưu cục bộ', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400)),
              ),
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