import 'vocabulary.dart';

/// Length of the trend window shown on the statistics screen.
enum StatsRange {
  week(7, 'Last 7 days'),
  month(30, 'Last 30 days'),
  quarter(90, 'Last 90 days');

  const StatsRange(this.days, this.label);

  final int days;
  final String label;

  /// Long windows are summed per week so the charts stay readable.
  bool get weekly => this == StatsRange.quarter;
}

/// Answers inside one chart bucket (a day, or a week for [StatsRange.quarter]).
class TrendBucket {
  const TrendBucket({
    required this.start,
    required this.answers,
    required this.firstAttempts,
    required this.firstCorrect,
  });

  final DateTime start;

  /// Every real answer, including repeats after Review Later.
  final int answers;

  /// First answers only; these drive accuracy.
  final int firstAttempts;
  final int firstCorrect;

  /// `null` when nothing was answered, so charts show a gap, not zero.
  double? get accuracy =>
      firstAttempts == 0 ? null : firstCorrect / firstAttempts;
}

class ModuleStat {
  const ModuleStat({
    required this.module,
    required this.answers,
    required this.firstAttempts,
    required this.firstCorrect,
  });

  final String module;
  final int answers;
  final int firstAttempts;
  final int firstCorrect;

  double? get accuracy =>
      firstAttempts == 0 ? null : firstCorrect / firstAttempts;
}

class LevelStat {
  const LevelStat({
    required this.category,
    required this.totalWords,
    required this.masteredWords,
    required this.firstAttempts,
    required this.firstCorrect,
  });

  final String category;
  final int totalWords;
  final int masteredWords;
  final int firstAttempts;
  final int firstCorrect;

  double? get accuracy =>
      firstAttempts == 0 ? null : firstCorrect / firstAttempts;
  double get masteredFraction =>
      totalWords == 0 ? 0 : masteredWords / totalWords;
}

class MissedWord {
  const MissedWord({
    required this.vocab,
    required this.firstAttempts,
    required this.firstCorrect,
  });

  final Vocabulary vocab;
  final int firstAttempts;
  final int firstCorrect;

  int get misses => firstAttempts - firstCorrect;
  double get accuracy => firstAttempts == 0 ? 0 : firstCorrect / firstAttempts;
}

/// Everything the statistics screen shows, computed in one pass.
class StatsSnapshot {
  const StatsSnapshot({
    required this.range,
    required this.totalEvents,
    required this.learnedWords,
    required this.masteredWords,
    required this.accuracyLast7,
    required this.accuracyPrevious7,
    required this.streakDays,
    required this.answersToday,
    required this.trend,
    required this.modules,
    required this.levels,
    required this.mostMissed,
  });

  const StatsSnapshot.empty(this.range)
    : totalEvents = 0,
      learnedWords = 0,
      masteredWords = 0,
      accuracyLast7 = null,
      accuracyPrevious7 = null,
      streakDays = 0,
      answersToday = 0,
      trend = const [],
      modules = const [],
      levels = const [],
      mostMissed = const [];

  final StatsRange range;

  /// Recorded answers since tracking started. Zero means "no data yet".
  final int totalEvents;
  final int learnedWords;
  final int masteredWords;

  /// First-attempt accuracy of the last 7 days and of the 7 days before.
  final double? accuracyLast7;
  final double? accuracyPrevious7;
  final int streakDays;
  final int answersToday;
  final List<TrendBucket> trend;
  final List<ModuleStat> modules;
  final List<LevelStat> levels;
  final List<MissedWord> mostMissed;

  bool get hasData => totalEvents > 0;

  /// Change in accuracy versus the previous 7 days, in fraction points.
  double? get accuracyDelta =>
      accuracyLast7 == null || accuracyPrevious7 == null
      ? null
      : accuracyLast7! - accuracyPrevious7!;
}

/// Small numbers for the Dashboard card.
class StatsSummary {
  const StatsSummary({
    required this.streakDays,
    required this.answersToday,
    required this.weakWords,
  });

  const StatsSummary.empty() : streakDays = 0, answersToday = 0, weakWords = 0;

  final int streakDays;
  final int answersToday;
  final int weakWords;
}
