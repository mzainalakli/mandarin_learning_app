import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/menu_app_controller.dart';
import '../../core/responsive.dart';
import '../../models/vocabulary.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/vocab_provider.dart';
import '../../screens/quiz/bopomofo_training_screen.dart';
import '../../screens/quiz/quiz_mode_selection_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalWords = 0;
  int _totalReviews = 0;
  int _totalCorrect = 0;
  Map<String, int> _tocflCounts = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final provider = context.read<VocabProvider>();
    final totalWords = await provider.getVocabulariesCountCumulative('All');
    final categories = Vocabulary.tocflCategories;
    final counts = <String, int>{};
    for (final cat in categories) {
      counts[cat] = await provider.getVocabulariesCountCumulative(cat);
    }
    final totalReviewsResult = await _getTotalReviews();
    final totalCorrectResult = await _getTotalCorrect();

    if (mounted) {
      setState(() {
        _totalWords = totalWords;
        _tocflCounts = counts;
        _totalReviews = totalReviewsResult;
        _totalCorrect = totalCorrectResult;
      });
    }
  }

  Future<int> _getTotalReviews() async {
    final db = context.read<VocabProvider>();
    return db.getVocabulariesCountCumulative('All');
  }

  Future<int> _getTotalCorrect() async {
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final menuController = context.read<MenuAppController>();
    final colors = Theme.of(context).colorScheme;
    final accuracy = _totalReviews == 0 ? 0.0 : _totalCorrect / _totalReviews;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(
            totalWords: _totalWords,
            totalReviews: _totalReviews,
            accuracy: accuracy,
            onStartQuiz: () => menuController.selectMenu(1),
            onManageWords: () => menuController.selectMenu(2),
            onImportExport: () => menuController.selectMenu(3),
            onSettings: () => menuController.selectMenu(4),
          ),
          const SizedBox(height: 24),
          _TOCFLProgressGrid(tocflCounts: _tocflCounts),
          const SizedBox(height: 24),
          _PracticeModuleCards(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalWords,
    required this.totalReviews,
    required this.accuracy,
    required this.onStartQuiz,
    required this.onManageWords,
    required this.onImportExport,
    required this.onSettings,
  });

  final int totalWords;
  final int totalReviews;
  final double accuracy;
  final VoidCallback onStartQuiz;
  final VoidCallback onManageWords;
  final VoidCallback onImportExport;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bp = Responsive.getBreakpoint(context);
    final isMobile = bp == AppBreakpoint.mobile;

    return ResponsiveCard(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF8E1D39), Color(0xFF0C6F64), Color(0xFF12253D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCopy(wordCount: totalWords),
                    const SizedBox(height: 20),
                    _HeroStats(
                      wordCount: totalWords,
                      totalReviews: totalReviews,
                      accuracy: accuracy,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _HeroCopy(wordCount: totalWords)),
                    const SizedBox(width: 24),
                    _HeroStats(
                      wordCount: totalWords,
                      totalReviews: totalReviews,
                      accuracy: accuracy,
                    ),
                  ],
                ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Quiz'),
                    onPressed: onStartQuiz,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8E1D39),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Manage Words'),
                    onPressed: onManageWords,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  _HeroActionChip(
                    icon: Icons.import_export_outlined,
                    label: 'Import / Export',
                    onTap: onImportExport,
                  ),
                  _HeroActionChip(
                    icon: Icons.tune_outlined,
                    label: 'Settings',
                    onTap: onSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.wordCount});

  final int wordCount;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Traditional Mandarin, built for TOCFL.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  height: 1.06,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Practice with 正體字, Pinyin, Zhuyin, and a curated TOCFL vocabulary deck ready for desktop and mobile.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(label: 'Words', value: '$wordCount'),
              _HeroMetric(label: 'TOCFL A1', value: '${context.read<VocabProvider>().getVocabulariesCountCumulative("TOCFL A1")}'),
              _HeroMetric(label: 'Deck ready', value: 'Yes'),
            ],
          ),
        ],
      );
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({
    required this.wordCount,
    required this.totalReviews,
    required this.accuracy,
  });

  final int wordCount;
  final int totalReviews;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final bp = Responsive.getBreakpoint(context);
    final cardWidth = bp == AppBreakpoint.mobile ? double.infinity : 260.0;

    return SizedBox(
      width: cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricCard(label: 'Words in deck', value: '$wordCount'),
          const SizedBox(height: 10),
          _MetricCard(label: 'Total reviews', value: '$totalReviews'),
          const SizedBox(height: 10),
          _MetricCard(
            label: 'Review accuracy',
            value: totalReviews == 0 ? '—' : '${(accuracy * 100).toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _HeroActionChip extends StatelessWidget {
  const _HeroActionChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, color: Colors.white, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        onPressed: onTap,
      );
}

