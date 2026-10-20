import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/vocabulary.dart';
import '../services/database_helper.dart';

enum QuizModule {
  pinyinToHanziAndMeaning,
  hanziToPinyinAndMeaning,
  hanziToMeaning,
  zhuyinByHanzi,
  hanziByZhuyin,
}

enum QuizAnswerMode { multipleChoice, essay }

typedef ReviewRecorder = Future<void> Function(int vocabId, bool correct);

class QuizProvider extends ChangeNotifier {
  QuizProvider({ReviewRecorder? recordReview, Random? random})
    : _recordReview =
          recordReview ?? DatabaseHelper.instance.updateReviewStats,
      _rng = random ?? Random();

  /// Words loaded for a "no limit" session; the pool is replayed in rounds.
  static const endlessPoolSize = 1000;

  final ReviewRecorder _recordReview;
  final Random _rng;

  QuizModule _module = QuizModule.pinyinToHanziAndMeaning;
  QuizModule get module => _module;
  QuizAnswerMode _answerMode = QuizAnswerMode.multipleChoice;
  QuizAnswerMode get answerMode => _answerMode;
  List<Vocabulary> _allVocabs = [];
  List<Vocabulary> _remaining = [];
  List<Vocabulary> _reviewLater = [];
  final Set<Vocabulary> _attempted = Set<Vocabulary>.identity();
  Vocabulary? _current;
  Vocabulary? get current => _current;
  List<Vocabulary> _options = [];
  List<Vocabulary> get options => _options;
  int? _selectedIndex;
  int? get selectedIndex => _selectedIndex;
  bool _answered = false;
  bool get answered => _answered;
  bool _revealed = false;
  bool get revealed => _revealed;
  bool _requeueCurrent = false;
  int _completedCount = 0;
  int get completedCount => _completedCount;
  int _roundCompleted = 0;
  int _round = 1;
  int get round => _round;
  int _score = 0;

  /// Words answered correctly on their first attempt (per round in a
  /// no-limit session).
  int get score => _score;
  bool _endless = false;

  /// True when the session has no question limit and only ends on request.
  bool get isEndless => _endless;
  bool _quizFinished = false;
  bool get quizFinished => _quizFinished;
  int get remainingCount => _remaining.length;

  /// Words deferred with Pass; they return once the main deck runs out.
  int get reviewLaterCount => _reviewLater.length;
  int get totalCount => _allVocabs.length;
  double get progressFraction {
    if (_allVocabs.isEmpty) return 0.0;
    final done = _endless ? _roundCompleted : _completedCount;
    return (done / _allVocabs.length).clamp(0.0, 1.0);
  }

  bool get hasCurrent => _current != null;

  // Track current quiz source for reference
  String? _currentCategory;
  int? _currentLibraryId;
  String? get currentCategory => _currentCategory;
  int? get currentLibraryId => _currentLibraryId;

  String get questionText {
    final current = _current;
    if (current == null) return '';
    return switch (_module) {
      QuizModule.pinyinToHanziAndMeaning => current.displayPronunciation,
      QuizModule.hanziByZhuyin =>
        current.zhuyin ?? current.displayPronunciation,
      QuizModule.hanziToPinyinAndMeaning ||
      QuizModule.hanziToMeaning ||
      QuizModule.zhuyinByHanzi => current.displayHanzi,
    };
  }

  String get answerText {
    final current = _current;
    if (current == null) return '';
    return switch (_module) {
      QuizModule.pinyinToHanziAndMeaning =>
        '${current.displayHanzi}\n${current.meaning}',
      QuizModule.hanziToPinyinAndMeaning =>
        '${current.displayPronunciation}\n${current.displayMeaning}',
      QuizModule.hanziToMeaning => current.displayMeaning,
      QuizModule.zhuyinByHanzi =>
        '${current.zhuyin ?? current.displayPronunciation}\n${current.displayMeaning}',
      QuizModule.hanziByZhuyin =>
        '${current.displayHanzi}\n${current.displayMeaning}',
    };
  }

