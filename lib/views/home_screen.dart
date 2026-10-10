import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../models/vocabulary.dart';
import '../providers/quiz_provider.dart';
import '../providers/vocab_provider.dart';
import '../services/database_helper.dart';
import 'manage_vocab_screen.dart';
import 'mode_selection_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  int _totalWords = 0;
  int _totalReviews = 0;
  int _totalCorrect = 0;
  int _tocflBands = 0;
  int _tocflA1Count = 0;
  int _tocflA2Count = 0;
  int _tocflB1Count = 0;
  int _tocflB2Count = 0;
  int _tocflC1Count = 0;
  int _tocflC2Count = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = DatabaseHelper.instance;
    final database = await db.database;
    final totalWords = await db.getVocabulariesCount();
    final totalReviewsResult = await database.rawQuery('SELECT SUM(reviewCount) as sum FROM vocabularies');
    final totalCorrectResult = await database.rawQuery('SELECT SUM(correctCount) as sum FROM vocabularies');
    final tocflCounts = <String, int>{};
    for (final cat in Vocabulary.tocflCategories) {
      tocflCounts[cat] = await db.getVocabulariesCount(category: cat);
    }
    if (mounted) {
      setState(() {
        _totalWords = totalWords;
        _totalReviews = totalReviewsResult.first['sum'] as int? ?? 0;
        _totalCorrect = totalCorrectResult.first['sum'] as int? ?? 0;
        _tocflBands = tocflCounts.values.where((v) => v > 0).length;
        _tocflA1Count = tocflCounts['TOCFL A1'] ?? 0;
        _tocflA2Count = tocflCounts['TOCFL A2'] ?? 0;
        _tocflB1Count = tocflCounts['TOCFL B1'] ?? 0;
        _tocflB2Count = tocflCounts['TOCFL B2'] ?? 0;
        _tocflC1Count = tocflCounts['TOCFL C1'] ?? 0;
        _tocflC2Count = tocflCounts['TOCFL C2'] ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = Responsive.getBreakpoint(context);
    final isDesktop = bp == AppBreakpoint.desktop;
    final sidebarWidth = isDesktop ? 260.0 : 0.0;
    final accuracy = _totalReviews == 0 ? 0.0 : _totalCorrect / _totalReviews;

    final navDestinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Home'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school),
        label: Text('Practice'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book),
        label: Text('Vocabulary'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
    ];

    final body = _buildBody(context, accuracy);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: sidebarWidth,
              child: NavigationRail(
                selectedIndex: _selectedNavIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedNavIndex = index);
                  _handleNavSelection(index);
                },
                extended: MediaQuery.sizeOf(context).width > 1300,
                minExtendedWidth: 220,
                leading: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('TOCFL Mandarin', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('v1.0.0', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  ),
                ),
                destinations: navDestinations,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                indicatorColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedNavIndex = index);
          _handleNavSelection(index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Practice'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Vocabulary'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  void _handleNavSelection(int index) {
    switch (index) {
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => ModeSelectionScreen(module: QuizModule.pinyinToHanziAndMeaning)));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageVocabScreen()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }

  Widget _buildBody(BuildContext context, double accuracy) {
    final padding = Responsive.getContentPadding(context);
    final maxWidth = Responsive.getContentMaxWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 16),
              sliver: SliverToBoxAdapter(child: _HeroSection(
                wordCount: _totalWords,
                tocflBands: _tocflBands,
                tocflA1Count: _tocflA1Count,
                tocflA2Count: _tocflA2Count,
                tocflB1Count: _tocflB1Count,
                tocflB2Count: _tocflB2Count,
                tocflC1Count: _tocflC1Count,
                tocflC2Count: _tocflC2Count,
                totalReviews: _totalReviews,
                accuracy: accuracy,
              )),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text('Practice modules', style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    Text('Three study paths', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, padding.bottom),
              sliver: SliverToBoxAdapter(
                child: BentoGrid(
                  spacing: 16,
                  runSpacing: 16,
                  maxCardWidth: 360,
                  children: [
                    _ModuleBentoCard(
                      index: '01',
                      title: 'Pinyin / Zhuyin → Hanzi + Meaning',
                      subtitle: 'Hear the sound, read the accent, and recall the characters plus meaning.',
                      icon: Icons.record_voice_over_outlined,
                      colors: const [Color(0xFF9D1F3C), Color(0xFFC86D4B)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModeSelectionScreen(module: QuizModule.pinyinToHanziAndMeaning))),
                    ),
                    _ModuleBentoCard(
                      index: '02',
                      title: 'Hanzi → Pinyin / Zhuyin + Meaning',
                      subtitle: 'Read 正體字 first, then recall pronunciation and meaning from memory.',
                      icon: Icons.translate_outlined,
                      colors: const [Color(0xFF087B68), Color(0xFF3CA79B)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModeSelectionScreen(module: QuizModule.hanziToPinyinAndMeaning))),
                    ),
                    _ModuleBentoCard(
                      index: '03',
                      title: 'Hanzi → Meaning',
                      subtitle: 'Pure recall mode for fast vocabulary recognition and meaning review.',
                      icon: Icons.lightbulb_outline,
                      colors: const [Color(0xFF435B9A), Color(0xFF7D92CE)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModeSelectionScreen(module: QuizModule.hanziToMeaning))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.wordCount,
    required this.tocflBands,
    required this.tocflA1Count,
    required this.tocflA2Count,
    required this.tocflB1Count,
    required this.tocflB2Count,
    required this.tocflC1Count,
    required this.tocflC2Count,
    required this.totalReviews,
    required this.accuracy,
  });

  final int wordCount;
  final int tocflBands;
  final int tocflA1Count;
  final int tocflA2Count;
  final int tocflB1Count;
  final int tocflB2Count;
  final int tocflC1Count;
  final int tocflC2Count;
  final int totalReviews;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final bp = Responsive.getBreakpoint(context);
    final isWide = bp != AppBreakpoint.mobile;

    return ResponsiveCard(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF8E1D39), Color(0xFF0C6F64), Color(0xFF12253D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 16)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _HeroCopy(wordCount: wordCount, tocflA1Count: tocflA1Count)),
                    const SizedBox(width: 24),
                    _HeroStats(
                      wordCount: wordCount,
                      tocflBands: tocflBands,
                      tocflA1Count: tocflA1Count,
                      tocflA2Count: tocflA2Count,
                      tocflB1Count: tocflB1Count,
                      tocflB2Count: tocflB2Count,
                      tocflC1Count: tocflC1Count,
                      tocflC2Count: tocflC2Count,
                      totalReviews: totalReviews,
                      accuracy: accuracy,
                    ),
                  ],
                )
              else ...[
                _HeroCopy(wordCount: wordCount, tocflA1Count: tocflA1Count),
                const SizedBox(height: 20),
                _HeroStats(
                  wordCount: wordCount,
                  tocflBands: tocflBands,
                  tocflA1Count: tocflA1Count,
                  tocflA2Count: tocflA2Count,
                  tocflB1Count: tocflB1Count,
                  tocflB2Count: tocflB2Count,
                  tocflC1Count: tocflC1Count,
                  tocflC2Count: tocflC2Count,
                  totalReviews: totalReviews,
                  accuracy: accuracy,
                ),
              ],
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HeroActionChip(icon: Icons.menu_book_outlined, label: 'Manage words', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageVocabScreen()))),
                  _HeroActionChip(icon: Icons.import_export_outlined, label: 'Import / Export', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageVocabScreen()))),
                  _HeroActionChip(icon: Icons.tune_outlined, label: 'Settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
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
  const _HeroCopy({required this.wordCount, required this.tocflA1Count});

  final int wordCount;
  final int tocflA1Count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Traditional Mandarin, built for TOCFL.', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, height: 1.06)),
      const SizedBox(height: 12),
      Text('Practice with 正體字, Pinyin, Zhuyin, and a curated TOCFL vocabulary deck that is ready for desktop and mobile.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.9), height: 1.5)),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _HeroMetric(label: 'Words', value: '$wordCount'),
        _HeroMetric(label: 'TOCFL A1', value: '$tocflA1Count'),
        _HeroMetric(label: 'Deck ready', value: 'Yes'),
      ]),
    ],
  );
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({
    required this.wordCount,
    required this.tocflBands,
    required this.tocflA1Count,
    required this.tocflA2Count,
    required this.tocflB1Count,
    required this.tocflB2Count,
    required this.tocflC1Count,
    required this.tocflC2Count,
    required this.totalReviews,
    required this.accuracy,
  });

  final int wordCount, tocflBands, tocflA1Count, tocflA2Count, tocflB1Count, tocflB2Count, tocflC1Count, tocflC2Count, totalReviews;
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
          _MetricCard(label: 'TOCFL bands loaded', value: '$tocflBands'),
          const SizedBox(height: 10),
          _MetricCard(label: 'TOCFL A1', value: '$tocflA1Count'),
          const SizedBox(height: 10),
          _MetricCard(label: 'TOCFL A2', value: '$tocflA2Count'),
          const SizedBox(height: 10),
          _MetricCard(label: 'TOCFL B1', value: '$tocflB1Count'),
          const SizedBox(height: 10),
          _MetricCard(label: 'TOCFL B2', value: '$tocflB2Count'),
          const SizedBox(height: 10),
          _MetricCard(label: 'TOCFL C1', value: '$tocflC1Count'),
          const SizedBox(height: 10),
          _MetricCard(label: 'TOCFL C2', value: '$tocflC2Count'),
          const SizedBox(height: 10),
          _MetricCard(label: 'Review accuracy', value: totalReviews == 0 ? '—' : '${(accuracy * 100).toStringAsFixed(0)}%'),
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
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
    ]),
  );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _HeroActionChip extends StatelessWidget {
  const _HeroActionChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, color: Colors.white),
    label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    backgroundColor: Colors.white.withValues(alpha: 0.12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
    onPressed: onTap,
  );
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 24)),
            const Spacer(),
            Text(index, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w800)),
          ]),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, height: 1.2)),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.4)),
          const SizedBox(height: 14),
          Row(children: [
            Text('Start practice', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
            const Spacer(),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ]),
        ],
      ),
    ),
  );
}