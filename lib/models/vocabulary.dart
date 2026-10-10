class Vocabulary {
  static const tocflCategories = [
    'TOCFL A1',
    'TOCFL A2',
    'TOCFL B1',
    'TOCFL B2',
    'TOCFL C1',
    'TOCFL C2',
  ];

  static const allCategoriesForFilter = [
    'All',
    'TOCFL A1',
    'TOCFL A2',
    'TOCFL B1',
    'TOCFL B2',
    'TOCFL C1',
    'TOCFL C2',
  ];

  static String safeDropdownValue(String? value, List<String> validItems) {
    if (value != null && validItems.contains(value)) return value;
    return validItems.first;
  }

  final int? id;
  final String hanzi;
  final String pinyin;
  final String? zhuyin;
  final String? traditionalHanzi;
  final String meaning;
  final String category;
  final int reviewCount;
  final int correctCount;
  final String lastReviewed;

  Vocabulary({
    this.id,
    required this.hanzi,
    required this.pinyin,
    this.zhuyin,
    this.traditionalHanzi,
    required this.meaning,
    required this.category,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.lastReviewed = '',
  });

  String get displayHanzi => _nonBlank(traditionalHanzi) ?? hanzi;
  String get displayPronunciation => pinyin;

  String get displayPronunciationFull => pinyin;

  double get accuracy => reviewCount == 0 ? 0.0 : correctCount / reviewCount;

  Vocabulary copyWith({
    int? id,
    String? hanzi,
    String? pinyin,
    String? zhuyin,
    String? traditionalHanzi,
    String? meaning,
    String? category,
    int? reviewCount,
    int? correctCount,
    String? lastReviewed,
  }) => Vocabulary(
    id: id ?? this.id,
    hanzi: hanzi ?? this.hanzi,
    pinyin: pinyin ?? this.pinyin,
    zhuyin: zhuyin ?? this.zhuyin,
    traditionalHanzi: traditionalHanzi ?? this.traditionalHanzi,
    meaning: meaning ?? this.meaning,
    category: category ?? this.category,
    reviewCount: reviewCount ?? this.reviewCount,
    correctCount: correctCount ?? this.correctCount,
    lastReviewed: lastReviewed ?? this.lastReviewed,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'hanzi': hanzi,
    'pinyin': pinyin,
    'zhuyin': zhuyin,
    'traditionalHanzi': traditionalHanzi,
    'meaning': meaning,
    'category': category,
    'reviewCount': reviewCount,
    'correctCount': correctCount,
    'lastReviewed': lastReviewed,
  };

  factory Vocabulary.fromMap(Map<String, dynamic> map) => Vocabulary(
    id: map['id'] as int?,
    hanzi: map['hanzi'] as String,
    pinyin: map['pinyin'] as String,
    zhuyin: _nonBlank(map['zhuyin'] as String?),
    traditionalHanzi: _nonBlank(map['traditionalHanzi'] as String?),
    meaning: map['meaning'] as String,
    category: normalizeCategory(map['category'] as String?),
    reviewCount: (map['reviewCount'] as int?) ?? 0,
    correctCount: (map['correctCount'] as int?) ?? 0,
    lastReviewed: (map['lastReviewed'] as String?) ?? '',
  );

  static String normalizeCategory(String? value) {
    final normalized = _nonBlank(value);
    if (normalized == null) return tocflCategories.first;
    return tocflCategories.contains(normalized) ? normalized : normalized;
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
