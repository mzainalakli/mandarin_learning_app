import 'package:flutter/material.dart';

import '../models/library_list.dart';
import '../providers/quiz_provider.dart';

class MenuAppController extends ChangeNotifier {
  static const dashboardIndex = 0;
  static const quizIndex = 1;
  static const bopomofoIndex = 2;
  static const libraryIndex = 3;
  static const dictionaryIndex = 4;
  static const importExportIndex = 5;
  static const settingsIndex = 6;

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = dashboardIndex;
  int get selectedIndex => _selectedIndex;

  QuizModule _quizModule = QuizModule.pinyinToHanziAndMeaning;
  QuizModule get quizModule => _quizModule;
  LibraryList? _quizLibrary;
  LibraryList? get quizLibrary => _quizLibrary;

  void setSelectedIndex(int index) {
    closeDrawer();
    if (_selectedIndex != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectedIndex = index;
        notifyListeners();
      });
    }
  }

  void selectMenu(int index) {
    setSelectedIndex(index);
  }

  void navigateToDashboard() {
    setSelectedIndex(dashboardIndex);
  }

  void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  void closeDrawer() {
    final scaffold = scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
  }

  /// Shows the Practice Quiz section preconfigured with [module] and,
  /// optionally, one of the user's [library] lists as the word source.
  /// Replaces pushing a second quiz-setup page on top of the section.
  void openQuiz({QuizModule? module, LibraryList? library}) {
    _quizModule = module ?? QuizModule.pinyinToHanziAndMeaning;
    _quizLibrary = library;
    if (_selectedIndex == quizIndex) {
      notifyListeners();
    } else {
      setSelectedIndex(quizIndex);
    }
  }
}
