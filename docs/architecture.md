# Architecture

The app is a conventional Flutter application: widgets read state from `provider` `ChangeNotifier`s, which call a single database service. There is no backend and no network code.

```
┌──────────────────────────── UI (lib/screens, lib/views, lib/widgets) ───────────────────────────┐
│  MainScreen ─ SideMenu / Header ─ IndexedStack of 7 sections ─ pushed pages (quiz session)       │
└───────────────▲──────────────────────────────▲──────────────────────────▲───────────────────────┘
                │ context.watch / read         │                          │
┌───────────────┴──────────┐ ┌─────────────────┴────────┐ ┌───────────────┴───────────┐ ┌─────────┴─────────┐
│ VocabProvider            │ │ QuizProvider             │ │ SettingsProvider          │ │ MenuAppController │
│ list, paging, import     │ │ session deck, scoring    │ │ answer mode, timer        │ │ selected tab,     │
└───────────────┬──────────┘ └─────────────────┬────────┘ └───────────────┬───────────┘ │ scaffold key      │
                │                              │                          │             └───────────────────┘
┌───────────────▼──────────────────────────────▼──────┐        ┌──────────▼──────────┐
│ Services: DatabaseHelper · ExcelService · TtsService │        │ shared_preferences  │
└───────────────┬──────────────────────────────────────┘        └─────────────────────┘
                │
        SQLite (sqflite / sqflite_common_ffi)         Utils: pinyinToZhuyin
```

## Source layout

```
lib/
├── main.dart                         bootstrap, providers, Material 3 theme
├── controllers/menu_app_controller.dart   selected section + scaffold key
├── core/responsive.dart              breakpoints, ResponsiveCard, BentoGrid, helpers
├── models/                           Vocabulary, LibraryList
├── providers/                        VocabProvider, QuizProvider, SettingsProvider
├── services/
│   ├── database_helper.dart          schema, migrations, seeding, all SQL
│   ├── excel_service.dart            XLSX/CSV import, export, template, category mapping
│   ├── tts_service.dart              flutter_tts wrapper
│   └── csv_import_service.dart       (unused — see below)
├── utils/pinyin_zhuyin.dart          Pinyin → Zhuyin converter
├── widgets/custom_app_bar.dart       app bar with context-aware leading button
├── screens/
│   ├── main/                         MainScreen, components/side_menu.dart, components/header.dart
│   ├── dashboard/                    dashboard_screen.dart, bulk_operations_screen.dart
│   ├── quiz/                         quiz_mode_selection_screen.dart, bopomofo_training_screen.dart, quiz_session_screen.dart
│   ├── library/library_screen.dart
│   └── dictionary/vocab_detail_modal.dart
└── views/
    ├── manage_vocab_screen.dart      Dictionary (live)
    ├── settings_screen.dart          Settings (live)
    └── home_screen.dart, mode_selection_screen.dart, quiz_screen.dart   (legacy — see below)
```

### Legacy / unused files

Three screens in `lib/views/` form an older navigation flow (`home_screen.dart` → `mode_selection_screen.dart` → `quiz_screen.dart`) that nothing imports any more; the live app uses the `lib/screens/` equivalents (`dashboard_screen`, `quiz_mode_selection_screen`, `quiz_session_screen`). `lib/services/csv_import_service.dart` is likewise not referenced. They still compile and pass analysis, so they are safe to delete in a future cleanup. Treat the `lib/screens/` versions as the source of truth when changing behaviour.

The repository root also contains `responsive_ui_template/`, a separate, unrelated Flutter project (package `admin`) that is excluded from analysis. It is not part of the app.

## Startup sequence

`main()` in [`lib/main.dart`](../lib/main.dart):

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. On Linux, Windows and macOS: `sqfliteFfiInit()` and `databaseFactory = databaseFactoryFfi`. Android uses the stock sqflite plugin.
3. `SettingsProvider.load()` — reads preferences.
4. `VocabProvider.initialize()` — `DatabaseHelper.ensureSeeded()` (opens/creates the database, runs migrations, seeds when empty) then loads the first page of words.
5. `runApp` with a `MultiProvider` exposing `VocabProvider`, `QuizProvider`, `MenuAppController` and `SettingsProvider`, and `MaterialApp(home: MainScreen())`.

The UI is not shown until step 4 completes, which is why the first launch (seeding ~15k rows) is slower.

## State management

| Provider | Owns | Persists to |
|---|---|---|
| `VocabProvider` | The currently displayed page of words (`vocabs`), `currentPage`, `totalCount`, `isLoading`; add/delete; import orchestration; library word loading | SQLite via `DatabaseHelper` |
| `QuizProvider` | The active session: deck, remaining and review-later queues, current word, options, score, answered/revealed flags | SQLite (review statistics only) |
| `SettingsProvider` | Answer-mode preference and timer settings | `shared_preferences` |
| `MenuAppController` | `selectedIndex` of the active section; the `GlobalKey<ScaffoldState>` used to open/close the drawer | memory |

Screens call `notifyListeners`-driven updates with `context.watch<T>()` and fire actions with `context.read<T>()`. Some screens also call `DatabaseHelper.instance` directly for read-only needs such as listing libraries; there is no repository layer between providers and the helper.

`VocabProvider.vocabs` is a *view* — whatever page/filter the Dictionary last loaded — not the full vocabulary. Code that needs full sets (Dashboard counts, quiz building) queries the database directly.

## Navigation

- **Sections:** `MainScreen` hosts an `IndexedStack` of seven tabs. `MenuAppController.setSelectedIndex` updates the index in a post-frame callback and closes the drawer first, which avoids framework assertions that occur when the tree changes during a frame. Each tab is wrapped in `TickerMode(enabled: isActive)` and `ExcludeSemantics(excluding: !isActive)` so hidden tabs neither animate nor appear in the accessibility tree.
- **Pushed pages:** the quiz session (`QuizSessionScreen`) and, when started from a Dashboard card or a library, a second `QuizModeSelectionScreen`, are pushed with `Navigator.push`.
- **Leaving a quiz:** `QuizSessionScreen` wraps its page in `PopScope(canPop: false)` and shows a confirmation dialog on back.
- **Back button logic:** `CustomAppBar` shows (in priority) a back arrow if the navigator can pop; a "Back to Dashboard" arrow on any section other than the Dashboard; or a menu button on narrow screens.

## Responsive design

[`lib/core/responsive.dart`](../lib/core/responsive.dart) defines `AppBreakpoint { mobile, tablet, desktop }` at 850 px and 1100 px, `Responsive.getContentMaxWidth/Padding/GridCrossAxisCount`, plus two reusable widgets: `ResponsiveCard` and `BentoGrid`. Screens read the breakpoint with `MediaQuery.sizeOf` and choose between layouts (for example the Library shows a single column on phones and a master/detail split on desktop).

## Theming

`MandarinApp` builds light and dark `ColorScheme`s from a crimson seed (`#9D1F3C`) with a jade tertiary (`#087B68`), then applies one shared `ThemeData` factory (Material 3, rounded cards and buttons, chip/tab/list-tile themes, a custom text scale). `themeMode` is `ThemeMode.system`.

## Dependencies

| Package | Used for |
|---|---|
| `provider` | state management |
| `sqflite`, `sqflite_common_ffi`, `path` | SQLite on mobile and desktop |
| `shared_preferences` | settings |
| `flutter_tts` | speech |
| `file_picker` | open/save dialogs |
| `excel`, `csv` | XLSX / CSV reading and writing |
| `cupertino_icons` | icons |
| `flutter_lints` (dev) | lint rules |
| `sqlite3` (dev) | the command-line import tool only |
