/// Simple Leitner schedule used for per-word progress.
///
/// Box 0 is "due now" (new or just missed). A correct first answer on a due
/// word moves it up one box; a miss always sends it back to box 0.
class Leitner {
  Leitner._();

  /// Days until the next review, indexed by box.
  static const intervalDays = [0, 1, 3, 7, 14, 30];

  static const maxBox = 5;

  /// A word in this box or higher counts as mastered.
  static const masteredBox = 4;

  /// Boxes at or below this are treated as weak when due.
  static const weakMaxBox = 1;

  static int dueAfter(int box, int nowMs) =>
      nowMs + Duration(days: intervalDays[box]).inMilliseconds;

  /// State after a first-attempt answer.
  ///
  /// A correct answer only promotes the word when it was due; reviewing a
  /// word early is recorded but does not climb the boxes.
  static ({int box, int nextDue, int wrongStreak}) next({
    required int? box,
    required int? nextDue,
    required int wrongStreak,
    required bool correct,
    required int nowMs,
  }) {
    if (!correct) {
      return (box: 0, nextDue: nowMs, wrongStreak: wrongStreak + 1);
    }
    final wasDue = nextDue == null || nextDue <= nowMs;
    if (!wasDue) {
      return (box: box ?? 0, nextDue: nextDue, wrongStreak: 0);
    }
    final newBox = ((box ?? 0) + 1).clamp(0, maxBox);
    return (box: newBox, nextDue: dueAfter(newBox, nowMs), wrongStreak: 0);
  }
}
