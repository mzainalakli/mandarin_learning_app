import 'package:flutter/material.dart';

enum AppBreakpoint { mobile, tablet, desktop }

class Responsive {
  static const double mobileBreakpoint = 850;
  static const double tabletBreakpoint = 1100;

  static AppBreakpoint getBreakpoint(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreakpoint) return AppBreakpoint.mobile;
    if (width < tabletBreakpoint) return AppBreakpoint.tablet;
    return AppBreakpoint.desktop;
  }

  static bool isMobile(BuildContext context) =>
      getBreakpoint(context) == AppBreakpoint.mobile;
  static bool isTablet(BuildContext context) =>
      getBreakpoint(context) == AppBreakpoint.tablet;
  static bool isDesktop(BuildContext context) =>
      getBreakpoint(context) == AppBreakpoint.desktop;
  static bool isTabletOrDesktop(BuildContext context) => !isMobile(context);
  static bool isMobileOrTablet(BuildContext context) => !isDesktop(context);

  // ── Height / orientation awareness ────────────────────────────────────
  // Width alone misclassifies phones in landscape (e.g. 915x412 is "tablet").
  // These helpers add the height and orientation signals.

  /// Below this height the screen is a phone held in landscape (or similar).
  static const double compactHeightBreakpoint = 480;

  /// Spacing scale used by screens that adapt to the available space.
  static const double compactGap = 8;
  static const double regularGap = 16;
  static const double wideGap = 24;

  /// Card padding scale.
  static const double compactCardPadding = 12;

  /// Height of the MainScreen header (regular / phone).
  static const double headerHeight = 72;
  static const double compactHeaderHeight = 56;

  /// Smallest hanzi / pronunciation prompt sizes the quiz may shrink to.
  static const double minHanziFontSize = 40;
  static const double minPronunciationFontSize = 28;

  /// Minimum touch target (Material guideline).
  static const double minTouchTarget = 48;

  /// Fixed minimum height of the bottom action block on session screens, so
  /// the layout does not jump when a button appears or disappears.
  static const double actionBlockMinHeight = 56;

  /// Smallest content height of the portrait quiz layout before it scrolls.
  static const double quizPortraitMinContentHeight = 560;

  /// Share of the portrait quiz height the answers may use before they scroll.
  static const double quizContentMaxFraction = 0.55;

  /// [quizPortraitMinContentHeight] grown with the system text scale.
  static double quizMinContentHeight(BuildContext context) =>
      quizPortraitMinContentHeight *
      MediaQuery.textScalerOf(context).scale(16) /
      16;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Short screen, regardless of width.
  static bool isCompactHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < compactHeightBreakpoint;

  /// Phone-like layout: narrow (portrait phone) or short (landscape phone).
  /// A phone in landscape is compact even when it is wider than 850 px.
  static bool isCompact(BuildContext context) =>
      isMobile(context) || isCompactHeight(context);

  /// Two-column layout for session-style screens: landscape and short.
  static bool useSplitLayout(BuildContext context) =>
      isLandscape(context) && isCompactHeight(context);

  /// Bottom/left/right system insets (gesture bar, 3-button bar, notch).
  /// Uses viewPadding so it stays stable while the keyboard is open.
  static EdgeInsets safeInsets(BuildContext context) =>
      MediaQuery.viewPaddingOf(context);

  /// Extra bottom padding a bottom sheet's content needs so its last item
  /// clears the system navigation bar. Zero while the keyboard is open (the
  /// keyboard already covers the bar, and sheets pad for it separately).
  static double bottomSafeInset(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 0
      ? 0
      : MediaQuery.viewPaddingOf(context).bottom;

  /// Vertical gap between blocks.
  static double gap(BuildContext context) {
    if (isCompact(context)) return compactGap;
    return isMobileOrTablet(context) ? regularGap : wideGap;
  }

  /// Outer padding of scrolling pages (Dashboard).
  static double pagePadding(BuildContext context) =>
      isCompact(context) ? compactCardPadding : wideGap;

  /// Gap between major sections of a page.
  static double sectionGap(BuildContext context) =>
      isCompact(context) ? regularGap : wideGap;

  /// Padding of gradient content blocks that sit inside a ResponsiveCard.
  static double innerCardPadding(BuildContext context) =>
      isCompact(context) ? compactCardPadding : 20;

  /// Padding inside cards.
  static double cardPadding(BuildContext context) {
    if (isCompact(context)) return compactCardPadding;
    return switch (getBreakpoint(context)) {
      AppBreakpoint.mobile => 16,
      AppBreakpoint.tablet => 20,
      AppBreakpoint.desktop => 24,
    };
  }

  /// Font size of the quiz prompt: the usual width-based size, shrunk to fit
  /// [availableHeight] but never below the readable minimum.
  static double promptFontSize({
    required double width,
    required double availableHeight,
    required bool hanziLed,
  }) {
    final compact = width < 560;
    final wide = width >= 900;
    final base = hanziLed
        ? (compact ? 50.0 : (wide ? 76.0 : 64.0))
        : (compact ? 30.0 : (wide ? 44.0 : 36.0));
    final min = hanziLed ? minHanziFontSize : minPronunciationFontSize;
    return (availableHeight * 0.3).clamp(min, base).toDouble();
  }

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

  static int getGridCrossAxisCount(
    BuildContext context, {
    double maxCardWidth = 360,
  }) {
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

  List<NavigationDestination> _buildDestinations(
    BuildContext context,
    Widget sidebar,
  ) {
    return const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school),
        label: 'Practice',
      ),
      NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book),
        label: 'Vocabulary',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
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
      selectedLabelTextStyle: TextStyle(
        color: colors.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: colors.onSurfaceVariant),
    );
  }
}

class BentoGrid extends StatelessWidget {
  /// Card height in a single-column grid at the default text scale.
  static const double singleColumnCardExtent = 280;

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
        final crossAxisCount = Responsive.getGridCrossAxisCount(
          context,
          maxCardWidth: maxCardWidth,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
            // One column (phones): a fixed height that grows with the system
            // text scale. A ratio of the width would make cards huge on wide
            // phones and clip text on large font settings.
            childAspectRatio: 1.1, // ignored when mainAxisExtent is set
            mainAxisExtent: crossAxisCount == 1
                ? singleColumnCardExtent *
                      MediaQuery.textScalerOf(context).scale(16) /
                      16
                : null,
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
    final cardPadding =
        padding ?? EdgeInsets.all(Responsive.cardPadding(context));

    final card = Card(
      elevation: elevation,
      shape:
          shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
