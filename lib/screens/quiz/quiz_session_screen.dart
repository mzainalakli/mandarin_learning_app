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

/// Pause between a flashcard verdict ("Got It" / "Review Later") and the next
/// card; long enough to see the card's feedback border.
const Duration flashcardAdvanceDelay = Duration(milliseconds: 350);

/// Pause after a multiple-choice answer, so the correct option can be read.
const Duration multipleChoiceAdvanceDelay = Duration(milliseconds: 700);

/// Length of the flashcard flip and of the next card's entrance.
const Duration flashcardFlipDuration = Duration(milliseconds: 350);
const Duration flashcardEnterDuration = Duration(milliseconds: 200);

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
  Timer? _advanceTimer;
  bool _advancing = false;

  /// Identifies the question on screen; the flashcard is rebuilt (front side
  /// up) whenever it changes.
  int _questionSerial = 0;
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
    _advanceTimer?.cancel();
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

  void _autoAdvance([Duration delay = multipleChoiceAdvanceDelay]) {
    _timer?.cancel();
    // One pending advance at a time, so nextQuestion() runs exactly once.
    if (_advancing) return;
    _advancing = true;
    _advanceTimer = Timer(delay, () {
      _advancing = false;
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
    final quiz = context.read<QuizProvider>();
    if (!quiz.answered) return;
    quiz.nextQuestion();
    _questionSerial++;
    _lastAnswerCorrect = null;
    _feedbackTick++;
    _startTimer();
  }

  void _pass() {
    _timer?.cancel();
    context.read<QuizProvider>().passQuestion();
    _questionSerial++;
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
    _autoAdvance(flashcardAdvanceDelay);
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
                    questionSerial: _questionSerial,
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
    required this.questionSerial,
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
  final int questionSerial;
  final bool? lastAnswerCorrect;
  final VoidCallback onSpeak;
  final ValueChanged<int> onSubmit;
  final VoidCallback onNext;
  final VoidCallback onPass;
  final ValueChanged<bool> onEvaluate;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    if (answerMode == QuizAnswerMode.essay) return _buildFlashcard(context);
    if (Responsive.isCompact(context)) return _buildCompact(context);
    return _buildRegular(context);
  }

  /// Essay / flashcard mode, every screen size: ONE card that flips in place
  /// (question -> answer) and big action buttons below it (or beside it in
  /// landscape).
  Widget _buildFlashcard(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final gap = Responsive.gap(context);
    final card = _FlashcardFlip(
      key: const ValueKey('flashcard-card'),
      serial: questionSerial,
      quiz: quiz,
      module: module,
      questionMode: _questionMode,
      feedback: lastAnswerCorrect,
      onSpeak: onSpeak,
      onReveal: onReveal,
    );
    final actions = _FlashcardActions(
      quiz: quiz,
      onReveal: onReveal,
      onEvaluate: onEvaluate,
    );

    if (compact) {
      final status = _CompactStatusBar(
        quiz: quiz,
        settings: settings,
        remainingSeconds: remainingSeconds,
      );
      if (Responsive.useSplitLayout(context)) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  status,
                  SizedBox(height: gap),
                  Expanded(child: card),
                ],
              ),
            ),
            const SizedBox(width: Responsive.regularGap),
            Expanded(
              flex: 2,
              child: Align(alignment: Alignment.bottomCenter, child: actions),
            ),
          ],
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final height = math.max(
            constraints.maxHeight,
            Responsive.flashcardMinContentHeight(context),
          );
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(height: height),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  status,
                  SizedBox(height: gap),
                  Expanded(child: card),
                  SizedBox(height: gap),
                  actions,
                ],
              ),
            ),
          );
        },
      );
    }

    // Tablet / desktop: the page scrolls; the card has a fixed height.
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Responsive.flashcardMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressStrip(
                quiz: quiz,
                settings: settings,
                remainingSeconds: remainingSeconds,
                isMobile: false,
              ),
              SizedBox(height: gap),
              SizedBox(
                height: Responsive.flashcardCardHeight(context),
                child: card,
              ),
              SizedBox(height: gap),
              actions,
            ],
          ),
        ),
      ),
    );
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
    final actions = _CompactActions(quiz: quiz, onNext: onNext);

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

  Widget _compactContent() => _MultipleChoiceOptions(
    options: quiz.options,
    answered: quiz.answered,
    correctIndex: quiz.correctIndex(),
    selectedIndex: quiz.selectedIndex,
    optionText: quiz.optionText,
    onTap: onSubmit,
    compact: true,
  );

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
          ),
          const SizedBox(height: 24),
          _MultipleChoiceOptions(
            options: quiz.options,
            answered: quiz.answered,
            correctIndex: quiz.correctIndex(),
            selectedIndex: quiz.selectedIndex,
            optionText: quiz.optionText,
            onTap: onSubmit,
          ),
          const SizedBox(height: 16),
          if (quiz.answered)
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

