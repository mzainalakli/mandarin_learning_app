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

**Going back:** on any section other than the Dashboard the app bar shows a back arrow that returns to the Dashboard, and the system back button (Android back, or the back gesture) does the same; from the Dashboard it leaves the app. Pages opened on top of a section (a running quiz) have their own back arrow, which asks for confirmation before ending the session. Only the section you are looking at is loaded, so switching sections is quick; it starts from a fresh state each time.

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
| 01 Pinyin → Hanzi + Meaning | Practice Quiz with this quiz type preselected |
| 02 Hanzi → Pinyin + Meaning | Practice Quiz with this quiz type preselected |
| 03 Hanzi → Meaning | Practice Quiz with this quiz type preselected |
| 04 Bopomofo / Zhuyin Training | The Bopomofo Training section |
| 05 My Library | The My Library section |

The hero card's **Total reviews** and **Review accuracy** are your real totals across all words (sum of every answer you have given and the share that were correct); they refresh each time you open the Dashboard.

## Practice Quiz

Choose how a session runs, then tap an answer-mode card to begin.

1. **Quiz type** — *Pinyin → Hanzi + Meaning*, *Hanzi → Pinyin + Meaning* or *Hanzi → Meaning*. Starting from a Dashboard module card preselects that type; you can change it here at any time.
2. **Number of questions** — choose a preset (10, 20, 50, 100 words), **No limit**, or **Custom…** to type any number from 1 to 1000. Your choice is remembered between launches and shared with Bopomofo Training.
3. **Category / Library** — `All`, one of `TOCFL A1`…`TOCFL C2`, or any of your libraries (shown as `Library: <name>`). Choosing a TOCFL band is **cumulative**: `TOCFL B1` practises A1 + A2 + B1 words. Starting a quiz from a library preselects it.
4. **Timer** — Off, 10 s, 20 s or 30 s, and a slider for any duration from 5 to 60 seconds once the timer is on.
5. **Answer mode** — tap **Multiple Choice Mode** or **Essay / Flashcard Mode**.

### No-limit sessions

With **No limit** the quiz never runs out of questions: it works through a pool of up to 1,000 random words from your chosen source, then reshuffles and starts another **round** (the same word never appears twice in a row across a round boundary). The session only ends when you tap **Finish** (to see a summary) or **Leave**. The progress strip shows `N answered`, the current round and how many words remain in it instead of a progress bar.

### During a quiz

The screen shows a progress strip (answered / total, remaining words, passed words, timer), a large prompt card, and the answer area.

- 🔊 **Pronounce** speaks the current word in Taiwan Mandarin (`zh-TW`).
- **Pass** (app bar, or the ⋮ menu on phones) defers the current word to the end of the main deck, without saving a result for it.
- **Finish** (no-limit sessions only) ends the session and shows the summary.
- **Leave** asks for confirmation. Words you already answered keep their saved statistics; the rest of the session ends. The system back button asks the same question.

**Multiple Choice** — four lettered options (A–D). Tap one: the correct option turns green, a wrong pick turns red and shakes. After about 0.7 seconds the quiz moves on to the next word automatically (the **Next word** button is also available). If the timer is on and runs out, the word counts as incorrect and the quiz advances.

**Essay / Flashcard** — the answer is hidden. Think of it, tap **Show answer**, then choose:

- **Got It** — the word is done and counts as correct.
- **Review Later** — the miss is saved, but the word stays in the session: it is put back at a **random position among the words you have not been asked yet** (never as the very next card unless it is the only one left) and you will be asked it again. You can choose Review Later as often as you like.

If the timer runs out in flashcard mode the answer is revealed so you can still grade yourself.

When a fixed-size deck is used up, or you tap Finish, a **Session complete** card shows `Correct X of Y on the first try` and a **Back to modes** button. "First try" means a word counts as correct only if your first answer to it was right — a word you had to review does not.

## Bopomofo Training

Practise the phonetic symbols ㄅㄆㄇㄈ against real vocabulary.

- **Training mode:** *Guess Zhuyin by Hanzi* (see the character, recall the Zhuyin) or *Guess Hanzi by Zhuyin* (see the Zhuyin, recall the character).
- **Number of questions** (including **No limit** and **Custom…**), **TOCFL level** (cumulative, or `All`) and **timer** work as in Practice Quiz.
- Choose Multiple Choice or Essay / Flashcard to begin.

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

Settings are saved on the device and restored at the next launch (the number of questions you pick on the quiz screens is saved too). The answer mode of a session is the card you tap on the Practice Quiz or Bopomofo Training screen; the Settings answer-mode switch is only a stored preference and does not change how a session runs (see [Known issues](known-issues.md#settings-answer-mode-does-not-affect-sessions)).

## Tips for effective study

1. Start with `TOCFL A1`, 20 words, Multiple Choice, no timer. When you want a long, uninterrupted drill, switch to **No limit**.
2. Move to Flashcard mode once options feel too easy — recall without prompts is harder.
3. Turn on a 10–20 s timer to train fast recognition.
4. Build a library of words you keep missing (the detail sheet shows per-word accuracy) and quiz only that library.
5. In flashcard mode use **Review Later** for words you got wrong or half-remembered: they come back among the cards you have not seen yet. Use **Pass** to skip a word without recording anything.
