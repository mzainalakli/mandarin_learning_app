import 'package:flutter/material.dart';

class MenuAppController extends ChangeNotifier {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    if (_selectedIndex != index) {
      if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
        scaffoldKey.currentState?.closeDrawer();
      }
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
    setSelectedIndex(0);
  }
}
