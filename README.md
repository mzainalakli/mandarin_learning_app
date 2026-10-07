# Mandarin Flashcards

Offline Flutter app for Traditional Mandarin vocabulary practice with SQLite storage, Zhuyin-ready entries, modular quiz sessions, and Excel/CSV exchange.

## Features

- Traditional Hanzi and Zhuyin fields with fallback to `hanzi` and `pinyin`
- Navigation: select module → select answer mode → start quiz
- Three modules: pronunciation → Hanzi/meaning, Hanzi → pronunciation/meaning, Hanzi → meaning
- Multiple-choice and Essay/Flashcard modes
- Session runs through every available word once; completed words do not repeat
- Pass sends current word to end of session for review later
- Leave exits cleanly; completed answer statistics stay saved
- Optional countdown timer
- Excel (`.xlsx`) and CSV vocabulary import/export
- Downloadable Excel template with required headers and example rows

## Setup

```bash
flutter pub get
flutter run
```

Checks:

```bash
flutter analyze
flutter test
```

## Quiz Flow

1. Choose one quiz module from Home.
2. Choose **Multiple Choice** or **Essay / Flashcard**.
3. Answer every word once. Multiple choice needs four vocabulary rows; Essay mode works with one.
4. Use **Pass** to defer a word until all other words are complete. Use **Leave** to end current session.

No fixed question limit exists. Completed words leave active session; passed words return only after unpassed words. Review statistics save when answer is evaluated.

## Vocabulary Files

Manage Vocabulary supports Excel, CSV, and existing JSON imports. Excel and CSV use headers:

```text
hanzi,traditionalHanzi,pinyin,zhuyin,meaning,category
```

Required: `hanzi`, `pinyin`, `meaning`. Optional fields default safely: blank `traditionalHanzi` displays `hanzi`; blank `zhuyin` displays `pinyin`; blank `category` becomes `Imported`.

Use **Export** menu for `mandarin_vocabulary.xlsx` or `.csv`. Use **Download Excel Template** for `mandarin_vocab_template.xlsx` with two example rows.

## Database

`mandarin.db`, table `vocabularies`, schema v3. Existing databases migrate by adding nullable `traditionalHanzi` and `zhuyin` columns.
