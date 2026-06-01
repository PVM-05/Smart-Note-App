// lib/models/note_model.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  /// Kiểm tra nhanh xem content có phải dạng checklist hay không
  bool get isChecklist {
    if (content.isEmpty) return false;
    try {
      final decoded = jsonDecode(content);
      return decoded is Map && decoded['type'] == 'checklist';
    } catch (_) {
      return false;
    }
  }

  /// Lấy plain text từ checklist items (dùng cho preview / search)
  String get checklistPlainText {
    if (!isChecklist) return '';
    try {
      final decoded = jsonDecode(content);
      final items = decoded['items'] as List? ?? [];
      return items.map((i) {
        final checked = i['checked'] == true ? '☑' : '☐';
        return '$checked ${i['text'] ?? ''}'.trim();
      }).join('\n');
    } catch (_) {
      return '';
    }
  }

  final String id;
  final String userId;
  final String title;
  final String content;
  final String status; // normal | pinned | archived | trash
  final bool isSynced;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? noteColor;
  final List<String> tags;
  final List<String> imageUrls;  // ← MỚI: URL ảnh Cloudinary
  final List<String> audioUrls;  // ← MỚI: URL audio Cloudinary

  Note({
    required this.id,
    this.userId = '',
    required this.title,
    required this.content,
    this.status = 'normal',
    this.isSynced = false,
    this.isLocked = false,
    this.noteColor,
    this.tags = const [],
    this.imageUrls = const [],   // ← MỚI
    this.audioUrls = const [],   // ← MỚI
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ── SQLite ──
  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'content': content,
    'status': status,
    'is_synced': isSynced ? 1 : 0,
    'is_locked': isLocked ? 1 : 0,
    'note_color': noteColor,
    'tags': jsonEncode(tags),            // JSON-safe, hỗ trợ mọi ký tự
    'image_urls': jsonEncode(imageUrls), // JSON-safe
    'audio_urls': jsonEncode(audioUrls), // JSON-safe
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  /// Helper an toàn: decode JSON list, fallback về [] nếu dữ liệu cũ (CSV hoặc null)
  static List<String> _decodeStringList(dynamic raw) {
    if (raw == null || (raw is String && raw.isEmpty)) return [];
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return List<String>.from(decoded);
      } catch (_) {
        // Fallback: dữ liệu cũ lưu dạng CSV
        return raw.split(',').where((s) => s.isNotEmpty).toList();
      }
    }
    return [];
  }

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'],
    userId: m['user_id'] ?? '',
    title: m['title'],
    content: m['content'],
    status: m['status'] ?? 'normal',
    isSynced: (m['is_synced'] ?? 0) == 1,
    isLocked: (m['is_locked'] ?? 0) == 1,
    noteColor: m['note_color'] ?? m['noteColor'],
    tags: _decodeStringList(m['tags']),
    imageUrls: _decodeStringList(m['image_urls']),
    audioUrls: _decodeStringList(m['audio_urls']),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      m['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      m['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
    ),
  );

  // ── Firestore ──
  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'content': content,
    'status': status,
    'is_locked': isLocked,
    'note_color': noteColor,
    'tags': tags,
    'image_urls': imageUrls,  // ← MỚI
    'audio_urls': audioUrls,  // ← MỚI
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  factory Note.fromFirestoreMap(Map<String, dynamic> m) => Note(
    id: m['id'] ?? '',
    userId: m['user_id'] ?? '',
    title: m['title'] ?? '',
    content: m['content'] ?? '',
    status: m['status'] ?? 'normal',
    isSynced: true,
    isLocked: m['is_locked'] ?? false,
    noteColor: m['note_color'] ?? m['noteColor'],
    tags: List<String>.from(m['tags'] ?? []),
    imageUrls: List<String>.from(m['image_urls'] ?? []),  // ← MỚI
    audioUrls: List<String>.from(m['audio_urls'] ?? []),  // ← MỚI
    createdAt: m['created_at'] != null
        ? (m['created_at'] as Timestamp).toDate()
        : DateTime.now(),
    updatedAt: m['updated_at'] != null
        ? (m['updated_at'] as Timestamp).toDate()
        : DateTime.now(),
  );

  Note copyWith({
    String? title,
    String? content,
    String? status,
    bool? isSynced,
    List<String>? tags,
    List<String>? imageUrls,  // ← MỚI
    List<String>? audioUrls,  // ← MỚI
    String? noteColor,
    bool? isLocked,
    DateTime? updatedAt,
  }) =>
      Note(
        id: id,
        userId: userId,
        title: title ?? this.title,
        content: content ?? this.content,
        status: status ?? this.status,
        isSynced: isSynced ?? this.isSynced,
        isLocked: isLocked ?? this.isLocked,
        noteColor: noteColor ?? this.noteColor,
        tags: tags ?? this.tags,
        imageUrls: imageUrls ?? this.imageUrls,  // ← MỚI
        audioUrls: audioUrls ?? this.audioUrls,  // ← MỚI
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}