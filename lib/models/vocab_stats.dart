import 'vocabulary.dart';

/// Aggregate numbers for the dashboard, computed by one database query.
class VocabStats {
  const VocabStats({
    required this.countsByCategory,
    required this.totalReviews,
    required this.totalCorrect,
  });

  const VocabStats.empty()
    : countsByCategory = const {},
      totalReviews = 0,
      totalCorrect = 0;

  /// Number of words in each stored category (exact, not cumulative).
  final Map<String, int> countsByCategory;

  /// Sum of every word's `reviewCount`.
  final int totalReviews;

  /// Sum of every word's `correctCount`.
  final int totalCorrect;

  int get totalWords => countsByCategory.values.fold(0, (a, b) => a + b);

  double get accuracy => totalReviews == 0 ? 0.0 : totalCorrect / totalReviews;

  /// Words in [category] and every lower TOCFL band (A2 = A1 + A2, ...).
  int cumulativeCount(String category) {
    final bands = Vocabulary.tocflCategories;
    final index = bands.indexOf(category);
    if (index < 0) return countsByCategory[category] ?? 0;
    return bands
        .take(index + 1)
        .fold(0, (sum, band) => sum + (countsByCategory[band] ?? 0));
  }
}
