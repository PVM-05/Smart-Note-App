// lib/core/theme/note_theme.dart
import 'package:flutter/material.dart';

class NoteTheme extends ThemeExtension<NoteTheme> {
  final Color? pinnedNote;
  final Color? selectedNote;
  final Color? archivedNote;
  final Color? lockedNote;

  const NoteTheme({this.pinnedNote, this.selectedNote, this.archivedNote, this.lockedNote});

  @override
  NoteTheme copyWith({Color? pinnedNote, Color? selectedNote, Color? archivedNote, Color? lockedNote}) {
    return NoteTheme(
      pinnedNote: pinnedNote ?? this.pinnedNote,
      selectedNote: selectedNote ?? this.selectedNote,
      archivedNote: archivedNote ?? this.archivedNote,
      lockedNote: lockedNote ?? this.lockedNote,
    );
  }

  @override
  NoteTheme lerp(ThemeExtension<NoteTheme>? other, double t) {
    if (other is! NoteTheme) return this;
    return NoteTheme(
      pinnedNote: Color.lerp(pinnedNote, other.pinnedNote, t),
      selectedNote: Color.lerp(selectedNote, other.selectedNote, t),
      archivedNote: Color.lerp(archivedNote, other.archivedNote, t),
      lockedNote: Color.lerp(lockedNote, other.lockedNote, t),
    );
  }
}