  String optionText(Vocabulary vocab) => switch (_module) {
    QuizModule.pinyinToHanziAndMeaning =>
      '${vocab.displayHanzi}  —  ${vocab.displayMeaning}',
    QuizModule.hanziToPinyinAndMeaning =>
      '${vocab.displayPronunciation}  —  ${vocab.displayMeaning}',
    QuizModule.hanziToMeaning => vocab.displayMeaning,
    QuizModule.zhuyinByHanzi =>
      '${vocab.zhuyin ?? vocab.displayPronunciation}  —  ${vocab.displayMeaning}',
    QuizModule.hanziByZhuyin =>
      '${vocab.displayHanzi}  —  ${vocab.displayMeaning}',
  };

  /// Starts a session from a TOCFL category. A `null` [sessionSize] means
  /// "no limit".
  Future<void> startQuiz({
    required String category,
    required QuizModule module,
    required QuizAnswerMode answerMode,
    int? sessionSize = 20,
  }) async {
    _currentCategory = category;
    _currentLibraryId = null;
    final vocabs = await DatabaseHelper.instance.getQuizVocabulary(
      category: category,
      limit: sessionSize ?? endlessPoolSize,
    );
    _initQuiz(
      vocabs,
      module: module,
      answerMode: answerMode,
      sessionSize: sessionSize,
    );
  }

  Future<void> startQuizFromLibrary({
    required int libraryId,
    required QuizModule module,
    required QuizAnswerMode answerMode,
    int? sessionSize = 20,
  }) async {
    _currentCategory = null;
    _currentLibraryId = libraryId;
    final vocabs = await DatabaseHelper.instance.getQuizVocabularyFromLibrary(
      libraryId: libraryId,
      limit: sessionSize ?? endlessPoolSize,
    );
    _initQuiz(
      vocabs,
      module: module,
      answerMode: answerMode,
      sessionSize: sessionSize,
    );
  }

  void startNewQuiz(
    List<Vocabulary> vocabs, {
    required QuizModule module,
    required QuizAnswerMode answerMode,
    int? sessionSize = 20,
  }) {
    _currentCategory = null;
    _currentLibraryId = null;
    _initQuiz(
      vocabs,
      module: module,
      answerMode: answerMode,
      sessionSize: sessionSize,
    );
  }

  void _initQuiz(
    List<Vocabulary> vocabs, {
    required QuizModule module,
    required QuizAnswerMode answerMode,
    required int? sessionSize,
  }) {
    _module = module;
    _answerMode = answerMode;
    _endless = sessionSize == null;
    final shuffled = List<Vocabulary>.from(vocabs)..shuffle(_rng);
    _allVocabs = shuffled.take(sessionSize ?? endlessPoolSize).toList();
    _remaining = List<Vocabulary>.from(_allVocabs)..shuffle(_rng);
    _reviewLater = [];
    _attempted.clear();
    _current = null;
    _options = [];
    _selectedIndex = null;
    _answered = false;
    _revealed = false;
    _requeueCurrent = false;
    _completedCount = 0;
    _roundCompleted = 0;
    _round = 1;
    _score = 0;
    _quizFinished = false;
    _advance();
  }

  void _registerOutcome(bool correct) {
    final firstAttempt = _attempted.add(_current!);
    if (correct && firstAttempt) _score++;
  }

  Future<bool> checkAnswer(int index) async {
    if (_answered ||
        _current == null ||
        _current!.id == null ||
        index < 0 ||
        index >= _options.length) {
      return false;
    }
    _selectedIndex = index;
    _answered = true;
    final correct = identical(_options[index], _current);
    _registerOutcome(correct);
    await _recordReview(_current!.id!, correct);
    notifyListeners();
    return correct;
  }

