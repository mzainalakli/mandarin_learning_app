import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/quiz_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/vocab_provider.dart';
import 'views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VocabProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: const MandarinApp(),
    ),
  );
}

class MandarinApp extends StatelessWidget {
  const MandarinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mandarin Flashcards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
