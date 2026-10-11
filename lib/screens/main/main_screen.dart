import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/menu_app_controller.dart';
import '../../core/responsive.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/dashboard/bulk_operations_screen.dart';
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

    return Scaffold(
      key: menuController.scaffoldKey,
      drawer: isDesktop ? null : const SideMenu(),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Expanded(
                flex: 1,
                child: SideMenu(),
              ),
Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Header(
                      title: _getScreenTitle(menuController.selectedIndex),
                      onMenuTap: () => Scaffold.of(context).openDrawer(),
                    ),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey<int>(menuController.selectedIndex),
                        child: IndexedStack(
                          index: menuController.selectedIndex,
                          children: [
                            _buildTab(0, menuController.selectedIndex, const DashboardScreen()),
                            _buildTab(1, menuController.selectedIndex, const QuizModeSelectionScreen()),
                            _buildTab(2, menuController.selectedIndex, const BopomofoTrainingScreen()),
                            _buildTab(3, menuController.selectedIndex, const ManageVocabScreen()),
                            _buildTab(4, menuController.selectedIndex, const BulkOperationsScreen()),
                            _buildTab(5, menuController.selectedIndex, const SettingsScreen()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getScreenTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Practice Quiz';
      case 2:
        return 'Bopomofo Training';
      case 3:
        return 'Manage Vocabulary';
      case 4:
        return 'Import / Export';
      case 5:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildTab(int tabIndex, int currentIndex, Widget child) {
    final bool isActive = tabIndex == currentIndex;
    return TickerMode(
      enabled: isActive,
      child: ExcludeSemantics(
        excluding: !isActive,
        child: child,
      ),
    );
  }
}