/// Which words a quiz deck may draw from. `categories == null` and
/// `libraryId == null` means every word.
class DeckFilter {
  const DeckFilter({this.categories, this.libraryId});

  const DeckFilter.all() : categories = null, libraryId = null;

  final List<String>? categories;
  final int? libraryId;

  bool get isAll => categories == null && libraryId == null;
}
