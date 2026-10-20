import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Chips for choosing how many questions a session has: presets, "No limit"
/// or a custom number. The choice is stored in [SettingsProvider].
class SessionSizeSelector extends StatelessWidget {
  const SessionSizeSelector({super.key});

  static const presets = [10, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final size = settings.sessionSize;
    final isCustom = size != null && !presets.contains(size);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final preset in presets)
              ChoiceChip(
                label: Text('$preset words'),
                selected: size == preset,
                onSelected: (_) => settings.setSessionSize(preset),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.all_inclusive, size: 18),
              label: const Text('No limit'),
              selected: size == null,
              onSelected: (_) => settings.setSessionSize(null),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.tune, size: 18),
              label: Text(isCustom ? 'Custom: $size' : 'Custom…'),
              selected: isCustom,
              onSelected: (_) => _pickCustom(context, settings, size),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          size == null
              ? 'No limit: questions keep coming until you tap Finish or leave.'
              : '$size words per session.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustom(
    BuildContext context,
    SettingsProvider settings,
    int? current,
  ) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _CustomSizeDialog(
        initial: current ?? SettingsProvider.defaultSessionSize,
      ),
    );
    if (value != null) await settings.setSessionSize(value);
  }
}

class _CustomSizeDialog extends StatefulWidget {
  const _CustomSizeDialog({required this.initial});

  final int initial;

  @override
  State<_CustomSizeDialog> createState() => _CustomSizeDialogState();
}

class _CustomSizeDialogState extends State<_CustomSizeDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initial}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null ||
        value < SettingsProvider.minSessionSize ||
        value > SettingsProvider.maxSessionSize) {
      setState(() {
        _error =
            'Enter a number from ${SettingsProvider.minSessionSize} to '
            '${SettingsProvider.maxSessionSize}.';
      });
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom number of words'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Words per session',
          helperText:
              '${SettingsProvider.minSessionSize} – '
              '${SettingsProvider.maxSessionSize}. Use "No limit" for endless practice.',
          helperMaxLines: 2,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }
}

/// Timer presets plus a slider for any duration from 5 to 60 seconds.
class TimerSelector extends StatelessWidget {
  const TimerSelector({super.key});

  static const presets = [10, 20, 30];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final enabled = settings.isTimerEnabled;
    final seconds = settings.timerDurationSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Off'),
              selected: !enabled,
              onSelected: (_) => settings.setTimerEnabled(false),
            ),
            for (final preset in presets)
              ChoiceChip(
                label: Text('$preset s'),
                selected: enabled && seconds == preset,
                onSelected: (_) {
                  settings.setTimerEnabled(true);
                  settings.setTimerDurationSeconds(preset);
                },
              ),
          ],
        ),
        if (enabled)
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  '$seconds s',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Expanded(
                child: Slider(
                  min: SettingsProvider.minTimerSeconds.toDouble(),
                  max: SettingsProvider.maxTimerSeconds.toDouble(),
                  divisions:
                      SettingsProvider.maxTimerSeconds -
                      SettingsProvider.minTimerSeconds,
                  label: '$seconds s',
                  value: seconds.toDouble(),
                  onChanged: (value) =>
                      settings.setTimerDurationSeconds(value.round()),
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Text(
          enabled
              ? 'Timer: $seconds seconds per question. Multiple choice counts a '
                    'timeout as incorrect; flashcards reveal the answer.'
              : 'Timer off. Take as long as you like.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Large tappable card used to start a session in a given answer mode.
class AnswerModeCard extends StatelessWidget {
  const AnswerModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, size: 36),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}
