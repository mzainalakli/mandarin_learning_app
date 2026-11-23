# Quiz Engine

The quiz logic lives in [`lib/providers/quiz_provider.dart`](../lib/providers/quiz_provider.dart) (`QuizProvider`, a `ChangeNotifier`). The UI is [`quiz_session_screen.dart`](../lib/screens/quiz/quiz_session_screen.dart); sessions are configured in [`quiz_mode_selection_screen.dart`](../lib/screens/quiz/quiz_mode_selection_screen.dart) and [`bopomofo_training_screen.dart`](../lib/screens/quiz/bopomofo_training_screen.dart).

## Modules

`QuizModule` has five values. Each defines what the learner sees (the *prompt*), what counts as the answer, and how multiple-choice options are written.

| Module | Prompt | Revealed answer (flashcard) | Option text (multiple choice) | Shown in UI as |
|---|---|---|---|---|
| `pinyinToHanziAndMeaning` | Pinyin | Hanzi + meaning | `Hanzi — meaning` | Pronunciation → Hanzi |
| `hanziToPinyinAndMeaning` | Hanzi | Pinyin + meaning | `Pinyin — meaning` | Hanzi → Pronunciation |
| `hanziToMeaning` | Hanzi | Meaning | meaning | Hanzi → Meaning |
| `zhuyinByHanzi` | Hanzi | Zhuyin + meaning | `Zhuyin — meaning` | Hanzi → Zhuyin |
| `hanziByZhuyin` | Zhuyin (Pinyin if the word has no Zhuyin) | Hanzi + meaning | `Hanzi — meaning` | Zhuyin → Hanzi |

"Hanzi" always means the **Traditional** form when one exists (`Vocabulary.displayHanzi`), otherwise the simplified `hanzi` column.

The three Pinyin/Hanzi/Meaning modules are chosen with the *Quiz type* chips on Practice Quiz (or preselected by a Dashboard card); the two Zhuyin modules are chosen on Bopomofo Training.

## Answer modes

`QuizAnswerMode` is `multipleChoice` or `essay` (flashcard).

- **Multiple choice** builds four options per question: the correct word plus three distractors drawn at random from the *other words in the same session*. The options are shuffled. A session therefore needs at least **4 words**; with fewer, the screen shows "Multiple choice needs at least 4 vocabulary words."
- **Essay / flashcard** has no options. The learner reveals the answer and self-grades.

## Building a session

Both configuration screens call `launchQuiz()` ([`quiz_launcher.dart`](../lib/screens/quiz/quiz_launcher.dart)), which loads a fresh deck into `QuizProvider` and then pushes `QuizSessionScreen`. The session screen never loads words itself.

