import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';

class FirestoreNoteService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Lấy uid của user đang login
  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User chưa đăng nhập');
    }

    return user.uid;
  }

  // Reference đến collection notes của user
  CollectionReference get _notesRef =>
      _firestore.collection('users').doc(_uid).collection('notes');

  // ── Lưu hoặc cập nhật 1 note ──
  Future<void> saveNote(Note note) async {
    await _notesRef
        .doc(note.id)
        .set(note.toFirestoreMap()); // ← dùng toFirestoreMap
  }

  // ── Lấy tất cả notes ──
  Future<List<Note>> getNotes() async {
    final snap = await _notesRef
        .where('status', isNotEqualTo: 'trash')
        .orderBy('updated_at', descending: true)
        .get();

    return snap.docs
        .map((doc) => Note.fromFirestoreMap(doc.data() as Map<String, dynamic>))
        .toList(); // ← dùng fromFirestoreMap
  }

  // ── Xóa 1 note ──
  Future<void> deleteNote(String noteId) async {
    await _notesRef.doc(noteId).delete();
  }

  // ── Batch save nhiều notes cùng lúc (dùng trong SyncService) ──
  Future<void> batchSaveNotes(List<Note> notes) async {
    final batch = _firestore.batch();
    for (final note in notes) {
      batch.set(_notesRef.doc(note.id),
          note.toFirestoreMap()); // ← dùng toFirestoreMap
    }
    await batch.commit();
  }
}
