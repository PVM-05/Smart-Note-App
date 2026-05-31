import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_note_app/models/checklist_item.dart';
import 'package:smart_note_app/models/note_model.dart';

void main() {
  group('ChecklistItem Model Tests', () {
    test('should create ChecklistItem with default values', () {
      final item = ChecklistItem();
      expect(item.id, isNotEmpty);
      expect(item.text, isEmpty);
      expect(item.checked, isFalse);
    });

    test('should create ChecklistItem with custom values', () {
      final item = ChecklistItem(id: '123', text: 'Task 1', checked: true);
      expect(item.id, '123');
      expect(item.text, 'Task 1');
      expect(item.checked, isTrue);
    });

    test('should convert ChecklistItem to JSON and from JSON', () {
      final item = ChecklistItem(id: '123', text: 'Task 1', checked: true);
      final json = item.toJson();
      expect(json['id'], '123');
      expect(json['text'], 'Task 1');
      expect(json['checked'], true);

      final fromJson = ChecklistItem.fromJson(json);
      expect(fromJson.id, '123');
      expect(fromJson.text, 'Task 1');
      expect(fromJson.checked, isTrue);
    });
  });

  group('Note Model Checklist Integration Tests', () {
    test('should identify non-checklist content', () {
      final note = Note(
        id: '1',
        title: 'Plain text note',
        content: 'Hello World',
        updatedAt: DateTime.now(),
        userId: 'user1',
      );
      expect(note.isChecklist, isFalse);
      expect(note.checklistPlainText, isEmpty);
    });

    test('should identify checklist content and extract plain text', () {
      final checklistContent = jsonEncode({
        'type': 'checklist',
        'items': [
          {'id': '1', 'text': 'Buy milk', 'checked': false},
          {'id': '2', 'text': 'Call John', 'checked': true},
        ]
      });

      final note = Note(
        id: '2',
        title: 'Shopping list',
        content: checklistContent,
        updatedAt: DateTime.now(),
        userId: 'user1',
      );
      expect(note.isChecklist, isTrue);
      expect(note.checklistPlainText, contains('☐ Buy milk'));
      expect(note.checklistPlainText, contains('☑ Call John'));
    });
  });
}
