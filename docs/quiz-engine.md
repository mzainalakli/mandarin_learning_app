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
| `hanziByZhuyin` | Hanzi | Hanzi + meaning | `Hanzi — meaning` | Zhuyin → Hanzi |

"Hanzi" always means the **Traditional** form when one exists (`Vocabulary.displayHanzi`), otherwise the simplified `hanzi` column.

> `hanziByZhuyin` is described as "see Zhuyin, recall Hanzi", but the prompt card currently displays the Hanzi for every module except `pinyinToHanziAndMeaning`. See [Known issues](known-issues.md#zhuyin-prompt-modes-show-hanzi-as-the-prompt).

The three Pinyin/Hanzi/Meaning modules are launched from the Dashboard; the two Zhuyin modules from Bopomofo Training.

## Answer modes

`QuizAnswerMode` is `multipleChoice` or `essay` (flashcard).

- **Multiple choice** builds four options per question: the correct word plus three distractors drawn at random from the *other words in the same session*. The options are shuffled. A session therefore needs at least **4 words**; with fewer, the screen shows "Multiple choice needs at least 4 vocabulary words."
- **Essay / flashcard** has no options. The learner reveals the answer and self-grades.

## Building a session

1. A start method loads candidate words from the database:
   - `startQuiz(category, …)` → `DatabaseHelper.getQuizVocabulary` — random order, `LIMIT sessionSize`.
   - `startQuizFromLibrary(libraryId, …)` → `getQuizVocabularyFromLibrary` — random order, `LIMIT sessionSize`.
   - `startNewQuiz(vocabs, …)` — uses an in-memory list (used by the unit tests).
2. The list is shuffled and trimmed to `sessionSize` (10, 20, 50 or 100; default 20). This is the session's **deck** (`totalCount`).
3. The deck is shuffled again into the `remaining` queue; the `reviewLater` queue starts empty and counters reset.
4. The first question is drawn.

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
                    ├─ remaining empty AND reviewLater not empty → move reviewLater into remaining
                    ├─ both empty → quizFinished = true
                    └─ otherwise → current = remaining.removeLast(), build options (multiple choice)
```

A question is *answered* when the learner selects an option (`checkAnswer`), self-grades (`selfEvaluate`), or the timer expires in multiple-choice mode (`markTimedOut`). `nextQuestion()` then increments `completedCount` and advances. In the UI, all three paths auto-advance after 700 ms.

### Pass, Review Later and Got It

| Action | Effect on the session | Effect on saved statistics |
|---|---|---|
| **Pass** | Word goes to the `reviewLater` queue and returns once the main deck is empty. Not allowed after the question has been answered. | none |
| **Got It** (flashcard) | Counts as answered and correct (`score++`). | `reviewCount + 1`, `correctCount + 1` |
| **Review Later** (flashcard) | Counts as answered and **incorrect**; the word is **not** re-queued. | `reviewCount + 1` |
| Correct option (multiple choice) | `score++` | `reviewCount + 1`, `correctCount + 1` |
| Wrong option (multiple choice) | answered, no score | `reviewCount + 1` |
| Timeout (multiple choice) | answered, no score, answer shown | `reviewCount + 1` |

Because every deck word is served exactly once (plus once more per Pass), a word never appears twice in a row unless it is the only one left in the pass queue.

## Timer

- Controlled by `SettingsProvider` (`isTimerEnabled`, `timerDurationSeconds` in the range 5–60, default 10 s). The presets on the configuration screens set 10, 20 or 30 s; the Settings slider allows any value from 5 to 60 in 5-second steps.
- A one-second periodic timer restarts for each new question (including after Pass).
- On expiry: in multiple-choice mode the question is marked timed out (incorrect) and the quiz advances; in flashcard mode the answer is revealed.
- The timer is cancelled as soon as the learner answers, passes or leaves.

## Scoring and persistence

- In-session: `score` (correct answers), `completedCount` (answered words), `progressFraction = completedCount / totalCount`.
- The finish card reports `Correct <score> of <completedCount>` and `You reviewed <totalCount> words in total.`
- Persistent: `DatabaseHelper.updateReviewStats(id, correct)` adds one to `reviewCount`, adds one to `correctCount` if correct, and stores `lastReviewed` as an ISO-8601 timestamp. Words without a database id (`id == null`) are never scored.
- `Vocabulary.accuracy` is `correctCount / reviewCount` (0 when never reviewed). It is shown in the word detail sheet.

## Text-to-speech

`TtsService` (`flutter_tts`) is a singleton initialised lazily on first use: language `zh-TW`, speech rate 0.45, volume 1.0, pitch 1.0. On Android it selects the Google TTS engine (`com.google.android.tts`), so that engine and a Chinese voice must be installed on the device. The Speak button always speaks the word's Hanzi.

## Tests

`test/widget_test.dart` covers: Traditional/Zhuyin fallback in `Vocabulary`; non-repetition of a session deck; that a passed word returns only after the remaining words; CSV import with BOM and mixed-case headers; and the Excel template. Run them with `flutter test`.
