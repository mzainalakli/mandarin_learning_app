class LibraryList {
  final int id;
  final String name;
  final DateTime createdAt;
  final int itemCount;

  LibraryList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.itemCount,
  });

  String get formattedDate {
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }
}