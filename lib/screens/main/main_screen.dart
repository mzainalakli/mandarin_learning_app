import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/menu_app_controller.dart';
import '../../core/responsive.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/dashboard/bulk_operations_screen.dart';
import '../../screens/library/library_screen.dart';
import '../../screens/quiz/bopomofo_training_screen.dart';
import '../../screens/quiz/quiz_mode_selection_screen.dart';
import '../../views/manage_vocab_screen.dart';
import '../../views/settings_screen.dart';
import 'components/header.dart';
import 'components/side_menu.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuController = context.watch<MenuAppController>();
    final isDesktop = Responsive.isDesktop(context);
    final selectedIndex = menuController.selectedIndex;

    // System back from any section returns to the Dashboard first; only from
    // the Dashboard does it leave the app.
    return PopScope(
      canPop: selectedIndex == MenuAppController.dashboardIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) menuController.navigateToDashboard();
      },
      child: Scaffold(
        key: menuController.scaffoldKey,
        drawer: isDesktop ? null : const SideMenu(),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop) const Expanded(flex: 1, child: SideMenu()),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Header(
                      title: _screenTitle(selectedIndex),
                      onMenuTap: menuController.openDrawer,
                    ),
                    // Only the active section is built. Each switch builds
                    // one screen instead of keeping all seven alive.
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey<int>(selectedIndex),
                        child: _screenFor(selectedIndex),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _screenFor(int index) => switch (index) {
    MenuAppController.quizIndex => const QuizModeSelectionScreen(),
    MenuAppController.bopomofoIndex => const BopomofoTrainingScreen(),
    MenuAppController.libraryIndex => const LibraryScreen(),
    MenuAppController.dictionaryIndex => const ManageVocabScreen(),
    MenuAppController.importExportIndex => const BulkOperationsScreen(),
    MenuAppController.settingsIndex => const SettingsScreen(),
    _ => const DashboardScreen(),
  };

  static String _screenTitle(int index) => switch (index) {
    MenuAppController.quizIndex => 'Practice Quiz',
    MenuAppController.bopomofoIndex => 'Bopomofo Training',
    MenuAppController.libraryIndex => 'My Library',
    MenuAppController.dictionaryIndex => 'Dictionary',
    MenuAppController.importExportIndex => 'Import / Export',
    MenuAppController.settingsIndex => 'Settings',
    _ => 'Dashboard',
  };
}
