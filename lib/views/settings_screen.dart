import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/menu_app_controller.dart';
import '../providers/settings_provider.dart';
import '../widgets/custom_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: const CustomAppBar(title: 'Quiz Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Answer mode',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Multiple choice')),
              ButtonSegment(value: false, label: Text('Flashcards')),
            ],
            selected: {settings.isMultipleChoice},
            onSelectionChanged: (selection) =>
                settings.setMultipleChoice(selection.first),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Countdown timer'),
            subtitle: const Text('Reveal or move on when time runs out.'),
            value: settings.isTimerEnabled,
            onChanged: settings.setTimerEnabled,
          ),
          if (settings.isTimerEnabled) ...[
            const SizedBox(height: 8),
            Text('Timer: ${settings.timerDurationSeconds} seconds'),
            Slider(
              min: 5,
              max: 60,
              divisions: 11,
              label: '${settings.timerDurationSeconds} seconds',
              value: settings.timerDurationSeconds.toDouble(),
              onChanged: (value) =>
                  settings.setTimerDurationSeconds(value.round()),
            ),
          ],
        ],
      ),
    );
  }
}
