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

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'smart_note.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT
          )
        ''');
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
