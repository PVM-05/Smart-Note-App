// lib/services/local_note_service.dart
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
      version: 10,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            user_id TEXT DEFAULT '',
            title TEXT,
            content TEXT,
            status TEXT DEFAULT 'normal',
            is_synced INTEGER DEFAULT 0,
            is_locked INTEGER DEFAULT 0,
            note_color TEXT,
            tags TEXT,
            image_urls TEXT,
            audio_urls TEXT,          
            created_at INTEGER,
            updated_at INTEGER,
            reminder INTEGER,
            sort_order INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE labels(
            name TEXT,
            user_id TEXT,
            PRIMARY KEY (name, user_id)
          )
        ''');
        // ── Performance indexes ──
        await db.execute('CREATE INDEX idx_notes_user_status ON notes(user_id, status)');
        await db.execute('CREATE INDEX idx_notes_user_synced ON notes(user_id, is_synced)');
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
        if (oldVersion < 6) {
          await db.execute("ALTER TABLE notes ADD COLUMN is_locked INTEGER DEFAULT 0");
          await db.execute("ALTER TABLE notes ADD COLUMN note_color TEXT");
        }
        if (oldVersion < 7) {
          try {
            await db.execute("ALTER TABLE notes ADD COLUMN reminder INTEGER");
          } catch (_) {}
          // Thêm index để tăng tốc truy vấn
          await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_user_status ON notes(user_id, status)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_user_synced ON notes(user_id, is_synced)');
        }
        if (oldVersion < 8) {
          try {
            await db.execute("ALTER TABLE notes ADD COLUMN reminder INTEGER");
          } catch (_) {}
        }
        if (oldVersion < 9) {
          try {
            await db.execute("ALTER TABLE notes ADD COLUMN sort_order INTEGER DEFAULT 0");
          } catch (_) {}
          // Gán sort_order ban đầu cho các note hiện có dựa trên thứ tự updated_at DESC
          await db.execute('''
            UPDATE notes SET sort_order = (
              SELECT COUNT(*) FROM notes AS n2
              WHERE n2.updated_at > notes.updated_at
            )
          ''');
        }
        if (oldVersion < 10) {
          await db.execute('''
            CREATE TABLE labels(
              name TEXT,
              user_id TEXT,
              PRIMARY KEY (name, user_id)
            )
          ''');
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
      orderBy: 'sort_order ASC, updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  /// Lấy riêng các note đã ghim — tránh phải tải toàn bộ bảng
  Future<List<Note>> getPinnedNotes({required String userId}) async {
    if (kIsWeb) {
      return _webNotes
          .where((n) => n.userId == userId && n.status == 'pinned')
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'pinned'],
      orderBy: 'sort_order ASC, updated_at DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<List<Note>> getAbsoluteAllNotes({required String userId}) async {
    if (kIsWeb) {
      return _webNotes.where((n) => n.userId == userId).toList();
    }
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // ── SEARCH NÂNG CAO CHUẨN GOOGLE KEEP STYLE ──
  Future<List<Note>> searchNotes({required String userId, required String query}) async {
    if (query.trim().isEmpty) {
      return getAllNotes(userId: userId);
    }
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

    // ── Dùng SQL LIKE để lọc text trước, giảm lượng data tải vào RAM ──
    List<Note> candidates;
    if (kIsWeb) {
      candidates = _webNotes.where((n) => n.userId == userId && n.status != 'trash').toList();
    } else {
      final database = await db;
      if (cleanTextQuery.isNotEmpty) {
        // Tìm bằng SQL LIKE — sử dụng index hiệu quả hơn
        final sqlQuery = '%$cleanTextQuery%';
        final maps = await database.query(
          'notes',
          where: 'user_id = ? AND status != ? AND (LOWER(title) LIKE ? OR LOWER(content) LIKE ?)',
          whereArgs: [userId, 'trash', sqlQuery, sqlQuery],
          orderBy: 'updated_at DESC',
        );
        candidates = maps.map((m) => Note.fromMap(m)).toList();
      } else {
        // Không có text query, chỉ có token filters → tải tất cả (trừ trash)
        final maps = await database.query(
          'notes',
          where: 'user_id = ? AND status != ?',
          whereArgs: [userId, 'trash'],
          orderBy: 'updated_at DESC',
        );
        candidates = maps.map((m) => Note.fromMap(m)).toList();
      }
    }

    // ── Client-side filtering cho các token đặc biệt ──
    return candidates.where((note) {
      if (hasImageToken && note.imageUrls.isEmpty) return false;
      if (hasAudioToken && note.audioUrls.isEmpty) return false;
      if (hasUrlToken) {
        final urlRegex = RegExp(r'(https?:\/\/|www\.)[^\s/$.?#].[^\s]*', caseSensitive: false);
        if (!urlRegex.hasMatch(note.content)) return false;
      }
      if (isPinnedToken && note.status != 'pinned') return false;
      if (isArchivedToken && note.status != 'archived') return false;
      if (!isArchivedToken && note.status == 'archived') return false;
      if (targetLabel != null && !note.tags.map((t) => t.toLowerCase()).contains(targetLabel.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<Note?> getNoteById(String id) async {
    if (kIsWeb) {
      try {
        return _webNotes.firstWhere((n) => n.id == id);
      } catch (_) {
        return null;
      }
    }
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
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
      _webNotes.removeWhere((n) => n.userId == userId);
      return;
    }
    final database = await db;
    await database.delete(
      'notes',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<String>> getCustomLabels(String userId) async {
    if (kIsWeb) return [];
    final database = await db;
    final maps = await database.query(
      'labels',
      columns: ['name'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((m) => m['name'] as String).toList();
  }

  Future<void> syncCustomLabels(String userId, List<String> names) async {
    if (kIsWeb) return;
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('labels', where: 'user_id = ?', whereArgs: [userId]);
      for (final name in names) {
        await txn.insert(
          'labels',
          {'name': name, 'user_id': userId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}