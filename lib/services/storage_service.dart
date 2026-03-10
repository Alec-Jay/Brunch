import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meeting.dart';

class StorageService {
  static const _meetingsKey = 'brunch_meetings';
  static StorageService? _instance;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  /// Load all meetings from local storage, sorted newest first.
  Future<List<Meeting>> loadMeetings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_meetingsKey);
      if (raw == null) return [];
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      final meetings = jsonList
          .map((e) => Meeting.fromJson(e as Map<String, dynamic>))
          .toList();
      meetings.sort((a, b) => b.date.compareTo(a.date));
      return meetings;
    } catch (_) {
      return [];
    }
  }

  /// Save a new meeting (prepends to list).
  Future<void> saveMeeting(Meeting meeting) async {
    final meetings = await loadMeetings();
    meetings.removeWhere((m) => m.id == meeting.id);
    meetings.insert(0, meeting);
    await _persist(meetings);
  }

  /// Update an existing meeting (e.g. after transcription/summary).
  Future<void> updateMeeting(Meeting meeting) async {
    final meetings = await loadMeetings();
    final index = meetings.indexWhere((m) => m.id == meeting.id);
    if (index != -1) {
      meetings[index] = meeting;
      await _persist(meetings);
    }
  }

  /// Delete a meeting by ID.
  Future<void> deleteMeeting(String id) async {
    final meetings = await loadMeetings();
    meetings.removeWhere((m) => m.id == id);
    await _persist(meetings);
  }

  Future<void> _persist(List<Meeting> meetings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = meetings.map((m) => m.toJson()).toList();
    await prefs.setString(_meetingsKey, jsonEncode(jsonList));
  }
}
