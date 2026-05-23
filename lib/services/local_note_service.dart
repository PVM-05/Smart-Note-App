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
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            user_id TEXT DEFAULT '',
            title TEXT,
            content TEXT,
            status TEXT DEFAULT 'normal',
            is_synced INTEGER DEFAULT 0,
            tags TEXT,
            image_urls TEXT,
            audio_urls TEXT,          
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
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE notes ADD COLUMN tags TEXT");
        }
        if (oldVersion < 5) {
          await db.execute("ALTER TABLE notes ADD COLUMN image_urls TEXT");
          await db.execute("ALTER TABLE notes ADD COLUMN audio_urls TEXT");
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
            (n) => n.userId == userId && n.status != 'trash',
      )
          .toList();
      notes.sort(
            (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );
      if (offset != null && limit != null) {
        final start = offset;
        final end = (offset + limit > notes.length) ? notes.length : offset + limit;
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
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // ── SỬA LỖI & NÂNG CẤP SEARCH NÂNG CAO CHUẨN GOOGLE KEEP STYLE ──
  Future<List<Note>> searchNotes({required String userId, required String query}) async {
    // 1. Tải toàn bộ dữ liệu hoạt động của User lên bộ nhớ tạm để bóc tách mảng (Client-side filtering)
    // Thay đổi từ 'getNotes' thành 'getAllNotes' bám sát hàm định nghĩa gốc của bạn
    final allNotes = await getAllNotes(userId: userId);

    if (query.trim().isEmpty) return allNotes;
    final lowerQuery = query.toLowerCase();

    // ⚡ BỘ NÃO PHÂN TÍCH TOKEN TỪ SEARCH SCREEN CHIP
    final hasImageToken = lowerQuery.contains('has:image');
    final hasAudioToken = lowerQuery.contains('has:audio');
    final hasUrlToken = lowerQuery.contains('has:url');
    final isPinnedToken = lowerQuery.contains('is:pinned');
    final isArchivedToken = lowerQuery.contains('is:archived');

    // ⚡ TRÍCH XUẤT TỪ KHÓA VĂN BẢN THUẦN TÚY: Gỡ bỏ toàn bộ mã lệnh token
    String cleanTextQuery = query
        .replaceAll('has:image', '')
        .replaceAll('has:audio', '')
        .replaceAll('has:url', '')
        .replaceAll('is:pinned', '')
        .replaceAll('is:archived', '')
        .trim()
        .toLowerCase();

    // Bóc tách cấu trúc nhãn gắn kèm nếu có: label:"tên_nhãn"
    String? targetLabel;
    if (lowerQuery.contains('label:"')) {
      final match = RegExp(r'label:"([^"]+)"').firstMatch(lowerQuery);
      if (match != null) {
        targetLabel = match.group(1);
        cleanTextQuery = cleanTextQuery.replaceAll(RegExp(r'label:"[^"]+"'), '').trim();
      }
    }

    // 2. THỰC HIỆN LỌC ĐỒNG THỜI TOÀN BỘ ĐIỀU KIỆN (Khắc phục lỗi không hiển thị kết quả)
    return allNotes.where((note) {
      // Điều kiện 1: Nếu chọn nút "Hình ảnh" -> Thẻ note phải chứa ít nhất 1 ảnh
      if (hasImageToken && note.imageUrls.isEmpty) return false;

      // Điều kiện 2: Nếu chọn nút "Âm thanh" -> Thẻ note phải chứa file ghi âm
      if (hasAudioToken && note.audioUrls.isEmpty) return false;

      // Điều kiện 3: Nếu chọn nút "URL" -> Nội dung text của note phải chứa đường link
      if (hasUrlToken) {
        final urlRegex = RegExp(r'(https?:\/\/|www\.)[^\s/$.?#].[^\s]*', caseSensitive: false);
        if (!urlRegex.hasMatch(note.content)) return false;
      }

      // Điều kiện 4: Trạng thái Ghim hệ thống
      if (isPinnedToken && note.status != 'pinned') return false;

      // Điều kiện 5: Trạng thái Lưu trữ (Vì getAllNotes đã chặn 'trash', ta check 'archived')
      if (isArchivedToken && note.status != 'archived') return false;

      // Nếu không chọn chip "Lưu trữ", mặc định kết quả tìm kiếm thông thường chỉ hiển thị note đang active (không hiện note đã lưu trữ)
      if (!isArchivedToken && note.status == 'archived') return false;

      // Điều kiện 6: Nhãn dán (Mảng Tags vỏ bọc văn bản)
      if (targetLabel != null && !note.tags.map((t) => t.toLowerCase()).contains(targetLabel.toLowerCase())) {
        return false;
      }

      // Điều kiện 7: Lọc kết hợp chuỗi văn bản gõ thêm thủ công (Tìm trong cả Tiêu đề và Nội dung)
      if (cleanTextQuery.isNotEmpty) {
        final matchTitle = note.title.toLowerCase().contains(cleanTextQuery);
        final matchContent = note.content.toLowerCase().contains(cleanTextQuery);
        if (!matchTitle && !matchContent) return false;
      }

      return true;
    }).toList();
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
      _webNotes.removeWhere((n) => n.userId == userId && n.isSynced == true);
      return;
    }
    final database = await db;
    await database.delete(
      'notes',
      where: 'user_id = ? AND is_synced = ?',
      whereArgs: [userId, 1],
    );
  }
}