import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/menu_app_controller.dart';
import '../../models/vocabulary.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/custom_app_bar.dart';
import 'quiz_session_screen.dart';

class BopomofoTrainingScreen extends StatefulWidget {
  const BopomofoTrainingScreen({super.key});

  @override
  State<BopomofoTrainingScreen> createState() => _BopomofoTrainingScreenState();
}

class _BopomofoTrainingScreenState extends State<BopomofoTrainingScreen> {
  int _sessionSize = 20;
  String _selectedCategory = 'All';
  QuizModule _selectedModule = QuizModule.zhuyinByHanzi;

  @override
  void initState() {
    super.initState();
    setState(() => _selectedCategory = 'All');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final categories = Vocabulary.allCategoriesForFilter;

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
                            icon: Icons.translate_outlined,
                            selected: _selectedModule == QuizModule.zhuyinByHanzi,
                            onSelected: () => setState(() => _selectedModule = QuizModule.zhuyinByHanzi),
                          ),
                          _TrainingModeChip(
                            title: 'Guess Hanzi by Zhuyin',
                            subtitle: 'See ㄅㄆㄇㄈ, recall 正體字',
                            icon: Icons.translate_outlined,
                            selected: _selectedModule == QuizModule.hanziByZhuyin,
                            onSelected: () => setState(() => _selectedModule = QuizModule.hanziByZhuyin),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Session settings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SessionSizeChip(
                            label: '10',
                            selected: _sessionSize == 10,
                            onSelected: () => setState(() => _sessionSize = 10),
                          ),
                          _SessionSizeChip(
                            label: '20',
                            selected: _sessionSize == 20,
                            onSelected: () => setState(() => _sessionSize = 20),
                          ),
                          _SessionSizeChip(
                            label: '50',
                            selected: _sessionSize == 50,
                            onSelected: () => setState(() => _sessionSize = 50),
                          ),
                          _SessionSizeChip(
                            label: '100',
                            selected: _sessionSize == 100,
                            onSelected: () => setState(() => _sessionSize = 100),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: Vocabulary.safeDropdownValue(_selectedCategory, categories),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedCategory = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'TOCFL Level (cumulative)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Timer presets',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Off'),
                            selected: !settings.isTimerEnabled,
                            onSelected: (_) => settings.setTimerEnabled(false),
                          ),
                          ChoiceChip(
                            label: const Text('10 s'),
                            selected: settings.isTimerEnabled && settings.timerDurationSeconds == 10,
                            onSelected: (_) {
                              settings.setTimerEnabled(true);
                              settings.setTimerDurationSeconds(10);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('20 s'),
                            selected: settings.isTimerEnabled && settings.timerDurationSeconds == 20,
                            onSelected: (_) {
                              settings.setTimerEnabled(true);
                              settings.setTimerDurationSeconds(20);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('30 s'),
                            selected: settings.isTimerEnabled && settings.timerDurationSeconds == 30,
                            onSelected: (_) {
                              settings.setTimerEnabled(true);
                              settings.setTimerDurationSeconds(30);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        settings.isTimerEnabled
                            ? 'Timer enabled for ${settings.timerDurationSeconds} seconds in multiple choice mode.'
                            : 'Timer disabled. Multiple choice will wait for your answer.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ModeCard(
                title: 'Multiple Choice Mode',
                subtitle:
                    'Interactive 4-option quiz with instant feedback, pass support, and timer-based pace control.',
                icon: Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primaryContainer,
                onTap: () => _openQuiz(context, QuizAnswerMode.multipleChoice),
              ),
              _ModeCard(
                title: 'Essay / Flashcard Mode',
                subtitle:
                    'Think first, reveal the answer card, then self-evaluate with Got It or Review Later.',
                icon: Icons.style_outlined,
                color: Theme.of(context).colorScheme.tertiaryContainer,
                onTap: () => _openQuiz(context, QuizAnswerMode.essay),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQuiz(BuildContext context, QuizAnswerMode answerMode) async {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizSessionScreen(
          module: _selectedModule,
          answerMode: answerMode,
          category: _selectedCategory,
          sessionSize: _sessionSize,
        ),
      ),
    );
  }
}

class _TrainingModeChip extends StatelessWidget {
  const _TrainingModeChip({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: Icon(icon, color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant, size: 20),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
      selectedColor: colors.primaryContainer,
      labelStyle: TextStyle(color: selected ? colors.onPrimaryContainer : colors.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SessionSizeChip extends StatelessWidget {
  const _SessionSizeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$label words'),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, size: 36),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}