import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/responsive.dart';
import '../../../providers/settings_provider.dart';

class Header extends StatefulWidget {
  final String title;
  final VoidCallback? onMenuTap;

  const Header({super.key, required this.title, this.onMenuTap});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  // Compact layout only: the search field collapses into an icon that
  // expands it over the title.
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDesktop = Responsive.isDesktop(context);
    final compact = Responsive.isCompact(context);

    return Container(
      height: compact ? Responsive.compactHeaderHeight : Responsive.headerHeight,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Responsive.compactGap : 24,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: compact ? _compactRow(context) : _regularRow(context, isDesktop),
    );
  }

  Widget _menuButton() => IconButton(
    icon: const Icon(Icons.menu),
    onPressed: widget.onMenuTap ?? () => Scaffold.of(context).openDrawer(),
    tooltip: 'Open menu',
  );

  Widget _regularRow(BuildContext context, bool isDesktop) => Row(
    children: [
      if (!isDesktop) _menuButton(),
      if (!isDesktop) const SizedBox(width: 8),
      Text(
        widget.title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      const Expanded(child: _SearchField()),
      const SizedBox(width: 16),
      const _ThemeToggle(),
      const SizedBox(width: 8),
      const _ProfileCard(),
    ],
  );

  /// Phones: 56 dp tall. Menu, title, search (icon that expands), timer
  /// toggle and profile avatar are all still reachable.
  Widget _compactRow(BuildContext context) => Row(
    children: [
      _menuButton(),
      Expanded(
        child: _searching
            ? _SearchField(
                autofocus: true,
                onClose: () => setState(() => _searching = false),
              )
            : Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
      ),
      if (!_searching) ...[
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search vocabulary',
          onPressed: () => setState(() => _searching = true),
        ),
        const _ThemeToggle(),
        const SizedBox(width: Responsive.compactGap),
        const _ProfileCard(),
      ],
    ],
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({this.autofocus = false, this.onClose});

  final bool autofocus;

  /// When set, a close button collapses the field (compact header).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: 'Search vocabulary...',
        prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
        suffixIcon: onClose == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close search',
                onPressed: onClose,
              ),
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    return IconButton.filledTonal(
      icon: Icon(
        settings.isTimerEnabled ? Icons.timer : Icons.timer_off,
        size: 20,
      ),
      onPressed: () => settings.setTimerEnabled(!settings.isTimerEnabled),
      tooltip: settings.isTimerEnabled ? 'Disable timer' : 'Enable timer',
      style: IconButton.styleFrom(
        backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        foregroundColor: colors.onSurface,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDesktop = Responsive.isDesktop(context);
    final compact = Responsive.isCompact(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : (isDesktop ? 16 : 12),
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.person,
              size: 18,
              color: colors.onPrimaryContainer,
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 8),
            Text(
              'Learner',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}
