# Architecture

The app is a conventional Flutter application: widgets read state from `provider` `ChangeNotifier`s, which call a single database service. There is no backend and no network code.

```
┌──────────────────────────── UI (lib/screens, lib/views, lib/widgets) ───────────────────────────┐
│  MainScreen ─ SideMenu / Header ─ the active one of 8 sections ─ pushed pages (quiz session)      │
└───────────────▲──────────────────────────────▲──────────────────────────▲───────────────────────┘
                │ context.watch / read         │                          │
┌───────────────┴──────────┐ ┌─────────────────┴────────┐ ┌───────────────┴───────────┐ ┌─────────┴─────────┐
│ VocabProvider            │ │ QuizProvider             │ │ SettingsProvider          │ │ MenuAppController │
│ list, paging, import     │ │ session deck, scoring    │ │ answer mode, timer        │ │ selected tab,     │
└───────────────┬──────────┘ └─────────────────┬────────┘ └───────────────┬───────────┘ │ scaffold key      │
                │                              │                          │             └───────────────────┘
┌───────────────▼──────────────────────────────▼──────┐        ┌──────────▼──────────┐
│ Services: DatabaseHelper · DeckBuilder · StatsRepository · ExcelService · TtsService │        │ shared_preferences  │
└───────────────┬──────────────────────────────────────┘        └─────────────────────┘
                │
        SQLite (sqflite / sqflite_common_ffi)         Utils: pinyinToZhuyin
```

## Source layout

