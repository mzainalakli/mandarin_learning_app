import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../models/vocabulary.dart';
import '../providers/vocab_provider.dart';
import '../services/database_helper.dart';
import '../services/excel_service.dart';
import '../services/tts_service.dart';
import '../widgets/custom_app_bar.dart';

class ManageVocabScreen extends StatefulWidget {
  const ManageVocabScreen({super.key});

  @override
  State<ManageVocabScreen> createState() => _ManageVocabScreenState();
}

class _ManageVocabScreenState extends State<ManageVocabScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hanziCtrl = TextEditingController();
  final _traditionalCtrl = TextEditingController();
  final _pinyinCtrl = TextEditingController();
  final _zhuyinCtrl = TextEditingController();
  final _meaningCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  static const _tocflCategories = Vocabulary.tocflCategories;

  String _selectedCategory = Vocabulary.tocflCategories.first;
  String _filterCategory = 'All';
  String _searchQuery = '';
  bool _isSaving = false;
  bool _isImporting = false;
  bool _isExporting = false;
  int? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadVocabs();
  }

  @override
  void dispose() {
    _hanziCtrl.dispose();
    _traditionalCtrl.dispose();
    _pinyinCtrl.dispose();
    _zhuyinCtrl.dispose();
    _meaningCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVocabs() async {
    try {
      await context.read<VocabProvider>().loadVocabs(
        category: _filterCategory,
        searchQuery: _searchQuery,
      );
    } catch (_) {
      if (mounted) _showMessage('Could not load vocabulary.');
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _loadVocabs();
  }

  void _onCategoryChanged(String category) {
    setState(() => _filterCategory = category);
    _loadVocabs();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addWord() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await context.read<VocabProvider>().addVocab(
        Vocabulary(
          hanzi: _hanziCtrl.text.trim(),
          traditionalHanzi: _traditionalCtrl.text.trim().isEmpty
              ? null
              : _traditionalCtrl.text.trim(),
          pinyin: _pinyinCtrl.text.trim(),
          zhuyin: _zhuyinCtrl.text.trim().isEmpty
              ? null
              : _zhuyinCtrl.text.trim(),
          meaning: _meaningCtrl.text.trim(),
          category: _selectedCategory,
        ),
      );
      if (!mounted) return;
      _formKey.currentState?.reset();
      _hanziCtrl.clear();
      _traditionalCtrl.clear();
      _pinyinCtrl.clear();
      _zhuyinCtrl.clear();
      _meaningCtrl.clear();
      _showMessage('Vocabulary added.');
    } catch (_) {
      if (mounted) _showMessage('Could not add vocabulary.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _importFile() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'xlsx'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || !mounted) return;
      final extension = p.extension(file.name).toLowerCase();
      final provider = context.read<VocabProvider>();
      final importResult = switch (extension) {
        '.xlsx' when file.bytes != null => await provider.importFromExcelBytes(
          file.bytes!,
        ),
        '.csv' when file.bytes != null => await provider.importFromCsvBytes(
          file.bytes!,
        ),
        '.json' when file.path != null => await provider.importFromJsonFile(
          file.path!,
        ),
        _ => throw const FormatException(
          'Choose a readable XLSX, CSV, or JSON file.',
        ),
      };
      if (mounted)
        _showMessage(
          'Imported ${importResult.importedCount} rows; skipped ${importResult.skippedCount} invalid rows.',
        );
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Import failed. Check file and try again.');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _export(bool xlsx) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final extension = xlsx ? 'xlsx' : 'csv';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export vocabulary',
        fileName: 'mandarin_vocabulary.$extension',
        type: FileType.custom,
        allowedExtensions: [extension],
      );
      if (path == null || !mounted) return;
      final vocabs = context.read<VocabProvider>().vocabs;
      final bytes = xlsx
          ? ExcelService.exportXlsx(vocabs)
          : ExcelService.exportCsv(vocabs);
      await File(path).writeAsBytes(bytes, flush: true);
      if (mounted) _showMessage('Vocabulary exported.');
    } catch (_) {
      if (mounted) _showMessage('Could not export vocabulary.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadTemplate() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel template',
        fileName: 'mandarin_vocab_template.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (path == null) return;
      await File(path).writeAsBytes(ExcelService.createTemplate(), flush: true);
      if (mounted) _showMessage('Excel template saved.');
    } catch (_) {
      if (mounted) _showMessage('Could not save Excel template.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _confirmDelete(Vocabulary vocab) async {
    final id = vocab.id;
    if (id == null || _deletingId != null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vocabulary?'),
        content: Text(
          'Delete "${vocab.displayHanzi} — ${vocab.displayMeaning}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() => _deletingId = id);
    try {
      await context.read<VocabProvider>().deleteVocab(id);
      if (mounted) _showMessage('Vocabulary deleted.');
    } catch (_) {
      if (mounted) _showMessage('Could not delete vocabulary.');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = Responsive.getBreakpoint(context);
    final isDesktop = bp == AppBreakpoint.desktop;
    final sidebarWidth = isDesktop ? 260.0 : 0.0;
    final provider = context.watch<VocabProvider>();
    final categories = {
      ..._tocflCategories,
      ...provider.vocabs.map((v) => v.category),
    }.toList()..sort();

    final body = _buildBody(context, provider, categories);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: isDesktop
            ? null
            : const CustomAppBar(title: 'Manage Vocabulary'),
        body: isDesktop
            ? Row(
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: NavigationRail(
                      selectedIndex: 0,
                      onDestinationSelected: (_) {},
                      extended: MediaQuery.sizeOf(context).width > 1300,
                      minExtendedWidth: 220,
                      leading: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Manage Vocabulary',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'v1.0.0',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.add_outlined),
                          selectedIcon: Icon(Icons.add),
                          label: Text('Quick Add'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.import_export_outlined),
                          selectedIcon: Icon(Icons.import_export),
                          label: Text('Bulk Ops'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.list_outlined),
                          selectedIcon: Icon(Icons.list),
                          label: Text('Vocab List'),
                        ),
                      ],
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLowest,
                      indicatorColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    VocabProvider provider,
    List<String> categories,
  ) {
    final bp = Responsive.getBreakpoint(context);
    final isMobile = bp == AppBreakpoint.mobile;
    final padding = Responsive.getContentPadding(context);

    final tabViews = [
      _buildQuickAddTab(),
      _buildBulkTab(),
      _buildListTab(provider, categories, padding),
    ];

    if (isMobile) {
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              padding.top,
              padding.right,
              12,
            ),
            child: _HeaderSummary(total: provider.totalCount),
          ),
          TabBar(
            tabs: const [
              Tab(text: 'Quick Add'),
              Tab(text: 'Bulk Operations'),
              Tab(text: 'Vocabulary List'),
            ],
          ),
          Expanded(child: TabBarView(children: tabViews)),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            padding.top,
            padding.right,
            12,
          ),
          sliver: SliverToBoxAdapter(
            child: _HeaderSummary(total: provider.totalCount),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding.horizontal),
          sliver: SliverToBoxAdapter(
            child: TabBar(
              tabs: const [
                Tab(text: 'Quick Add'),
                Tab(text: 'Bulk Operations'),
                Tab(text: 'Vocabulary List'),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              0,
              padding.right,
              padding.bottom,
            ),
            child: TabBarView(children: tabViews),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAddTab() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      ResponsiveCard(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick add a TOCFL word',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add Traditional Hanzi, optional Zhuyin, and a TOCFL category in one pass.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _field(_hanziCtrl, 'Hanzi', 160, required: true),
                    _field(_traditionalCtrl, 'Traditional Hanzi', 180),
                    _field(_pinyinCtrl, 'Pinyin', 170, required: true),
                    _field(_zhuyinCtrl, 'Zhuyin', 170),
                    _field(_meaningCtrl, 'Meaning', 220, required: true),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: Vocabulary.safeDropdownValue(
                          _selectedCategory,
                          Vocabulary.tocflCategories,
                        ),
                        items: Vocabulary.tocflCategories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) => v != null
                            ? setState(() => _selectedCategory = v)
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        onPressed: _isSaving ? null : _addWord,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Add word'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildBulkTab() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 820 ? 2 : 1;
          return GridView.count(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.25,
            children: [
              _ActionCard(
                icon: Icons.grid_view_outlined,
                title: 'Export to Excel (.xlsx)',
                description: 'Download the full vocabulary set with the canonical TOCFL schema and pronunciation fields.',
                buttonLabel: 'Export XLSX',
                onPressed: _isExporting ? null : () => _export(true),
                loading: _isExporting,
              ),
              _ActionCard(
                icon: Icons.description_outlined,
                title: 'Export to CSV',
                description: 'Produce a simple UTF-8 CSV file for spreadsheet tools and quick inspection.',
                buttonLabel: 'Export CSV',
                onPressed: _isExporting ? null : () => _export(false),
                loading: _isExporting,
              ),
              _ActionCard(
                icon: Icons.file_upload_outlined,
                title: 'Import Excel / CSV / JSON',
                description: 'Import rows with hanzi, pinyin, zhuyin, meaning, and TOCFL category fields.',
                buttonLabel: 'Import file',
                onPressed: _isImporting ? null : _importFile,
                loading: _isImporting,
              ),
              _ActionCard(
                icon: Icons.table_chart_outlined,
                title: 'Download .xlsx template',
                description: 'Get a starter workbook with TOCFL A1 examples and the expected header row.',
                buttonLabel: 'Download template',
                onPressed: _isExporting ? null : _downloadTemplate,
                loading: _isExporting,
              ),
              _ActionCard(
                icon: Icons.refresh_outlined,
                title: 'Reset & Reload English Vocabulary',
                description: 'Clear all vocabulary and reload the seed data with English meanings from tocfl_a1_seed.json.',
                buttonLabel: 'Reset & Reload',
                onPressed: _isExporting ? null : _resetAndReloadVocabulary,
                loading: _isExporting,
              ),
            ],
          );
        },
      ),
    ],
  );

  Future<void> _resetAndReloadVocabulary() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset & Reload English Vocabulary?'),
        content: const Text(
          'This will delete ALL vocabulary and reload the English seed data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset & Reload'),
          ),
        ],
      ),
    );
    if (shouldReset != true || !mounted) return;

    setState(() => _isExporting = true);
    try {
      await DatabaseHelper.instance.resetAndReloadEnglishVocabulary();
      if (!mounted) return;
      await context.read<VocabProvider>().loadVocabs();
      if (mounted)
        _showMessage('Vocabulary reset and reloaded with English meanings.');
    } catch (_) {
      if (mounted) _showMessage('Could not reset vocabulary.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildListTab(
    VocabProvider provider,
    List<String> categories,
    EdgeInsets padding,
  ) => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          padding.top,
          padding.right,
          12,
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search hanzi, zhuyin, pinyin, meaning, or category',
          ),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: padding.horizontal),
          scrollDirection: Axis.horizontal,
          children: [
            _CategoryChip(
              label: 'All',
              selected: _filterCategory == 'All',
              onSelected: () => _onCategoryChanged('All'),
            ),
            ...categories.map(
              (c) => _CategoryChip(
                label: c,
                selected: _filterCategory == c,
                onSelected: () => _onCategoryChanged(c),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.vocabs.isEmpty
            ? const Center(child: Text('No vocabulary yet.'))
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        4,
                        padding.right,
                        24,
                      ),
                      itemCount: provider.vocabs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final vocab = provider.vocabs[index];
                        Future<void> onPronounce() async {
                          await TtsService.instance.speak(vocab.displayHanzi);
                        }

                        return _VocabTile(
                          vocab: vocab,
                          deletingId: _deletingId,
                          onDelete: _confirmDelete,
                          onPronounce: onPronounce,
                        );
                      },
                    ),
                  ),
                  if (provider.totalCount > VocabProvider.pageSize)
                    _PaginationControls(provider: provider),
                ],
              ),
      ),
    ],
  );

  Widget _field(
    TextEditingController c,
    String l,
    double w, {
    bool required = false,
  }) => SizedBox(
    width: w,
    child: TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: l),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
          : null,
    ),
  );
}

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) => ResponsiveCard(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.library_books_outlined),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vocabulary workspace',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Add, import, export, and curate TOCFL vocabulary from one place.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$total',
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    required this.loading,
  });
  final IconData icon;
  final String title, description, buttonLabel;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => ResponsiveCard(
    elevation: 1.5,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

class _VocabTile extends StatelessWidget {
  const _VocabTile({
    required this.vocab,
    required this.deletingId,
    required this.onDelete,
    required this.onPronounce,
  });
  final Vocabulary vocab;
  final int? deletingId;
  final Future<void> Function(Vocabulary) onDelete;
  final Future<void> Function() onPronounce;

  @override
  Widget build(BuildContext context) {
    final deleting = deletingId == vocab.id;
    return Dismissible(
      key: ValueKey('vocab-${vocab.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final id = vocab.id;
        if (id == null) return false;
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete vocabulary?'),
                content: Text(
                  'Delete "${vocab.displayHanzi} — ${vocab.displayMeaning}"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(vocab),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: ResponsiveCard(
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.28),
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
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                vocab.displayHanzi,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          title: Text(
            '${vocab.displayPronunciationWithZhuyin} • ${vocab.category}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${vocab.displayMeaning}${vocab.reviewCount > 0 ? ' • ${vocab.correctCount}/${vocab.reviewCount}' : ''}${vocab.traditionalHanzi != null && vocab.traditionalHanzi != vocab.hanzi ? ' • Trad: ${vocab.traditionalHanzi}' : ''}',
            ),
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
                icon: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                onPressed: deleting ? null : () => onDelete(vocab),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({required this.provider});
  final VocabProvider provider;

  @override
  Widget build(BuildContext context) {
    final totalPages = (provider.totalCount / VocabProvider.pageSize).ceil();
    final currentPage = provider.currentPage + 1;
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: provider.currentPage > 0
                ? provider.loadPreviousPage
                : null,
            tooltip: 'Previous page',
          ),
          Text(
            'Page $currentPage of $totalPages (${provider.totalCount} total)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: provider.currentPage < totalPages - 1
                ? provider.loadNextPage
                : null,
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}
