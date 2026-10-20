# Development

## Workflow

```bash
flutter pub get
flutter analyze        # must print "No issues found!"
flutter test
flutter run -d linux   # or windows / android
```

CI fails the build if `flutter analyze` reports **any** issue, including `info`-level lints, so run it before pushing.

## Code conventions

- **Lints:** `package:flutter_lints/flutter.yaml` (see [`analysis_options.yaml`](../analysis_options.yaml)). Notable rules that have bitten this project:
  - `curly_braces_in_flow_control_structures` — always use braces for `if` bodies that span lines.
  - `use_build_context_synchronously` — after an `await`, check `mounted` before using a `State`'s `context`. Prefer using the `State.context` field over passing a `BuildContext` parameter into async methods; a `mounted` check does not protect a context passed in as an argument.
  - `avoid_print` — do not use `print` in project code.
  - `unnecessary_import`, `unused_local_variable`, `deprecated_member_use`.
- **Excluded from analysis:** `build/`, `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` and `responsive_ui_template/`. Do not add `// ignore` comments or widen the exclude list to silence real findings.
- **State:** add logic to a provider, not to a widget, when more than one screen needs it. Keep SQL in `DatabaseHelper`.
- **Models:** `Vocabulary` is immutable; use `copyWith`.
- **Text:** user-visible strings are inline English literals (there is no localisation layer).

## Tests

27 tests in three files; none needs SQLite or a device, so they run quickly everywhere (including CI):

| File | Covers |
|---|---|
| `test/widget_test.dart` | `Vocabulary` fallbacks, deck non-repetition, Pass ordering, CSV/Excel import and export |
| `test/quiz_provider_test.dart` | Review Later re-queuing and random placement, no-limit rounds and Finish, first-try scoring, multiple-choice scoring, Zhuyin prompt, persisted session size |
| `test/navigation_test.dart` | Drawer selection does not pop the page, header menu opens the drawer, `CustomAppBar` back-button rules, `openQuiz` presets |

`QuizProvider(recordReview:, random:)` takes a fake recorder and a seeded `Random`, so session logic can be tested without a database. Prefer adding such seams over tests that need the native SQLite library.

Areas without automated coverage: the database layer and migrations, import of JSON/XLSX files, the Zhuyin converter (only checked by the scripts below), and the full screens against a real database. When changing navigation or quiz start-up it is worth running the app once on a phone-sized window and a desktop window.

## Command-line tools

The `tool/` folder and two root-level scripts are developer utilities, not part of the shipped app. They talk to the same desktop SQLite file the app uses (see [Getting started](getting-started.md#where-the-database-is-stored) — the file is resolved relative to the working directory).

| Script | Run with | Purpose |
|---|---|---|
| `tool/import_csv_to_db.dart` | `dart run tool/import_csv_to_db.dart --csv <file> [--db <path>]` | Bulk-load a CSV into the database ([details](import-export.md#command-line-import)) |
| `tool/convert_xlsx_to_csv.dart` | `dart run tool/convert_xlsx_to_csv.dart` | Convert `assets/data/mandarin_vocabulary.xlsx` to `assets/data/mandarin_vocabulary.csv`. The XLSX source is not committed, so you must supply it. |
| `tool/delete_vocab.dart` | `dart run tool/delete_vocab.dart` | **Deletes all rows** from `vocabularies` in the desktop database |
| `tool/test_pinyin_fix.dart` | `dart run tool/test_pinyin_fix.dart` | Pass/fail check of the Pinyin→Zhuyin converter |
| `tool/test_zhuyin.dart` | `dart run tool/test_zhuyin.dart` | Prints converter output next to expected values |
| `import_csv.dart` (root) | `dart run import_csv.dart` | Older one-off importer; the CSV path is hard-coded to a developer machine, so edit it before use |
| `verify_import.dart` (root) | `dart run verify_import.dart` | Prints the row count and first ten rows of `vocabularies` |

Scripts print with `stdout.writeln` rather than `print`, which keeps them lint-clean without importing Flutter.

## Changing the bundled vocabulary

1. Edit or replace `assets/data/mandarin_vocabulary.csv`. Keep the header `hanzi,traditionalHanzi,pinyin,zhuyin,meaning,category`.
2. **Fill in the `category` column.** Otherwise the position-based band inference applies (see [Data & database](data-and-database.md#seeding)) and any change to the row order or counts will shift bands.
3. The new data is only loaded into an **empty** table. For a development database, delete `mandarin.db` or use **Reset & Reload English Vocabulary** (which wipes all words).
4. If you change the schema, bump `version` in `DatabaseHelper._initDb`, add an `oldVersion < N` step in `onUpgrade`, and mirror the change in `_createTables`. Do not reuse the wipe-and-reseed pattern from versions 5–6 unless you intend to discard user data.

## Adding a quiz module

1. Add a value to `QuizModule` in `quiz_provider.dart` and extend the four `switch` expressions there (`questionText`, `answerText`, `optionText`).
2. Add the title in `_getAppBarTitle` and the instruction in `_QuestionView` (both in `quiz_session_screen.dart`), and decide how `_PromptCard` should render the prompt (`isHanziLed`).
3. Add an entry point: a Dashboard card (`_PracticeModuleCards`) or a mode chip on `BopomofoTrainingScreen`.

## Repository hygiene

The legacy files listed in [Architecture](architecture.md#legacy--unused-files) are safe to remove; removing them reduces confusion about which screen is live. The older notes `docs/resume.md`, `docs/summary.md`, `docs/tes.md`, the root `result.md` and the root `README.md` refer to assets that do not exist in the repository (see [Known issues](known-issues.md#documentation-drift)).
