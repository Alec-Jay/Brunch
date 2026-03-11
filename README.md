# Brunch — AI Meeting Notes App

Flutter app for recording meetings, transcribing speech (English & **Afrikaans**), and generating AI summaries with action items. Similar to Granola. Built for Android and iOS.

---

## Tech Stack

- **Flutter** (Dart), Material 3, dark glassmorphism theme
- **Audio:** `record` package (mic), `audioplayers` (playback)
- **Storage:** `shared_preferences` (meetings, notes, API keys — all local)
- **APIs:** HTTP only (`http` package); no Firebase in current scope

---

## Features (Current)

| Area | Details |
|------|--------|
| **Home** | Dashboard with 4 tiles: **Meetings**, **Notes** (text + voice), **Calendar**, **Folder** (all recordings & notes) |
| **Meetings** | Record → save → open meeting → **Transcribe** → **Summarize** |
| **Transcription** | **Android:** On-device Whisper first (no API key). **Then:** ElevenLabs Scribe (best Afrikaans, speaker diarization), **fallback:** Groq Whisper, then OpenAI Whisper. Auto language detection. |
| **Summaries** | Groq (Llama 3) or Claude or OpenAI GPT-4o — summary + action items + key decisions |
| **Notes** | Text notes (keyboard) and voice notes (record + save); stored locally |
| **Folder** | Browse all meetings and notes; filter All / Recordings / Notes |
| **Calendar** | Placeholder UI; sync planned for later phase |

---

## Project Structure

```
lib/
├── main.dart                 # Entry, theme, SystemChrome
├── theme/
│   └── app_theme.dart        # Dark theme colors, card/input styles
├── models/
│   ├── meeting.dart          # Meeting (id, title, date, transcript, summary, actionItems, transcriptSegments, audioFilePath, participants)
│   ├── note.dart             # Note (text/voice, id, title, content, date, type, audioFilePath, durationSeconds)
│   └── transcript_segment.dart  # Speaker-labeled segment (speakerLabel, text, start/end optional)
├── services/
│   ├── api_keys_service.dart       # Save/load API keys (ElevenLabs, Groq, OpenAI, Claude)
│   ├── storage_service.dart        # Meetings CRUD (shared_preferences)
│   ├── notes_storage_service.dart  # Notes CRUD
│   ├── audio_recorder_service.dart # Mic record, .m4a/.3gp, amplitude stream
│   ├── transcription_service.dart  # Groq + OpenAI Whisper (no diarization)
│   ├── elevenlabs_transcription_service.dart  # ElevenLabs Scribe, diarize=true, segments
│   ├── local_transcription_service.dart       # On-device Whisper (Android), no API key
│   └── summary_service.dart        # Groq Llama 3, OpenAI GPT-4o, Claude
├── screens/
│   ├── home_screen.dart      # Dashboard with 4 tiles
│   ├── meetings_screen.dart  # List meetings, search, FAB "New Meeting"
│   ├── new_meeting_screen.dart   # Title, participants, record, waveform, save
│   ├── meeting_detail_screen.dart # Playback, transcript (plain or speaker segments), summary, action items, transcribe/summarize buttons
│   ├── notes_screen.dart     # List notes, FAB → text or voice note
│   ├── calendar_screen.dart  # Placeholder calendar UI
│   ├── folder_screen.dart    # All recordings + notes, filters
│   └── settings_screen.dart  # API keys: ElevenLabs, Groq, OpenAI, Claude; Save
└── widgets/
    ├── home_tile.dart        # Gradient tile (icon, title, subtitle, badge)
    ├── meeting_card.dart     # Meeting list card
    └── waveform_widget.dart  # Live waveform from recorder
```

---

## API Keys (User-Configurable in App)

**Do not hardcode API keys.** Users enter them in **Settings** (gear on home screen). Stored locally via `ApiKeysService` (shared_preferences).

| Key | Purpose | Priority (transcription) |
|-----|---------|---------------------------|
| **ElevenLabs** | Scribe speech-to-text (Afrikaans + English, speaker labels) | 1st |
| **Groq** | Whisper-style transcription + Llama 3 summaries | 2nd (fallback) |
| **OpenAI** | Whisper transcription + GPT-4o summaries | 3rd (fallback) |
| **Claude** | Summaries only (optional) | Used for summary if set |

Transcription flow: **Android** — try on-device Whisper first (no key); then ElevenLabs → Groq → OpenAI. **iOS/other** — ElevenLabs → Groq → OpenAI. Summary: Groq → Claude → OpenAI.

---

## How to Run

```bash
# Dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Build debug APK
flutter build apk --debug
```

**First time / clean build:** If Gradle fails (e.g. `stripDebugDebugSymbols`), run `flutter clean` then `flutter run` again.

---

## Conventions

- **Theme:** `AppTheme` in `lib/theme/app_theme.dart` — use for colors, don’t hardcode hex elsewhere.
- **Mounted checks:** After any `await` in widgets, use `if (!mounted) return;` before `setState` or `context`.
- **Secrets:** No `.env` or keys in repo; keys only in app Settings.

---

## Phases / Roadmap

| Phase | Status | Notes |
|-------|--------|--------|
| 1 – UI / navigation | Done | Home dashboard, tiles, theme |
| 2 – Audio record & storage | Done | Record, save meeting, playback, local persistence |
| 3 – Transcription | Done | ElevenLabs Scribe (primary), Groq/OpenAI fallback, speaker segments |
| 4 – AI summaries | Done | Summary + action items + decisions |
| 5 – Export | Not started | Share/export meeting (e.g. PDF, text) |
| 6 – Calendar sync | Not started | Google Calendar / Outlook |
| Future – More SA languages | Planned | isiZulu, isiXhosa, Sesotho |

---

## For New Agents / Developers

- **Transcription:** On Android, `local_transcription_service.dart` (on-device Whisper) is tried first; then `elevenlabs_transcription_service.dart` (ElevenLabs Scribe) and `transcription_service.dart` (Groq/OpenAI). Meeting detail tries local, then `getBestTranscriptionKey()` for cloud.
- **Summaries:** `summary_service.dart` — Groq, Claude, OpenAI; expects transcript text and returns summary + action_items + key_decisions (JSON).
- **New API keys:** Add getter/setter in `api_keys_service.dart`, persist in Settings screen, then use in the relevant service (transcription or summary).
- **Speaker labels:** Stored in `Meeting.transcriptSegments` (list of `TranscriptSegment`). When `meeting.hasSpeakerLabels` is true, meeting detail UI shows “Speaker 1”, “Speaker 2”, etc.

---

## Repository

Git remote: `origin` → GitHub (e.g. `Alec-Jay/Brunch`). Commit and push after meaningful changes; do not commit API keys or secrets.