/// Bottom action block of the multiple-choice phone layout. Always at least
/// [Responsive.actionBlockMinHeight] tall so the layout does not jump when the
/// button appears.
class _CompactActions extends StatelessWidget {
  const _CompactActions({required this.quiz, required this.onNext});
  final QuizProvider quiz;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const size = Size(0, Responsive.minTouchTarget);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: Responsive.actionBlockMinHeight,
      ),
      child: Align(
        alignment: Alignment.center,
        child: quiz.answered
            ? FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: size),
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next word'),
              )
            : null,
      ),
    );
  }
}

/// Action buttons of flashcard mode: a full-width "Show answer", then two
/// large side-by-side verdict buttons. Same height in both states.
class _FlashcardActions extends StatelessWidget {
  const _FlashcardActions({
    required this.quiz,
    required this.onReveal,
    required this.onEvaluate,
  });
  final QuizProvider quiz;
  final VoidCallback onReveal;
  final ValueChanged<bool> onEvaluate;

  /// The scheme's own "on" colour when it reads well on [background]; some
  /// colours (the jade tertiary in the dark theme) need a lighter one.
  static Color _readableOn(ColorScheme colors, Color background, Color on) {
    final candidates = [on, colors.onSurface, colors.surface];
    candidates.sort(
      (a, b) => _contrast(b, background).compareTo(_contrast(a, background)),
    );
    return _contrast(on, background) >= 4.5 ? on : candidates.first;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance() + 0.05;
    final lb = b.computeLuminance() + 0.05;
    return la > lb ? la / lb : lb / la;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = Responsive.flashcardActionExtent(context);
    const padding = EdgeInsets.symmetric(horizontal: Responsive.compactGap);
    final labelStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    final Widget child;
    if (!quiz.revealed) {
      child = SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: Size(double.infinity, height),
            textStyle: labelStyle,
          ),
          onPressed: onReveal,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Show answer'),
        ),
      );
    } else {
      final canReview = !quiz.answered && quiz.canReviewLater;
      final gotItBackground = colors.tertiary;
      child = Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: Size(0, height),
                padding: padding,
                textStyle: labelStyle,
                backgroundColor: colors.errorContainer,
                foregroundColor: colors.onErrorContainer,
                side: canReview ? BorderSide(color: colors.error) : null,
              ),
              onPressed: canReview ? () => onEvaluate(false) : null,
              icon: const Icon(Icons.replay),
              label: Text(
                quiz.canReviewLater ? 'Review Later' : 'Review limit reached',
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: Responsive.flashcardActionGap),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: Size(0, height),
                padding: padding,
                textStyle: labelStyle,
                backgroundColor: gotItBackground,
                foregroundColor: _readableOn(
                  colors,
                  gotItBackground,
                  colors.onTertiary,
                ),
              ),
              onPressed: quiz.answered ? null : () => onEvaluate(true),
              icon: const Icon(Icons.check),
              label: const Text('Got It', textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: child,
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

bool _isHanziLed(QuizModule module) =>
    module != QuizModule.pinyinToHanziAndMeaning &&
    module != QuizModule.hanziByZhuyin;

String _promptTextFor(QuizModule module, Vocabulary current) =>
    switch (module) {
      QuizModule.pinyinToHanziAndMeaning => current.displayPronunciation,
      QuizModule.hanziByZhuyin =>
        current.zhuyin ?? current.displayPronunciation,
      _ => current.displayHanzi,
    };

/// Question label and the pronounce button at the top of a prompt.
class _PromptHeader extends StatelessWidget {
  const _PromptHeader({
    required this.questionMode,
    required this.onSpeak,
    required this.compact,
  });
  final String questionMode;
  final VoidCallback onSpeak;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
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
    this.compact = false,
  });

  final Vocabulary current;
  final QuizModule module;
  final int feedbackTick;
  final bool? lastAnswerCorrect;
  final VoidCallback onSpeak;
  final String questionMode;
  final bool showDetails;

  /// Phone layout: fills the height it is given and sizes the prompt to it.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width;
    final isHanziLed = _isHanziLed(module);
    final promptText = _promptTextFor(module, current);
    final regularTextSize = Responsive.promptFontSize(
      width: maxWidth,
      availableHeight: double.infinity,
      hanziLed: isHanziLed,
    );

    final header = _PromptHeader(
      questionMode: questionMode,
      onSpeak: onSpeak,
      compact: compact,
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

/// The single flashcard of essay mode. The question is the front; tapping it
/// (or the "Show answer" button, or the timer running out) flips it in place
/// to the answer. Only one face is built at a time, so there is always exactly
/// one card on screen and both faces share the card's size.
class _FlashcardFlip extends StatelessWidget {
  const _FlashcardFlip({
    super.key,
    required this.serial,
    required this.quiz,
    required this.module,
    required this.questionMode,
    required this.feedback,
    required this.onSpeak,
    required this.onReveal,
  });

  /// Changes for every new question; the card then starts on its front.
  final int serial;
  final QuizProvider quiz;
  final QuizModule module;
  final String questionMode;

  /// Verdict of the last evaluation: true = Got It, false = Review Later.
  final bool? feedback;
  final VoidCallback onSpeak;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    // A keyed builder: each question gets a fresh, front-up card that fades
    // and slides in briefly (instantly when animations are reduced).
    return TweenAnimationBuilder<double>(
      key: ValueKey('flashcard-$serial'),
      tween: Tween(begin: 0, end: 1),
      duration: reduce ? Duration.zero : flashcardEnterDuration,
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * Responsive.regularGap),
          child: child,
        ),
      ),
      child: _FlashcardBody(
        quiz: quiz,
        module: module,
        questionMode: questionMode,
        feedback: feedback,
        onSpeak: onSpeak,
        onReveal: onReveal,
      ),
    );
  }
}

