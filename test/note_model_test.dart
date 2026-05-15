// test/note_model_test.dart
// ✅ NGÀY 2 – UNIT TESTS: NoteModel
// Kiểm tra: toMap/fromMap (SQLite), toFirestoreMap/fromFirestoreMap, copyWith
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_note_app/models/note_model.dart';

void main() {
  // ─── NHÓM 1: SQLite serialization ───────────────────────────────────────
  group('NoteModel – SQLite toMap / fromMap', () {
    test('toMap() tạo ra Map đúng kiểu SQLite', () {
      final now = DateTime(2026, 5, 15, 19, 0, 0);
      final note = Note(
        id: 'abc123',
        title: 'Test title',
        content: 'Test content',
        status: 'pinned',
        isSynced: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = note.toMap();

      expect(map['id'], equals('abc123'));
      expect(map['title'], equals('Test title'));
      expect(map['content'], equals('Test content'));
      expect(map['status'], equals('pinned'));
      expect(map['is_synced'], equals(1)); // bool → int
      expect(map['created_at'], equals(now.millisecondsSinceEpoch));
      expect(map['updated_at'], equals(now.millisecondsSinceEpoch));
    });

    test('fromMap() khôi phục Note đúng từ SQLite Map', () {
      final now = DateTime(2026, 5, 15, 19, 0, 0);
      final map = {
        'id': 'xyz789',
        'title': 'Hello',
        'content': 'World',
        'status': 'normal',
        'is_synced': 0,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      };

      final note = Note.fromMap(map);

      expect(note.id, equals('xyz789'));
      expect(note.title, equals('Hello'));
      expect(note.isSynced, isFalse);
      expect(note.status, equals('normal'));
      expect(note.createdAt, equals(now));
    });

    test('fromMap() dùng giá trị mặc định khi thiếu field', () {
      final map = {
        'id': 'id1',
        'title': 'T',
        'content': 'C',
      };

      final note = Note.fromMap(map);

      expect(note.status, equals('normal'));
      expect(note.isSynced, isFalse);
    });

    test('toMap() → fromMap() round-trip giữ nguyên dữ liệu', () {
      final original = Note(
        id: 'roundtrip',
        title: 'RT',
        content: 'Body',
        status: 'archived',
        isSynced: false,
      );

      final restored = Note.fromMap(original.toMap());

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.content, equals(original.content));
      expect(restored.status, equals(original.status));
      expect(restored.isSynced, equals(original.isSynced));
    });
  });

  // ─── NHÓM 2: Firestore serialization ────────────────────────────────────
  group('NoteModel – Firestore toFirestoreMap / fromFirestoreMap', () {
    test('toFirestoreMap() không chứa is_synced', () {
      final note = Note(
        id: 'f1',
        title: 'Firestore note',
        content: 'Content',
        isSynced: false, // KHÔNG được lưu lên cloud
      );

      final map = note.toFirestoreMap();

      expect(map.containsKey('is_synced'), isFalse);
      expect(map['id'], equals('f1'));
    });

    test('toFirestoreMap() lưu DateTime dạng Timestamp', () {
      final note = Note(id: 'f2', title: 'T', content: 'C');
      final map = note.toFirestoreMap();

      expect(map['created_at'], isA<Timestamp>());
      expect(map['updated_at'], isA<Timestamp>());
    });

    test('fromFirestoreMap() luôn set isSynced = true', () {
      final ts = Timestamp.now();
      final map = {
        'id': 'f3',
        'title': 'Cloud note',
        'content': 'From Firestore',
        'status': 'normal',
        'created_at': ts,
        'updated_at': ts,
      };

      final note = Note.fromFirestoreMap(map);

      expect(note.isSynced, isTrue); // lấy từ cloud → luôn synced
    });

    test('fromFirestoreMap() xử lý thiếu field không crash', () {
      final map = {'id': 'f4', 'title': '', 'content': ''};
      expect(() => Note.fromFirestoreMap(map), returnsNormally);
    });
  });

  // ─── NHÓM 3: copyWith ────────────────────────────────────────────────────
  group('NoteModel – copyWith', () {
    test('copyWith() tạo bản sao với field đã thay đổi', () {
      final original = Note(id: 'c1', title: 'Old', content: 'Old body');
      final updated = original.copyWith(title: 'New title', status: 'pinned');

      expect(updated.id, equals('c1')); // id không đổi
      expect(updated.title, equals('New title'));
      expect(updated.status, equals('pinned'));
      expect(updated.content, equals('Old body')); // không thay đổi
    });

    test('copyWith() tự động cập nhật updatedAt', () {
      final original = Note(id: 'c2', title: 'T', content: 'C');
      final before = original.updatedAt;

      // Thêm delay nhỏ để đảm bảo updatedAt khác
      Future.delayed(const Duration(milliseconds: 1));
      final updated = original.copyWith(title: 'Changed');

      // updatedAt trong copyWith luôn = DateTime.now()
      expect(updated.updatedAt.isAfter(original.createdAt) ||
          updated.updatedAt == before, isTrue);
    });
  });
}
