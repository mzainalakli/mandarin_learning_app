import 'package:flutter/foundation.dart';

import '../models/stats_snapshot.dart';
import '../services/stats_repository.dart';

typedef StatsLoader = Future<StatsSnapshot> Function(StatsRange range);

/// Holds the statistics shown on the Statistics screen.
class StatsProvider extends ChangeNotifier {
  StatsProvider({StatsLoader? loader})
    : _loader = loader ?? StatsRepository().load;

  final StatsLoader _loader;

  StatsRange _range = StatsRange.week;
  StatsRange get range => _range;
  StatsSnapshot? _snapshot;
  StatsSnapshot? get snapshot => _snapshot;
  bool _loading = false;
  bool get loading => _loading;
  Object? _error;
  Object? get error => _error;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _loader(_range);
      if (generation != _generation) return;
      _snapshot = snapshot;
    } catch (e) {
      if (generation != _generation) return;
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> setRange(StatsRange range) {
    if (range == _range) return Future.value();
    _range = range;
    return load();
  }
}
