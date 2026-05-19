// lib/models/note_model.dart
import 'dart:convert';

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

  Note({
    required this.id,
    this.userId = '',
    required this.title,
    required this.content,
    this.status = 'normal',
    this.isSynced = false,
    this.tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ────────────────────────────────────────────
  // SQLite — dùng int milliseconds
  // ────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'status': status,
        'is_synced': isSynced ? 1 : 0,
        'tags': jsonEncode(tags),
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
        tags: m['tags'] != null ? List<String>.from(jsonDecode(m['tags'])) : [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          m['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          m['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  // ────────────────────────────────────────────
  // Firestore — dùng Timestamp
  // ────────────────────────────────────────────
  Map<String, dynamic> toFirestoreMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'status': status,
        'tags': tags,
        'created_at': Timestamp.fromDate(createdAt), // DateTime → Timestamp
        'updated_at': Timestamp.fromDate(updatedAt),
        // KHÔNG lưu isSynced lên cloud — field này chỉ có nghĩa ở local
      };

  factory Note.fromFirestoreMap(Map<String, dynamic> m) => Note(
        id: m['id'] ?? '',
        userId: m['user_id'] ?? '',
        title: m['title'] ?? '',
        content: m['content'] ?? '',
        status: m['status'] ?? 'normal',
        isSynced: true, // lấy từ Firestore về → luôn là đã sync
        tags: m['tags'] != null ? List<String>.from(m['tags']) : [],
        createdAt: m['created_at'] != null
            ? (m['created_at'] as Timestamp).toDate() // Timestamp → DateTime
            : DateTime.now(),
        updatedAt: m['updated_at'] != null
            ? (m['updated_at'] as Timestamp).toDate()
            : DateTime.now(),
      );

  // ────────────────────────────────────────────
  // copyWith — tạo bản sao thay đổi 1 vài field
  // ────────────────────────────────────────────
  Note copyWith({
    String? title,
    String? content,
    String? status,
    bool? isSynced,
    List<String>? tags,
    DateTime? updatedAt
  }) =>
      Note(
        id: id,
        userId: userId,
        title: title ?? this.title,
        content: content ?? this.content,
        status: status ?? this.status,
        isSynced: isSynced ?? this.isSynced,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(), // luôn cập nhật updatedAt khi copyWith
      );
}
