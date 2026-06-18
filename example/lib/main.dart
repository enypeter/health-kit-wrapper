import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/body_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/profile_screen.dart';
import 'services/reminder_service.dart';

void main() => runApp(const HealthKitWrapperApp());

class HealthKitWrapperApp extends StatelessWidget {
  const HealthKitWrapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Kit Wrapper',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    AnalyticsScreen(),
    BodyScreen(),
    ExerciseScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    ReminderService.addListener(_onReminder);
    ReminderService.start();
  }

  @override
  void dispose() {
    ReminderService.removeListener(_onReminder);
    ReminderService.stop();
    super.dispose();
  }

  void _onReminder(Reminder reminder) {
    if (!mounted) return;
    _showReminderSheet(reminder);
  }

  void _showReminderSheet(Reminder reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReminderSheet(reminder: reminder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Body'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Exercise'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _ReminderSheet extends StatelessWidget {
  final Reminder reminder;
  const _ReminderSheet({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (reminder.type) {
      ReminderType.water => Colors.blue,
      ReminderType.exercise => Colors.orange,
      ReminderType.nightExercise => Colors.indigo,
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(reminder.icon, size: 28, color: color),
        ),
        const SizedBox(height: 16),
        Text(reminder.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 8),
        Text(reminder.message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: cs.onSurface)),
        if (reminder.actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: reminder.actions.map((a) =>
            ActionChip(
              avatar: const Icon(Icons.play_arrow, size: 16),
              label: Text(a.label),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(a.description), duration: const Duration(seconds: 3)),
                );
              },
            ),
          ).toList()),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
