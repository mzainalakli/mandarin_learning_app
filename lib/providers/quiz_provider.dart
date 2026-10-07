import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/vocabulary.dart';
import '../services/database_helper.dart';

enum QuizModule {
  pinyinToHanziAndMeaning,
  hanziToPinyinAndMeaning,
  hanziToMeaning,
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

  String get questionText {
    final current = _current;
    if (current == null) return '';
    return switch (_module) {
      QuizModule.pinyinToHanziAndMeaning => current.displayPronunciation,
      QuizModule.hanziToPinyinAndMeaning ||
      QuizModule.hanziToMeaning => current.displayHanzi,
    };
  }

  String get answerText {
    final current = _current;
    if (current == null) return '';
    return switch (_module) {
      QuizModule.pinyinToHanziAndMeaning =>
        '${current.displayHanzi}\n${current.meaning}',
      QuizModule.hanziToPinyinAndMeaning =>
        '${current.displayPronunciation}\n${current.meaning}',
      QuizModule.hanziToMeaning => current.meaning,
    };
  }

  String optionText(Vocabulary vocab) => switch (_module) {
    QuizModule.pinyinToHanziAndMeaning =>
      '${vocab.displayHanzi}  —  ${vocab.meaning}',
    QuizModule.hanziToPinyinAndMeaning =>
      '${vocab.displayPronunciation}  —  ${vocab.meaning}',
    QuizModule.hanziToMeaning => vocab.meaning,
  };

  void startNewQuiz(
    List<Vocabulary> vocabs, {
    required QuizModule module,
    required QuizAnswerMode answerMode,
  }) {
    _module = module;
    _answerMode = answerMode;
    _allVocabs = List<Vocabulary>.from(vocabs);
    _remaining = List<Vocabulary>.from(vocabs)..shuffle(_rng);
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
