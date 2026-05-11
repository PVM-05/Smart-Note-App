import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note_model.dart';

class LocalNoteService {
  static Database? _db;
  static final List<Note> _webNotes = []; // Data tạm trên RAM cho Web

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  // lib/services/local_note_service.dart — phần _initDb
  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'smart_note.db');
    return openDatabase(
      path,
      version: 2,                          // ← tăng từ 1 lên 2
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
          // Thêm cột mới, không xóa data cũ
          await db.execute("ALTER TABLE notes ADD COLUMN status TEXT DEFAULT 'normal'");
          await db.execute("ALTER TABLE notes ADD COLUMN is_synced INTEGER DEFAULT 0");
          await db.execute("ALTER TABLE notes ADD COLUMN created_at INTEGER DEFAULT 0");
          await db.execute("ALTER TABLE notes ADD COLUMN updated_at INTEGER DEFAULT 0");
        }
      },
    );
  }

  Future<void> insertNote(Note note) async {
    if (kIsWeb) {
      _webNotes.add(note);
      return;
    }
    final database = await db;
    await database.insert('notes', note.toMap());
  }

  Future<List<Note>> getAllNotes() async {
    if (kIsWeb) {
      return _webNotes.toList();
    }
    final database = await db;
    final maps = await database.query('notes');
    return maps.map((m) => Note.fromMap(m)).toList();
  }
}
