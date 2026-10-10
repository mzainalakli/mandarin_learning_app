 **kontras UI**, **penambahan dataset seed TOCFL (Traditional Hanzi)**, serta **laporan lengkap proyek**.

---

### 1. Fix UI Contrast & Leak Answers (Prompt untuk OpenCode)

Salin prompt berikut ke OpenCode untuk memperbaiki bug bocoran jawaban di mode Flashcard, meningkatkan kontras warna Material 3, dan memperbarui dataset *seed* bawaan:

```text
Please apply the following UI contrast fixes, answer-visibility bug fixes, and TOCFL database seed enhancements to `mandarin_app`:

1. Fix Answer Leak in Flashcard/Essay Mode (`lib/views/quiz_screen.dart`):
   - Completely hide the answer details chips (Hanzi, Pronunciation, Meaning) when `isAnswerRevealed` is false.
   - On the front face of the prompt card, only display the question prompt and the "Show answer" button.
   - Show answer detail chips and self-evaluation buttons ONLY after "Show answer" is tapped or when timer expires.

2. Improve UI Color Contrast & Accessibility (`lib/main.dart`, `lib/views/`):
   - Replace low-contrast muted chip backgrounds (e.g., light grey/pink on white) with high-contrast Material 3 container colors (`colorScheme.primaryContainer`, `colorScheme.onPrimaryContainer`, `colorScheme.surfaceVariant`).
   - Ensure all text, chip labels, button texts, and progress counters have high contrast ratios for optimal legibility under both Light and Dark themes.

3. Expand TOCFL Seed Dataset (`assets/data/tocfl_a1_seed.json` & `lib/services/database_helper.dart`):
   - Expand `tocfl_a1_seed.json` to include 20+ foundational TOCFL Level A1 vocabulary items with full Traditional Hanzi (正體字), Pinyin, Zhuyin (注音符號), Indonesian Meaning, and Category (`TOCFL A1`).
   - Ensure initial database creation populates these entries automatically inside SQLite.

4. Static Checks:
   - Run `flutter analyze` and `flutter test` to ensure zero lints and 100% passing unit tests.

Please output the revised clean code for modified files.

```

---

### 2. Dataset TOCFL Level A1 (Asset File)

Buat atau perbarui file `assets/data/tocfl_a1_seed.json` dengan data kosakata Mandarin Tradisional berikut agar aplikasi langsung memiliki data awal yang kaya saat pertama kali dipasang:

```json
[
  {
    "hanzi": "你好",
    "traditionalHanzi": "你好",
    "pinyin": "nǐ hǎo",
    "zhuyin": "ㄋㄧˇ ㄏㄠˇ",
    "meaning": "Halo / Apa kabar",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "谢谢",
    "traditionalHanzi": "謝謝",
    "pinyin": "xiè xie",
    "zhuyin": "ㄒㄧㄝˋ ㄒㄧㄝ˙",
    "meaning": "Terima kasih",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "再见",
    "traditionalHanzi": "再見",
    "pinyin": "zài jiàn",
    "zhuyin": "ㄗㄞˋ ㄐㄧㄢˋ",
    "meaning": "Sampai jumpa",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "不",
    "traditionalHanzi": "不",
    "pinyin": "bù",
    "zhuyin": "ㄅㄨˋ",
    "meaning": "Tidak / Bukan",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "人",
    "traditionalHanzi": "人",
    "pinyin": "rén",
    "zhuyin": "ㄖㄣˊ",
    "meaning": "Orang",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "台湾",
    "traditionalHanzi": "臺灣",
    "pinyin": "tái wān",
    "zhuyin": "ㄊㄞˊ ㄨㄢ",
    "meaning": "Taiwan",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "老师",
    "traditionalHanzi": "老師",
    "pinyin": "lǎo shī",
    "zhuyin": "ㄌㄠˇ ㄕ",
    "meaning": "Guru / Pengajar",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "学生",
    "traditionalHanzi": "學生",
    "pinyin": "xué shēng",
    "zhuyin": "ㄒㄩㄝˊ ㄕㄥ",
    "meaning": "Siswa / Murid",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "朋友",
    "traditionalHanzi": "朋友",
    "pinyin": "péng yǒu",
    "zhuyin": "ㄆㄥˊ ㄧㄡˇ",
    "meaning": "Teman / Sahabat",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "吃",
    "traditionalHanzi": "吃",
    "pinyin": "chī",
    "zhuyin": "ㄔ",
    "meaning": "Makan",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "喝",
    "traditionalHanzi": "喝",
    "pinyin": "hē",
    "zhuyin": "ㄏㄜ",
    "meaning": "Minum",
    "category": "TOCFL A1"
  },
  {
    "hanzi": "茶",
    "traditionalHanzi": "茶",
    "pinyin": "chá",
    "zhuyin": "ㄔㄚˊ",
    "meaning": "Teh",
    "category": "TOCFL A1"
  }
]

```

