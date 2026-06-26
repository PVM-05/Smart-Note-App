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
  // ── Lấy tất cả notes (Bao gồm cả normal, pinned và trash) ──
  Future<List<Note>> getNotes() async {
    final snap = await _notesRef
    // Đã xóa dòng: .where('status', isNotEqualTo: 'trash')
        .orderBy('updated_at', descending: true)
        .get();

    return snap.docs
        .map((doc) => Note.fromFirestoreMap(doc.data() as Map<String, dynamic>))
        .toList();
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

  // ── Lấy custom labels ──
  Future<List<String>> getCustomLabels() async {
    try {
      final doc = await _firestore.collection('users').doc(_uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('custom_labels')) {
          return List<String>.from(data['custom_labels'] as List);
        }
      }
    } catch (_) {}
    return [];
  }

  // ── Lưu custom labels ──
  Future<void> saveCustomLabels(List<String> labels) async {
    await _firestore.collection('users').doc(_uid).set({
      'custom_labels': labels,
    }, SetOptions(merge: true));
  }
}