```
lib/
├── main.dart                         bootstrap, providers, Material 3 theme
├── controllers/menu_app_controller.dart   selected section, drawer control, quiz preset (module/library)
├── core/responsive.dart              breakpoints, ResponsiveCard, BentoGrid, helpers
├── models/                           Vocabulary, LibraryList, VocabStats (dashboard aggregates), ReviewEvent, DeckFilter, StatsSnapshot
├── providers/                        VocabProvider, QuizProvider, SettingsProvider, StatsProvider
├── services/
│   ├── database_helper.dart          schema, migrations, seeding, all SQL
│   ├── deck_builder.dart             quiz deck selection (weak / due / unseen words)
│   ├── leitner.dart                  box/interval constants and the promotion rules
│   ├── stats_repository.dart         read-only statistics queries (trends, streak, levels, most missed)
│   ├── excel_service.dart            XLSX/CSV import, export, template, category mapping
│   ├── tts_service.dart              flutter_tts wrapper
│   └── csv_import_service.dart       (unused — see below)
├── utils/pinyin_zhuyin.dart          Pinyin → Zhuyin converter
├── widgets/
│   ├── custom_app_bar.dart           app bar with context-aware leading button
│   └── session_options.dart          session-size / timer selectors, answer-mode card
├── screens/
│   ├── main/                         MainScreen, components/side_menu.dart, components/header.dart
│   ├── dashboard/                    dashboard_screen.dart, bulk_operations_screen.dart
│   ├── stats/stats_screen.dart       Statistics section (fl_chart charts)
│   ├── quiz/                         quiz_mode_selection_screen.dart, bopomofo_training_screen.dart, quiz_launcher.dart, quiz_session_screen.dart
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
5. `runApp` with a `MultiProvider` exposing `VocabProvider`, `QuizProvider`, `StatsProvider`, `MenuAppController` and `SettingsProvider`, and `MaterialApp(home: MainScreen())`.

The UI is not shown until step 4 completes, which is why the first launch (seeding ~15k rows) is slower.

## State management

| Provider | Owns | Persists to |
|---|---|---|
| `VocabProvider` | The currently displayed page of words (`vocabs`), `currentPage`, `totalCount`, `isLoading`; add/delete; import orchestration; library word loading | SQLite via `DatabaseHelper` |
| `QuizProvider` | The active session: deck, remaining and passed queues, current word, options, score, round, answered/revealed flags. Accepts an optional review recorder, `Random`, clock (`now`) and `DeckBuilder` for testing. Every real answer is passed to the recorder as a `ReviewEvent` (module, mode, correct, first attempt, session id, response time, outcome); Pass is not recorded. Review Later is capped at `maxReviewLaterPerWord` (3) per word and exposes `canReviewLater`, `repeatTotal` and `repeatedWordCount` for the UI | SQLite (review totals, `review_events`, `vocab_progress`) |
| `StatsProvider` | The `StatsSnapshot` shown on the Statistics screen and the selected range (7/30/90 days); loads through an injectable loader (default `StatsRepository.load`) | read-only SQLite |
| `SettingsProvider` | Answer-mode preference, timer settings and the number of questions per session (`null` = no limit) | `shared_preferences` |
| `MenuAppController` | `selectedIndex` of the active section; the `GlobalKey<ScaffoldState>` used to open/close the drawer; the quiz preset (`quizModule`, `quizLibrary`, `quizWeakWords`) set by `openQuiz()` | memory |

Screens call `notifyListeners`-driven updates with `context.watch<T>()` and fire actions with `context.read<T>()`. Some screens also call `DatabaseHelper.instance` directly for read-only needs such as listing libraries; there is no repository layer between providers and the helper.

The Library's "Add words" sheet (`_AddVocabBottomSheet`) keeps its own local state rather than using `VocabProvider`. It pages 50 rows at a time through `DatabaseHelper.getVocabulariesPaged(excludeLibraryId:)`, which hides words already in the library with a `NOT EXISTS` on `library_vocab_items`. The selection (a set of ids) survives search and category changes, and "Select all" uses `getVocabularyIds`, which returns every matching id regardless of paging. `addVocabsToLibrary` runs in one transaction and returns the number of rows actually inserted.

`VocabProvider.vocabs` is a *view* — whatever page/filter the Dictionary last loaded — not the full vocabulary. Code that needs full sets (Dashboard counts, quiz building) queries the database directly.

## Learning statistics and word selection

**Recording.** `QuizProvider` builds a `ReviewEvent` for each real answer (multiple choice, Got It / Review Later, timeout) and hands it to `DatabaseHelper.recordReview`, which in one transaction (1) updates the legacy totals on `vocabularies` for *every* answer (unchanged behaviour, used by the Dashboard), (2) inserts a `review_events` row, and (3) for a **first attempt only** updates the word's Leitner state in `vocab_progress`. Answers after Review Later are stored with `is_first_attempt = 0` and change neither accuracy nor the schedule. Pass is not an answer and is not recorded. Bopomofo training records nothing.

**Schedule (Leitner).** Box 0 = due now; intervals per box are 0, 1, 3, 7, 14, 30 days (`Leitner.intervalDays`). A miss sends the word to box 0 (due immediately) and raises `wrong_streak`. A correct answer promotes the word one box only if it was due; reviewing early is recorded but does not promote. A word in box 4 or higher counts as mastered (`Leitner.masteredBox`). Progress is one row per word and is shared by all quiz modules; `module` and `mode` are kept on events for later analysis.

**Deck selection.** `DeckBuilder.build(filter, size)` (used by `startQuiz` / `startQuizFromLibrary`) fills about half of the deck (`weakSlotFraction = 0.5`) with weak or due words, then never-seen words, then any other words, without duplicates and respecting the category/library filter. Weak words (missed recently, or box ≤ 1 after a miss) are sampled before merely-due words. Candidates come from indexed queries limited to `slots × candidateOversample`; random draws fetch ids only and sample in Dart, so the whole vocabulary is never loaded and the `Random` and clock are injectable. A brand-new user gets the same random deck as before. The old "fewer than 4 words → whole vocabulary" fallback is kept. In no-limit sessions the same builder fills the 1000-word pool.

**Weak words practice.** `DeckBuilder.buildWeak` returns the weakest words overall (worst first, padded with random words up to `weakWordsMinDeck = 4`). It is the "Weak words" entry of the Practice Quiz dropdown, opened by `openQuiz(weakWords: true)` from the Dashboard card or the Statistics screen; it is disabled while fewer than 4 weak words exist.

**Statistics screen.** A separate section (`MenuAppController.statsIndex = 7`, "Statistics"). `StatsRepository` computes everything with local calendar days (`review_events.day`, `yyyymmdd`, written from the injected clock): words learned and mastered, first-attempt accuracy for the last 7 days vs the 7 before, streak (it survives until the day ends), answers today, accuracy line and answers bar chart (daily for 7/30 days, weekly for 90), accuracy by quiz type, mastered words and accuracy by TOCFL level, and the 20 most missed words. Accuracy on this screen is **first-attempt accuracy**; the Dashboard shows accuracy over all answers, so the two differ by design. With no events it shows a "No data yet" state; trends start with the release that introduced `review_events`. The layout uses `Responsive` helpers (`pagePadding`, `gap`, `useSplitLayout`, `safeInsets`) and two columns on tablet/desktop and landscape phones.

## Navigation

- **Sections:** `MainScreen` builds **only the active section** (a `KeyedSubtree` keyed by the selected index). Switching sections builds one screen instead of keeping all eight alive (there is no `IndexedStack`), and each section starts fresh, which is also what refreshes the Dashboard numbers. `MenuAppController.setSelectedIndex` always closes an open drawer first and then updates the index in a post-frame callback, which avoids framework assertions that occur when the tree changes during a frame.
- **Drawer:** on screens narrower than 1100 px the `SideMenu` is the `Scaffold`'s drawer. Selecting an item only calls `MenuAppController.selectMenu`; closing the drawer is the controller's job. (An extra `Navigator.pop()` after closing the drawer used to pop the app's last route and leave a blank screen.) The header's menu button calls `MenuAppController.openDrawer()`, which uses the scaffold key, because `Scaffold.of(context)` with the `MainScreen` context finds no scaffold.
- **System back:** `MainScreen` wraps its scaffold in `PopScope(canPop: selectedIndex == dashboard)`. Back from any other section returns to the Dashboard; from the Dashboard it leaves the app.
- **Starting a quiz from elsewhere:** the Dashboard module cards and a library's **Start Quiz** call `MenuAppController.openQuiz(module:, library:, weakWords:)`. That records the preset and switches to the Practice Quiz section, whose screen reads it in `initState`. No second setup page is pushed on top of the section any more.
- **Pushed pages:** only the running quiz (`QuizSessionScreen`) is pushed, by `launchQuiz()` after the deck has been loaded. It wraps itself in `PopScope(canPop: false)` and shows a confirmation dialog on back.
- **Back button logic:** `CustomAppBar` shows (in priority) a back arrow if *its own route* can pop (`ModalRoute.canPop`); a "Back to Dashboard" arrow on any section other than the Dashboard; or a menu button on narrow screens. It deliberately does not ask the whole navigator (`Navigator.canPop`): a section screen rebuilt while a quiz page sat on top would otherwise keep a stale "Back" button that, once the page was gone, popped the last route.

## Responsive design

[`lib/core/responsive.dart`](../lib/core/responsive.dart) defines `AppBreakpoint { mobile, tablet, desktop }` at 850 px and 1100 px, `Responsive.getContentMaxWidth/Padding/GridCrossAxisCount`, plus two reusable widgets: `ResponsiveCard` and `BentoGrid`. Screens read the breakpoint with `MediaQuery.sizeOf` and choose between layouts (for example the Library shows a single column on phones and a master/detail split on desktop).

**Height and orientation.** Width alone misclassifies a phone in landscape (915x412 is "tablet" by width). `Responsive` therefore also exposes:

| Helper | Meaning |
|---|---|
| `isCompactHeight` | height < `compactHeightBreakpoint` (480 px) |
| `isCompact` | `isMobile || isCompactHeight`: any phone, portrait or landscape |
| `useSplitLayout` | landscape and compact height: two-column session layout |
| `gap`, `sectionGap`, `pagePadding`, `cardPadding`, `innerCardPadding` | spacing scale that tightens when compact (tablet/desktop values unchanged) |
| `promptFontSize` | quiz prompt size from width *and* available height; never below 40 px (hanzi) / 28 px |
| `bottomSafeInset` | `viewPadding.bottom` (0 while the keyboard is open) for bottom-sheet content |
| `actionBlockMinHeight`, `minTouchTarget` | fixed minimum height of the quiz action block (no layout jump); 48 dp targets |

Rules:

- Decide phone vs. tablet layouts with `isCompact` / `useSplitLayout`, not with `isMobile` alone. Tablet and desktop (not compact) keep their original layouts.
- **Safe area.** The app is edge-to-edge (Flutter targets SDK 36, which enforces it). `MainScreen` wraps its body in `SafeArea`; any *pushed* page (`QuizSessionScreen`) must do the same, and bottom-sheet lists add `Responsive.bottomSafeInset` to their bottom padding.
- **Quiz layout.** Phones in portrait: one-line status (`_CompactStatusBar`), a prompt card that fills the free height (`Expanded`), answers, and a bottom action block of fixed minimum height. The column has a tight height of `max(available, quizMinContentHeight)` inside a `SingleChildScrollView`, so it scrolls only when text is large; answers scroll inside a band capped at `quizContentMaxFraction`. Landscape phones use two columns (prompt + status | answers + actions).
- **MainScreen header** is 56 dp when compact: menu, title, a search icon that expands inline, the timer toggle and the avatar.
- Tests: `test/quiz_session_layout_test.dart`, `main_screen_layout_test.dart`, `bottom_sheet_safe_area_test.dart` and `responsive_helpers_test.dart` render these screens at 360x640, 412x915, 640x360, 800x360, 915x412 and 1024x768 (plus text scale 1.3) and check bottom controls against simulated system insets.

## Theming

`MandarinApp` builds light and dark `ColorScheme`s from a crimson seed (`#9D1F3C`) with a jade tertiary (`#087B68`), then applies one shared `ThemeData` factory (Material 3, rounded cards and buttons, chip/tab/list-tile themes, a custom text scale). `themeMode` is `ThemeMode.system`.

## Dependencies

| Package | Used for |
|---|---|
| `provider` | state management |
| `fl_chart` | line and bar charts on the Statistics screen (MIT, pure Dart, no native code) |
| `sqflite`, `sqflite_common_ffi`, `path` | SQLite on mobile and desktop |
| `shared_preferences` | settings |
| `flutter_tts` | speech |
| `file_picker` | open/save dialogs |
| `excel`, `csv` | XLSX / CSV reading and writing |
| `cupertino_icons` | icons |
| `flutter_lints` (dev) | lint rules |
| `sqlite3` (dev) | the command-line import tool only |
