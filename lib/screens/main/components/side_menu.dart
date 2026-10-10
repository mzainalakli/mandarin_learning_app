import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/menu_app_controller.dart';
import '../../../core/responsive.dart';

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  final List<_MenuItem> _menuItems = [
    _MenuItem(title: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, index: 0),
    _MenuItem(title: 'Practice Quiz', icon: Icons.school_outlined, selectedIcon: Icons.school, index: 1),
    _MenuItem(title: 'Bopomofo Training', icon: Icons.translate_outlined, selectedIcon: Icons.translate, index: 2),
    _MenuItem(title: 'Manage Vocabulary', icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book, index: 3),
    _MenuItem(title: 'Import / Export', icon: Icons.import_export_outlined, selectedIcon: Icons.import_export, index: 4),
    _MenuItem(title: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings, index: 5),
  ];

  @override
  Widget build(BuildContext context) {
    final menuController = context.watch<MenuAppController>();
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildBrandingHeader(colors),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = menuController.selectedIndex == item.index;
                  return _MenuTile(
                    item: item,
                    isSelected: isSelected,
                    onTap: () {
                      menuController.selectMenu(item.index);
                      _handleNavigation(context);
                    },
                  );
                },
              ),
            ),
            _buildFooter(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingHeader(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary.withValues(alpha: 0.15), colors.tertiary.withValues(alpha: 0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.translate, color: colors.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOCFL Mandarin',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                ),
                Text(
                  'Traditional Chinese Mastery',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Divider(color: colors.outlineVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'v1.0.0 • Offline First',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context) {
    if (!Responsive.isDesktop(context)) {
      Navigator.of(context).pop();
    }
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final int index;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.index,
  });
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _MenuItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? colors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isSelected ? colors.onPrimaryContainer : colors.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}