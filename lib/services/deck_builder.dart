import 'dart:math';

import '../models/deck_filter.dart';
import '../models/vocabulary.dart';
import 'database_helper.dart';

/// Builds quiz decks that favour words the user is weak at or that are due,
/// instead of a purely random draw.
class DeckBuilder {
  DeckBuilder({DatabaseHelper? db, Random? random, DateTime Function()? now})
    : _db = db ?? DatabaseHelper.instance,
      _rng = random ?? Random(),
      _now = now ?? DateTime.now;

  /// Share of a deck reserved for weak / due words (when available).
  static const weakSlotFraction = 0.5;

  /// Candidates fetched per weak slot; the slots are then sampled from them
  /// so the weakest words do not repeat identically every session.
  static const candidateOversample = 3;

  /// Smallest deck that still gives multiple choice enough options.
  static const weakWordsMinDeck = 4;

  /// TOCFL category selection as used by the quiz: cumulative bands, or
  /// every word for `'All'`.
  static DeckFilter categoryFilter(String category) => category == 'All'
      ? const DeckFilter.all()
      : DeckFilter(
          categories: DatabaseHelper.cumulativeCategoriesFor(category),
        );

  final DatabaseHelper _db;
  final Random _rng;
  final DateTime Function() _now;

  /// Up to [size] unique words from [filter]: about [weakSlotFraction] weak
  /// or due words, the rest never-seen words, topped up with any other word.
  /// Falls back to the whole vocabulary when the filter yields fewer than
  /// [weakWordsMinDeck] words (same safety net as before).
  Future<List<Vocabulary>> build({
    required DeckFilter filter,
    required int size,
  }) async {
    final deck = await _build(filter, size);
    if (deck.length < weakWordsMinDeck && !filter.isAll) {
      final wider = await _build(const DeckFilter.all(), size);
      if (wider.length >= weakWordsMinDeck) return wider;
    }
    return deck;
  }

  Future<List<Vocabulary>> _build(DeckFilter filter, int size) async {
    if (size <= 0) return [];
    final chosen = <int>[];
    final seen = <int>{};
    void take(Iterable<int> ids, int limit) {
      for (final id in ids) {
        if (chosen.length >= limit) return;
        if (seen.add(id)) chosen.add(id);
      }
    }

    final weakSlots = (size * weakSlotFraction).round();
    final due = await _db.getDueCandidates(
      filter,
      nowMs: _now().toUtc().millisecondsSinceEpoch,
      limit: weakSlots * candidateOversample,
    );
    // Weak words first; each tier is sampled on its own so due-but-fine
    // words never push out a weak one.
    for (final weak in const [true, false]) {
      final tier = [
        for (final c in due)
          if (c.weak == weak) c.id,
      ]..shuffle(_rng);
      take(tier, weakSlots);
    }

    if (chosen.length < size) {
      final unseen = await _db.getDeckIds(filter, unseenOnly: true)
        ..shuffle(_rng);
      take(unseen, size);
    }
    if (chosen.length < size) {
      final rest = await _db.getDeckIds(filter)
        ..shuffle(_rng);
      take(rest, size);
    }
    return _db.getVocabulariesByIds(chosen);
  }

  /// The [size] weakest words overall, padded with random words up to
  /// [weakWordsMinDeck] so a session is always playable.
  Future<List<Vocabulary>> buildWeak({required int size}) async {
    final ids = await _db.getWeakestIds(limit: size);
    final seen = ids.toSet();
    final chosen = [...ids];
    if (chosen.length < weakWordsMinDeck) {
      final rest = (await _db.getDeckIds(
        const DeckFilter.all(),
      )).where((id) => !seen.contains(id)).toList()..shuffle(_rng);
      chosen.addAll(rest.take(weakWordsMinDeck - chosen.length));
    }
    return _db.getVocabulariesByIds(chosen);
  }
}
