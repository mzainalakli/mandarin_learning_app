import 'package:sqflite/sqflite.dart';

import '../models/review_event.dart';
import '../models/stats_snapshot.dart';
import '../models/vocabulary.dart';
import 'database_helper.dart';
import 'leitner.dart';

/// Read-only statistics queries. Days are the device's local calendar days
/// (stored as `review_events.day`); "now" is injectable for tests.
class StatsRepository {
  StatsRepository({DatabaseHelper? db, DateTime Function()? now})
    : _db = db ?? DatabaseHelper.instance,
      _now = now ?? DateTime.now;

  final DatabaseHelper _db;
  final DateTime Function() _now;

  /// Entries in the "most missed words" list.
  static const mostMissedLimit = 20;

  /// Days compared for the accuracy trend (this window vs the one before).
  static const comparisonDays = 7;

  /// Most distinct days scanned when counting the streak.
  static const streakScanLimit = 3660;

  static DateTime _dateOfKey(int key) =>
      DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  Future<StatsSummary> loadSummary() async {
    final db = await _db.database;
    final today = _now();
    return StatsSummary(
      streakDays: await _streak(db, today),
      answersToday: await _countWhere(db, 'day = ?', [dayKeyOf(today)]),
      weakWords: await _db.getWeakWordCount(),
    );
  }

  Future<StatsSnapshot> load(StatsRange range) async {
    final db = await _db.database;
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);

    final totalEvents = await _countWhere(db, '1 = 1', []);
    if (totalEvents == 0) return StatsSnapshot.empty(range);

    final windowDays = range.days > comparisonDays * 2
        ? range.days
        : comparisonDays * 2;
    final first = _addDays(today, -(windowDays - 1));
    final rows = await db.rawQuery(
      '''
      SELECT day, COUNT(*) AS answers,
             SUM(is_first_attempt) AS fa,
             SUM(is_first_attempt * correct) AS fc
      FROM review_events WHERE day BETWEEN ? AND ? GROUP BY day
    ''',
      [dayKeyOf(first), dayKeyOf(today)],
    );
    final perDay = {
      for (final r in rows)
        r['day'] as int: (
          answers: r['answers'] as int,
          fa: (r['fa'] as int?) ?? 0,
          fc: (r['fc'] as int?) ?? 0,
        ),
    };

    double? accuracy(int fromOffset, int toOffset) {
      var fa = 0;
      var fc = 0;
      for (var i = fromOffset; i <= toOffset; i++) {
        final d = perDay[dayKeyOf(_addDays(today, -i))];
        if (d == null) continue;
        fa += d.fa;
        fc += d.fc;
      }
      return fa == 0 ? null : fc / fa;
    }