1. A start method loads candidate words from the database:
   - `startQuiz(category, …)` and `startQuizFromLibrary(libraryId, …)` → `DeckBuilder.build` — about half of the deck is weak or due words, the rest never-seen and then random words, no duplicates (see [Architecture](architecture.md#learning-statistics-and-word-selection)).
   - `startWeakWordsQuiz(…)` → `DeckBuilder.buildWeak` — the weakest words overall ("Weak words" in the quiz dropdown).
   - The old `getQuizVocabulary` / `getQuizVocabularyFromLibrary` random queries still exist in `DatabaseHelper` but the quiz no longer uses them.
   - `startNewQuiz(vocabs, …)` — uses an in-memory list (used by the unit tests).
2. `sessionSize` is an `int?`: a number from 1 to 1000 (`SettingsProvider.sessionSize`, default 20), or `null` for **no limit**. The candidate list is shuffled and trimmed to that size — or, for no limit, to `QuizProvider.endlessPoolSize` (1000) words. This is the session's **deck** (`totalCount`).
3. The deck is shuffled again into the `remaining` queue; the Pass queue (`reviewLater`) starts empty and counters reset.
4. The first question is drawn.

### No-limit sessions

`isEndless` is true when `sessionSize` is `null`. When the `remaining` and Pass queues are both empty, `_startNextRound()` increments `round`, clears the first-try bookkeeping, reshuffles the whole pool and carries on, so `quizFinished` never becomes true by itself. If the first card of the new round would be the card just answered, it is swapped with another so the same word is never asked twice in a row. The session ends only through `finishSession()` (the **Finish** button) or by leaving. Progress for the strip is `roundCompleted / poolSize`.

### Category selection is cumulative

For quiz selection, a TOCFL band means "that band and everything below it":

| Selected | Words included |
|---|---|
| `All` | everything |
| `TOCFL A1` | A1 |
| `TOCFL A2` | A1, A2 |
| `TOCFL B1` | A1, A2, B1 |
| `TOCFL B2` | A1 – B2 |
| `TOCFL C1` | A1 – C1 |
| `TOCFL C2` | A1 – C2 |

If a band query returns **fewer than 4 words** (and the category is not `All`), the helper falls back to a random sample from the *whole* vocabulary, provided that sample has at least 4 words. This keeps Multiple Choice playable on sparse data but means the session may contain words outside the selected band.

## Question flow

```
start → _advance() ─┐
                    ├─ remaining empty AND passed queue not empty → move passed words into remaining
                    ├─ remaining empty AND no-limit session → start next round
                    ├─ remaining still empty → quizFinished = true
                    └─ otherwise → current = remaining.removeLast(), build options (multiple choice)
```

A question is *answered* when the learner selects an option (`checkAnswer`), self-grades (`selfEvaluate` / `reviewLater`), or the timer expires in multiple-choice mode (`markTimedOut`). `nextQuestion()` then moves on. In the UI, all of these auto-advance: after 700 ms in multiple choice, after 350 ms for Got It / Review Later (`flashcardAdvanceDelay`).

### Pass, Review Later and Got It

| Action | Effect on the session | Effect on saved statistics |
|---|---|---|
| **Pass** | Word goes to the *passed* queue and returns once the main deck is empty. Not allowed after the question has been answered. | none |
| **Got It** (flashcard) | Word is completed (`completedCount + 1`). | `reviewCount + 1`, `correctCount + 1` |
| **Review Later** (flashcard) | Word is **not** completed. After the feedback delay it is inserted at a random position among the questions not yet asked and will be asked again. | `reviewCount + 1` (a miss) |
| Correct option (multiple choice) | Word is completed. | `reviewCount + 1`, `correctCount + 1` |
| Wrong option (multiple choice) | Word is completed. | `reviewCount + 1` |
| Timeout (multiple choice) | Word is completed, answer shown. | `reviewCount + 1` |

**Random reinsertion.** `remaining` is used as a stack whose last element is the next question. `_reinsertRandomly` inserts the word at `nextInt(remaining.length)`, i.e. at any position *below* the last element. At least one other question is therefore asked first whenever one is available; if the main deck is empty it first pulls in the passed words, and if the word is truly the only one left it simply returns.

Every deck word is served once, plus once more per Pass or Review Later. A word being reviewed repeatedly records a miss each time and one correct answer when it is finally graded Got It, so its stored accuracy reflects how hard it was.

## Timer

- Controlled by `SettingsProvider` (`isTimerEnabled`, `timerDurationSeconds` in the range 5–60, default 10 s). The configuration screens offer 10, 20 and 30 s presets plus a slider for any value from 5 to 60 s (1-second steps); the Settings screen has the same slider.
- A one-second periodic timer restarts for each new question (including after Pass and Review Later).
- On expiry the **session's** answer mode decides: in multiple-choice mode the question is marked timed out (incorrect) and the quiz advances; in flashcard mode the answer is revealed.
- The timer is cancelled as soon as the learner answers, passes or leaves.

## Scoring and persistence

- In-session: `score` (words answered correctly **on the first attempt**), `completedCount` (completed words), `progressFraction` (`completedCount / totalCount`, or the current round's share in a no-limit session).
- First-attempt scoring: the first graded answer to a word decides whether it scores; later attempts (after Review Later or Pass) do not. In a no-limit session the bookkeeping resets every round.
- The finish card reports `Correct <score> of <completedCount> on the first try` and either `You reviewed <totalCount> words in total.` or, for no-limit sessions, `You answered <completedCount> words (<round> rounds).`
- A word is **weak** when it has at least one real first attempt and either its latest first attempt was a miss (`wrong_streak > 0`) or its first-attempt accuracy is below `Leitner.weakAccuracyThreshold` (0.6) after at least `Leitner.weakMinAttempts` (2) attempts. A newly learned word answered correctly once is not weak, and the Leitner box plays no part in the definition. Right after an upgrade or on a fresh install there are no weak words until the first wrong first answer. The same definition drives deck selection, "Weak words" practice and its count, the Dashboard card and the most-missed list. Merely due words (not weak) fill the reschedule slots of a deck separately.
- Persistent: `DatabaseHelper.recordReview(event)` runs one transaction per real answer: it adds one to `reviewCount`, adds one to `correctCount` if correct, stores `lastReviewed` as an ISO-8601 timestamp, inserts a `review_events` row and, for first attempts only, updates `vocab_progress` (Leitner box). Pass is not recorded; Review Later and timeouts are recorded as misses; answers after Review Later are stored with `is_first_attempt = 0`. Words without a database id (`id == null`) are never scored.
- `Vocabulary.accuracy` is `correctCount / reviewCount` (0 when never reviewed). It is shown in the word detail sheet.

## Text-to-speech

`TtsService` (`flutter_tts`) is a singleton initialised lazily on first use: language `zh-TW`, speech rate 0.45, volume 1.0, pitch 1.0. On Android it selects the Google TTS engine (`com.google.android.tts`), so that engine and a Chinese voice must be installed on the device. The Speak button always speaks the word's Hanzi.

## Tests

`QuizProvider` accepts an optional review recorder (it receives a `ReviewEvent`), random generator, clock and `DeckBuilder`, so the session logic is tested without a database: [`test/quiz_provider_test.dart`](../test/quiz_provider_test.dart) covers Review Later (re-queuing, random position, never immediately next, first-try scoring), no-limit sessions (rounds, no repeats across rounds, Finish), multiple-choice scoring and the persisted session size. [`test/widget_test.dart`](../test/widget_test.dart) covers the model, deck non-repetition, the Pass queue and import/export. Deck selection is covered by `test/deck_builder_test.dart` (seeded `Random`, fake clock, 15k-word timing test), event recording and the 7 → 8 migration by `test/stats_db_test.dart`, aggregation by `test/stats_repository_test.dart` and the Statistics layout by `test/stats_screen_test.dart`. Run everything with `flutter test`.
