import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/menu_app_controller.dart';
import '../../core/responsive.dart';
import '../../models/stats_snapshot.dart';
import '../../providers/stats_provider.dart';
import '../../services/leitner.dart';

/// Layout constants of the statistics screen.
class _Metrics {
  static const contentMaxWidth = 1100.0;
  static const chartHeight = 190.0;
  static const compactChartHeight = 140.0;
  static const axisLabelSize = 10.0;
  static const leftAxisWidth = 34.0;
  static const bottomAxisHeight = 28.0;
  static const targetXLabels = 4;
  static const tileMinWidth = 150.0;
  static const barWidth = 8.0;
  static const missedHanziMaxWidth = 96.0;
  static const progressHeight = 8.0;
  static const emptyIconSize = 56.0;
}

const _moduleLabels = {
  'pinyinToHanziAndMeaning': 'Pinyin → Hanzi + Meaning',
  'hanziToPinyinAndMeaning': 'Hanzi → Pinyin + Meaning',
  'hanziToMeaning': 'Hanzi → Meaning',
  'zhuyinByHanzi': 'Hanzi → Zhuyin',
  'hanziByZhuyin': 'Zhuyin → Hanzi',
};

String _percent(double? value) =>
    value == null ? '–' : '${(value * 100).round()}%';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StatsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final snapshot = stats.snapshot;
    if (snapshot == null) {
      if (stats.error != null) {
        return _MessageState(
          icon: Icons.error_outline,
          title: 'Could not load statistics',
          body: 'Please try again.',
          actionLabel: 'Retry',
          onAction: stats.load,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData) {
      return _MessageState(
        icon: Icons.insights_outlined,
        title: 'No data yet',
        body:
            'Answer some questions in a quiz and your progress will show up '
            'here. Trends start from this version, so earlier answers '
            'cannot be charted.',
        actionLabel: 'Start a quiz',
        onAction: () => context.read<MenuAppController>().openQuiz(),
      );
    }
    return _StatsContent(snapshot: snapshot);
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Responsive.pagePadding(context),
        Responsive.pagePadding(context),
        Responsive.pagePadding(context),
        Responsive.pagePadding(context) + Responsive.safeInsets(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ResponsiveCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: _Metrics.emptyIconSize, color: colors.primary),
                SizedBox(height: Responsive.gap(context)),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: Responsive.gap(context)),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                SizedBox(height: Responsive.gap(context) * 2),
                FilledButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final pad = Responsive.pagePadding(context);
    final gap = Responsive.sectionGap(context);
    final twoColumns =
        Responsive.useSplitLayout(context) || !Responsive.isMobile(context);

    final overview = <Widget>[
      _SummarySection(snapshot: snapshot),
      const _RangeSelector(),
      _TrendCard(snapshot: snapshot),
      _AnswersCard(snapshot: snapshot),
    ];
    final details = <Widget>[
      _MissedCard(words: snapshot.mostMissed),
      _LevelsCard(levels: snapshot.levels),
      _ModulesCard(modules: snapshot.modules),
    ];

    Widget column(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          items[i],
        ],
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        pad,
        pad,
        pad,
        pad + Responsive.safeInsets(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _Metrics.contentMaxWidth),
          child: twoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: column(overview)),
                    SizedBox(width: gap),
                    Expanded(child: column(details)),
                  ],
                )
              : column([...overview, ...details]),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.gap(context)),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- summary

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final delta = snapshot.accuracyDelta;
    final deltaText = delta == null
        ? 'vs previous 7 days: –'
        : 'vs previous 7 days: ${delta >= 0 ? '+' : ''}${(delta * 100).round()} pts';
    final gap = Responsive.gap(context);
    final tiles = [
      _StatTile(label: 'Words learned', value: '${snapshot.learnedWords}'),
      _StatTile(
        label: 'Words mastered',
        value: '${snapshot.masteredWords}',
        caption: 'Box ${Leitner.masteredBox}+',
      ),
      _StatTile(
        label: 'Accuracy, 7 days',
        value: _percent(snapshot.accuracyLast7),
        caption: deltaText,
      ),
      _StatTile(label: 'Day streak', value: '${snapshot.streakDays}'),
      _StatTile(label: 'Answers today', value: '${snapshot.answersToday}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / _Metrics.tileMinWidth)
                .floor()
                .clamp(1, tiles.length);
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
        SizedBox(height: gap),
        Text(
          'Accuracy here counts only your first answer to each word in a '
          'session. The Dashboard counts every answer.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.headlineMedium),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    return SegmentedButton<StatsRange>(
      showSelectedIcon: false,
      segments: [
        for (final range in StatsRange.values)
          ButtonSegment(value: range, label: Text('${range.days}d')),
      ],
      selected: {stats.range},
      onSelectionChanged: (value) => stats.setRange(value.first),
    );
  }
}

// ----------------------------------------------------------------- charts

