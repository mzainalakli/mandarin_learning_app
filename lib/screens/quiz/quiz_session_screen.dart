import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../models/vocabulary.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/tts_service.dart';
import '../../widgets/custom_app_bar.dart';

class QuizSessionScreen extends StatefulWidget {
  const QuizSessionScreen({
    super.key,
    required this.module,
    required this.answerMode,
    required this.category,
    required this.sessionSize,
  });

  final QuizModule module;
  final QuizAnswerMode answerMode;
  final String category;
  final int sessionSize;

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  Timer? _timer;
  bool _loaded = false;
  int _remainingSeconds = 0;
  bool? _lastAnswerCorrect;
  int _feedbackTick = 0;

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
    final quiz = context.read<QuizProvider>();

    await quiz.startQuiz(
      category: widget.category,
      module: widget.module,
      answerMode: widget.answerMode,
      sessionSize: widget.sessionSize,
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
        if (context.read<SettingsProvider>().isMultipleChoice) {
          await context.read<QuizProvider>().markTimedOut();
          _markFeedback(false);
          _autoAdvance();
        } else {
          context.read<QuizProvider>().revealAnswer();
        }
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _markFeedback(bool correct) {
    setState(() {
      _lastAnswerCorrect = correct;
      _feedbackTick++;
    });
  }

  void _autoAdvance() {
    _timer?.cancel();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _next();
    });
  }

  Future<void> _submitAnswer(int index) async {
    final quiz = context.read<QuizProvider>();
    if (quiz.answered) return;
    _timer?.cancel();
    final correct = await quiz.checkAnswer(index);
    if (!mounted) return;
    _markFeedback(correct);
    _autoAdvance();
  }

  void _next() {
    context.read<QuizProvider>().nextQuestion();
    _lastAnswerCorrect = null;
    _feedbackTick++;
    _startTimer();
  }

  void _pass() {
    _timer?.cancel();
    context.read<QuizProvider>().passQuestion();
    _lastAnswerCorrect = null;
    _feedbackTick++;
    _startTimer();
  }

  Future<void> _evaluateAnswer(bool correct) async {
    final quiz = context.read<QuizProvider>();
    if (!quiz.revealed || quiz.answered) return;
    _timer?.cancel();
    await quiz.selfEvaluate(correct);
    if (!mounted) return;
    _markFeedback(correct);
    _autoAdvance();
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
    final settings = context.watch<SettingsProvider>();
    final bp = Responsive.getBreakpoint(context);
    final isMobile = bp == AppBreakpoint.mobile;
    final needsFourWords = settings.isMultipleChoice && quiz.totalCount < 4;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => !didPop ? _leave() : null,
      child: Scaffold(
        appBar: CustomAppBar(
          title: _title(widget.module),
          actions: [
            if (!isMobile) ...[
              TextButton.icon(
                onPressed: quiz.answered ? null : _pass,
                icon: const Icon(Icons.skip_next),
                label: const Text('Pass'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _leave,
                icon: const Icon(Icons.logout),
                label: const Text('Leave'),
              ),
              const SizedBox(width: 12),
            ] else ...[
              PopupMenuButton<String>(
                onSelected: (value) => value == 'pass' ? _pass() : _leave(),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'pass',
                    child: ListTile(
                      leading: Icon(Icons.skip_next),
                      title: Text('Pass'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'leave',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Leave'),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = Responsive.getContentMaxWidth(context);
            final horizontalPadding = isMobile ? 16.0 : 24.0;
            final content = !_loaded
                ? const Center(child: CircularProgressIndicator())
                : needsFourWords
                ? _buildEmptyState(
                    'Multiple choice needs at least 4 vocabulary words.',
                  )
                : !quiz.hasCurrent
                ? _buildEmptyState('Add vocabulary before starting a quiz.')
                : quiz.quizFinished
                ? _FinishedCard(
                    quiz: quiz,
                    onRestart: () => Navigator.pop(context),
                  )
                : _QuestionView(
                    quiz: quiz,
                    settings: settings,
                    remainingSeconds: _remainingSeconds,
                    module: widget.module,
                    answerMode: widget.answerMode,
                    feedbackTick: _feedbackTick,
                    lastAnswerCorrect: _lastAnswerCorrect,
                    onSpeak: () =>
                        TtsService.instance.speak(quiz.current!.displayHanzi),
                    onSubmit: _submitAnswer,
                    onNext: _next,
                    onPass: _pass,
                    onEvaluate: _evaluateAnswer,
                    onReveal: () => context.read<QuizProvider>().revealAnswer(),
                  );
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: isMobile ? 12 : 16,
                  ),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );

  String _title(QuizModule module) => switch (module) {
    QuizModule.pinyinToHanziAndMeaning => 'Pronunciation → Hanzi',
    QuizModule.hanziToPinyinAndMeaning => 'Hanzi → Pronunciation',
    QuizModule.hanziToMeaning => 'Hanzi → Meaning',
    QuizModule.zhuyinByHanzi => 'Hanzi → Zhuyin',
    QuizModule.hanziByZhuyin => 'Zhuyin → Hanzi',
  };
}

class _FinishedCard extends StatelessWidget {
  const _FinishedCard({required this.quiz, required this.onRestart});
  final QuizProvider quiz;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ResponsiveCard(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Session complete',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Correct ${quiz.score} of ${quiz.completedCount}.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'You reviewed ${quiz.totalCount} words in total.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRestart,
                child: const Text('Back to modes'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.quiz,
    required this.settings,
    required this.remainingSeconds,
    required this.module,
    required this.answerMode,
    required this.feedbackTick,
    required this.lastAnswerCorrect,
    required this.onSpeak,
    required this.onSubmit,
    required this.onNext,
    required this.onPass,
    required this.onEvaluate,
    required this.onReveal,
  });

  final QuizProvider quiz;
  final SettingsProvider settings;
  final int remainingSeconds;
  final QuizModule module;
  final QuizAnswerMode answerMode;
  final int feedbackTick;
  final bool? lastAnswerCorrect;
  final VoidCallback onSpeak;
  final ValueChanged<int> onSubmit;
  final VoidCallback onNext;
  final VoidCallback onPass;
  final ValueChanged<bool> onEvaluate;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final current = quiz.current!;
    final bp = Responsive.getBreakpoint(context);
    final isMobile = bp == AppBreakpoint.mobile;

    final questionMode = switch (module) {
      QuizModule.pinyinToHanziAndMeaning => 'Listen and recall the word',
      QuizModule.hanziToPinyinAndMeaning =>
        'Read the Hanzi and recall pronunciation',
      QuizModule.hanziToMeaning => 'Read the Hanzi and recall the meaning',
      QuizModule.zhuyinByHanzi => 'Read the Hanzi and recall Zhuyin',
      QuizModule.hanziByZhuyin => 'Read the Zhuyin and recall Hanzi',
    };
    final showDetails =
        quiz.revealed ||
        (quiz.answered && answerMode == QuizAnswerMode.multipleChoice);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressStrip(
            quiz: quiz,
            settings: settings,
            remainingSeconds: remainingSeconds,
            isMobile: isMobile,
          ),
          const SizedBox(height: 16),
          _PromptCard(
            current: current,
            module: module,
            feedbackTick: feedbackTick,
            lastAnswerCorrect: lastAnswerCorrect,
            onSpeak: onSpeak,
            questionMode: questionMode,
            showDetails: showDetails,
            showAnswerAction:
                answerMode == QuizAnswerMode.essay && !quiz.revealed
                ? FilledButton.icon(
                    onPressed: onReveal,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Show answer'),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          if (answerMode == QuizAnswerMode.multipleChoice)
            _MultipleChoiceOptions(
              options: quiz.options,
              answered: quiz.answered,
              correctIndex: quiz.correctIndex(),
              selectedIndex: quiz.selectedIndex,
              optionText: quiz.optionText,
              onTap: onSubmit,
            )
          else ...[
            if (quiz.revealed) ...[
              _AnswerCard(quiz: quiz, feedbackTick: feedbackTick),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: quiz.answered ? null : () => onEvaluate(false),
                      child: const Text('Review Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: quiz.answered ? null : () => onEvaluate(true),
                      child: const Text('Got It'),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 16),
          if (quiz.answered && answerMode == QuizAnswerMode.multipleChoice)
            Align(
              alignment: Alignment.center,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next word'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.quiz,
    required this.settings,
    this.remainingSeconds,
    required this.isMobile,
  });
  final QuizProvider quiz;
  final SettingsProvider settings;
  final int? remainingSeconds;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = quiz.progressFraction.clamp(0.0, 1.0);

    return ResponsiveCard(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Session progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${quiz.completedCount}/${quiz.totalCount}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SessionPill(
                  label: 'Main deck',
                  value: '${quiz.remainingCount}',
                ),
                _SessionPill(
                  label: 'Review later',
                  value: '${quiz.reviewLaterCount}',
                ),
                _SessionPill(
                  label: 'Answered',
                  value: '${quiz.completedCount}',
                ),
                if (settings.isTimerEnabled && remainingSeconds != null)
                  _SessionPill(label: 'Timer', value: '${remainingSeconds}s'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionPill extends StatelessWidget {
  const _SessionPill({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        '$label • $value',
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.current,
    required this.module,
    required this.feedbackTick,
    required this.lastAnswerCorrect,
    required this.onSpeak,
    required this.questionMode,
    required this.showDetails,
    this.showAnswerAction,
  });

  final Vocabulary current;
  final QuizModule module;
  final int feedbackTick;
  final bool? lastAnswerCorrect;
  final VoidCallback onSpeak;
  final String questionMode;
  final bool showDetails;
  final Widget? showAnswerAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width;
    final isHanziLed = module != QuizModule.pinyinToHanziAndMeaning;
    final promptText = isHanziLed
        ? current.displayHanzi
        : current.displayPronunciation;
    final compact = maxWidth < 560;
    final wide = maxWidth >= 900;
    final textSize = isHanziLed
        ? compact
              ? 50.0
              : wide
              ? 76.0
              : 64.0
        : compact
        ? 30.0
        : wide
        ? 44.0
        : 36.0;

    return ResponsiveCard(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: lastAnswerCorrect == null
                ? colors.outlineVariant.withValues(alpha: 0.6)
                : lastAnswerCorrect == true
                ? Colors.green.withValues(alpha: 0.7)
                : Colors.red.withValues(alpha: 0.65),
            width: 1.2,
          ),
          boxShadow: lastAnswerCorrect == null
              ? null
              : [
                  BoxShadow(
                    color:
                        (lastAnswerCorrect == true ? Colors.green : Colors.red)
                            .withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      questionMode,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: onSpeak,
                    icon: const Icon(Icons.volume_up_outlined),
                    tooltip: 'Pronounce',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  promptText,
                  key: ValueKey('$promptText-$feedbackTick'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium
                      ?.copyWith(fontSize: textSize, height: 1.08),
                ),
              ),
              if (showDetails) ...[
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoBadge(label: 'Hanzi', value: current.displayHanzi),
                    _InfoBadge(
                      label: 'Pronunciation',
                      value: current.displayPronunciation,
                    ),
                    _InfoBadge(label: 'Meaning', value: current.meaning),
                  ],
                ),
              ] else if (showAnswerAction != null) ...[
                const SizedBox(height: 18),
                Align(alignment: Alignment.center, child: showAnswerAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurface),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.quiz, required this.feedbackTick});
  final QuizProvider quiz;
  final int feedbackTick;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    child: ResponsiveCard(
      key: ValueKey('answer-$feedbackTick'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Answer revealed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              quiz.answerText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontSize: 28, height: 1.35),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MultipleChoiceOptions extends StatelessWidget {
  const _MultipleChoiceOptions({
    required this.options,
    required this.answered,
    required this.correctIndex,
    required this.selectedIndex,
    required this.optionText,
    required this.onTap,
  });

  final List<Vocabulary> options;
  final bool answered;
  final int correctIndex;
  final int? selectedIndex;
  final String Function(Vocabulary) optionText;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(options.length, (index) {
      final vocab = options[index];
      final isCorrect = index == correctIndex;
      final isSelected = index == selectedIndex;
      final colors = Theme.of(context).colorScheme;
      final background = !answered
          ? colors.surfaceContainerLowest
          : isCorrect
          ? Colors.green.withValues(alpha: 0.14)
          : isSelected
          ? Colors.red.withValues(alpha: 0.12)
          : colors.surfaceContainerLowest;
      final border = !answered
          ? colors.outlineVariant.withValues(alpha: 0.7)
          : isCorrect
          ? Colors.green.withValues(alpha: 0.85)
          : isSelected
          ? Colors.red.withValues(alpha: 0.75)
          : colors.outlineVariant.withValues(alpha: 0.7);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: answered && isSelected && !isCorrect ? 1 : 0,
          ),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            final shake = answered && isSelected && !isCorrect
                ? math.sin(value * math.pi * 8) * 8
                : 0.0;
            return Transform.translate(offset: Offset(shake, 0), child: child);
          },
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              mouseCursor: answered
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              onTap: answered ? null : () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border, width: 1.2),
                  boxShadow: answered && isCorrect
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.12),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        String.fromCharCode(65 + index),
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        optionText(vocab),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (answered)
                      Icon(
                        isCorrect
                            ? Icons.check_circle_outline
                            : isSelected
                            ? Icons.cancel_outlined
                            : Icons.circle_outlined,
                        color: isCorrect
                            ? Colors.green
                            : isSelected
                            ? Colors.red
                            : colors.onSurfaceVariant,
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}
