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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            status TEXT DEFAULT 'normal',
            is_synced INTEGER DEFAULT 0,
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
      },
    );
  }

  // ── Insert ──
  Future<void> insertNote(Note note) async {
    if (kIsWeb) {
      final i = _webNotes.indexWhere((n) => n.id == note.id);
      if (i != -1) _webNotes[i] = note; // update nếu đã có
      else _webNotes.add(note);
      return;
    }
    final database = await db;
    await database.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // ← quan trọng
    );
  }

  // ── Get all ──
  Future<List<Note>> getAllNotes() async {
    if (kIsWeb) return _webNotes.toList();
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'status != ?',
      whereArgs: ['trash'],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // ── Update ──
  Future<void> updateNote(Note note) async {
    if (kIsWeb) {
      final i = _webNotes.indexWhere((n) => n.id == note.id);
      if (i != -1) _webNotes[i] = note;
      return;
    }
    final database = await db;
    await database.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // ── Delete ──
  Future<void> deleteNote(String id) async {
    if (kIsWeb) { _webNotes.removeWhere((n) => n.id == id); return; }
    final database = await db;
    await database.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ── Lấy notes chưa sync — SyncService dùng ──
  Future<List<Note>> getUnsyncedNotes() async {
    if (kIsWeb) return _webNotes.where((n) => !n.isSynced).toList();
    final database = await db;
    final maps = await database.query(
      'notes',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // ── Đánh dấu đã sync — SyncService dùng ──
  Future<void> markSynced(String id) async {
    if (kIsWeb) {
      final i = _webNotes.indexWhere((n) => n.id == id);
      if (i != -1) {
        _webNotes[i] = _webNotes[i].copyWith(isSynced: true);
      }
      return;
    }
    final database = await db;
    await database.update(
      'notes',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}