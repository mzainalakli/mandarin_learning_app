import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../controllers/menu_app_controller.dart';
import '../../providers/vocab_provider.dart';
import '../../services/excel_service.dart';
import '../../widgets/custom_app_bar.dart';

class BulkOperationsScreen extends StatefulWidget {
  const BulkOperationsScreen({super.key});

  @override
  State<BulkOperationsScreen> createState() => _BulkOperationsScreenState();
}

class _BulkOperationsScreenState extends State<BulkOperationsScreen> {
  bool _isImporting = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Import / Export'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          LayoutBuilder(builder: (context, constraints) {
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
                  description:
                      'Download the full vocabulary set with the canonical TOCFL schema and pronunciation fields.',
                  buttonLabel: 'Export XLSX',
                  onPressed: _isExporting ? null : () => _export(true),
                  loading: _isExporting,
                ),
                _ActionCard(
                  icon: Icons.description_outlined,
                  title: 'Export to CSV',
                  description:
                      'Produce a simple UTF-8 CSV file for spreadsheet tools and quick inspection.',
                  buttonLabel: 'Export CSV',
                  onPressed: _isExporting ? null : () => _export(false),
                  loading: _isExporting,
                ),
                _ActionCard(
                  icon: Icons.file_upload_outlined,
                  title: 'Import Excel / CSV / JSON',
                  description:
                      'Import rows with hanzi, pinyin, zhuyin, meaning, and TOCFL category fields.',
                  buttonLabel: 'Import file',
                  onPressed: _isImporting ? null : _importFile,
                  loading: _isImporting,
                ),
                _ActionCard(
                  icon: Icons.table_chart_outlined,
                  title: 'Download .xlsx template',
                  description:
                      'Get a starter workbook with TOCFL A1 examples and the expected header row.',
                  buttonLabel: 'Download template',
                  onPressed: _isExporting ? null : _downloadTemplate,
                  loading: _isExporting,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
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
        '.xlsx' when file.bytes != null => await provider.importFromExcelBytes(file.bytes!),
        '.csv' when file.bytes != null => await provider.importFromCsvBytes(file.bytes!),
        '.json' when file.path != null => await provider.importFromJsonFile(file.path!),
        _ => throw const FormatException('Choose a readable XLSX, CSV, or JSON file.'),
      };
      if (mounted) _showMessage('Imported ${importResult.importedCount} rows; skipped ${importResult.skippedCount} invalid rows.');
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
      final bytes = xlsx ? ExcelService.exportXlsx(vocabs) : ExcelService.exportCsv(vocabs);
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 34, color: colors.primary),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(child: Text(description, style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}