class _TOCFLProgressGrid extends StatelessWidget {
  const _TOCFLProgressGrid({required this.tocflCounts});

  final Map<String, int> tocflCounts;

  static const _tocflColors = {
    'TOCFL A1': [Color(0xFF9D1F3C), Color(0xFFC86D4B)],
    'TOCFL A2': [Color(0xFF087B68), Color(0xFF3CA79B)],
    'TOCFL B1': [Color(0xFF435B9A), Color(0xFF7D92CE)],
    'TOCFL B2': [Color(0xFF6B3A8C), Color(0xFF9B59B6)],
    'TOCFL C1': [Color(0xFFB45309), Color(0xFFF59E0B)],
    'TOCFL C2': [Color(0xFF0F766E), Color(0xFF14B8A6)],
  };

  @override
  Widget build(BuildContext context) {
    final bp = Responsive.getBreakpoint(context);
    final crossAxisCount = bp == AppBreakpoint.mobile ? 2 : bp == AppBreakpoint.tablet ? 3 : 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOCFL Progress',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: bp == AppBreakpoint.mobile ? 1.1 : 1.3,
          ),
          itemCount: Vocabulary.tocflCategories.length,
          itemBuilder: (context, index) {
            final category = Vocabulary.tocflCategories[index];
            final count = tocflCounts[category] ?? 0;
            final colors = _tocflColors[category] ?? [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary];
            return _TOCFLBandCard(
              category: category,
              wordCount: count,
              colors: colors,
            );
          },
        ),
      ],
    );
  }
}

class _TOCFLBandCard extends StatelessWidget {
  const _TOCFLBandCard({
    required this.category,
    required this.wordCount,
    required this.colors,
  });

  final String category;
  final int wordCount;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return ResponsiveCard(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$wordCount words',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              wordCount == 0 ? 'Not loaded' : '$wordCount vocabulary items',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (wordCount / 300).clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeModuleCards extends StatelessWidget {
  const _PracticeModuleCards();

  @override
  Widget build(BuildContext context) {
    final menuController = context.read<MenuAppController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
Row(
            children: [
              Text(
                'Practice Modules',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Select a module to begin',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        BentoGrid(
          spacing: 16,
          runSpacing: 16,
          maxCardWidth: 360,
          children: [
            _ModuleBentoCard(
              index: '01',
              title: 'Pinyin → Hanzi + Meaning',
              subtitle: 'Hear the sound, recall the characters plus meaning.',
              icon: Icons.record_voice_over_outlined,
              colors: const [Color(0xFF9D1F3C), Color(0xFFC86D4B)],
              onTap: () {
                menuController.selectMenu(1);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizModeSelectionScreen(initialModule: QuizModule.pinyinToHanziAndMeaning),
                  ),
                );
              },
            ),
            _ModuleBentoCard(
              index: '02',
              title: 'Hanzi → Pinyin + Meaning',
              subtitle: 'Read 正體字 first, then recall pronunciation and meaning from memory.',
              icon: Icons.translate_outlined,
              colors: const [Color(0xFF087B68), Color(0xFF3CA79B)],
              onTap: () {
                menuController.selectMenu(1);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizModeSelectionScreen(initialModule: QuizModule.hanziToPinyinAndMeaning),
                  ),
                );
              },
            ),
            _ModuleBentoCard(
              index: '03',
              title: 'Hanzi → Meaning',
              subtitle: 'Pure recall mode for fast vocabulary recognition and meaning review.',
              icon: Icons.lightbulb_outline,
              colors: const [Color(0xFF435B9A), Color(0xFF7D92CE)],
              onTap: () {
                menuController.selectMenu(1);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizModeSelectionScreen(initialModule: QuizModule.hanziToMeaning),
                  ),
                );
              },
            ),
            _ModuleBentoCard(
              index: '04',
              title: 'Bopomofo / Zhuyin Training',
              subtitle: 'Master ㄅㄆㄇㄈ with Hanzi↔Zhuyin bidirectional practice.',
              icon: Icons.translate_outlined,
              colors: const [Color(0xFF6B3A8C), Color(0xFF9B59B6)],
              onTap: () => menuController.selectMenu(2),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModuleBentoCard extends StatelessWidget {
  const _ModuleBentoCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String index, title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ResponsiveCard(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    index,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Start practice',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ],
          ),
        ),
      );
}