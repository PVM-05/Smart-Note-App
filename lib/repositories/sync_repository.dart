import 'dart:async';
import '../models/note_model.dart';
import '../services/local_note_service.dart';
import '../services/firestore_note_service.dart';
import '../models/sync_status.dart';



abstract class SyncRepository {
  Future<void> syncNotesBatch(List<Note> notes);
  Future<List<Note>> getUnsyncedNotes(String userId);
  Stream<SyncStatus> get syncStatusStream;
  Future<void> pullFromCloud();
  Future<void> syncWithConflictResolution(String userId);
}

class SyncRepositoryImpl implements SyncRepository {
  final LocalNoteService _localService = LocalNoteService();
  final FirestoreNoteService _firestoreService = FirestoreNoteService();

  final _statusController = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  void _updateStatus(SyncStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  @override
  Future<void> syncNotesBatch(List<Note> notes) async {
    if (notes.isEmpty) return;
    try {
      _updateStatus(SyncStatus.syncing);
      await _firestoreService.batchSaveNotes(notes);
      for (final note in notes) {
        await _localService.markSynced(note.id);
      }
      _updateStatus(SyncStatus.success);
    } catch (e) {
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  @override
  Future<List<Note>> getUnsyncedNotes(String userId) async {
    return await _localService.getUnsyncedNotes(userId: userId);
  }

  @override
  Future<void> pullFromCloud() async {
    try {
      _updateStatus(SyncStatus.syncing);
      final cloudNotes = await _firestoreService.getNotes();
      for (final note in cloudNotes) {
        await _localService.insertNote(note);
      }
      _updateStatus(SyncStatus.success);
    } catch (e) {
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> syncWithConflictResolution(String userId) async {
    try {
      _updateStatus(SyncStatus.syncing);
      final localNotes = await _localService.getAllNotes(userId: userId);
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
      _updateStatus(SyncStatus.success);
    } catch (e) {
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }
}
