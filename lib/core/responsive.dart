import 'package:flutter/material.dart';

enum AppBreakpoint {
  mobile,
  tablet,
  desktop,
}

class Responsive {
  static const double mobileBreakpoint = 850;
  static const double tabletBreakpoint = 1100;

  static AppBreakpoint getBreakpoint(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreakpoint) return AppBreakpoint.mobile;
    if (width < tabletBreakpoint) return AppBreakpoint.tablet;
    return AppBreakpoint.desktop;
  }

  static bool isMobile(BuildContext context) => getBreakpoint(context) == AppBreakpoint.mobile;
  static bool isTablet(BuildContext context) => getBreakpoint(context) == AppBreakpoint.tablet;
  static bool isDesktop(BuildContext context) => getBreakpoint(context) == AppBreakpoint.desktop;
  static bool isTabletOrDesktop(BuildContext context) => !isMobile(context);
  static bool isMobileOrTablet(BuildContext context) => !isDesktop(context);

  static double getContentMaxWidth(BuildContext context) {
    final bp = getBreakpoint(context);
    switch (bp) {
      case AppBreakpoint.mobile:
        return double.infinity;
      case AppBreakpoint.tablet:
        return 900;
      case AppBreakpoint.desktop:
        return 1100;
    }
  }

  static double getSidebarWidth(BuildContext context) {
    return isDesktop(context) ? 260 : 0;
  }

  static EdgeInsets getContentPadding(BuildContext context) {
    final bp = getBreakpoint(context);
    switch (bp) {
      case AppBreakpoint.mobile:
        return const EdgeInsets.all(16);
      case AppBreakpoint.tablet:
        return const EdgeInsets.all(24);
      case AppBreakpoint.desktop:
        return const EdgeInsets.all(32);
    }
  }

  static int getGridCrossAxisCount(BuildContext context, {double maxCardWidth = 360}) {
    final bp = getBreakpoint(context);
    final width = MediaQuery.sizeOf(context).width;
    if (bp == AppBreakpoint.mobile) return 1;
    return (width / maxCardWidth).floor().clamp(2, 4);
  }
}

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.body,
    this.sidebar,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.floatingActionButton,
  });

  final Widget body;
  final Widget? sidebar;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final bp = Responsive.getBreakpoint(context);
    final sidebarWidth = Responsive.getSidebarWidth(context);

    if (bp == AppBreakpoint.desktop && sidebar != null) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: sidebarWidth, child: sidebar!),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: bp != AppBreakpoint.desktop && sidebar != null
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected ?? (_) {},
              destinations: _buildDestinations(context, sidebar!),
            )
          : null,
      floatingActionButton: floatingActionButton,
    );
  }

  List<NavigationDestination> _buildDestinations(BuildContext context, Widget sidebar) {
    return const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Practice'),
      NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Vocabulary'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ];
  }
}

class ResponsiveSidebar extends StatelessWidget {
  const ResponsiveSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.logo,
    this.destinations = const [],
    this.footer,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? logo;
  final List<NavigationRailDestination> destinations;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      extended: MediaQuery.sizeOf(context).width > 1300,
      minExtendedWidth: 220,
      leading: logo ?? const SizedBox.shrink(),
      trailing: footer,
      destinations: destinations,
      backgroundColor: colors.surfaceContainerLowest,
      indicatorColor: colors.primaryContainer,
      selectedLabelTextStyle: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: colors.onSurfaceVariant),
    );
  }
}

class BentoGrid extends StatelessWidget {
  const BentoGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.maxCardWidth = 400,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double maxCardWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = Responsive.getGridCrossAxisCount(context, maxCardWidth: maxCardWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
            childAspectRatio: crossAxisCount == 1 ? 1.2 : 1.1,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation = 2,
    this.shape,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double elevation;
  final ShapeBorder? shape;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bp = Responsive.getBreakpoint(context);
    final cardPadding = padding ?? switch (bp) {
      AppBreakpoint.mobile => const EdgeInsets.all(16),
      AppBreakpoint.tablet => const EdgeInsets.all(20),
      AppBreakpoint.desktop => const EdgeInsets.all(24),
    };

    final card = Card(
      elevation: elevation,
      shape: shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color,
      margin: margin,
      child: Padding(padding: cardPadding, child: child),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}