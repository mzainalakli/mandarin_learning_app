import 'package:flutter/material.dart';

import '../providers/quiz_provider.dart';
import 'manage_vocab_screen.dart';
import 'mode_selection_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mandarin Flashcards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Quiz settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                '學中文',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a quiz module',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 32),
              _ModuleCard(
                title: 'Pinyin → Hanzi + Meaning',
                subtitle: 'Read pronunciation. Recall characters and meaning.',
                icon: Icons.record_voice_over,
                module: QuizModule.pinyinToHanziAndMeaning,
              ),
              _ModuleCard(
                title: 'Hanzi → Pronunciation + Meaning',
                subtitle:
                    'Read characters. Recall Zhuyin or pinyin and meaning.',
                icon: Icons.translate,
                module: QuizModule.hanziToPinyinAndMeaning,
              ),
              _ModuleCard(
                title: 'Hanzi → Meaning',
                subtitle: 'Read characters. Recall meaning.',
                icon: Icons.lightbulb_outline,
                module: QuizModule.hanziToMeaning,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageVocabScreen()),
                ),
                icon: const Icon(Icons.library_books),
                label: const Text('Manage Vocabulary'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.module,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final QuizModule module;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon, size: 32),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ModeSelectionScreen(module: module)),
      ),
    ),
  );
}