  void revealAnswer() {
    if (_current == null || _answered) return;
    _revealed = true;
    notifyListeners();
  }

  Future<void> markTimedOut() async {
    if (_current == null || _current!.id == null || _answered) return;
    _answered = true;
    _revealed = true;
    _registerOutcome(false);
    await _recordReview(_current!.id!, false);
    notifyListeners();
  }

  Future<void> selfEvaluate(bool correct) async {
    if (_current == null || _current!.id == null || _answered || !_revealed) {
      return;
    }
    _answered = true;
    _registerOutcome(correct);
    await _recordReview(_current!.id!, correct);
    notifyListeners();
  }

  /// Flashcard "Review Later": the miss is saved, but the word is not
  /// completed. On [nextQuestion] it is put back at a random position among
  /// the questions that have not been asked yet.
  Future<void> reviewLater() async {
    final current = _current;
    if (current == null || _answered || !_revealed) return;
    _answered = true;
    _requeueCurrent = true;
    _registerOutcome(false);
    if (current.id != null) await _recordReview(current.id!, false);
    notifyListeners();
  }

  void nextQuestion() {
    if (!_answered) return;
    final current = _current;
    if (_requeueCurrent && current != null) {
      _requeueCurrent = false;
      _reinsertRandomly(current);
    } else {
      _completedCount++;
      _roundCompleted++;
    }
    _advance();
  }

  void passQuestion() {
    final current = _current;
    if (current == null || _answered) return;
    _reviewLater.add(current);
    _advance();
  }

  /// Ends the session and shows its summary (used by "no limit" sessions).
  void finishSession() {
    if (_quizFinished) return;
    _current = null;
    _options = [];
    _selectedIndex = null;
    _answered = false;
    _revealed = false;
    _requeueCurrent = false;
    _quizFinished = true;
    notifyListeners();
  }

  // `_remaining` is a stack: the next question is its last element.
  void _reinsertRandomly(Vocabulary word) {
    if (_remaining.isEmpty && _reviewLater.isNotEmpty) {
      _remaining = List<Vocabulary>.from(_reviewLater);
      _reviewLater = [];
    }
    if (_remaining.isEmpty) {
      _remaining.add(word);
      return;
    }
    // An index below the last element guarantees another word comes first.
    _remaining.insert(_rng.nextInt(_remaining.length), word);
  }

  void _startNextRound() {
    _round++;
    _roundCompleted = 0;
    _attempted.clear();
    _remaining = List<Vocabulary>.from(_allVocabs)..shuffle(_rng);
    final previous = _current;
    if (_remaining.length > 1 &&
        previous != null &&
        identical(_remaining.last, previous)) {
      final swapWith = _rng.nextInt(_remaining.length - 1);
      final moved = _remaining[swapWith];
      _remaining[swapWith] = _remaining.last;
      _remaining[_remaining.length - 1] = moved;
    }
  }

  void _advance() {
    if (_remaining.isEmpty && _reviewLater.isNotEmpty) {
      _remaining = List<Vocabulary>.from(_reviewLater);
      _reviewLater = [];
    }
    if (_remaining.isEmpty && _endless && _allVocabs.isNotEmpty) {
      _startNextRound();
    }
    if (_remaining.isEmpty) {
      _current = null;
      _options = [];
      _quizFinished = true;
      notifyListeners();
      return;
    }
    _current = _remaining.removeLast();
    _options = [];
    _selectedIndex = null;
    _answered = false;
    _revealed = false;
    _requeueCurrent = false;
    if (_answerMode == QuizAnswerMode.multipleChoice) {
      final pool = List<Vocabulary>.from(_allVocabs)..remove(_current);
      pool.shuffle(_rng);
      _options = [_current!, ...pool.take(3)]..shuffle(_rng);
    }
    notifyListeners();
  }

  int correctIndex() => _current == null ? -1 : _options.indexOf(_current!);
}
