/// How a recorded answer came about.
enum ReviewOutcome {
  /// A normal answer (multiple choice, or Got It in flashcard mode).
  answer,

  /// The timer ran out; counted as a miss.
  timeout,

  /// Flashcard "Review Later"; counted as a miss, the word comes back.
  reviewLater,
}

/// Calendar day of [time] in the device's local zone as `yyyymmdd`.
int dayKeyOf(DateTime time) {
  final local = time.toLocal();
  return local.year * 10000 + local.month * 100 + local.day;
}

/// One real answer given in a quiz. "Pass" is not an answer and is never
/// recorded.
class ReviewEvent {
  const ReviewEvent({
    required this.vocabId,
    required this.timestamp,
    required this.module,
    required this.mode,
    required this.correct,
    required this.isFirstAttempt,
    required this.sessionId,
    this.responseMs,
    this.outcome = ReviewOutcome.answer,
  });

  final int vocabId;

  /// When the answer was given. Stored as epoch ms (UTC); the local calendar
  /// day is derived from it.
  final DateTime timestamp;

  /// `QuizModule` name.
  final String module;

  /// `choice` or `essay`.
  final String mode;
  final bool correct;

  /// First answer for this word in the session (per round when endless).
  /// Only first attempts change accuracy and the Leitner schedule.
  final bool isFirstAttempt;
  final int sessionId;
  final int? responseMs;
  final ReviewOutcome outcome;

  static const modeChoice = 'choice';
  static const modeEssay = 'essay';

  int get day => dayKeyOf(timestamp);

  Map<String, Object?> toMap() => {
    'vocab_id': vocabId,
    'ts': timestamp.toUtc().millisecondsSinceEpoch,
    'day': day,
    'module': module,
    'mode': mode,
    'correct': correct ? 1 : 0,
    'is_first_attempt': isFirstAttempt ? 1 : 0,
    'session_id': sessionId,
    'response_ms': responseMs,
    'outcome': switch (outcome) {
      ReviewOutcome.answer => 'answer',
      ReviewOutcome.timeout => 'timeout',
      ReviewOutcome.reviewLater => 'review_later',
    },
  };
}
