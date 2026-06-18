import 'dart:async';
import 'package:flutter/material.dart';
import 'health_analytics.dart';

/// In-app reminder system for water intake, exercise, and sleep preparation.
///
/// Uses periodic timers to check conditions and display snackbar/dialog
/// reminders within the app. Does not require platform notification
/// permissions — works entirely within the Flutter lifecycle.
class ReminderService {
  ReminderService._();

  static Timer? _waterTimer;
  static Timer? _exerciseTimer;
  static Timer? _nightTimer;
  static bool _initialized = false;
  static final List<ReminderCallback> _listeners = [];

  /// Register a callback to receive reminder events.
  static void addListener(ReminderCallback callback) {
    _listeners.add(callback);
  }

  static void removeListener(ReminderCallback callback) {
    _listeners.remove(callback);
  }

  /// Start the reminder system. Call once from the app's main screen.
  static void start() {
    if (_initialized) return;
    _initialized = true;

    // Water reminders: check every 2 hours (3 times a day coverage)
    _waterTimer = Timer.periodic(const Duration(hours: 2), (_) => _checkWater());

    // Exercise reminder: check at 14:00 and 17:00 equivalent (every 3 hours)
    _exerciseTimer = Timer.periodic(const Duration(hours: 3), (_) => _checkExercise());

    // Night reminder: check every hour after 8 PM
    _nightTimer = Timer.periodic(const Duration(hours: 1), (_) => _checkNight());

    // Initial check after a short delay
    Future.delayed(const Duration(seconds: 30), () {
      _checkWater();
    });
  }

  static void stop() {
    _waterTimer?.cancel();
    _exerciseTimer?.cancel();
    _nightTimer?.cancel();
    _initialized = false;
  }

  static void _notify(Reminder reminder) {
    for (final listener in _listeners) {
      listener(reminder);
    }
  }

  static final _shownToday = <String, DateTime>{};

  static bool _alreadyShown(String key, {int maxPerDay = 3}) {
    final today = DateTime.now();
    final lastShown = _shownToday[key];
    if (lastShown != null && lastShown.day == today.day) {
      // Count how many times shown today
      final countKey = '${key}_count';
      final count = _shownCounts[countKey] ?? 0;
      if (count >= maxPerDay) return true;
    }
    return false;
  }

  static final _shownCounts = <String, int>{};

  static void _markShown(String key) {
    final today = DateTime.now();
    final lastShown = _shownToday[key];
    if (lastShown == null || lastShown.day != today.day) {
      _shownCounts['${key}_count'] = 1;
    } else {
      _shownCounts['${key}_count'] = (_shownCounts['${key}_count'] ?? 0) + 1;
    }
    _shownToday[key] = today;
  }

  static void _checkWater() {
    if (_alreadyShown('water', maxPerDay: 3)) return;
    final hour = DateTime.now().hour;
    // Only remind during waking hours (8 AM - 9 PM)
    if (hour < 8 || hour > 21) return;

    _markShown('water');
    _notify(Reminder(
      type: ReminderType.water,
      title: 'Stay Hydrated',
      message: _waterMessages[DateTime.now().hour % _waterMessages.length],
      icon: Icons.water_drop,
    ));
  }

  static Future<void> _checkExercise() async {
    final hour = DateTime.now().hour;
    // Only check between 2 PM and 6 PM
    if (hour < 14 || hour > 18) return;
    if (_alreadyShown('exercise', maxPerDay: 1)) return;

    final hasExercised = await HealthAnalytics.hasExercisedToday();
    if (hasExercised) return;

    _markShown('exercise');
    _notify(Reminder(
      type: ReminderType.exercise,
      title: 'Time to Move',
      message: 'No exercise logged today. Try a 10-min walk, '
          'some squats, or a quick stretch session.',
      icon: Icons.directions_walk,
      actions: _quickExercises,
    ));
  }

  static Future<void> _checkNight() async {
    final hour = DateTime.now().hour;
    // Only check between 8 PM and 10 PM
    if (hour < 20 || hour > 22) return;
    if (_alreadyShown('night', maxPerDay: 1)) return;

    final hasExercised = await HealthAnalytics.hasExercisedToday();
    if (hasExercised) return;

    _markShown('night');
    _notify(Reminder(
      type: ReminderType.nightExercise,
      title: 'Evening Wind-Down',
      message: 'No exercise today. Try gentle stretching or '
          'a short walk before bed to improve sleep quality.',
      icon: Icons.bedtime,
      actions: _eveningExercises,
    ));
  }

  static const _waterMessages = [
    'Time for a glass of water! Staying hydrated improves focus and energy.',
    'Hydration check! Aim for 2-3 liters today.',
    'Water break! Even mild dehydration affects performance.',
  ];

  static const _quickExercises = [
    QuickAction(label: '10 Squats', description: 'Bodyweight squats — great for legs and core'),
    QuickAction(label: '10-Min Walk', description: 'A brisk walk around the block'),
    QuickAction(label: '5-Min Stretch', description: 'Neck, shoulders, hamstrings, hip flexors'),
    QuickAction(label: '20 Push-ups', description: 'Modified or full — build upper body strength'),
  ];

  static const _eveningExercises = [
    QuickAction(label: 'Gentle Yoga', description: '10 minutes of relaxing poses'),
    QuickAction(label: 'Evening Walk', description: '15-minute neighborhood stroll'),
    QuickAction(label: 'Stretching', description: 'Full-body stretch routine before bed'),
  ];
}

typedef ReminderCallback = void Function(Reminder reminder);

enum ReminderType { water, exercise, nightExercise }

class Reminder {
  const Reminder({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    this.actions = const [],
  });
  final ReminderType type;
  final String title;
  final String message;
  final IconData icon;
  final List<QuickAction> actions;
}

class QuickAction {
  const QuickAction({required this.label, required this.description});
  final String label;
  final String description;
}