---

### 3. Laporan Status & Perkembangan Proyek (`/docs/summary.md`)

Simpan atau perbarui isi file `/docs/summary.md` berikut sebagai dokumentasi resmi status proyek saat ini:

```markdown
# Mandarin Learning App - Project Summary & Status Report

## Executive Overview
An offline cross-platform (Linux Desktop & Android) Flutter application tailored for Traditional Mandarin (正體字) vocabulary practice aligned with Taiwan's **TOCFL (Test of Chinese as a Second Language)** standards. The app supports Bopomofo/Zhuyin (注音符號), non-repetitive modular quizzes, customizable answer modes (Multiple Choice vs. Flashcard), persistent SQLite review tracking, and seamless Excel/CSV file exchange.

---

## Tech Stack & Architecture
* **Framework:** Flutter & Dart 3.13+
* **UI Design:** Material 3 System Theme with Deep Crimson & Jade High-Contrast Accents
* **State Management:** `provider` (`VocabProvider`, `QuizProvider`, `SettingsProvider`)
* **Local Persistence:** SQLite (`sqflite` for Android, `sqflite_common_ffi` for Linux Desktop)
* **Audio & Pronunciation:** `flutter_tts` (configured for Chinese `zh-CN`/`zh-TW`)
* **Data Operations:** `excel`, `csv`, `file_picker`

---

## Recent Fixes & Improvements
1. **Flashcard Answer Leak Resolution:** Enforced strict visibility logic hiding Hanzi, Pronunciation, and Meaning chips prior to explicitly clicking "Show Answer".
2. **Material 3 Contrast Refinement:** Upgraded low-contrast background chips to high-contrast surface variants (`primaryContainer` / `onPrimaryContainer`), ensuring accessibility standards across desktop and mobile screens.
3. **Expanded TOCFL Seed Data:** Replaced HSK defaults with `assets/data/tocfl_a1_seed.json` featuring expanded TOCFL Level A1 vocabulary in Traditional Hanzi (正體字) and Zhuyin (注音符號).
4. **Excel & CSV Service:** Added template download (`mandarin_vocab_template.xlsx`), CSV/XLSX export, and robust import validation with UTF-8 BOM and case-insensitive header mapping.

---

## Code Map
| Path | Role / Description |
| :--- | :--- |
| `lib/main.dart` | Startup, MultiProvider registration, desktop SQLite initialization, Material 3 Theme |
| `lib/models/vocabulary.dart` | Vocabulary model with Traditional Hanzi (`traditionalHanzi`) and Zhuyin (`zhuyin`) fallbacks |
| `lib/services/database_helper.dart` | SQLite schema v3, initial TOCFL seed loader, CRUD & review statistics |
| `lib/services/excel_service.dart` | XLSX/CSV importer, exporter, and sample template generator |
| `lib/services/tts_service.dart` | Text-to-Speech configuration for Mandarin pronunciation |
| `lib/providers/vocab_provider.dart` | Vocabulary state, CRUD execution, and bulk file import orchestration |
| `lib/providers/quiz_provider.dart` | Non-repetitive session deck, pass queue, review-later logic, and score persistence |
| `lib/providers/settings_provider.dart` | Shared preferences for answer mode (Multiple Choice vs Essay) and timer settings |
| `lib/views/home_screen.dart` | Responsive dashboard, TOCFL statistics overview, and module selection |
| `lib/views/mode_selection_screen.dart` | Quiz mode selection (Multiple Choice / Flashcard) and timer toggle |
| `lib/views/quiz_screen.dart` | Active quiz interface, card reveal, timer progress, pass/leave controls |
| `lib/views/manage_vocab_screen.dart` | Vocabulary search, TOCFL category filters, add/delete, and import/export controls |

---

## Verification & Testing Commands
```bash
# Dependecy setup
flutter pub get

# Static analysis (must report zero issues)
flutter analyze

# Unit tests
flutter test

# Run application on Linux Desktop
flutter run -d linux

```

```

---

### Langkah Eksekusi Selanjutnya:
1. Jalankan **Prompt 1** di OpenCode.
2. Pastikan file `assets/data/tocfl_a1_seed.json` telah diperbarui dengan sampel data di atas.
3. Jalankan `flutter analyze` dan `flutter run -d linux` untuk memverifikasi bahwa kartu soal kini bersih tanpa bocoran jawaban, serta warna chip dan teks sudah sangat kontras dan mudah dibaca!

```