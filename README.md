# TOCFL Mandarin

Offline Flutter app for learning Traditional Mandarin aligned with Taiwan's **TOCFL** bands: A1, A2, B1, B2, C1, and C2.

## Highlights

- Traditional Hanzi, Pinyin, and Zhuyin display
- Material 3 dashboard with three practice modules and modern gradient cards
- Flow: choose module → choose Multiple Choice or Essay / Flashcard → practice
- Non-repeating session deck; **Pass** moves a word to the review-later queue
- Timer: timeout marks Multiple Choice incorrect; Essay mode reveals the answer card
- Local SQLite storage and `zh-TW` pronunciation
- Import/export `.xlsx`, `.csv`, and `.json`; downloadable Excel template
- Search, TOCFL filters, swipe-to-delete, and tabbed vocabulary management

## First-run TOCFL Deck

Fresh databases load `assets/data/tocfl_a1_seed.json` during database creation. It contains foundational TOCFL A1 vocabulary in 正體字, Pinyin, 注音符號, and Indonesian meanings. Existing databases are preserved and never reseeded automatically.

## Quiz Modules

1. **Pronunciation / Zhuyin → Hanzi + Meaning**
2. **Hanzi → Pronunciation / Zhuyin + Meaning**
3. **Hanzi → Meaning**

Multiple Choice needs four words. Essay / Flashcard needs one word: reveal answer, then choose **Got It** or **Review Later**. Completed words leave the session. Passed words return after the main deck is exhausted. Leave ends the active session while saved review statistics remain.

## Vocabulary Files

XLSX and CSV use canonical, case-insensitive headers:

```text
hanzi,traditionalHanzi,pinyin,zhuyin,meaning,category
```

`hanzi`, `pinyin`, and `meaning` are required. Blank Traditional fields fall back to Hanzi. Import merges rows; duplicate detection is not yet implemented.

## Excel Template

The downloadable `.xlsx` template includes the canonical header row and TOCFL A1 example entries.

Required headers:

```text
hanzi,traditionalHanzi,pinyin,zhuyin,meaning,category
```

The importer accepts case-insensitive headers and UTF-8 BOM input. Category defaults fall back to `TOCFL A1` when not provided.

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```
