# Known Issues

Findings from a review of the source code. Each item states the symptom, the cause with a file reference, and a suggested fix. **How they were verified:** by reading the code and call graph, by running `flutter analyze` and `flutter test` (both clean), and, for the Pinyin converter and file-picker behaviour, by running the converter and inspecting the package source. The UI was not exercised interactively, so on-screen wording of a symptom is inferred from the code.

## Functional bugs

### Bopomofo Training does not start a new deck

- **Symptom:** starting a session from *Bopomofo Training* does not build a deck from your chosen session size and TOCFL level. If no quiz has run yet in this launch, the session screen shows "Add vocabulary before starting a quiz."; if one has, it shows that earlier session's state.
- **Cause:** [`bopomofo_training_screen.dart`](../lib/screens/quiz/bopomofo_training_screen.dart) `_openQuiz` pushes `QuizSessionScreen` directly. `QuizProvider.startQuiz` is only called from `QuizModeSelectionScreen._openQuiz` (and the unused legacy `quiz_screen.dart`), and `QuizSessionScreen` assumes the quiz was already started. The selected category and size are passed to the screen but never used.
- **Fix:** make `_openQuiz` `await context.read<QuizProvider>().startQuiz(category: …, module: _selectedModule, answerMode: …, sessionSize: …)` before pushing, as the Practice Quiz screen does.

### Zhuyin prompt modes show Hanzi as the prompt

- **Symptom:** in *Zhuyin → Hanzi* (`hanziByZhuyin`) the large prompt shows the Hanzi even though the instruction reads "Read the Zhuyin and recall Hanzi", and the options are Hanzi too.
- **Cause:** `_PromptCard` in [`quiz_session_screen.dart`](../lib/screens/quiz/quiz_session_screen.dart) treats every module except `pinyinToHanziAndMeaning` as Hanzi-led, and `QuizProvider.questionText` returns the Hanzi for `hanziByZhuyin`.
- **Fix:** make the prompt for `hanziByZhuyin` the word's Zhuyin (fall back to Pinyin when empty) and show Zhuyin-led styling.

### Timeout and 4-word check use the global answer-mode setting

- **Symptom:** the answer mode you tap on a quiz configuration screen can disagree with the *Settings* switch. With Settings on "Multiple choice" (the default), a timer expiry in a Flashcard session marks the word as timed out instead of just revealing it; and a Flashcard session with fewer than 4 words is rejected with the "needs at least 4 words" message.
- **Cause:** `_startTimer` and `build` in `quiz_session_screen.dart` read `SettingsProvider.isMultipleChoice` rather than the session's `widget.answerMode` / `QuizProvider.answerMode`.
- **Fix:** use the session's answer mode in both places.

### Dashboard review statistics are not real

- **Symptom:** the hero card's **Total reviews** equals the word count, **Review accuracy** always shows 0 %, and the **TOCFL A1** metric chip shows `Instance of 'Future<int>'` instead of a number. **Deck ready: Yes** is a constant.
- **Cause:** [`dashboard_screen.dart`](../lib/screens/dashboard/dashboard_screen.dart) `_getTotalReviews()` returns the cumulative word count, `_getTotalCorrect()` returns `0`, and `_HeroCopy` interpolates a `Future` directly into a string.
- **Fix:** add a database query that sums `reviewCount` and `correctCount`; load the A1 count in `_loadStats` and pass it down as an `int`.

### Export writes only the currently loaded page

- **Symptom:** *Export XLSX/CSV* produces at most the 50 words on the current Dictionary page (or the current filter/search result), although the card says it downloads "the full vocabulary set".
- **Cause:** both export screens use `context.read<VocabProvider>().vocabs`, which is a paged view. 
- **Fix:** export from `DatabaseHelper.getAllVocabularies()` (limit 10,000 — raise it, or add an unpaged query, since the bundled data has 14,868 rows).

### Export and template download fail on Android

- **Symptom:** *Export* and *Download template* show "Could not export vocabulary." / "Could not save Excel template." on Android.
- **Cause:** `FilePicker.saveFile` requires the file `bytes` on Android and iOS (`file_picker` 8.3.7 throws "Bytes are required on Android & iOS when saving a file"). The app calls it without bytes and writes the file itself afterwards, which only works on desktop.
- **Fix:** generate the bytes first and pass them to `saveFile(bytes: …)` on mobile.

### Header search field does nothing

