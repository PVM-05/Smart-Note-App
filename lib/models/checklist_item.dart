// lib/models/checklist_item.dart
import 'package:uuid/uuid.dart';

class ChecklistItem {
  final String id;
  String text;
  bool checked;

  ChecklistItem({
    String? id,
    this.text = '',
    this.checked = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'checked': checked,
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'] as String?,
    text: json['text'] as String? ?? '',
    checked: json['checked'] as bool? ?? false,
  );

  ChecklistItem copyWith({String? text, bool? checked}) => ChecklistItem(
    id: id,
    text: text ?? this.text,
    checked: checked ?? this.checked,
  );
}
