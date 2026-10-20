# Import & Export

Import, export and template actions are available in **Import / Export** and in **Dictionary → Bulk Operations**. The parsing logic is in [`lib/services/excel_service.dart`](../lib/services/excel_service.dart) (XLSX/CSV) and [`VocabProvider.importFromJsonFile`](../lib/providers/vocab_provider.dart) (JSON).

## Canonical columns

```text
hanzi,traditionalHanzi,pinyin,zhuyin,meaning,category
```

| Column | Required | Meaning |
|---|---|---|
| `hanzi` | yes | Simplified (or default) form of the word |
| `traditionalHanzi` | no | Traditional form (正體字). When blank the app displays `hanzi` |
| `pinyin` | yes | Pinyin with tone marks or tone digits, e.g. `nǐ hǎo` / `ni3 hao3` |
| `zhuyin` | no | Zhuyin. When blank it is generated from `pinyin` (XLSX, CSV) |
| `meaning` | yes | English (or any language) gloss |
| `category` | no | TOCFL band, see [Category rules](#category-rules) |

A row missing any of `hanzi`, `pinyin` or `meaning` (after trimming) is **skipped** and counted in the "skipped" total. Completely empty rows are ignored silently.

## Importing

1. Open **Import / Export** → **Import file** (or Dictionary → Bulk Operations → **Import file**).
2. Pick a `.xlsx`, `.csv` or `.json` file.
3. A message reports `Imported N rows; skipped M invalid rows.` The vocabulary list reloads.

Imported rows are **appended**. There is no duplicate detection — importing the same file twice doubles the entries.

### XLSX

- The worksheet named `Vocabulary` is used; if there is none, the first sheet is used.
- The first row must be the header row. Cell values are read as text.
- A workbook with no worksheet raises *"Excel file has no worksheet."*

### CSV

- Decoded as UTF-8; if that fails the bytes are decoded as Latin-1-style code units. A UTF-8 **BOM** is tolerated.
- Parsed with a standard CSV parser (quotes, embedded commas and newlines work).
- If the standard parse cannot find the required headers, the file is re-read with a simple comma-split parser as a fallback.

### JSON

A JSON **array of objects**:

```json
[
  {
    "hanzi": "谢谢",
    "traditionalHanzi": "謝謝",
    "pinyin": "xiè xie",
    "zhuyin": "ㄒㄧㄝˋ ˙ㄒㄧㄝ",
    "meaning": "thank you",
    "category": "TOCFL A1"
  }
]
```

- `hanzi`, `pinyin` and `meaning` must be non-empty strings, otherwise the object is skipped. Non-object entries are skipped too. A top-level value that is not an array raises *"JSON must contain a list of vocabulary rows."*
- `traditionalHanzi`, `zhuyin` and `category` are optional.
- Unlike CSV/XLSX, JSON import does **not** generate Zhuyin: if `zhuyin` is absent the field stays empty.
- JSON files are read from disk by path, so the picker must return a file path.

### Header matching (XLSX and CSV)

Headers are trimmed, lower-cased and stripped of a leading BOM before matching. Two columns with the same normalised name raise *"Duplicate header: …"*. Aliases accepted:

| Field | Accepted headers (in priority order) |
|---|---|
| Hanzi | `hanzi`, `simplified`, `traditional` |
| Traditional Hanzi | `traditionalhanzi`, `traditional` |
| Pinyin | `pinyin` |
| Meaning | `meaning` |
| Zhuyin | `zhuyin` |
| Category | `category` |
| Sub-category | `subcategory` |
| Row id | `id` |

If `hanzi`, `pinyin` or `meaning` cannot be found the import fails with *"Required headers: hanzi, pinyin, meaning (or compatible aliases)."* Extra columns are ignored.

### Category rules

For XLSX and CSV the category of each row is decided in this order:

1. **Row id** — if an `id` column holds a value like `L1`, `L2` … `L6`, the row is assigned `TOCFL A1` … `TOCFL C2` accordingly.
2. **Valid TOCFL band** — if `category` is exactly one of `TOCFL A1`…`TOCFL C2`, it is used.
3. **Mapping** — `HSK 1–3` → `TOCFL A1`, `HSK 4–5` → `TOCFL A2`, `HSK 6` → `TOCFL B1`; and a list of common topic names (family, food, colours, numbers, transport…) found in `category` or `subcategory` → `TOCFL A1`.
4. **Fallback** — `category/subcategory` if both are present, else the raw `category` text, else `TOCFL A1`.

Rows whose category is not a TOCFL band (for example a topic name that is not in the mapping) keep that text as their category. They appear in the *All* view and can be exported, but they do not take part in band filters or the cumulative TOCFL quiz selection. For JSON, an absent category becomes `TOCFL A1` and any other text is kept as is.

## Exporting

- **Export XLSX** writes a workbook with one sheet, `Vocabulary`, the canonical header row, and one row per word.
- **Export CSV** writes UTF-8 text (no BOM) with the same columns.
- **Download template** writes `mandarin_vocab_template.xlsx` with the header row and three TOCFL A1 example rows (你好, 谢谢/謝謝, 再見).
- The default file name is `mandarin_vocabulary.xlsx` / `.csv`; you choose the location in a save dialog.

> **Important:** export currently writes the words **already loaded in the list** — normally the current page of up to 50 words, or the current filter/search result — not the entire database. See [Known issues](known-issues.md#export-writes-only-the-currently-loaded-page). Export and template download also fail on Android today; see [Known issues](known-issues.md#export-and-template-download-fail-on-android).

Review statistics (`reviewCount`, `correctCount`, `lastReviewed`) are not part of the exported columns, so they are not preserved across an export/import round trip.

## Command-line import

For loading a large CSV straight into a desktop database without opening the app there is `tool/import_csv_to_db.dart`:

```bash
dart run tool/import_csv_to_db.dart --csv /path/to/words.csv [--db /path/to/mandarin.db]
```

It reuses `ExcelService.importCsv`, creates the `vocabularies` table if missing and inserts all valid rows in one transaction. Exit codes: `64` bad usage, `66` CSV not found, `1` import failure. See [Development](development.md#command-line-tools) for the other tools.
