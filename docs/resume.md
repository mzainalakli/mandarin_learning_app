# Mandarin Learning App — Technical Project Resume (Updated)

## Project Overview
Cross-platform Flutter application for **Traditional Mandarin (正體字)** vocabulary practice aligned with **TOCFL (Test of Chinese as a Second Language)** standards. Supports Linux Desktop & Android with offline SQLite persistence, Zhuyin/Bopomofo (注音符號), non-repetitive modular quizzes, and Excel/CSV data exchange.

---

## Technical Stack
| Layer | Technology |
|-------|------------|
| **Framework** | Flutter 3.13+, Dart 3.x |
| **State Management** | `provider` (`VocabProvider`, `QuizProvider`, `SettingsProvider`, `MenuAppController`) |
| **Local DB** | SQLite (`sqflite` Android, `sqflite_common_ffi` Linux Desktop) |
| **TTS** | `flutter_tts` (zh-CN / zh-TW) |
| **Data I/O** | `excel`, `csv`, `file_picker` |
| **UI System** | Material 3 with Deep Crimson & Jade high-contrast theme |

---

## Core Features Implemented

### 1. Dataset Integration & Auto-Seeding (14,868 entries)
- **Asset**: `assets/data/mandarin_vocabulary.xlsx` (Sheet: `Vocabulary`) registered in `pubspec.yaml`
- **Auto-seed on startup**: `DatabaseHelper.ensureSeeded()` checks `SELECT COUNT(*) FROM vocabularies`; if empty:
  - Reads XLSX via `Excel.decodeBytes()` from asset bundle
  - Maps columns: `hanzi`, `traditionalHanzi`, `pinyin`, `meaning`, `category`
  - Auto-generates `zhuyin` via `pinyin_zhuyin.dart` for all entries
  - Defaults missing/null `meaning` to `"-"` (B2–C2 levels)
  - Batch inserts via `db.batch()` transaction (< 2 seconds)
- **Fallback chain**: XLSX → CSV assets (`tocfl_cleaned_import.csv`, `tbcl_full.csv`) → JSON seed (`tocfl_a1_seed.json`)

### 2. Vocabulary Management (`lib/views/manage_vocab_screen.dart`)
- Paginated list (50 items/page) with search across Hanzi, Pinyin, Zhuyin, Meaning, Category
- TOCFL band filter chips (A1–C2 + All) — **purely local UI state**, does NOT mutate QuizProvider
- Inline add/edit/delete with form validation
- Bulk import/export: XLSX, CSV, JSON with UTF-8 BOM support
- "Reset & Reload English Vocabulary" action (clears DB → reloads seed data)
- Template download (`mandarin_vocab_template.xlsx`)

### 3. Quiz Engine (`lib/providers/quiz_provider.dart`, `lib/views/quiz_screen.dart`)
| Module | Direction |
|--------|-----------|
| `pinyinToHanziAndMeaning` | Audio/Pinyin → Hanzi + Meaning |
| `hanziToPinyinAndMeaning` | Hanzi → Pinyin + Meaning |
| `hanziToMeaning` | Hanzi → Meaning only |
| `zhuyinByHanzi` | Hanzi → Zhuyin |
| `hanziByZhuyin` | Zhuyin → Hanzi |

- **Answer Modes:** Multiple Choice (4 options) / Flashcard (self-evaluate)
- **Non-repetitive deck:** Fisher-Yates shuffle; pass queue returns only after all remaining served
- **Timer:** Configurable 5–60s countdown with auto-reveal/advance
- **Review tracking:** Persistent `reviewCount`, `correctCount`, `lastReviewed` per word
- **Review-Later queue:** Deferred words reappear at session end
- **Cumulative TOCFL queries:**
  - Selected `TOCFL A2` → `WHERE category IN ('TOCFL A1', 'TOCFL A2')`
  - Selected `TOCFL B1` → `WHERE category IN ('TOCFL A1', 'TOCFL A2', 'TOCFL B1')`
  - Selected `TOCFL B2` → `WHERE category IN ('TOCFL A1', 'TOCFL A2', 'TOCFL B1', 'TOCFL B2')`
- **Fallback:** If result < 4 words, automatically fetches all words from SQLite — quiz NEVER shows "Add vocabulary before starting"

### 4. Bopomofo / Zhuyin Training Module (`lib/screens/quiz/bopomofo_training_screen.dart`)
Two study modes accessible from Dashboard / SideMenu:
1. **Guess Zhuyin by Hanzi** — Prompt shows Traditional Hanzi → Multiple choice reveals Zhuyin
2. **Guess Hanzi by Zhuyin** — Prompt shows Zhuyin → Multiple choice reveals Traditional Hanzi
- Cumulative TOCFL level dropdown (`TOCFL A1` through `TOCFL C2` / `All`)
- Deck size selector (10, 20, 50, 100 words)
- Both Multiple Choice and Essay/Flashcard answer modes