The top-bar search box, the "Learner" badge and the dropdown arrow beside it are decorative: the `TextField` has no controller or handler. The adjacent icon button, named `_ThemeToggle` in [`header.dart`](../lib/screens/main/components/header.dart), actually toggles the quiz timer, not the theme. Use the search box inside *Dictionary → Vocabulary List*.

### Library deletion dialog is misleading

The confirmation says "Delete '<name>' and all its words?" but only the library list is removed; the words stay in the dictionary. Reword the dialog or clarify in the UI.

### Dictionary side rail on desktop is inert

On wide screens the Dictionary shows an extra "Manage Vocabulary" `NavigationRail` whose selection callback is empty. Switch tabs with the tab bar. The rail duplicates information and can be removed.

## Data and persistence

### Most B2–C2 words have no meaning

Only 1,365 of 14,868 bundled entries have an English meaning; the rest are stored as `-`. Meaning-based practice at B2–C2 is therefore weak, and in Multiple Choice several options may all read `-`, making them indistinguishable (correctness is still decided by the actual word, not the text). See [Data & database](data-and-database.md#the-bundled-dataset).

### Foreign keys are not enforced

`PRAGMA foreign_keys` is never enabled, so `ON DELETE CASCADE` does not fire. Deleting a library or word leaves orphan rows in `library_vocab_items`, and a library's item count can be higher than the number of words you can see. See [Data & database](data-and-database.md#foreign-keys-are-not-enforced).

### Some operations erase user data

- Upgrading a database older than schema version 6 wipes `vocabularies`.
- **Reset & Reload English Vocabulary** deletes every word, including ones you added, along with their review statistics. Libraries are kept, but their links to the deleted words become orphans because the reloaded words get new ids (auto-increment ids are not reused).

### Imports are not de-duplicated, and statistics are not exported

Importing the same file twice duplicates every row. Exported files omit `reviewCount`, `correctCount` and `lastReviewed`, so they cannot be used to back up study progress.

### Desktop database path depends on the working directory

`sqflite_common_ffi` stores the database under `./.dart_tool/sqflite_common_ffi/databases/` relative to where the process starts. Launching a release build from a different folder (or a shortcut with a different "start in") creates a separate, empty-progress database. Fix by calling `databaseFactoryFfi.setDatabasesPath(...)` with an application-support directory (for example from `path_provider`) during startup.

### Category inference by row position

When the bundled CSV's `category` is empty the band is inferred from the row index. This is fragile: re-ordering or editing the CSV silently changes bands. Fill in the `category` column for every row.

## Pinyin → Zhuyin

- Neutral tone must be written with the digit `5`; a marked-tone phrase such as `xiè xie` produces `ㄒㄧㄝˋ ㄒㄧㄝ` with no `˙`.
- Apostrophes and hyphens are not handled (`xi'an` → `xi'ㄚn`).
- JSON import and the Quick Add form do not generate Zhuyin.

See [Pinyin → Zhuyin converter](pinyin-zhuyin.md).

## Platform and release

- The Android release is signed with the **debug keystore** and uses the default application id `com.example.mandarin_app`; it cannot be published to the Play Store as is.
- Text-to-speech on Android selects `com.google.android.tts`; devices without it (or without a Chinese voice) will be silent or fall back unpredictably.
- Web, iOS and macOS are not built or tested in CI.

## Code health

- `lib/views/home_screen.dart`, `lib/views/mode_selection_screen.dart`, `lib/views/quiz_screen.dart` and `lib/services/csv_import_service.dart` are unreferenced legacy code. See [Architecture](architecture.md#legacy--unused-files).
- `QuizSessionScreen` accepts `category` and `sessionSize` parameters it never reads.
- The only automated tests are 7 unit tests; there are none for the database layer, migrations, JSON/XLSX import, the converter or any screen.
- The `responsive_ui_template/` folder at the repository root is an unrelated Flutter project; it is excluded from analysis and can be deleted.

## Documentation drift

The root `README.md` says fresh databases load `assets/data/tocfl_a1_seed.json` with Indonesian meanings; that file does not exist and the app seeds from `assets/data/mandarin_vocabulary.csv`. `docs/resume.md`, `docs/summary.md`, `docs/tes.md` and the root `result.md` repeat references to files that are not in the repository (`tocfl_a1_seed.json`, `mandarin_vocabulary.xlsx`, `tocfl_cleaned_import.csv`, `tbcl_full.csv`) and describe a seed fallback chain the code does not have. Prefer the documents indexed in [README](README.md).
