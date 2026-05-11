// lib/models/note_model.dart
class Note {
  final String id;
  final String title;
  final String content;
  final String status;      // normal | pinned | archived | trash
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.status = 'normal',
    this.isSynced = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'status': status,
    'is_synced': isSynced ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'],
    title: m['title'],
    content: m['content'],
    status: m['status'] ?? 'normal',
    isSynced: (m['is_synced'] ?? 0) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] ?? 0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] ?? 0),
  );

  // Dùng để tạo bản sao có thay đổi 1 vài field
  Note copyWith({
    String? title, String? content,
    String? status, bool? isSynced,
  }) => Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    status: status ?? this.status,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}