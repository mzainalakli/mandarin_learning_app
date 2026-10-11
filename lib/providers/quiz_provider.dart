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

class QuizProvider extends ChangeNotifier {
  final _rng = Random();
  QuizModule _module = QuizModule.pinyinToHanziAndMeaning;
  QuizModule get module => _module;
  QuizAnswerMode _answerMode = QuizAnswerMode.multipleChoice;
  QuizAnswerMode get answerMode => _answerMode;
  List<Vocabulary> _allVocabs = [];
  List<Vocabulary> _remaining = [];
  List<Vocabulary> _reviewLater = [];
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
  int _completedCount = 0;
  int get completedCount => _completedCount;
  int _score = 0;
  int get score => _score;
  bool _quizFinished = false;
  bool get quizFinished => _quizFinished;
  int get remainingCount => _remaining.length;
  int get reviewLaterCount => _reviewLater.length;
  int get totalCount => _allVocabs.length;
  double get progressFraction =>
      _allVocabs.isEmpty ? 0.0 : _completedCount / _allVocabs.length;
  bool get hasCurrent => _current != null;

  String get questionText {
    final current = _current;
    if (current == null) return '';
    return switch (_module) {
      QuizModule.pinyinToHanziAndMeaning => current.displayPronunciation,
      QuizModule.hanziToPinyinAndMeaning ||
      QuizModule.hanziToMeaning ||
      QuizModule.zhuyinByHanzi ||
      QuizModule.hanziByZhuyin => current.displayHanzi,
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

  Future<void> startQuiz({
    required String category,
    required QuizModule module,
    required QuizAnswerMode answerMode,
    int sessionSize = 20,
  }) async {
    final vocabs = await DatabaseHelper.instance.getQuizVocabulary(
      category: category,
      limit: sessionSize,
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
    int sessionSize = 20,
  }) {
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
    int sessionSize = 20,
  }) {
    _module = module;
    _answerMode = answerMode;
    final shuffled = List<Vocabulary>.from(vocabs)..shuffle(_rng);
    _allVocabs = shuffled.take(sessionSize).toList();
    _remaining = List<Vocabulary>.from(_allVocabs)..shuffle(_rng);
    _reviewLater = [];
    _current = null;
    _options = [];
    _selectedIndex = null;
    _answered = false;
    _revealed = false;
    _completedCount = 0;
    _score = 0;
    _quizFinished = false;
    _advance();
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
    if (correct) _score++;
    await DatabaseHelper.instance.updateReviewStats(_current!.id!, correct);
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
    await DatabaseHelper.instance.updateReviewStats(_current!.id!, false);
    notifyListeners();
  }

  Future<void> selfEvaluate(bool correct) async {
    if (_current == null || _current!.id == null || _answered || !_revealed) {
      return;
    }
    _answered = true;
    if (correct) _score++;
    await DatabaseHelper.instance.updateReviewStats(_current!.id!, correct);
    notifyListeners();
  }

  void nextQuestion() {
    if (!_answered) return;
    _completedCount++;
    _advance();
  }

  void passQuestion() {
    final current = _current;
    if (current == null || _answered) return;
    _reviewLater.add(current);
    _advance();
  }

  void _advance() {
    if (_remaining.isEmpty && _reviewLater.isNotEmpty) {
      _remaining = List<Vocabulary>.from(_reviewLater);
      _reviewLater = [];
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
    if (_answerMode == QuizAnswerMode.multipleChoice) {
      final pool = List<Vocabulary>.from(_allVocabs)..remove(_current);
      pool.shuffle(_rng);
      _options = [_current!, ...pool.take(3)]..shuffle(_rng);
    }
    notifyListeners();
  }

  int correctIndex() => _current == null ? -1 : _options.indexOf(_current!);
}