    return StatsSnapshot(
      range: range,
      totalEvents: totalEvents,
      learnedWords: await _scalar(db, 'SELECT COUNT(*) FROM vocab_progress'),
      masteredWords: await _scalar(
        db,
        'SELECT COUNT(*) FROM vocab_progress WHERE box >= ${Leitner.masteredBox}',
      ),
      accuracyLast7: accuracy(0, comparisonDays - 1),
      accuracyPrevious7: accuracy(comparisonDays, comparisonDays * 2 - 1),
      streakDays: await _streak(db, now),
      answersToday: perDay[dayKeyOf(today)]?.answers ?? 0,
      trend: _buckets(range, today, perDay),
      modules: await _modules(db),
      levels: await _levels(db),
      mostMissed: await _mostMissed(db),
    );
  }

  List<TrendBucket> _buckets(
    StatsRange range,
    DateTime today,
    Map<int, ({int answers, int fa, int fc})> perDay,
  ) {
    final sums = <DateTime, List<int>>{};
    for (var i = range.days - 1; i >= 0; i--) {
      final date = _addDays(today, -i);
      final start = range.weekly
          ? _addDays(date, -(date.weekday - DateTime.monday))
          : date;
      final sum = sums.putIfAbsent(start, () => [0, 0, 0]);
      final d = perDay[dayKeyOf(date)];
      if (d == null) continue;
      sum[0] += d.answers;
      sum[1] += d.fa;
      sum[2] += d.fc;
    }
    return [
      for (final e in sums.entries)
        TrendBucket(
          start: e.key,
          answers: e.value[0],
          firstAttempts: e.value[1],
          firstCorrect: e.value[2],
        ),
    ];
  }

  Future<int> _streak(Database db, DateTime now) async {
    final rows = await db.rawQuery(
      'SELECT DISTINCT day FROM review_events ORDER BY day DESC LIMIT ?',
      [streakScanLimit],
    );
    if (rows.isEmpty) return 0;
    final days = [for (final r in rows) r['day'] as int];
    final today = DateTime(now.year, now.month, now.day);
    // A streak survives until the day ends: no answer yet today is fine.
    var expected = days.first == dayKeyOf(today) ? today : _addDays(today, -1);
    var streak = 0;
    for (final key in days) {
      if (key != dayKeyOf(expected)) break;
      streak++;
      expected = _addDays(_dateOfKey(key), -1);
    }
    return streak;
  }

  Future<List<ModuleStat>> _modules(Database db) async {
    final rows = await db.rawQuery('''
      SELECT module, COUNT(*) AS answers,
             SUM(is_first_attempt) AS fa,
             SUM(is_first_attempt * correct) AS fc
      FROM review_events GROUP BY module ORDER BY answers DESC
    ''');
    return [
      for (final r in rows)
        ModuleStat(
          module: r['module'] as String,
          answers: r['answers'] as int,
          firstAttempts: (r['fa'] as int?) ?? 0,
          firstCorrect: (r['fc'] as int?) ?? 0,
        ),
    ];
  }

  Future<List<LevelStat>> _levels(Database db) async {
    final rows = await db.rawQuery(
      '''
      SELECT v.category AS category, COUNT(*) AS total,
             SUM(CASE WHEN p.box >= ? THEN 1 ELSE 0 END) AS mastered,
             COALESCE(SUM(p.first_attempts), 0) AS fa,
             COALESCE(SUM(p.first_correct), 0) AS fc
      FROM vocabularies v
      LEFT JOIN vocab_progress p ON p.vocab_id = v.id
      GROUP BY v.category
    ''',
      [Leitner.masteredBox],
    );
    final levels = [
      for (final r in rows)
        LevelStat(
          category: r['category'] as String,
          totalWords: r['total'] as int,
          masteredWords: (r['mastered'] as int?) ?? 0,
          firstAttempts: r['fa'] as int,
          firstCorrect: r['fc'] as int,
        ),
    ];
    int rank(String c) {
      final i = Vocabulary.tocflCategories.indexOf(c);
      return i < 0 ? Vocabulary.tocflCategories.length : i;
    }

    return levels..sort((a, b) => rank(a.category).compareTo(rank(b.category)));
  }

  Future<List<MissedWord>> _mostMissed(Database db) async {
    final rows = await db.rawQuery(
      '''
      SELECT v.*, p.first_attempts AS fa, p.first_correct AS fc
      FROM vocab_progress p JOIN vocabularies v ON v.id = p.vocab_id
      WHERE p.first_attempts > p.first_correct
      ORDER BY (p.first_attempts - p.first_correct) DESC,
               p.first_correct * 1.0 / p.first_attempts ASC, v.id
      LIMIT ?
    ''',
      [mostMissedLimit],
    );
    return [
      for (final r in rows)
        MissedWord(
          vocab: Vocabulary.fromMap(r),
          firstAttempts: r['fa'] as int,
          firstCorrect: r['fc'] as int,
        ),
    ];
  }

  Future<int> _countWhere(Database db, String where, List<Object?> args) =>
      _scalar(db, 'SELECT COUNT(*) FROM review_events WHERE $where', args);

  Future<int> _scalar(Database db, String sql, [List<Object?>? args]) async =>
      Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
}
