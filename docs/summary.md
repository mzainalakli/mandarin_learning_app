# Project Summary

## Purpose

Offline Flutter app for Traditional Mandarin vocabulary practice. SQLite stores vocabulary and review statistics locally. Sessions support non-repeating practice and file exchange through Excel and CSV.

## Navigation and Quiz Architecture

Navigation path:

1. `HomeScreen`: choose one of three quiz modules.
2. `ModeSelectionScreen`: choose Multiple Choice or Essay/Flashcard.
3. `QuizScreen`: runs active session.

`QuizProvider` builds a shuffled session deck. A completed word leaves session permanently. **Pass** moves current word into review-later deck, which begins only after all remaining words. Session ends after every word, including passed words, is completed. No fixed question count.

Answered review stats write immediately to SQLite. **Leave** closes active session but keeps already saved answers.

## Answer Modes

- **Multiple Choice**: four options; requires at least four words.
- **Essay / Flashcard**: reveal answer then self-evaluate; requires one word.
- Optional timer marks multiple-choice expiry incorrect; Flashcard expiry reveals answer.

## Excel and CSV

`ExcelService` supports:

- Excel export: `mandarin_vocabulary.xlsx`
- CSV export: `mandarin_vocabulary.csv`
- Excel import with header mapping
- Sample template: `mandarin_vocab_template.xlsx`

Canonical headers:

```text
hanzi,traditionalHanzi,pinyin,zhuyin,meaning,category
```

`hanzi`, `pinyin`, and `meaning` required. Blank optional Traditional fields preserve display fallback behavior.

## Code Map

| Path | Role |
| --- | --- |
| `lib/views/home_screen.dart` | Module selection |
| `lib/views/mode_selection_screen.dart` | Answer mode selection |
| `lib/views/quiz_screen.dart` | Session UI, pass, leave, timer |
| `lib/providers/quiz_provider.dart` | Non-repeating session deck and review-later queue |
| `lib/services/excel_service.dart` | XLSX/CSV export, XLSX parsing, template generation |
| `lib/views/manage_vocab_screen.dart` | File import, export, template controls |

## Run and Check

```bash
flutter pub get
flutter analyze
flutter test
```
