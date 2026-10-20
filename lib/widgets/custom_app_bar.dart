import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/menu_app_controller.dart';
import '../core/responsive.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.elevation = 0,
    this.backgroundColor,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double elevation;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final menuController = context.read<MenuAppController>();
    final isDesktop = Responsive.isDesktop(context);
    // Ask this page's own route, not the whole navigator: a section screen
    // that is rebuilt while another page sits on top must not offer a Back
    // button that would pop the last route and leave a blank screen.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final isSecondaryTab =
        menuController.selectedIndex != MenuAppController.dashboardIndex;

    Widget? leadingWidget = leading;

    if (leadingWidget == null && automaticallyImplyLeading) {
      if (canPop) {
        leadingWidget = IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        );
      } else if (isSecondaryTab) {
        leadingWidget = IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: menuController.navigateToDashboard,
        );
      } else if (!isDesktop) {
        leadingWidget = IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: menuController.openDrawer,
        );
      }
    }

    return AppBar(
      title: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      leading: leadingWidget,
      actions: actions,
      elevation: elevation,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      centerTitle: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