double _chartHeight(BuildContext context) => Responsive.isCompactHeight(context)
    ? _Metrics.compactChartHeight
    : _Metrics.chartHeight;

String _bucketLabel(TrendBucket bucket) =>
    '${bucket.start.day}/${bucket.start.month}';

FlTitlesData _titles(BuildContext context, List<TrendBucket> trend) {
  final style = TextStyle(
    fontSize: _Metrics.axisLabelSize,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
  final interval = (trend.length / _Metrics.targetXLabels).ceil().clamp(
    1,
    1000,
  );
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: _Metrics.leftAxisWidth,
        maxIncluded: false,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(value.toInt().toString(), maxLines: 1, style: style),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: _Metrics.bottomAxisHeight,
        interval: interval.toDouble(),
        getTitlesWidget: (value, meta) {
          final i = value.round();
          if (i < 0 || i >= trend.length || value != i.toDouble()) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            child: Text(_bucketLabel(trend[i]), maxLines: 1, style: style),
          );
        },
      ),
    ),
  );
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final trend = snapshot.trend;
    final colors = Theme.of(context).colorScheme;
    final points = trend.where((b) => b.accuracy != null).length;
    final unit = snapshot.range.weekly ? 'week' : 'day';

    final Widget body;
    if (points < 2) {
      body = Text(
        'Need answers on at least 2 ${unit}s to draw a trend.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    } else {
      body = SizedBox(
        height: _chartHeight(context),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            minX: 0,
            maxX: (trend.length - 1).toDouble(),
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: _titles(context, trend),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < trend.length; i++)
                    trend[i].accuracy == null
                        ? FlSpot.nullSpot
                        : FlSpot(i.toDouble(), trend[i].accuracy! * 100),
                ],
                color: colors.primary,
                barWidth: 3,
                isCurved: false,
                dotData: FlDotData(show: trend.length <= 31),
              ),
            ],
          ),
        ),
      );
    }
    return _SectionCard(
      title: 'Accuracy (%) per $unit',
      child: Semantics(
        label: 'Accuracy trend over ${snapshot.range.label.toLowerCase()}',
        child: body,
      ),
    );
  }
}

class _AnswersCard extends StatelessWidget {
  const _AnswersCard({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final trend = snapshot.trend;
    final colors = Theme.of(context).colorScheme;
    final peak = trend.fold<int>(0, (m, b) => b.answers > m ? b.answers : m);
    return _SectionCard(
      title: 'Answers per ${snapshot.range.weekly ? 'week' : 'day'}',
      child: Semantics(
        label: 'Answers chart over ${snapshot.range.label.toLowerCase()}',
        child: SizedBox(
          height: _chartHeight(context),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (peak == 0 ? 1 : peak * 1.15).toDouble(),
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: _titles(context, trend),
              barGroups: [
                for (var i = 0; i < trend.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: trend[i].answers.toDouble(),
                        color: colors.tertiary,
                        width: _Metrics.barWidth,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- lists

class _MissedCard extends StatelessWidget {
  const _MissedCard({required this.words});

  final List<MissedWord> words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      title: 'Most missed words',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () =>
                  context.read<MenuAppController>().openQuiz(weakWords: true),
              icon: const Icon(Icons.fitness_center_outlined),
              label: const Text('Practice weak words'),
            ),
          ),
          SizedBox(height: Responsive.gap(context)),
          if (words.isEmpty)
            Text('No missed words yet.', style: theme.textTheme.bodyMedium),
          for (final word in words)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.gap(context) / 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _Metrics.missedHanziMaxWidth,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        word.vocab.displayHanzi,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.gap(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.vocab.displayPronunciation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          word.vocab.displayMeaning,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: Responsive.gap(context)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${word.misses} ${word.misses == 1 ? 'miss' : 'misses'}',
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        _percent(word.accuracy),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelsCard extends StatelessWidget {
  const _LevelsCard({required this.levels});

  final List<LevelStat> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      title: 'By TOCFL level',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final level in levels)
            Padding(
              padding: EdgeInsets.only(bottom: Responsive.gap(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          level.category,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        'Accuracy ${_percent(level.accuracy)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: level.masteredFraction,
                    minHeight: _Metrics.progressHeight,
                    borderRadius: BorderRadius.circular(
                      _Metrics.progressHeight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${level.masteredWords} of ${level.totalWords} mastered',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModulesCard extends StatelessWidget {
  const _ModulesCard({required this.modules});

  final List<ModuleStat> modules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      title: 'By quiz type',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final module in modules)
            Padding(
              padding: EdgeInsets.only(bottom: Responsive.gap(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _moduleLabels[module.module] ?? module.module,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: module.accuracy ?? 0,
                    minHeight: _Metrics.progressHeight,
                    borderRadius: BorderRadius.circular(
                      _Metrics.progressHeight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accuracy ${_percent(module.accuracy)} · '
                    '${module.answers} answers',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
