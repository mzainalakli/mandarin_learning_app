# Mandarin Learning App - Project Summary & Status Report

## Executive Overview
An offline cross-platform (Linux Desktop & Android) Flutter application tailored for Traditional Mandarin (正體字) vocabulary practice aligned with Taiwan's **TOCFL (Test of Chinese as a Second Language)** standards. The app supports Bopomofo/Zhuyin (注音符號), non-repetitive modular quizzes, customizable answer modes (Multiple Choice vs. Flashcard), persistent SQLite review tracking, and seamless Excel/CSV file exchange.

---

## Tech Stack & Architecture
* **Framework:** Flutter & Dart 3.13+
* **UI Design:** Material 3 System Theme with Deep Crimson & Jade High-Contrast Accents
* **State Management:** `provider` (`VocabProvider`, `QuizProvider`, `SettingsProvider`)
* **Local Persistence:** SQLite (`sqflite` for Android, `sqflite_common_ffi` for Linux Desktop)
* **Audio & Pronunciation:** `flutter_tts` (configured for Chinese `zh-CN`/`zh-TW`)
* **Data Operations:** `excel`, `csv`, `file_picker`

---

## Recent Fixes & Improvements
1. **Flashcard Answer Leak Resolution:** Enforced strict visibility logic hiding Hanzi, Pronunciation, and Meaning chips prior to explicitly clicking "Show Answer".
2. **Material 3 Contrast Refinement:** Upgraded low-contrast background chips to high-contrast surface variants (`primaryContainer` / `onPrimaryContainer`), ensuring accessibility standards across desktop and mobile screens.
3. **Expanded TOCFL Seed Data:** Replaced HSK defaults with `assets/data/tocfl_a1_seed.json` featuring expanded TOCFL Level A1 vocabulary in Traditional Hanzi (正體字) and Zhuyin (注音符號).
4. **Excel & CSV Service:** Added template download (`mandarin_vocab_template.xlsx`), CSV/XLSX export, and robust import validation with UTF-8 BOM and case-insensitive header mapping.

---

## Code Map
| Path | Role / Description |
| :--- | :--- |
| `lib/main.dart` | Startup, MultiProvider registration, desktop SQLite initialization, Material 3 Theme |
| `lib/models/vocabulary.dart` | Vocabulary model with Traditional Hanzi (`traditionalHanzi`) and Zhuyin (`zhuyin`) fallbacks |
| `lib/services/database_helper.dart` | SQLite schema v3, initial TOCFL seed loader, CRUD & review statistics |
| `lib/services/excel_service.dart` | XLSX/CSV importer, exporter, and sample template generator |
| `lib/services/tts_service.dart` | Text-to-Speech configuration for Mandarin pronunciation |
| `lib/providers/vocab_provider.dart` | Vocabulary state, CRUD execution, and bulk file import orchestration |
| `lib/providers/quiz_provider.dart` | Non-repetitive session deck, pass queue, review-later logic, and score persistence |
| `lib/providers/settings_provider.dart` | Shared preferences for answer mode (Multiple Choice vs Essay) and timer settings |
| `lib/views/home_screen.dart` | Responsive dashboard, TOCFL statistics overview, and module selection |
| `lib/views/mode_selection_screen.dart` | Quiz mode selection (Multiple Choice / Flashcard) and timer toggle |
| `lib/views/quiz_screen.dart` | Active quiz interface, card reveal, timer progress, pass/leave controls |
| `lib/views/manage_vocab_screen.dart` | Vocabulary search, TOCFL category filters, add/delete, and import/export controls |

---

## Verification & Testing Commands
```bash
# Dependecy setup
flutter pub get

# Static analysis (must report zero issues)
flutter analyze

# Unit tests
flutter test

# Run application on Linux Desktop
flutter run -d linux

```
