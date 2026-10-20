import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/quiz_provider.dart';
import '../../providers/settings_provider.dart';
import 'quiz_session_screen.dart';

/// Loads a fresh deck into [QuizProvider] and opens the session page.
///
/// The session size comes from [SettingsProvider.sessionSize]; `null` starts
/// a "no limit" session. Pass [libraryId] to draw words from a user library
/// instead of a TOCFL [category].
Future<void> launchQuiz(
  BuildContext context, {
  required QuizModule module,
  required QuizAnswerMode answerMode,
  required String category,
  int? libraryId,
}) async {
  final quiz = context.read<QuizProvider>();
  final sessionSize = context.read<SettingsProvider>().sessionSize;
  final navigator = Navigator.of(context);

  if (libraryId != null) {
    await quiz.startQuizFromLibrary(
      libraryId: libraryId,
      module: module,
      answerMode: answerMode,
      sessionSize: sessionSize,
    );
  } else {
    await quiz.startQuiz(
      category: category,
      module: module,
      answerMode: answerMode,
      sessionSize: sessionSize,
    );
  }

  if (!navigator.mounted) return;
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => QuizSessionScreen(module: module, answerMode: answerMode),
    ),
  );
}
