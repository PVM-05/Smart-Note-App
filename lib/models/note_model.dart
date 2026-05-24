// lib/models/note_model.dart
// ── THÊM 2 FIELD: imageUrls, audioUrls vào Note ──
// Chỉ thay thế toàn bộ file note_model.dart bằng file này

import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String status; // normal | pinned | archived | trash
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
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
    'tags': tags.join(','),
    'image_urls': imageUrls.join(','),   // ← MỚI
    'audio_urls': audioUrls.join(','),   // ← MỚI
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'],
    userId: m['user_id'] ?? '',
    title: m['title'],
    content: m['content'],
    status: m['status'] ?? 'normal',
    isSynced: (m['is_synced'] ?? 0) == 1,
    tags: (m['tags'] as String? ?? '').isEmpty
        ? []
        : (m['tags'] as String).split(','),
    imageUrls: (m['image_urls'] as String? ?? '').isEmpty  // ← MỚI
        ? []
        : (m['image_urls'] as String).split(','),
    audioUrls: (m['audio_urls'] as String? ?? '').isEmpty  // ← MỚI
        ? []
        : (m['audio_urls'] as String).split(','),
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
    DateTime? updatedAt,
  }) =>
      Note(
        id: id,
        userId: userId,
        title: title ?? this.title,
        content: content ?? this.content,
        status: status ?? this.status,
        isSynced: isSynced ?? this.isSynced,
        tags: tags ?? this.tags,
        imageUrls: imageUrls ?? this.imageUrls,  // ← MỚI
        audioUrls: audioUrls ?? this.audioUrls,  // ← MỚI
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}