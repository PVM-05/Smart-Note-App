// lib/services/local_note_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note_model.dart';

class LocalNoteService {
  static Database? _db;
  static final List<Note> _webNotes = [];

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'smart_note.db');
    return openDatabase(
      path,
      version: 4, // 1. NÂNG LÊN VERSION 4 ĐỂ KÍCH HOẠT QUÁ TRÌNH NÂNG CẤP SCHEMA
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            user_id TEXT DEFAULT '',
            title TEXT,
            content TEXT,
            status TEXT DEFAULT 'normal',
            is_synced INTEGER DEFAULT 0,
            tags TEXT,          -- 2. THÊM CỘT TAGS ĐỂ LƯU CHUỖI JSON TAG CHO THIẾT BỊ MỚI CÀI APP
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE notes ADD COLUMN status TEXT DEFAULT 'normal'");
          await db.execute("ALTER TABLE notes ADD COLUMN is_synced INTEGER DEFAULT 0");
          await db.execute("ALTER TABLE notes ADD COLUMN created_at INTEGER DEFAULT 0");
          await db.execute("ALTER TABLE notes ADD COLUMN updated_at INTEGER DEFAULT 0");
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE notes ADD COLUMN user_id TEXT DEFAULT ''");
        }
        // 3. THÊM LOGIC DI CƯ (MIGRATION): THÊM CỘT TAGS VÀO CHO CÁC THIẾT BỊ ĐANG CHẠY BẢN CŨ (V3)
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE notes ADD COLUMN tags TEXT");
        }
      },
    );
  }

  Future<void> insertNote(Note note) async {
    if (kIsWeb) {
      final i = _webNotes.indexWhere((n) => n.id == note.id);
      if (i != -1) {
        _webNotes[i] = note;
      } else {
        _webNotes.add(note);
      }
      return;
    }
    final database = await db;
    await database.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Note>> getAllNotes({
    required String userId,
    int? limit,
    int? offset,
  }) async {
    if (kIsWeb) {
      final notes = _webNotes
          .where(
            (n) =>
        n.userId == userId &&
            n.status != 'trash',
      )
          .toList();
      // Sort newest first
      notes.sort(
            (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );
      // Pagination for web
      if (offset != null && limit != null) {
        final start = offset;
        final end =
        (offset + limit > notes.length)
            ? notes.length
            : offset + limit;
        if (start >= notes.length) {
          return [];
        }
        return notes.sublist(start, end);
      }
      return notes;
    }
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'user_id = ? AND status != ?',
      whereArgs: [
        userId,
        'trash',
      ],
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps
        .map((m) => Note.fromMap(m))
        .toList();
  }

  // ── Search nâng cao: Hỗ trợ Filter Tokens (is:pinned, has:image, label:"...") ──
  Future<List<Note>> searchNotes({
    required String userId,
    required String query,
  }) async {
    if (query.trim().isEmpty) return getAllNotes(userId: userId);

    String q = query.trim();
    String whereString = 'user_id = ? AND status != ?';
    List<dynamic> whereArgs = [userId, 'trash'];

    // --- XỬ LÝ TRÊN MÔI TRƯỜNG WEB ---
    if (kIsWeb) {
      return _webNotes.where((n) {
        bool match = n.userId == userId && n.status != 'trash';
        String qWeb = query.trim();

        if (qWeb.contains('is:pinned')) { match = match && n.status == 'pinned'; qWeb = qWeb.replaceAll('is:pinned', '').trim(); }
        else if (qWeb.contains('is:archived')) { match = match && n.status == 'archived'; qWeb = qWeb.replaceAll('is:archived', '').trim(); }

        if (qWeb.contains('has:image')) { match = match && n.content.contains('!['); qWeb = qWeb.replaceAll('has:image', '').trim(); }
        if (qWeb.contains('has:url')) { match = match && n.content.contains('http'); qWeb = qWeb.replaceAll('has:url', '').trim(); }
        if (qWeb.contains('has:list')) { match = match && (n.content.contains('- ') || n.content.contains('[ ]')); qWeb = qWeb.replaceAll('has:list', '').trim(); }

        final labelRegExp = RegExp(r'label:"([^"]+)"|label:([^\s]+)');
        for (final m in labelRegExp.allMatches(qWeb)) {
          final label = m.group(1) ?? m.group(2);
          if (label != null) match = match && n.tags.contains(label);
        }
        qWeb = qWeb.replaceAll(labelRegExp, '').trim().toLowerCase();

        if (qWeb.isNotEmpty) {
          match = match && (n.title.toLowerCase().contains(qWeb) || n.content.toLowerCase().contains(qWeb));
        }
        return match;
      }).toList();
    }

    // --- XỬ LÝ TRÊN MÔI TRƯỜNG SQLITE MOBILE ---

    // 1. Phân tích trạng thái
    if (q.contains('is:pinned')) {
      whereString += " AND status = 'pinned'";
      q = q.replaceAll('is:pinned', '').trim();
    } else if (q.contains('is:archived')) {
      whereString += " AND status = 'archived'";
      q = q.replaceAll('is:archived', '').trim();
    }

    // 2. Phân tích loại nội dung (Markdown)
    if (q.contains('has:image')) {
      whereString += " AND content LIKE '%![%'";
      q = q.replaceAll('has:image', '').trim();
    }
    if (q.contains('has:url')) {
      whereString += " AND content LIKE '%http%'";
      q = q.replaceAll('has:url', '').trim();
    }
    if (q.contains('has:list')) {
      whereString += " AND (content LIKE '%- %' OR content LIKE '%[ ]%' OR content LIKE '%[x]%')";
      q = q.replaceAll('has:list', '').trim();
    }

    // 3. Phân tích Nhãn dán (Label)
    final labelRegExp = RegExp(r'label:"([^"]+)"|label:([^\s]+)');
    final matches = labelRegExp.allMatches(q);
    for (final match in matches) {
      final label = match.group(1) ?? match.group(2);
      if (label != null) {
        whereString += " AND tags LIKE ?";
        whereArgs.add('%"$label"%'); // Tìm chuỗi chứa tên label chính xác trong JSON Array
      }
    }
    q = q.replaceAll(labelRegExp, '').trim();

    // 4. Đoạn text còn lại chính là từ khóa người dùng muốn tìm
    if (q.isNotEmpty) {
      whereString += ' AND (title LIKE ? OR content LIKE ?)';
      whereArgs.addAll(['%$q%', '%$q%']);
    }

    final database = await db;
    final maps = await database.query(
      'notes',
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<void> updateNote(Note note) async {
    if (kIsWeb) {
      final i = _webNotes.indexWhere((n) => n.id == note.id);
      if (i != -1) _webNotes[i] = note;
      return;
    }
    final database = await db;
    await database.update('notes', note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> deleteNote(String id) async {
    if (kIsWeb) { _webNotes.removeWhere((n) => n.id == id); return; }
    final database = await db;
    await database.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getArchivedNotes({required String userId}) async {
    if (kIsWeb) {
      return _webNotes
          .where((n) => n.userId == userId && n.status == 'archived')
          .toList();
    }
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'status = ? AND user_id = ?',
      whereArgs: ['archived', userId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // Lấy các ghi chú đang nằm trong thùng rác
  Future<List<Note>> getTrashNotes({required String userId}) async {
    if (kIsWeb) {
      return _webNotes.where((n) => n.userId == userId && n.status == 'trash').toList();
    }
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'status = ? AND user_id = ?',
      whereArgs: ['trash', userId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<List<Note>> getUnsyncedNotes({required String userId}) async {
    if (kIsWeb) {
      return _webNotes.where((n) => !n.isSynced && n.userId == userId).toList();
    }
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'is_synced = ? AND user_id = ?',
      whereArgs: [0, userId],
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<void> markSynced(String id) async {
    if (kIsWeb) {
      final i = _webNotes.indexWhere((n) => n.id == id);
      if (i != -1) _webNotes[i] = _webNotes[i].copyWith(isSynced: true);
      return;
    }
    final database = await db;
    await database.update('notes', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearUserNotes(String userId) async {
    if (kIsWeb) {
      // Chỉ loại bỏ những ghi chú đã đồng bộ lên cloud trên môi trường Web
      _webNotes.removeWhere((n) => n.userId == userId && n.isSynced == true);
      return;
    }
    /// Xóa sạch các ghi chú cục bộ của user để giải phóng bộ nhớ thiết bị.
    /// ⚠️ CỰC KỲ QUAN TRỌNG: Chỉ cho phép xóa các ghi chú ĐÃ ĐỒNG BỘ THÀNH CÔNG (is_synced = 1).
    /// Giữ lại tuyệt đối các ghi chú offline (is_synced = 0) để không làm mất data của user.
    final database = await db;
    await database.delete(
      'notes',
      where: 'user_id = ? AND is_synced = ?',
      whereArgs: [userId, 1], // Chỉ xóa hàng có is_synced = 1
    );
  }
}