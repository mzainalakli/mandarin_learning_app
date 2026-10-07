import 'package:flutter/material.dart';

import '../providers/quiz_provider.dart';
import 'quiz_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key, required this.module});

  final QuizModule module;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose Quiz Mode')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Choose answer mode',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _ModeCard(
              title: 'Multiple Choice',
              subtitle: 'Pick one of four answers.',
              icon: Icons.checklist,
              onTap: () => _openQuiz(context, QuizAnswerMode.multipleChoice),
            ),
            _ModeCard(
              title: 'Essay / Flashcard',
              subtitle: 'Recall answer, reveal it, then self-evaluate.',
              icon: Icons.style_outlined,
              onTap: () => _openQuiz(context, QuizAnswerMode.essay),
            ),
          ],
        ),
      ),
    ),
  );

  void _openQuiz(BuildContext context, QuizAnswerMode answerMode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(module: module, answerMode: answerMode),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(20),
      leading: Icon(icon, size: 32),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward),
      onTap: onTap,
    ),
  );
}
