import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'controllers/menu_app_controller.dart';
import 'providers/quiz_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/vocab_provider.dart';
import 'screens/main/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final settingsProvider = SettingsProvider();
  await settingsProvider.load();
  final vocabProvider = VocabProvider();
  await vocabProvider.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: vocabProvider),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => MenuAppController()),
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
    const crimson = Color(0xFF9D1F3C);
    const jade = Color(0xFF087B68);
    final light =
        ColorScheme.fromSeed(
          seedColor: crimson,
          tertiary: jade,
          brightness: Brightness.light,
        ).copyWith(
          primary: crimson,
          secondary: jade,
          surface: const Color(0xFFFAF7F4),
          surfaceContainerHighest: const Color(0xFFF0E8E2),
          surfaceTint: crimson,
        );
    final dark =
        ColorScheme.fromSeed(
          seedColor: crimson,
          tertiary: jade,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFFFF7C8D),
          secondary: const Color(0xFF58C2AE),
          surface: const Color(0xFF1B1817),
          surfaceContainerHighest: const Color(0xFF2A2423),
          surfaceTint: const Color(0xFFFF7C8D),
        );
    return MaterialApp(
      title: 'TOCFL Mandarin',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _theme(light),
      darkTheme: _theme(dark),
      home: const MainScreen(),
    );
  }

  ThemeData _theme(ColorScheme colors) => ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface.withValues(alpha: 0.92),
      surfaceTintColor: colors.surfaceTint,
      foregroundColor: colors.onSurface,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.primaryContainer,
      labelStyle: TextStyle(
        color: colors.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textTheme: Typography.material2021().black
        .copyWith(
          displayLarge: TextStyle(
            color: colors.onSurface,
            fontSize: 56,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
          displayMedium: TextStyle(
            color: colors.onSurface,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.06,
          ),
          displaySmall: TextStyle(
            color: colors.onSurface,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.08,
          ),
          headlineLarge: TextStyle(
            color: colors.onSurface,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: TextStyle(
            color: colors.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: TextStyle(
            color: colors.onSurface,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            height: 1.4,
          ),
          bodyMedium: TextStyle(
            color: colors.onSurface,
            fontSize: 14,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            color: colors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.primary,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorColor: colors.primary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      tileColor: colors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: 0.4),
    ),
  );
}
