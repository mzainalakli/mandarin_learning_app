# User Guide

This guide walks through every screen of the app. For the rules behind the quizzes see [Quiz engine](quiz-engine.md); for file formats see [Import & export](import-export.md).

## Layout and navigation

The app has seven top-level sections, available from the side menu:

| # | Section | Purpose |
|---|---|---|
| 0 | **Dashboard** | Overview, TOCFL band cards, shortcuts to every practice module |
| 1 | **Practice Quiz** | Configure and start a quiz |
| 2 | **Bopomofo Training** | Configure Zhuyin ↔ Hanzi practice |
| 3 | **My Library** | Custom word lists |
| 4 | **Dictionary** | Browse/search words, add words, bulk operations |
| 5 | **Import / Export** | Import and export vocabulary files |
| 6 | **Settings** | Answer mode and timer |

**Responsive behaviour** (breakpoints by window width):

| Width | Class | Navigation |
|---|---|---|
| < 850 px | mobile | Hamburger button opens a slide-out drawer |
| 850 – 1099 px | tablet | Drawer, wider content |
| ≥ 1100 px | desktop | Permanent sidebar on the left |

On any section other than the Dashboard, the app bar shows a back arrow that returns to the Dashboard. Pages pushed on top (a running quiz, for example) show a normal back arrow instead.

**Theme:** light or dark follows your operating system. There is no in-app theme switch.

### The top bar

The top bar shows the section title, a search field, a timer button and a "Learner" badge.