class _FlashcardBody extends StatefulWidget {
  const _FlashcardBody({
    required this.quiz,
    required this.module,
    required this.questionMode,
    required this.feedback,
    required this.onSpeak,
    required this.onReveal,
  });
  final QuizProvider quiz;
  final QuizModule module;
  final String questionMode;
  final bool? feedback;
  final VoidCallback onSpeak;
  final VoidCallback onReveal;

  @override
  State<_FlashcardBody> createState() => _FlashcardBodyState();
}

class _FlashcardBodyState extends State<_FlashcardBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: flashcardFlipDuration,
    value: widget.quiz.revealed ? 1 : 0,
  );

  @override
  void didUpdateWidget(_FlashcardBody old) {
    super.didUpdateWidget(old);
    final target = widget.quiz.revealed ? 1.0 : 0.0;
    if (_flip.value == target || _flip.status == AnimationStatus.forward) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _flip.value = target;
    } else {
      _flip.animateTo(target, curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Color _borderColor(ColorScheme colors) => switch (widget.feedback) {
    null => colors.outlineVariant,
    true => colors.tertiary,
    false => colors.error,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final revealed = widget.quiz.revealed;
    return Semantics(
      container: true,
      label: revealed ? 'Answer side' : 'Question side',
      hint: revealed ? null : 'Double tap to show answer',
      child: AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final angle = _flip.value * math.pi;
          final showBack = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: _borderColor(colors),
                  width: widget.feedback == null ? 1.2 : 3,
                ),
              ),
              child: showBack
                  // The back is turned by pi so its text is not mirrored.
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _FlashcardBack(
                        key: const ValueKey('flashcard-back'),
                        quiz: widget.quiz,
                        module: widget.module,
                      ),
                    )
                  : InkWell(
                      onTap: revealed ? null : widget.onReveal,
                      child: _FlashcardFront(
                        key: const ValueKey('flashcard-front'),
                        quiz: widget.quiz,
                        module: widget.module,
                        questionMode: widget.questionMode,
                        onSpeak: widget.onSpeak,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// Centres [child] in the card, scrolling inside the card when it is taller.
class _CardScroll extends StatelessWidget {
  const _CardScroll({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}

class _FlashcardFront extends StatelessWidget {
  const _FlashcardFront({
    super.key,
    required this.quiz,
    required this.module,
    required this.questionMode,
    required this.onSpeak,
  });
  final QuizProvider quiz;
  final QuizModule module;
  final String questionMode;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = quiz.current!;
    final width = MediaQuery.sizeOf(context).width;
    final compact = Responsive.isCompact(context);
    return Padding(
      padding: EdgeInsets.all(
        compact ? Responsive.compactGap : Responsive.innerCardPadding(context),
      ),
      child: Column(
        children: [
          _PromptHeader(
            questionMode: questionMode,
            onSpeak: onSpeak,
            compact: compact,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _promptTextFor(module, current),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                height: 1.08,
                                fontSize: Responsive.promptFontSize(
                                  width: width,
                                  availableHeight: constraints.maxHeight,
                                  hanziLed: _isHanziLed(module),
                                ),
                              ),
                        ),
                        if (module == QuizModule.pinyinToHanziAndMeaning &&
                            current.meaning.trim().isNotEmpty) ...[
                          const SizedBox(height: Responsive.compactGap),
                          Text(
                            current.meaning,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashcardBack extends StatelessWidget {
  const _FlashcardBack({super.key, required this.quiz, required this.module});
  final QuizProvider quiz;
  final QuizModule module;

  /// Hanzi, pronunciation and meaning that [QuizProvider.answerText] does not
  /// already show (compared line by line), so nothing appears twice.
  List<(String, String)> _details() {
    final current = quiz.current!;
    final shown = quiz.answerText.split('\n').map((l) => l.trim()).toSet();
    final entries = <(String, String)>[
      ('Hanzi', current.displayHanzi),
      ('Pronunciation', current.displayPronunciation),
      ('Meaning', current.meaning),
    ];
    return [
      for (final e in entries)
        if (e.$2.trim().isNotEmpty &&
            e.$2.trim() != '-' &&
            !shown.contains(e.$2.trim()))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = Responsive.isCompact(context);
    final details = _details();
    return ColoredBox(
      color: colors.secondaryContainer,
      child: Padding(
        padding: EdgeInsets.all(
          compact
              ? Responsive.compactGap
              : Responsive.innerCardPadding(context),
        ),
        child: _CardScroll(
          child: DefaultTextStyle.merge(
            style: TextStyle(color: colors.onSecondaryContainer),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Answer revealed',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.onSecondaryContainer),
                ),
                const SizedBox(height: Responsive.compactGap),
                Text(
                  quiz.answerText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: compact ? 26 : 32,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: Responsive.regularGap),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: Responsive.compactGap,
                    runSpacing: Responsive.compactGap,
                    children: [
                      for (final d in details)
                        _InfoBadge(label: d.$1, value: d.$2),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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
