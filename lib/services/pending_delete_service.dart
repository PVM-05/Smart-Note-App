import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Lưu danh sách note ID cần xóa trên Firestore khi có mạng trở lại.
/// Đây là giải pháp cho bài toán: xóa local (ngay) nhưng offline → không xóa được cloud.
class PendingDeleteService {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'pending_deletes.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_deletes(
            note_id TEXT PRIMARY KEY,
            created_at INTEGER
          )
        ''');
      },
    );
  }

  // Thêm một note ID vào hàng đợi xóa
  Future<void> add(String noteId) async {
    final database = await db;
    await database.insert(
      'pending_deletes',
      {
        'note_id': noteId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // tránh duplicate
    );
    log('📋 PendingDeleteService: thêm $noteId');
  }

  // Lấy toàn bộ note ID đang chờ xóa
  Future<List<String>> getAll() async {
    final database = await db;
    final maps = await database.query(
      'pending_deletes',
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => m['note_id'] as String).toList();
  }

  // Xóa khỏi hàng đợi sau khi đã xóa thành công trên cloud
  Future<void> remove(String noteId) async {
    final database = await db;
    await database.delete(
      'pending_deletes',
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
  }

  // Xóa toàn bộ hàng đợi (dùng khi debug hoặc reset)
  Future<void> clearAll() async {
    final database = await db;
    await database.delete('pending_deletes');
  }
}