- The **timer button** (stopwatch icon) switches the quiz countdown timer on or off. It is the same setting as in *Settings*.
- The **search field** and the **Learner** badge are currently decorative; use the search box inside *Dictionary* to search (see [Known issues](known-issues.md#header-search-field-does-nothing)).

## Dashboard

- A hero card with your deck size, **Start Quiz**, **Manage Words**, **My Library**, **Import / Export** and **Settings** shortcuts.
- **TOCFL Progress** — one card for each band A1–C2 with a word count and progress bar. Counts are **cumulative**: the A2 card counts A1 + A2 words, the B1 card counts A1 + A2 + B1, and so on. The bar fills towards 300 words.
- **Practice Modules** — five cards:

| Card | Opens |
|---|---|
| 01 Pinyin → Hanzi + Meaning | Quiz settings with this module preselected |
| 02 Hanzi → Pinyin + Meaning | Quiz settings with this module preselected |
| 03 Hanzi → Meaning | Quiz settings with this module preselected |
| 04 Bopomofo / Zhuyin Training | The Bopomofo Training section |
| 05 My Library | The My Library section |

> The **Total reviews** and **Review accuracy** tiles on the hero card do not yet reflect your real study history; see [Known issues](known-issues.md#dashboard-review-statistics-are-not-real).

## Practice Quiz

Choose how a session runs, then tap an answer-mode card to begin.

1. **Session size** — 10, 20, 50 or 100 words. Words are drawn at random from the chosen source.
2. **Category / Library** — `All`, one of `TOCFL A1`…`TOCFL C2`, or any of your libraries (shown as `Library: <name>`). Choosing a TOCFL band is **cumulative**: `TOCFL B1` practises A1 + A2 + B1 words.
3. **Timer presets** — Off, 10 s, 20 s or 30 s per question.
4. **Answer mode** — tap **Multiple Choice Mode** or **Essay / Flashcard Mode**.

If you open this section from the side menu, the quiz module defaults to **Pinyin → Hanzi + Meaning**. To use another module, start from the matching card on the Dashboard. Starting a quiz from a library also uses the default module.

### During a quiz

The screen shows a progress strip (`answered / total`, main deck remaining, review-later count, timer), a large prompt card, and the answer area.

- 🔊 **Pronounce** speaks the current word in Taiwan Mandarin (`zh-TW`).
- **Pass** (app bar, or the ⋮ menu on phones) defers the current word. Passed words come back after the rest of the deck has been served.
- **Leave** asks for confirmation. Words you already answered keep their saved statistics; the session itself ends. The system back button asks the same question.

**Multiple Choice** — four lettered options (A–D). Tap one: the correct option turns green, a wrong pick turns red and shakes. After about 0.7 seconds the quiz moves on to the next word automatically (the **Next word** button is also available). If the timer is on and runs out, the word counts as incorrect and the quiz advances.

**Essay / Flashcard** — the answer is hidden. Think of it, tap **Show answer**, then choose:

- **Got It** — counts as correct.
- **Review Later** — counts as *incorrect* for statistics and moves on. (Only **Pass** puts a word back into the same session; see [Quiz engine](quiz-engine.md#pass-review-later-and-got-it).)

If the timer runs out in flashcard mode the answer is revealed so you can still grade yourself.

When the deck is exhausted, a **Session complete** card shows `Correct X of Y` and a **Back to modes** button.

## Bopomofo Training

Practise the phonetic symbols ㄅㄆㄇㄈ against real vocabulary.

- **Training mode:** *Guess Zhuyin by Hanzi* (see the character, recall the Zhuyin) or *Guess Hanzi by Zhuyin* (see the Zhuyin, recall the character).
- **Session size**, **TOCFL level** (cumulative, or `All`) and **timer presets** work as in Practice Quiz.
- Choose Multiple Choice or Essay / Flashcard to begin.

> Starting a session from this screen currently does not load a fresh deck; see [Known issues](known-issues.md#bopomofo-training-does-not-start-a-new-deck).

## My Library

Libraries are your own word lists, stored in the same database as the main vocabulary.

- **Create** a library with the **+** button; **rename** or **delete** it from its menu. Deleting a library asks for confirmation and removes the list. The dialog says "Delete '<name>' and all its words?", but only the list is removed — the words themselves stay in the dictionary.
- **Open** a library to see its words. On wide screens the list of libraries is on the left and the selected library's words on the right; on phones you move between the two views.
- **Add vocabulary** opens a sheet where you can search, filter by TOCFL band, select several words (or **select all**) and tap **Save (n)**.
- **Remove** a word from a library with the remove button on its row (with confirmation).
- **Start Quiz** begins a quiz limited to that library's words.
- Each word row has a 🔊 pronounce button.

You can also add a single word to a library from the **Dictionary** list (the "Add to Library" button on each row, which lets you pick an existing library or create a new one) or from the word detail sheet.

## Dictionary

Three tabs, switched with the tab bar at the top. (On wide screens an extra "Manage Vocabulary" rail with the same three names appears beside the content; it is purely visual — use the tab bar.)

### Vocabulary List

- Search box — matches Hanzi, Traditional Hanzi, Pinyin, Zhuyin and Meaning (substring match, 250 ms debounce).
- Filter chips — `All`, each TOCFL band, and one chip per library (📚 name). Band filters here are **exact** (A2 shows only A2 words), unlike quiz selection.
- Results are paginated, **50 words per page**, with previous/next controls. (Library views are not paginated.)
- Each row shows the word, pronunciation, meaning, your `correct/reviews` tally (once reviewed) and the Traditional form when different.
- **Tap a row** for the detail sheet: Hanzi, Traditional form, Pinyin, Zhuyin, TOCFL level, review count, correct count and accuracy, a pronounce button, and chips to add the word to any library (or create a new one).
- **Swipe left** (or use the trash button) to delete a word; you are asked to confirm.

### Quick Add

Add one word: **Hanzi**, **Pinyin** and **Meaning** are required; **Traditional Hanzi**, **Zhuyin** and the **TOCFL category** are optional (category defaults to `TOCFL A1`).

### Bulk Operations

Export to XLSX/CSV, import from XLSX/CSV/JSON, download the XLSX template, and **Reset & Reload English Vocabulary**. The reset action deletes **all** words (including ones you added) and reloads the bundled dataset; it asks for confirmation first. Libraries are kept, but any library entries pointing to deleted words become empty references.

## Import / Export

A dedicated screen with the same import, export and template actions as the Dictionary's Bulk Operations tab. See [Import & export](import-export.md) for formats. After an import, a message reports `Imported N rows; skipped M invalid rows.`

## Settings

- **Answer mode** — Multiple choice or Flashcards.
- **Countdown timer** — on/off, and when on, a slider from 5 to 60 seconds.

Settings are saved on the device and restored at the next launch. Note that the answer mode you tap on the Practice Quiz screen decides how a session is presented; the Settings answer-mode switch currently only affects timeout behaviour and the "needs 4 words" check (see [Known issues](known-issues.md#timeout-and-4-word-check-use-the-global-answer-mode-setting)).

## Tips for effective study

1. Start with `TOCFL A1`, 20 words, Multiple Choice, no timer.
2. Move to Flashcard mode once options feel too easy — recall without prompts is harder.
3. Turn on a 10–20 s timer to train fast recognition.
4. Build a library of words you keep missing (the detail sheet shows per-word accuracy) and quiz only that library.
5. Use **Pass** when you genuinely do not know a word: it is re-served later without being counted as wrong.
