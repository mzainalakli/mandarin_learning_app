import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/menu_app_controller.dart';
import '../../models/library_list.dart';
import '../../models/vocabulary.dart';
import '../../providers/quiz_provider.dart';
import '../../services/database_helper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/session_options.dart';
import 'quiz_launcher.dart';

class QuizModeSelectionScreen extends StatefulWidget {
  const QuizModeSelectionScreen({super.key});

  @override
  State<QuizModeSelectionScreen> createState() =>
      _QuizModeSelectionScreenState();
}

class _QuizModeSelectionScreenState extends State<QuizModeSelectionScreen> {
  static const _libraryPrefix = 'library:';
  static const _modules = [
    (QuizModule.pinyinToHanziAndMeaning, 'Pinyin → Hanzi + Meaning'),
    (QuizModule.hanziToPinyinAndMeaning, 'Hanzi → Pinyin + Meaning'),
    (QuizModule.hanziToMeaning, 'Hanzi → Meaning'),
  ];

  late QuizModule _module;
  String _selection = 'All';
  List<LibraryList> _libraries = [];
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final menu = context.read<MenuAppController>();
    _module = menu.quizModule;
    final library = menu.quizLibrary;
    if (library != null) _selection = '$_libraryPrefix${library.id}';
    _loadLibraries();
  }

  Future<void> _loadLibraries() async {
    try {
      final libs = await DatabaseHelper.instance.getAllLibraries();
      if (mounted) setState(() => _libraries = libs);
    } catch (_) {
      // Keep the list empty; the quiz still works with TOCFL categories.
    }
  }

  int? get _libraryId => _selection.startsWith(_libraryPrefix)
      ? int.tryParse(_selection.substring(_libraryPrefix.length))
      : null;

  Future<void> _start(QuizAnswerMode answerMode) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await launchQuiz(
        context,
        module: _module,
        answerMode: answerMode,
        category: _selection,
        libraryId: _libraryId,
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      for (final category in Vocabulary.allCategoriesForFilter)
        DropdownMenuItem(value: category, child: Text(category)),
      for (final library in _libraries)
        DropdownMenuItem(
          value: '$_libraryPrefix${library.id}',
          child: Text('Library: ${library.name}'),
        ),
    ];
    final selection = items.any((item) => item.value == _selection)
        ? _selection
        : 'All';
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Practice Quiz'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz type',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final (module, label) in _modules)
                            ChoiceChip(
                              label: Text(label),
                              selected: _module == module,
                              onSelected: (_) =>
                                  setState(() => _module = module),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Number of questions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      const SessionSizeSelector(),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        key: ValueKey('$selection/${_libraries.length}'),
                        initialValue: selection,
                        items: items,
                        onChanged: (value) {
                          if (value != null) setState(() => _selection = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Category / Library',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Timer',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      const TimerSelector(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AnswerModeCard(
                title: 'Multiple Choice Mode',
                subtitle:
                    'Interactive 4-option quiz with instant feedback, pass support, and timer-based pace control.',
                icon: Icons.check_circle_outline,
                color: colors.primaryContainer,
                onTap: _starting
                    ? null
                    : () => _start(QuizAnswerMode.multipleChoice),
              ),
              AnswerModeCard(
                title: 'Essay / Flashcard Mode',
                subtitle:
                    'Think first, reveal the answer card, then Got It or Review Later — a word you review later comes back among the unseen ones.',
                icon: Icons.style_outlined,
                color: colors.tertiaryContainer,
                onTap: _starting ? null : () => _start(QuizAnswerMode.essay),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
