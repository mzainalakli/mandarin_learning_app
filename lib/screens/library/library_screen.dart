import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/menu_app_controller.dart';
import '../../../core/responsive.dart';
import '../../../models/library_list.dart';
import '../../../models/vocabulary.dart';
import '../../../services/database_helper.dart';
import '../../../services/tts_service.dart';
import '../../../widgets/custom_app_bar.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibraryList> _libraries = [];
  bool _isLoading = true;
  LibraryList? _selectedLibrary;
  List<Vocabulary> _libraryVocabs = [];
  bool _isLoadingVocabs = false;

  @override
  void initState() {
    super.initState();
    _loadLibraries();
  }

  Future<void> _loadLibraries() async {
    setState(() => _isLoading = true);
    try {
      final libs = await DatabaseHelper.instance.getAllLibraries();
      if (mounted) {
        setState(() {
          _libraries = libs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLibraryVocabs(int libraryId) async {
    setState(() => _isLoadingVocabs = true);
    try {
      final vocabs = await DatabaseHelper.instance.getLibraryVocabularies(libraryId);
      if (mounted) {
        setState(() {
          _libraryVocabs = vocabs;
          _isLoadingVocabs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVocabs = false);
    }
  }

  Future<void> _createLibrary() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Library'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Library name',
            hintText: 'My Custom Library',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      await DatabaseHelper.instance.createLibrary(name);
      await _loadLibraries();
      if (mounted) _showMessage('Library created');
    }
  }

  Future<void> _renameLibrary(LibraryList library) async {
    final controller = TextEditingController(text: library.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Library'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && name != library.name && mounted) {
      await DatabaseHelper.instance.renameLibrary(library.id, name);
      await _loadLibraries();
      if (mounted) _showMessage('Library renamed');
    }
  }

  Future<void> _deleteLibrary(LibraryList library) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Library?'),
        content: Text('Delete "${library.name}" and all its words?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await DatabaseHelper.instance.deleteLibrary(library.id);
      if (_selectedLibrary?.id == library.id) {
        setState(() => _selectedLibrary = null);
      }
      await _loadLibraries();
      if (mounted) _showMessage('Library deleted');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bp = Responsive.getBreakpoint(context);
    final isMobile = bp == AppBreakpoint.mobile;

    return Scaffold(
      appBar: isMobile
          ? CustomAppBar(
              title: 'My Library',
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _createLibrary,
                  tooltip: 'Create Library',
                ),
              ],
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isMobile
              ? _buildMobileLayout()
              : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedLibrary == null) {
      return _buildLibraryList();
    }
    return Column(
      children: [
        _buildLibraryDetailHeader(),
        Expanded(child: _buildVocabList()),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Column(
            children: [
              _buildDesktopHeader(),
              Expanded(child: _buildLibraryList()),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: _selectedLibrary == null
              ? _buildEmptyDetail()
              : Column(
                  children: [
                    _buildLibraryDetailHeader(),
                    Expanded(child: _buildVocabList()),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'My Libraries',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createLibrary,
            tooltip: 'Create Library',
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryList() {
    return Column(
      children: [
        if (!Responsive.isDesktop(context))
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'My Libraries',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _createLibrary,
                  tooltip: 'Create Library',
                ),
              ],
            ),
          ),
        Expanded(
          child: _libraries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.library_books_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No libraries yet',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first library to organize vocabulary',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create Library'),
                        onPressed: _createLibrary,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _libraries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final library = _libraries[index];
                    final isSelected = _selectedLibrary?.id == library.id;
                    return _LibraryTile(
                      library: library,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() => _selectedLibrary = library);
                        _loadLibraryVocabs(library.id);
                      },
                      onRename: () => _renameLibrary(library),
                      onDelete: () => _deleteLibrary(library),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLibraryDetailHeader() {
    final library = _selectedLibrary!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          if (Responsive.isMobile(context))
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedLibrary = null),
              tooltip: 'Back',
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  library.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${library.itemCount} words • Created ${library.formattedDate}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _renameLibrary(library),
                tooltip: 'Rename',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteLibrary(library),
                tooltip: 'Delete',
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _openAddVocabBottomSheet(library),
                tooltip: 'Add vocabulary',
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: library.itemCount > 0
                    ? () => _openQuizFromLibrary(library)
                    : null,
                tooltip: 'Start Quiz',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDetail() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a library from the left to view its vocabulary',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabList() {
    return _isLoadingVocabs
        ? const Center(child: CircularProgressIndicator())
        : _libraryVocabs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No words in this library',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add vocabulary from the dictionary',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add vocabulary'),
                      onPressed: () => _openAddVocabBottomSheet(_selectedLibrary!),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _libraryVocabs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final vocab = _libraryVocabs[index];
                  return _VocabInLibraryTile(
                    vocab: vocab,
                    onRemove: () => _removeFromLibrary(vocab),
                    onPronounce: () => TtsService.instance.speak(vocab.displayHanzi),
                  );
                },
              );
  }

  Future<void> _removeFromLibrary(Vocabulary vocab) async {
    if (_selectedLibrary == null || vocab.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from library?'),
        content: Text('Remove "${vocab.displayHanzi} — ${vocab.displayMeaning}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm == true && _selectedLibrary != null && vocab.id != null && mounted) {
      await DatabaseHelper.instance.removeVocabFromLibrary(_selectedLibrary!.id, vocab.id!);
      _loadLibraryVocabs(_selectedLibrary!.id);
      await _loadLibraries();
      if (mounted) _showMessage('Removed from library');
    }
  }

  void _openAddVocabBottomSheet(LibraryList library) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddVocabBottomSheet(
        library: library,
        onVocabsAdded: () {
          _loadLibraryVocabs(library.id);
          _loadLibraries();
        },
      ),
    );
  }

  void _openQuizFromLibrary(LibraryList library) {
    context.read<MenuAppController>().openQuiz(library: library);
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.library,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final LibraryList library;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isSelected
                                ? colors.onPrimaryContainer
                                : colors.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${library.itemCount} words',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? colors.onPrimaryContainer.withValues(alpha: 0.7)
                                : colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VocabInLibraryTile extends StatelessWidget {
  const _VocabInLibraryTile({
    required this.vocab,
    required this.onRemove,
    required this.onPronounce,
  });

  final Vocabulary vocab;
  final VoidCallback onRemove;
  final VoidCallback onPronounce;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: ListTile(
        leading: GestureDetector(
          onTap: onPronounce,
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              vocab.displayHanzi,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        title: Text(
          '${vocab.displayPronunciationWithZhuyin} • ${vocab.category}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(vocab.displayMeaning),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: onPronounce,
              tooltip: 'Pronounce',
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemove,
              tooltip: 'Remove from library',
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVocabBottomSheet extends StatefulWidget {
  const _AddVocabBottomSheet({
    required this.library,
    required this.onVocabsAdded,
  });

  final LibraryList library;
  final VoidCallback onVocabsAdded;

  @override
  State<_AddVocabBottomSheet> createState() => _AddVocabBottomSheetState();
}

class _AddVocabBottomSheetState extends State<_AddVocabBottomSheet> {
  static const _pageSize = 50;
  static const _debounce = Duration(milliseconds: 250);

  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  int _requestId = 0; // drops results of superseded loads
  String _searchQuery = '';
  String _filterCategory = 'All';
  bool _showAdded = false;
  List<Vocabulary> _results = [];
  Set<int> _libraryIds = {}; // words already in the library (show-added mode)
  List<int> _selectableIds = []; // every matching word that can be selected
  final Set<int> _selectedIds = {};
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  bool get _hasMore => _results.length < _total;
  bool get _allSelected =>
      _selectableIds.isNotEmpty && _selectableIds.every(_selectedIds.contains);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _reload();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim();
    if (query == _searchQuery) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _searchQuery = query;
      _reload();
    });
  }

  /// Loads the first page, the total and the selectable ids for the current
  /// filter. The selection is kept.
  Future<void> _reload() async {
    final request = ++_requestId;
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final libraryId = widget.library.id;
    final query = _searchQuery.isEmpty ? null : _searchQuery;
    final category = _filterCategory == 'All' ? null : _filterCategory;
    try {
      final exclude = _showAdded ? null : libraryId;
      final results = await Future.wait([
        db.getVocabulariesPaged(
          limit: _pageSize,
          category: category,
          searchQuery: query,
          excludeLibraryId: exclude,
        ),
        db.getVocabulariesCount(
          category: category,
          searchQuery: query,
          excludeLibraryId: exclude,
        ),
        db.getVocabularyIds(
          category: category,
          searchQuery: query,
          excludeLibraryId: libraryId,
        ),
        db.getLibraryVocabIds(libraryId),
      ]);
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = results[0] as List<Vocabulary>;
        _total = results[1] as int;
        _selectableIds = results[2] as List<int>;
        _libraryIds = results[3] as Set<int>;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && request == _requestId) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final request = _requestId;
    setState(() => _isLoadingMore = true);
    try {
      final page = await DatabaseHelper.instance.getVocabulariesPaged(
        limit: _pageSize,
        offset: _results.length,
        category: _filterCategory == 'All' ? null : _filterCategory,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        excludeLibraryId: _showAdded ? null : widget.library.id,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = [..._results, ...page];
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onCategoryChanged(String category) {
    _filterCategory = category;
    _reload();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.removeAll(_selectableIds);
      } else {
        _selectedIds.addAll(_selectableIds);
      }
    });
  }

  void _toggleSelection(int vocabId) {
    setState(() {
      if (!_selectedIds.remove(vocabId)) _selectedIds.add(vocabId);
    });
  }

  Future<void> _saveToLibrary() async {
    if (_selectedIds.isEmpty) return;

    final added = await DatabaseHelper.instance.addVocabsToLibrary(
      widget.library.id,
      _selectedIds.toList(),
    );
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onVocabsAdded();
      messenger.showSnackBar(
        SnackBar(content: Text('$added ${added == 1 ? 'word' : 'words'} added')),
      );
    }
  }

  String get _emptyMessage => _searchQuery.isEmpty && _filterCategory == 'All'
      ? 'All words are already in this library'
      : 'No results found';

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets;
    final isSmallScreen = Responsive.isMobile(context);

    return Padding(
      padding: EdgeInsets.only(bottom: padding.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: isSmallScreen ? 0.9 : 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Add to "${widget.library.name}"',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_selectedIds.isNotEmpty)
                          FilledButton.icon(
                            icon: const Icon(Icons.save),
                            label: Text('Save (${_selectedIds.length})'),
                            onPressed: _saveToLibrary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search hanzi, pinyin, zhuyin, meaning',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: FutureBuilder<List<String>>(
                        future: DatabaseHelper.instance.getDistinctCategories(),
                        builder: (context, snapshot) {
                          final categories = ['All', ...?snapshot.data?.where((c) => Vocabulary.tocflCategories.contains(c))];
                          return ListView(
                            scrollDirection: Axis.horizontal,
                            children: categories.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(c),
                                selected: _filterCategory == c,
                                onSelected: (_) => _onCategoryChanged(c),
                              ),
                            )).toList(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show words already added'),
                      value: _showAdded,
                      onChanged: (value) {
                        _showAdded = value;
                        _reload();
                      },
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text('$_total results', style: Theme.of(context).textTheme.labelLarge),
                        if (_selectableIds.isNotEmpty)
                          TextButton(
                            onPressed: _toggleSelectAll,
                            child: Text(
                              _allSelected
                                  ? 'Deselect all (${_selectableIds.length})'
                                  : 'Select all (${_selectableIds.length})',
                            ),
                          ),
                        if (_selectedIds.isNotEmpty) ...[
                          Text('${_selectedIds.length} selected', style: Theme.of(context).textTheme.labelLarge),
                          TextButton(
                            onPressed: () => setState(_selectedIds.clear),
                            child: const Text('Clear selection'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _emptyMessage,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.extentAfter < 400) _loadMore();
                              return false;
                            },
                            child: ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _results.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                if (index >= _results.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
                                final vocab = _results[index];
                                final id = vocab.id;
                                final inLibrary = id != null && _libraryIds.contains(id);
                                return _AddVocabTile(
                                  vocab: vocab,
                                  isSelected: id != null && _selectedIds.contains(id),
                                  inLibrary: inLibrary,
                                  onToggle: id != null && !inLibrary ? () => _toggleSelection(id) : null,
                                  onPronounce: () => TtsService.instance.speak(vocab.displayHanzi),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddVocabTile extends StatelessWidget {
  const _AddVocabTile({
    required this.vocab,
    required this.isSelected,
    required this.inLibrary,
    required this.onToggle,
    required this.onPronounce,
  });

  final Vocabulary vocab;
  final bool isSelected;
  final bool inLibrary;
  final VoidCallback? onToggle;
  final VoidCallback onPronounce;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.28),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isSelected || inLibrary,
          onChanged: onToggle != null ? (_) => onToggle!() : null,
        ),
        title: Text(
          vocab.displayHanzi,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${vocab.displayPronunciationWithZhuyin} • ${vocab.category}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(vocab.displayMeaning),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: onPronounce,
              tooltip: 'Pronounce',
            ),
            if (inLibrary)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}