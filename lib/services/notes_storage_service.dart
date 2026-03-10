import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class NotesStorageService {
  static const _key = 'brunch_notes';
  static NotesStorageService? _instance;

  NotesStorageService._();

  static NotesStorageService get instance {
    _instance ??= NotesStorageService._();
    return _instance!;
  }

  Future<List<Note>> loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final notes = list
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();
      notes.sort((a, b) => b.date.compareTo(a.date));
      return notes;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNote(Note note) async {
    final notes = await loadNotes();
    notes.removeWhere((n) => n.id == note.id);
    notes.insert(0, note);
    await _persist(notes);
  }

  Future<void> updateNote(Note note) async {
    final notes = await loadNotes();
    final i = notes.indexWhere((n) => n.id == note.id);
    if (i != -1) {
      notes[i] = note;
      await _persist(notes);
    }
  }

  Future<void> deleteNote(String id) async {
    final notes = await loadNotes();
    notes.removeWhere((n) => n.id == id);
    await _persist(notes);
  }

  Future<void> _persist(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }
}
