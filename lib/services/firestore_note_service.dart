import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';

class FirestoreNoteService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Lấy uid của user đang login
  String get _uid => _auth.currentUser!.uid;

  // Reference đến collection notes của user
  CollectionReference get _notesRef =>
      _firestore.collection('users').doc(_uid).collection('notes');

  // ── Lưu hoặc cập nhật 1 note ──
  Future<void> saveNote(Note note) async {
    await _notesRef.doc(note.id).set({
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'status': note.status,
      'created_at': Timestamp.fromDate(note.createdAt),
      'updated_at': Timestamp.fromDate(note.updatedAt),
    });
  }

  // ── Lấy tất cả notes ──
  Future<List<Note>> getNotes() async {
    final snap = await _notesRef
        .where('status', isNotEqualTo: 'trash')
        .orderBy('updated_at', descending: true)
        .get();

    return snap.docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return Note(
        id: d['id'],
        title: d['title'],
        content: d['content'],
        status: d['status'] ?? 'normal',
        isSynced: true,
        createdAt: (d['created_at'] as Timestamp).toDate(),
        updatedAt: (d['updated_at'] as Timestamp).toDate(),
      );
    }).toList();
  }

  // ── Xóa 1 note ──
  Future<void> deleteNote(String noteId) async {
    await _notesRef.doc(noteId).delete();
  }

  // ── Batch save nhiều notes cùng lúc (dùng trong SyncService) ──
  Future<void> batchSaveNotes(List<Note> notes) async {
    final batch = _firestore.batch();
    for (final note in notes) {
      batch.set(_notesRef.doc(note.id), {
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'status': note.status,
        'created_at': Timestamp.fromDate(note.createdAt),
        'updated_at': Timestamp.fromDate(note.updatedAt),
      });
    }
    await batch.commit();   // ghi tất cả 1 lần — nhanh hơn ghi từng cái
  }
}