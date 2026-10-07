import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/vocabulary.dart';
import '../providers/vocab_provider.dart';
import '../services/excel_service.dart';
import '../services/tts_service.dart';

class ManageVocabScreen extends StatefulWidget {
  const ManageVocabScreen({super.key});

  @override
  State<ManageVocabScreen> createState() => _ManageVocabScreenState();
}

class _ManageVocabScreenState extends State<ManageVocabScreen> {
  final _hanziCtrl = TextEditingController();
  final _pinyinCtrl = TextEditingController();
  final _meaningCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: 'HSK 1');
  final _formKey = GlobalKey<FormState>();
  var _isLoading = true;
  var _isSaving = false;
  var _isImporting = false;
  var _isExporting = false;
  int? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadVocabs();
  }

  @override
  void dispose() {
    _hanziCtrl.dispose();
    _pinyinCtrl.dispose();
    _meaningCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVocabs() async {
    try {
      await context.read<VocabProvider>().loadVocabs();
    } catch (_) {
      if (mounted) _showMessage('Could not load vocabulary.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          pinyin: _pinyinCtrl.text.trim(),
          meaning: _meaningCtrl.text.trim(),
          category: _categoryCtrl.text.trim().isEmpty
              ? 'Uncategorized'
              : _categoryCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      _hanziCtrl.clear();
      _pinyinCtrl.clear();
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
        '.csv' when file.path != null => await provider.importFromCsvFile(
          file.path!,
        ),
        '.json' when file.path != null => await provider.importFromJsonFile(
          file.path!,
        ),
        _ => throw const FormatException(
          'Choose a readable XLSX, CSV, or JSON file.',
        ),
      };
      if (mounted) {
        _showMessage(
          'Imported ${importResult.importedCount} rows; skipped ${importResult.skippedCount} invalid rows.',
        );
      }
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
        content: Text('Delete “${vocab.displayHanzi} — ${vocab.meaning}”?'),
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
    final provider = context.watch<VocabProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Vocabulary'),
        actions: [
          PopupMenuButton<String>(
            enabled: !_isExporting,
            tooltip: 'Export and template',
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            onSelected: (value) => switch (value) {
              'xlsx' => _export(true),
              'csv' => _export(false),
              'template' => _downloadTemplate(),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'xlsx', child: Text('Export to Excel')),
              PopupMenuItem(value: 'csv', child: Text('Export to CSV')),
              PopupMenuItem(
                value: 'template',
                child: Text('Download Excel Template'),
              ),
            ],
          ),
          IconButton(
            onPressed: _isImporting ? null : _importFile,
            icon: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload),
            tooltip: 'Import XLSX / CSV / JSON',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _field(_hanziCtrl, 'Hanzi', 120, required: true),
                  _field(_pinyinCtrl, 'Pinyin', 140, required: true),
                  _field(_meaningCtrl, 'Meaning', 160, required: true),
                  _field(_categoryCtrl, 'Category', 100),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _addWord,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.vocabs.isEmpty
                ? const Center(child: Text('No vocabulary yet.'))
                : ListView.separated(
                    itemCount: provider.vocabs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final vocab = provider.vocabs[index];
                      final deleting = _deletingId == vocab.id;
                      return ListTile(
                        leading: GestureDetector(
                          onTap: () =>
                              TtsService.instance.speak(vocab.displayHanzi),
                          child: Text(
                            vocab.displayHanzi,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        title: Text(vocab.displayPronunciation),
                        subtitle: Text(
                          '${vocab.meaning}  ·  ${vocab.category}${vocab.reviewCount > 0 ? '  ·  ${vocab.correctCount}/${vocab.reviewCount}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              onPressed: () =>
                                  TtsService.instance.speak(vocab.displayHanzi),
                              tooltip: 'Pronounce',
                            ),
                            IconButton(
                              icon: deleting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                              onPressed: deleting
                                  ? null
                                  : () => _confirmDelete(vocab),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    double width, {
    bool required = false,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    ),
  );
}
