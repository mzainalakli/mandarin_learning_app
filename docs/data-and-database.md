# Data & Database

All persistent data lives in a single SQLite file, `mandarin.db`, accessed through [`DatabaseHelper`](../lib/services/database_helper.dart) (a singleton, `DatabaseHelper.instance`). Small preferences use `shared_preferences`. See [Getting started](getting-started.md#where-the-database-is-stored) for the file location per platform.

## Schema (version 7)

```sql
CREATE TABLE vocabularies (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  hanzi            TEXT NOT NULL,
  pinyin           TEXT NOT NULL,
  zhuyin           TEXT,
  traditionalHanzi TEXT,
  meaning          TEXT NOT NULL,
  category         TEXT NOT NULL,
  reviewCount      INTEGER NOT NULL DEFAULT 0,
  correctCount     INTEGER NOT NULL DEFAULT 0,
  lastReviewed     TEXT NOT NULL DEFAULT ''
);

CREATE TABLE user_libraries (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  created_at TEXT NOT NULL            -- ISO-8601
);

CREATE TABLE library_vocab_items (
  library_id INTEGER NOT NULL,
  vocab_id   INTEGER NOT NULL,
  PRIMARY KEY (library_id, vocab_id),
  FOREIGN KEY (library_id) REFERENCES user_libraries(id)  ON DELETE CASCADE,
  FOREIGN KEY (vocab_id)   REFERENCES vocabularies(id)    ON DELETE CASCADE
);
```

The Dart model is [`Vocabulary`](../lib/models/vocabulary.dart) (`toMap`/`fromMap`, `copyWith`). Notable getters:

| Getter | Behaviour |
|---|---|
| `displayHanzi` | `traditionalHanzi` if non-blank, else `hanzi` |
| `displayPronunciation` | the Pinyin |
| `displayMeaning` | `meaning`, or `-` when blank |
| `displayPronunciationWithZhuyin` | `pinyin (zhuyin)` when Zhuyin exists |
| `accuracy` | `correctCount / reviewCount`, `0` if never reviewed |

`fromMap` trims blank `zhuyin`/`traditionalHanzi` to `null` and runs `category` through `normalizeCategory` (blank → `TOCFL A1`; any other text is kept as is).

`LibraryList` ([model](../lib/models/library_list.dart)) is a read model for a library plus its item count, with a `dd/mm/yyyy` `formattedDate`.

### Foreign keys are not enforced

The code never issues `PRAGMA foreign_keys = ON` (there is no `onConfigure` callback), so SQLite's default — foreign keys **off** — applies and the `ON DELETE CASCADE` clauses do nothing. Practical effects: deleting a library leaves its rows in `library_vocab_items`; deleting a word leaves its library links behind. Library word lists use a `JOIN`, so orphaned links are invisible there, but the item count shown on a library tile counts raw link rows and can be too high after words are deleted or the vocabulary is reset.

## Migrations

`onUpgrade` runs these steps in order, starting from the stored version:

| To version | Change |
|---|---|
| 2 | Add `reviewCount`, `correctCount`, `lastReviewed` |
| 3 | Add `zhuyin`, `traditionalHanzi` |
| 4 | Normalise legacy HSK categories to TOCFL bands |
| 5 | **Delete all vocabulary** and reseed |
| 6 | **Delete all vocabulary** and reseed |
| 7 | Create `user_libraries` and `library_vocab_items` |

A database created by an older build (version < 6) is therefore reset when opened by this build — user-added words and review history in `vocabularies` are lost at that point. Databases already at version 6 or 7 are upgraded without data loss.

## Seeding

`DatabaseHelper.ensureSeeded()` is called at startup. If `vocabularies` is empty it loads `assets/data/mandarin_vocabulary.csv` (registered in `pubspec.yaml`) and inserts every valid row in a single batch. Seeding also happens on first database creation and from **Reset & Reload English Vocabulary**. A non-empty table is never re-seeded automatically.

How each CSV row becomes a word:

- Header names are matched case-insensitively; `hanzi`, `pinyin` and `meaning` columns must exist or nothing is seeded.
- Rows where `hanzi` or `pinyin` is empty are skipped.
- An empty `meaning` is stored as `-`.
- `zhuyin` is generated from `pinyin` with [`pinyinToZhuyin`](pinyin-zhuyin.md) when the CSV cell is empty (it is empty in every bundled row).
- **Category:** if the CSV `category` is a valid TOCFL band it is used; otherwise the band is **inferred from the row's position** in the file (0-based data row index):

| Row index | Band |
|---|---|
| 0 – 445 | TOCFL A1 |
| 446 – 893 | TOCFL A2 |
| 894 – 1375 | TOCFL B1 |
| 1376 – 4375 | TOCFL B2 |
| 4376 – 9375 | TOCFL C1 |
| 9376 – end | TOCFL C2 |

If you replace or reorder the bundled CSV without filling its `category` column, these position thresholds will assign bands incorrectly.

## The bundled dataset

`assets/data/mandarin_vocabulary.csv` — header `hanzi,traditionalHanzi,pinyin,zhuyin,meaning,category` (plus empty trailing columns), **14,868 data rows**.

| Fact | Value |
|---|---|
| Rows with a `category` value in the file | 1,376 (A1: 446, A2: 448, B1: 482) |
| Rows whose band is inferred from position | 13,492 (B2: 3,000, C1: 5,000, C2: 5,492) |
| Rows with a Traditional form | all |
| Rows with a pre-filled Zhuyin | none (generated at seed time) |
| Rows with an English meaning | 1,365 (the rest are stored as `-`) |

The practical consequence: Multiple Choice and Flashcard modes that depend on the meaning (`Hanzi → Meaning`, and the meaning half of every answer) show `-` for most B2–C2 words. Fill in meanings, or import your own vocabulary, for useful practice at those levels.

## Query behaviour

| Need | Method | Notes |
|---|---|---|
| Dictionary list | `getVocabulariesPaged` | `ORDER BY category, hanzi`, `LIMIT/OFFSET`; exact band filter; search is `LIKE %q%` over hanzi, traditionalHanzi, pinyin, meaning, zhuyin |
| Count for pagination | `getVocabulariesCount` | same filters |
| Cumulative band list/count | `getVocabulariesCumulative`, `getVocabulariesCountCumulative` | `category IN (A1 … selected)`; used by the Dashboard cards |
| Quiz words | `getQuizVocabulary` | cumulative band, `ORDER BY RANDOM() LIMIT n`, fallback described in [Quiz engine](quiz-engine.md#category-selection-is-cumulative) |
| Library words | `getLibraryVocabularies`, `getQuizVocabularyFromLibrary` | `JOIN` through `library_vocab_items` |
| Review result | `updateReviewStats` | increments counters, sets `lastReviewed` |

Search is case-insensitive for Latin text (SQLite `LIKE`) but not diacritic-insensitive: searching `ni` will not match `nǐ`.

## Preferences

`SettingsProvider` stores four keys in `shared_preferences`:

| Key | Type | Default | Range |
|---|---|---|---|
| `isMultipleChoice` | bool | `true` | — |
| `isTimerEnabled` | bool | `false` | — |
| `timerDurationSeconds` | int | `10` | clamped to 5–60 |
| `sessionSize` | int | `20` | 1–1000; `0` is stored for "no limit" |
