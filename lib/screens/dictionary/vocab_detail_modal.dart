import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../models/library_list.dart';
import '../../models/vocabulary.dart';
import '../../services/database_helper.dart';
import '../../services/tts_service.dart';

class VocabDetailModal extends StatefulWidget {
  const VocabDetailModal({
    super.key,
    required this.vocab,
    this.onVocabAddedToLibrary,
  });

  final Vocabulary vocab;
  final VoidCallback? onVocabAddedToLibrary;

  static Future<void> show(
    BuildContext context, {
    required Vocabulary vocab,
    VoidCallback? onVocabAddedToLibrary,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VocabDetailModal(
        vocab: vocab,
        onVocabAddedToLibrary: onVocabAddedToLibrary,
      ),
    );
  }

  @override
  State<VocabDetailModal> createState() => _VocabDetailModalState();
}

class _VocabDetailModalState extends State<VocabDetailModal> {
  List<LibraryList> _libraries = [];
  int? _addingToLibraryId;

  @override
  void initState() {
    super.initState();
    _loadLibraries();
  }

  Future<void> _loadLibraries() async {
    try {
      final libs = await DatabaseHelper.instance.getAllLibraries();
      if (mounted) {
        setState(() {
          _libraries = libs;
        });
      }
    } catch (_) {
      // Ignore error, _libraries remains empty
    }
  }

  Future<void> _addToLibrary(int libraryId) async {
    if (widget.vocab.id == null) return;
    setState(() => _addingToLibraryId = libraryId);
    try {
      await DatabaseHelper.instance.addVocabToLibrary(libraryId, widget.vocab.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to library')),
        );
        widget.onVocabAddedToLibrary?.call();
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to library')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToLibraryId = null);
    }
  }

  Future<void> _createAndAddToLibrary() async {
    if (widget.vocab.id == null) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Library'),
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
      final libraryId = await DatabaseHelper.instance.createLibrary(name);
      await _addToLibrary(libraryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocab = widget.vocab;
    final bp = Responsive.getBreakpoint(context);
    final isMobile = bp == AppBreakpoint.mobile;

    return DraggableScrollableSheet(
      initialChildSize: isMobile ? 0.85 : 0.6,
      minChildSize: 0.4,
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
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vocab.displayHanzi,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (vocab.traditionalHanzi != null &&
                                vocab.traditionalHanzi != vocab.hanzi) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Traditional: ${vocab.traditionalHanzi}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => TtsService.instance.speak(vocab.displayHanzi),
                        icon: const Icon(Icons.volume_up_outlined),
                        tooltip: 'Pronounce',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoBadge(
                        label: 'Pinyin',
                        value: vocab.pinyin,
                        icon: Icons.text_fields,
                      ),
                      if (vocab.zhuyin != null && vocab.zhuyin!.isNotEmpty)
                        _InfoBadge(
                          label: 'Zhuyin',
                          value: vocab.zhuyin!,
                          icon: Icons.translate,
                        ),
                      _InfoBadge(
                        label: 'TOCFL Level',
                        value: vocab.category,
                        icon: Icons.grade_outlined,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Meaning',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vocab.meaning,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (vocab.reviewCount > 0) ...[
                    Row(
                      children: [
                        _StatPill(
                          label: 'Reviews',
                          value: vocab.reviewCount.toString(),
                        ),
                        const SizedBox(width: 12),
                        _StatPill(
                          label: 'Correct',
                          value: vocab.correctCount.toString(),
                        ),
                        const SizedBox(width: 12),
                        _StatPill(
                          label: 'Accuracy',
                          value: '${(vocab.accuracy * 100).toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  Divider(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add to Library',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_libraries.isEmpty) ...[
                    Text(
                      'No libraries yet. Create one to save this word.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create Library & Add'),
                      onPressed: _createAndAddToLibrary,
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._libraries.map((lib) => _LibraryActionChip(
                              library: lib,
                              isAdding: _addingToLibraryId == lib.id,
                              onTap: () => _addToLibrary(lib.id),
                            )),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('New Library'),
                          onPressed: _createAndAddToLibrary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.value,
    this.icon,
    this.backgroundColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurface),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label, value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: colors.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _LibraryActionChip extends StatelessWidget {
  const _LibraryActionChip({
    required this.library,
    required this.isAdding,
    required this.onTap,
  });

  final LibraryList library;
  final bool isAdding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: isAdding
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.library_books_outlined, size: 18, color: colors.primary),
      label: Text(
        library.name,
        style: TextStyle(
          color: isAdding ? colors.onSurfaceVariant : colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: isAdding ? null : onTap,
      backgroundColor: colors.primaryContainer.withValues(alpha: 0.3),
      side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
    );
  }
}