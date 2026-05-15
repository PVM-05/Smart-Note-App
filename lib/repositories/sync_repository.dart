import 'dart:async';
import '../models/note_model.dart';
import '../services/local_note_service.dart';
import '../services/firestore_note_service.dart';

enum SyncStatus { idle, syncing, success, error }

abstract class SyncRepository {
  Future<void> syncNotesBatch(List<Note> notes);
  Future<List<Note>> getUnsyncedNotes();
  Stream<SyncStatus> get syncStatusStream;
  Future<void> pullFromCloud();
  Future<void> syncWithConflictResolution();
}

class SyncRepositoryImpl implements SyncRepository {
  final LocalNoteService _localService = LocalNoteService();
  final FirestoreNoteService _firestoreService = FirestoreNoteService();
  
  final _statusController = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  void updateStatus(SyncStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  @override
  Future<void> syncNotesBatch(List<Note> notes) async {
    if (notes.isEmpty) return;
    await _firestoreService.batchSaveNotes(notes);
    for (final note in notes) {
      await _localService.markSynced(note.id);
    }
  }

  @override
  Future<List<Note>> getUnsyncedNotes() async {
    return await _localService.getUnsyncedNotes();
  }

  @override
  Future<void> pullFromCloud() async {
    final cloudNotes = await _firestoreService.getNotes();
    for (final note in cloudNotes) {
      await _localService.insertNote(note);
    }
  }

  @override
  Future<void> syncWithConflictResolution() async {
    final localNotes = await _localService.getAllNotes();
    final cloudNotes = await _firestoreService.getNotes();

    final cloudMap = {for (final n in cloudNotes) n.id: n};

    for (final local in localNotes) {
      final cloud = cloudMap[local.id];

      if (cloud == null) {
        await _firestoreService.saveNote(local);
        await _localService.markSynced(local.id);
      } else if (local.updatedAt.isAfter(cloud.updatedAt)) {
        await _firestoreService.saveNote(local);
        await _localService.markSynced(local.id);
      } else if (cloud.updatedAt.isAfter(local.updatedAt)) {
        await _localService.updateNote(cloud);
      }
    }
  }
}
