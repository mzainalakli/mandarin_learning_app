import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/vocab_provider.dart';
import '../services/tts_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.module, required this.answerMode});

  final QuizModule module;
  final QuizAnswerMode answerMode;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Timer? _timer;
  bool _loaded = false;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final vocab = context.read<VocabProvider>();
    await vocab.loadVocabs();
    if (!mounted) return;
    context.read<QuizProvider>().startNewQuiz(
      vocab.vocabs,
      module: widget.module,
      answerMode: widget.answerMode,
    );
    _startTimer();
    setState(() => _loaded = true);
  }

  void _startTimer() {
    _timer?.cancel();
    final settings = context.read<SettingsProvider>();
    final quiz = context.read<QuizProvider>();
    if (!settings.isTimerEnabled || quiz.current == null) return;
    setState(() => _remainingSeconds = settings.timerDurationSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return timer.cancel();
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (widget.answerMode == QuizAnswerMode.multipleChoice) {
          await context.read<QuizProvider>().markTimedOut();
        } else {
          context.read<QuizProvider>().revealAnswer();
        }
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _next() {
    context.read<QuizProvider>().nextQuestion();
    _startTimer();
  }

  void _pass() {
    _timer?.cancel();
    context.read<QuizProvider>().passQuestion();
    _startTimer();
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave quiz?'),
        content: const Text(
          'Answered words are saved. Unanswered session progress will end.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _timer?.cancel();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final vocab = context.watch<VocabProvider>();
    final settings = context.watch<SettingsProvider>();
    final needsFourWords =
        widget.answerMode == QuizAnswerMode.multipleChoice &&
        vocab.vocabs.length < 4;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title(widget.module)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Leave quiz',
            onPressed: _leave,
          ),
          actions: [
            if (quiz.current != null)
              IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: 'Pronounce',
                onPressed: () =>
                    TtsService.instance.speak(quiz.current!.displayHanzi),
              ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : needsFourWords
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Multiple choice needs at least 4 vocabulary words.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : vocab.vocabs.isEmpty
            ? const Center(
                child: Text('Add vocabulary before starting a quiz.'),
              )
            : quiz.quizFinished
            ? _finished(quiz)
            : _question(quiz, settings),
      ),
    );
  }

  Widget _finished(QuizProvider quiz) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Session Complete!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Correct: ${quiz.score} / ${quiz.completedCount}',
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to modes'),
          ),
        ],
      ),
    ),
  );

  Widget _question(QuizProvider quiz, SettingsProvider settings) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Completed: ${quiz.completedCount}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  'Score: ${quiz.score}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (settings.isTimerEnabled) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _remainingSeconds / settings.timerDurationSeconds,
              ),
              const SizedBox(height: 4),
              Text('$_remainingSeconds seconds'),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: GestureDetector(
                  onTap: () =>
                      TtsService.instance.speak(quiz.current!.displayHanzi),
                  child: Text(
                    quiz.questionText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:
                          widget.module == QuizModule.pinyinToHanziAndMeaning
                          ? 32
                          : 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: quiz.answered ? null : _pass,
              icon: const Icon(Icons.skip_next),
              label: const Text('Pass'),
            ),
            const SizedBox(height: 16),
            if (widget.answerMode == QuizAnswerMode.multipleChoice) ...[
              ...List.generate(
                quiz.options.length,
                (index) => _OptionButton(
                  text: quiz.optionText(quiz.options[index]),
                  answered: quiz.answered,
                  isCorrect: index == quiz.correctIndex(),
                  isSelected: index == quiz.selectedIndex,
                  onTap: () =>
                      quiz.checkAnswer(index).then((_) => _timer?.cancel()),
                ),
              ),
            ] else ...[
              if (quiz.revealed)
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      quiz.answerText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              if (!quiz.revealed)
                FilledButton(
                  onPressed: () {
                    _timer?.cancel();
                    quiz.revealAnswer();
                  },
                  child: const Text('Show Answer'),
                )
              else if (!quiz.answered)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => quiz.selfEvaluate(false),
                        child: const Text('Need practice'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => quiz.selfEvaluate(true),
                        child: const Text('Got it right'),
                      ),
                    ),
                  ],
                ),
            ],
            if (quiz.answered)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
              ),
          ],
        ),
      );

  String _title(QuizModule module) => switch (module) {
    QuizModule.pinyinToHanziAndMeaning => 'Pinyin → Hanzi',
    QuizModule.hanziToPinyinAndMeaning => 'Hanzi → Pronunciation',
    QuizModule.hanziToMeaning => 'Hanzi → Meaning',
  };
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.text,
    required this.answered,
    required this.isCorrect,
    required this.isSelected,
    required this.onTap,
  });
  final String text;
  final bool answered;
  final bool isCorrect;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !answered
        ? null
        : isCorrect
        ? Colors.green.shade100
        : isSelected
        ? Colors.red.shade100
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: answered ? null : onTap,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
