import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/responsive.dart';
import '../../../providers/settings_provider.dart';

class Header extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;

  const Header({
    super.key,
    required this.title,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuTap ?? () => Scaffold.of(context).openDrawer(),
              tooltip: 'Open menu',
            ),
          if (!isDesktop) const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          const Expanded(child: _SearchField()),
          const SizedBox(width: 16),
          const _ThemeToggle(),
          const SizedBox(width: 8),
          _ProfileCard(),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      decoration: InputDecoration(
        hintText: 'Search vocabulary...',
        prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : 12,
        vertical: 8,
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
            child: Icon(Icons.person, size: 18, color: colors.onPrimaryContainer),
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
            Icon(Icons.keyboard_arrow_down, size: 18, color: colors.onSurfaceVariant),
          ],
        ],
      ),
    );
  }
}