import 'package:flutter/material.dart';

import '../../models/vocabulary.dart';
import '../../providers/quiz_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/session_options.dart';
import 'quiz_launcher.dart';

class BopomofoTrainingScreen extends StatefulWidget {
  const BopomofoTrainingScreen({super.key});

  @override
  State<BopomofoTrainingScreen> createState() => _BopomofoTrainingScreenState();
}

class _BopomofoTrainingScreenState extends State<BopomofoTrainingScreen> {
  String _selectedCategory = 'All';
  QuizModule _selectedModule = QuizModule.zhuyinByHanzi;
  bool _starting = false;

  Future<void> _start(QuizAnswerMode answerMode) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await launchQuiz(
        context,
        module: _selectedModule,
        answerMode: answerMode,
        category: _selectedCategory,
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = Vocabulary.allCategoriesForFilter;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Bopomofo Training'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bopomofo / Zhuyin Training',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Practice Traditional Chinese phonetic symbols (ㄅㄆㄇㄈ) with two focused training modes.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Training mode',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _TrainingModeChip(
                            title: 'Guess Zhuyin by Hanzi',
                            subtitle: 'See 正體字, recall ㄅㄆㄇㄈ',
                            selected:
                                _selectedModule == QuizModule.zhuyinByHanzi,
                            onSelected: () => setState(
                              () => _selectedModule = QuizModule.zhuyinByHanzi,
                            ),
                          ),
                          _TrainingModeChip(
                            title: 'Guess Hanzi by Zhuyin',
                            subtitle: 'See ㄅㄆㄇㄈ, recall 正體字',
                            selected:
                                _selectedModule == QuizModule.hanziByZhuyin,
                            onSelected: () => setState(
                              () => _selectedModule = QuizModule.hanziByZhuyin,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Number of questions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      const SessionSizeSelector(),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: Vocabulary.safeDropdownValue(
                          _selectedCategory,
                          categories,
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCategory = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'TOCFL Level (cumulative)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Timer',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      const TimerSelector(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AnswerModeCard(
                title: 'Multiple Choice Mode',
                subtitle:
                    'Interactive 4-option quiz with instant feedback, pass support, and timer-based pace control.',
                icon: Icons.check_circle_outline,
                color: colors.primaryContainer,
                onTap: _starting
                    ? null
                    : () => _start(QuizAnswerMode.multipleChoice),
              ),
              AnswerModeCard(
                title: 'Essay / Flashcard Mode',
                subtitle:
                    'Think first, reveal the answer card, then Got It or Review Later — a word you review later comes back among the unseen ones.',
                icon: Icons.style_outlined,
                color: colors.tertiaryContainer,
                onTap: _starting ? null : () => _start(QuizAnswerMode.essay),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingModeChip extends StatelessWidget {
  const _TrainingModeChip({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: Icon(
        Icons.translate_outlined,
        color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
        size: 20,
      ),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
      selectedColor: colors.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? colors.onPrimaryContainer : colors.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