### 5. UI/UX Polish & Framework Fixes
- **Responsive layout:** NavigationRail (desktop) / BottomNavigationBar (mobile)
- **Material 3 high-contrast chips** (`primaryContainer`/`onPrimaryContainer`)
- **Framework assertion fixes:**
  - Single `GlobalKey<ScaffoldState>` in `MenuAppController`
  - `setSelectedIndex` wraps in `WidgetsBinding.instance.addPostFrameCallback`, closes drawer first
  - `IndexedStack` children wrapped with `TickerMode(enabled: isActive)` + `ExcludeSemantics(excluding: !isActive)`
- **Back navigation:** `CustomAppBar` auto-injects `arrow_back` button on all secondary screens → calls `menuController.navigateToDashboard()`
- **TabBar/TabBarView** wrapped in `DefaultTabController` (ManageVocabScreen)
- **Pinyin as default pronunciation** — Zhuyin only in detail badges; no raw Zhuyin clutter on standard quiz cards
- **Simplified workflow:** Dashboard module cards directly launch chosen quiz module — no redundant study-path re-selection

---

## Key Code Files
| Path | Responsibility |
|------|----------------|
| `lib/main.dart` | App bootstrap, providers, theme, platform DB init, calls `VocabProvider.initialize()` |
| `lib/models/vocabulary.dart` | Model + `displayMeaning` (`-` fallback), `displayPronunciationWithZhuyin` |
| `lib/services/database_helper.dart` | SQLite CRUD, seed, migrations, batch ops, **XLSX auto-seed with Zhuyin generation** |
| `lib/services/excel_service.dart` | XLSX/CSV import/export, template, `parseRows()` public |
| `lib/services/csv_import_service.dart` | CSV parsing, Zhuyin generation |
| `lib/utils/pinyin_zhuyin.dart` | Standalone Pinyin→Zhuyin converter (400+ syllables, tones 1–5) |
| `lib/providers/vocab_provider.dart` | Vocab state, paging, import orchestration, `initialize()` |
| `lib/providers/quiz_provider.dart` | Quiz session logic, deck mgmt, scoring, cumulative TOCFL queries |
| `lib/providers/settings_provider.dart` | Persisted settings (mode, timer) |
| `lib/controllers/menu_app_controller.dart` | Navigation state, scaffold key, post-frame callbacks |
| `lib/views/home_screen.dart` | Dashboard, stats, module launchers (direct to ModeSelectionScreen) |
| `lib/views/manage_vocab_screen.dart` | Vocab CRUD, search, import/export UI, local filter chips |
| `lib/views/quiz_session_screen.dart` | Active quiz UI, timer, pass/reveal, **CustomAppBar with back button** |
| `lib/screens/quiz/quiz_mode_selection_screen.dart` | Quiz config (module from Dashboard, category, size, timer, answer mode) |
| `lib/screens/quiz/bopomofo_training_screen.dart` | Bopomofo training config (two modes, cumulative TOCFL, deck size) |
| `lib/views/settings_screen.dart` | Answer mode, timer settings |
| `lib/screens/dashboard/bulk_operations_screen.dart` | Import/Export actions |
| `lib/widgets/custom_app_bar.dart` | Reusable AppBar with auto back-button on secondary tabs |
| `lib/screens/main/main_screen.dart` | Root layout, IndexedStack with TickerMode/ExcludeSemantics |

---

## Verification
```bash
flutter analyze   # zero errors in lib/
flutter test      # 7/7 passing
```

**Test Coverage:**
- Vocabulary fallback behavior
- Quiz session non-repetition & pass-queue logic
- Excel/CSV round-trip field preservation
- BOM & case-insensitive header handling
- Template validity

---

## Architecture Notes
- **Single-source-of-truth:** SQLite → `VocabProvider` → UI
- **Immutability:** `Vocabulary` model uses `copyWith` for updates
- **Batch transactions:** `DatabaseHelper.insertBatch()` wraps 14k inserts
- **Provider-scoped:** No global mutable state; `ChangeNotifier` for reactivity
- **Platform abstraction:** `databaseFactory` swap for desktop vs mobile
- **Deferred initialization:** `VocabProvider.initialize()` awaits auto-seed before `runApp()`

---

## Recent Enhancements (Latest Refactoring Session)
1. **Full XLSX auto-seeding** from `mandarin_vocabulary.xlsx` (14,868 rows) with Zhuyin generation
2. **Framework assertion fixes** — eliminated `'_elements.contains(element)'` and `!childSemantics.renderObject._needsLayout` errors
3. **Universal back navigation** via `CustomAppBar` on all secondary screens
4. **Decoupled Manage Vocab filters** from Quiz engine — local UI state only
5. **Cumulative TOCFL queries** with automatic fallback to all words
6. **Pinyin-first pronunciation** — Zhuyin optional detail only
7. **Direct module launch** from Dashboard — removed redundant study-path step
8. **All lints resolved**; test suite green

---

*Generated from codebase state as of 2026-10-10.*