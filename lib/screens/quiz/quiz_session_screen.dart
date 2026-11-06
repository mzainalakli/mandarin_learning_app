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
  });

  final QuizModule module;
  final QuizAnswerMode answerMode;

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
    // The deck is loaded by launchQuiz() before this page is pushed.
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
    if (correct) {
      await quiz.selfEvaluate(true);
    } else {
      await quiz.reviewLater();
    }
    if (!mounted) return;
    _markFeedback(correct);
    _autoAdvance();
  }

  void _finish() {
    _timer?.cancel();
    context.read<QuizProvider>().finishSession();
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave quiz?'),
        content: const Text(
          'Answered words are saved. The rest of this session will end.',
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
    // Phones (portrait or landscape) get the compact app bar and spacing;
    // width alone would treat a landscape phone as a tablet.
    final isMobile = Responsive.isCompact(context);
    final needsFourWords =
        widget.answerMode == QuizAnswerMode.multipleChoice &&
        !quiz.quizFinished &&
        quiz.totalCount < 4;
    final running = quiz.hasCurrent && !quiz.quizFinished;
    final canFinish = running && quiz.isEndless;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => !didPop ? _leave() : null,
      child: Scaffold(
        appBar: CustomAppBar(
          title: _getAppBarTitle(quiz, widget.module),
          actions: [
            if (!isMobile) ...[
              if (canFinish) ...[
                TextButton.icon(
                  onPressed: _finish,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Finish'),
                ),
                const SizedBox(width: 8),
              ],
              if (running) ...[
                TextButton.icon(
                  onPressed: quiz.answered ? null : _pass,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Pass'),
                ),
                const SizedBox(width: 8),
              ],
              TextButton.icon(
                onPressed: _leave,
                icon: const Icon(Icons.logout),
                label: const Text('Leave'),
              ),
              const SizedBox(width: 12),
            ] else ...[
              PopupMenuButton<String>(
                onSelected: (value) => switch (value) {
                  'finish' => _finish(),
                  'pass' => _pass(),
                  _ => _leave(),
                },
                itemBuilder: (context) => [
                  if (canFinish)
                    const PopupMenuItem(
                      value: 'finish',
                      child: ListTile(
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Finish'),
                      ),
                    ),
                  if (running)
                    PopupMenuItem(
                      value: 'pass',
                      enabled: !quiz.answered,
                      child: const ListTile(
                        leading: Icon(Icons.skip_next),
                        title: Text('Pass'),
                      ),
                    ),
                  const PopupMenuItem(
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
            final maxWidth = isMobile
                ? double.infinity
                : Responsive.getContentMaxWidth(context);
            final screenPadding = isMobile
                ? const EdgeInsets.symmetric(
                    horizontal: Responsive.compactCardPadding,
                    vertical: Responsive.compactGap,
                  )
                : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
            final content = !_loaded
                ? const Center(child: CircularProgressIndicator())
                : quiz.quizFinished && quiz.totalCount > 0
                ? _FinishedCard(
                    quiz: quiz,
                    onRestart: () => Navigator.pop(context),
                  )
                : needsFourWords
                ? _buildEmptyState(
                    'Multiple choice needs at least 4 vocabulary words.',
                  )
                : !quiz.hasCurrent
                ? _buildEmptyState('Add vocabulary before starting a quiz.')
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
            // This page is pushed above MainScreen, so it does not inherit
            // its SafeArea. Under edge-to-edge (Android 15+) the bottom
            // buttons would sit under the system navigation bar.
            return SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(padding: screenPadding, child: content),
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

  String _getAppBarTitle(QuizProvider quiz, QuizModule module) {
    if (quiz.currentLibraryId != null) {
      return 'Library Quiz';
    }
    return switch (module) {
      QuizModule.pinyinToHanziAndMeaning => 'Pronunciation → Hanzi',
      QuizModule.hanziToPinyinAndMeaning => 'Hanzi → Pronunciation',
      QuizModule.hanziToMeaning => 'Hanzi → Meaning',
      QuizModule.zhuyinByHanzi => 'Hanzi → Zhuyin',
      QuizModule.hanziByZhuyin => 'Zhuyin → Hanzi',
    };
  }
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
                'Correct ${quiz.score} of ${quiz.completedCount} on the first try.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                quiz.isEndless
                    ? 'You answered ${quiz.completedCount} words '
                          '(${quiz.round} ${quiz.round == 1 ? 'round' : 'rounds'}).'
                    : 'You reviewed ${quiz.totalCount} words in total.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (quiz.repeatedWordCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${quiz.repeatedWordCount} '
                  '${quiz.repeatedWordCount == 1 ? 'word was' : 'words were'} '
                  'repeated with Review Later.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
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
    if (Responsive.isCompact(context)) return _buildCompact(context);
    return _buildRegular(context);
  }

  String get _questionMode => switch (module) {
    QuizModule.pinyinToHanziAndMeaning => 'Listen and recall the word',
    QuizModule.hanziToPinyinAndMeaning =>
      'Read the Hanzi and recall pronunciation',
    QuizModule.hanziToMeaning => 'Read the Hanzi and recall the meaning',
    QuizModule.zhuyinByHanzi => 'Read the Hanzi and recall Zhuyin',
    QuizModule.hanziByZhuyin => 'Read the Zhuyin and recall Hanzi',
  };

  bool get _showDetails =>
      quiz.revealed ||
      (quiz.answered && answerMode == QuizAnswerMode.multipleChoice);

  /// Phone layout. Portrait: status line, prompt card that fills the free
  /// height, answers, then a fixed-height action block at the bottom.
  /// Landscape: prompt + status on the left, answers + actions on the right.
  Widget _buildCompact(BuildContext context) {
    final gap = Responsive.gap(context);
    final status = _CompactStatusBar(
      quiz: quiz,
      settings: settings,
      remainingSeconds: remainingSeconds,
    );
    final prompt = _PromptCard(
      current: quiz.current!,
      module: module,
      feedbackTick: feedbackTick,
      lastAnswerCorrect: lastAnswerCorrect,
      onSpeak: onSpeak,
      questionMode: _questionMode,
      showDetails: _showDetails,
      compact: true,
    );
    final content = _compactContent();
    final actions = _CompactActions(
      quiz: quiz,
      answerMode: answerMode,
      onReveal: onReveal,
      onEvaluate: onEvaluate,
      onNext: onNext,
    );

    if (Responsive.useSplitLayout(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                SizedBox(height: gap),
                Expanded(child: prompt),
              ],
            ),
          ),
          SizedBox(width: Responsive.regularGap),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scrolls only as a safety net when the answers do not fit.
                Expanded(child: SingleChildScrollView(child: content)),
                SizedBox(height: gap),
                actions,
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.max(
          constraints.maxHeight,
          Responsive.quizMinContentHeight(context),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(height: height),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                SizedBox(height: gap),
                Expanded(child: prompt),
                SizedBox(height: gap),
                // Long answers scroll inside this band instead of squeezing
                // the prompt card or overflowing.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: height * Responsive.quizContentMaxFraction,
                  ),
                  child: SingleChildScrollView(child: content),
                ),
                SizedBox(height: gap),
                actions,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _compactContent() {
    if (answerMode == QuizAnswerMode.multipleChoice) {
      return _MultipleChoiceOptions(
        options: quiz.options,
        answered: quiz.answered,
        correctIndex: quiz.correctIndex(),
        selectedIndex: quiz.selectedIndex,
        optionText: quiz.optionText,
        onTap: onSubmit,
        compact: true,
      );
    }
    if (quiz.revealed) {
      return _AnswerCard(quiz: quiz, feedbackTick: feedbackTick, compact: true);
    }
    return const SizedBox.shrink();
  }

  Widget _buildRegular(BuildContext context) {
    final current = quiz.current!;
    final bp = Responsive.getBreakpoint(context);
    final isMobile = bp == AppBreakpoint.mobile;
    final questionMode = _questionMode;
    final showDetails = _showDetails;

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
                      onPressed: quiz.answered || !quiz.canReviewLater
                          ? null
                          : () => onEvaluate(false),
                      child: Text(
                        quiz.canReviewLater
                            ? 'Review Later'
                            : 'Review limit reached',
                      ),
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

/// One-line session summary with a thin progress bar (phones).
class _CompactStatusBar extends StatelessWidget {
  const _CompactStatusBar({
    required this.quiz,
    required this.settings,
    required this.remainingSeconds,
  });
  final QuizProvider quiz;
  final SettingsProvider settings;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final parts = <String>[
      if (quiz.isEndless) ...[
        'Round ${quiz.round}',
        '${quiz.completedCount} answered',
      ] else
        '${quiz.completedCount}/${quiz.totalCount}'
            '${quiz.repeatTotal > 0 ? ' +${quiz.repeatTotal} repeats' : ''}',
      'Remaining ${quiz.remainingCount}',
      if (quiz.reviewLaterCount > 0) 'Passed ${quiz.reviewLaterCount}',
      if (settings.isTimerEnabled) 'Timer ${remainingSeconds}s',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: colors.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Responsive.compactGap / 2),
        LinearProgressIndicator(
          value: quiz.progressFraction.clamp(0.0, 1.0),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}

/// Bottom action block of the phone layout. Always at least
/// [Responsive.actionBlockMinHeight] tall so the layout does not jump when a
/// button appears.
class _CompactActions extends StatelessWidget {
  const _CompactActions({
    required this.quiz,
    required this.answerMode,
    required this.onReveal,
    required this.onEvaluate,
    required this.onNext,
  });
  final QuizProvider quiz;
  final QuizAnswerMode answerMode;
  final VoidCallback onReveal;
  final ValueChanged<bool> onEvaluate;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const size = Size(0, Responsive.minTouchTarget);
    final Widget? child;
    if (answerMode == QuizAnswerMode.multipleChoice) {
      child = quiz.answered
          ? FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: size),
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next word'),
            )
          : null;
    } else if (!quiz.revealed) {
      child = FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: size),
        onPressed: onReveal,
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('Show answer'),
      );
    } else {
      child = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: size),
              onPressed: quiz.answered || !quiz.canReviewLater
                  ? null
                  : () => onEvaluate(false),
              child: Text(
                quiz.canReviewLater ? 'Review Later' : 'Review limit reached',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: Responsive.compactCardPadding),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: size),
              onPressed: quiz.answered ? null : () => onEvaluate(true),
              child: const Text('Got It'),
            ),
          ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: Responsive.actionBlockMinHeight,
      ),
      child: Align(alignment: Alignment.center, child: child),
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
                  quiz.isEndless ? 'No-limit session' : 'Session progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  quiz.isEndless
                      ? '${quiz.completedCount} answered'
                      : '${quiz.completedCount}/${quiz.totalCount}'
                            '${quiz.repeatTotal > 0 ? ' +${quiz.repeatTotal} repeats' : ''}',
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
                if (quiz.isEndless)
                  _SessionPill(label: 'Round', value: '${quiz.round}'),
                _SessionPill(
                  label: 'Remaining',
                  value: '${quiz.remainingCount}',
                ),
                if (quiz.reviewLaterCount > 0)
                  _SessionPill(
                    label: 'Passed',
                    value: '${quiz.reviewLaterCount}',
                  ),
                if (!quiz.isEndless)
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
    this.compact = false,
  });

  final Vocabulary current;
  final QuizModule module;
  final int feedbackTick;
  final bool? lastAnswerCorrect;
  final VoidCallback onSpeak;
  final String questionMode;
  final bool showDetails;
  final Widget? showAnswerAction;

  /// Phone layout: fills the height it is given and sizes the prompt to it.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width;
    final isHanziLed =
        module != QuizModule.pinyinToHanziAndMeaning &&
        module != QuizModule.hanziByZhuyin;
    final promptText = switch (module) {
      QuizModule.pinyinToHanziAndMeaning => current.displayPronunciation,
      QuizModule.hanziByZhuyin =>
        current.zhuyin ?? current.displayPronunciation,
      _ => current.displayHanzi,
    };
    final regularTextSize = Responsive.promptFontSize(
      width: maxWidth,
      availableHeight: double.infinity,
      hanziLed: isHanziLed,
    );

    final header = Row(
      children: [
        Expanded(
          child: Text(
            questionMode,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
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
    );

    Widget promptBlock(double textSize) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        if (module == QuizModule.pinyinToHanziAndMeaning &&
            !showDetails &&
            current.meaning.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            current.meaning,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
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
    );

    return ResponsiveCard(
      elevation: 2,
      margin: compact ? EdgeInsets.zero : null,
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
          padding: EdgeInsets.all(compact ? Responsive.compactGap : 20),
          child: compact
              ? Column(
                  children: [
                    header,
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(
                                  child: promptBlock(
                                    Responsive.promptFontSize(
                                      width: maxWidth,
                                      availableHeight: showDetails
                                          ? constraints.maxHeight * 0.6
                                          : constraints.maxHeight,
                                      hanziLed: isHanziLed,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    header,
                    const SizedBox(height: 16),
                    promptBlock(regularTextSize),
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
  const _AnswerCard({
    required this.quiz,
    required this.feedbackTick,
    this.compact = false,
  });
  final QuizProvider quiz;
  final int feedbackTick;
  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    child: ResponsiveCard(
      key: ValueKey('answer-$feedbackTick'),
      margin: compact ? EdgeInsets.zero : null,
      color: Theme.of(context).colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(compact ? Responsive.compactGap : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Answer revealed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: compact ? Responsive.compactGap : 12),
            Text(
              quiz.answerText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontSize: compact ? 22 : 28, height: 1.35),
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
    this.compact = false,
  });

  final bool compact;
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
        padding: EdgeInsets.only(bottom: compact ? Responsive.compactGap : 10),
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
                constraints: const BoxConstraints(
                  minHeight: Responsive.minTouchTarget,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: compact ? 10 : 14,
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
