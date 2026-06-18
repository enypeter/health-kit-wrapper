import 'package:flutter/material.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';
import '../services/health_analytics.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});
  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  bool _loading = true;
  RecoveryScore? _recovery;
  List<ExerciseSuggestion> _suggestions = [];
  List<ExerciseSession> _recentWorkouts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final week = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));

    final results = await Future.wait([
      HealthAnalytics.computeRecoveryScore(),
      HealthAnalytics.getSuggestions(),
      HealthKitWrapper.readExerciseSessions(from: week, to: now),
    ]);

    if (!mounted) return;
    setState(() {
      _recovery = results[0] as RecoveryScore;
      _suggestions = results[1] as List<ExerciseSuggestion>;
      _recentWorkouts = results[2] as List<ExerciseSession>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise & Recovery')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Recovery status hero
                  if (_recovery != null) _RecoveryHero(recovery: _recovery!),
                  const SizedBox(height: 16),

                  // Recovery breakdown
                  if (_recovery != null) _RecoveryBreakdown(recovery: _recovery!),
                  const SizedBox(height: 16),

                  // Suggestions
                  if (_suggestions.isNotEmpty) ...[
                    Text('Suggested Workouts', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._suggestions.map((s) => _SuggestionCard(suggestion: s)),
                    const SizedBox(height: 16),
                  ],

                  // Recent workouts
                  if (_recentWorkouts.isNotEmpty) ...[
                    Text('This Week', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._recentWorkouts.reversed.take(10).map((w) => _WorkoutTile(workout: w)),
                  ] else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 12),
                          Expanded(child: Text(
                            'No workouts this week. Start with one of the suggestions above!',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                          )),
                        ]),
                      ),
                    ),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Suggestions based on your recovery, activity patterns, and body composition. '
                      'Not medical advice — consult a professional for personalized training plans.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RecoveryHero extends StatelessWidget {
  final RecoveryScore recovery;
  const _RecoveryHero({required this.recovery});

  @override
  Widget build(BuildContext context) {
    final color = _color(recovery.total);
    final icon = recovery.total >= 80 ? Icons.bolt
        : recovery.total >= 60 ? Icons.trending_up
        : recovery.total >= 40 ? Icons.trending_flat
        : Icons.hotel;

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${recovery.total}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(recovery.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ]),
            const SizedBox(height: 4),
            Text(
              _advice(recovery.total),
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            ),
          ])),
        ]),
      ),
    );
  }

  String _advice(int score) => switch (score) {
    >= 80 => 'Your body is ready for high-intensity training. Push it today!',
    >= 60 => 'Moderate recovery. Stick to moderate intensity or skill work.',
    >= 40 => 'Recovery is low. Light activity or active recovery recommended.',
    _ => 'Your body needs rest. Focus on sleep, hydration, and gentle movement.',
  };

  Color _color(int s) => s >= 80 ? Colors.green : s >= 60 ? Colors.teal : s >= 40 ? Colors.orange : Colors.red;
}

class _RecoveryBreakdown extends StatelessWidget {
  final RecoveryScore recovery;
  const _RecoveryBreakdown({required this.recovery});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recovery Breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          _RecoveryRow(
            label: 'HRV',
            pts: recovery.hrvPts, maxPts: 30,
            detail: recovery.hrvToday > 0
                ? '${recovery.hrvToday.toStringAsFixed(0)}ms (avg: ${recovery.hrvAvg.toStringAsFixed(0)}ms)'
                : 'No data',
          ),
          _RecoveryRow(
            label: 'Resting HR',
            pts: recovery.restingHrPts, maxPts: 25,
            detail: recovery.restingHrToday > 0
                ? '${recovery.restingHrToday.toStringAsFixed(0)} bpm (avg: ${recovery.restingHrAvg.toStringAsFixed(0)})'
                : 'No data',
          ),
          _RecoveryRow(label: 'Sleep Quality', pts: recovery.sleepPts, maxPts: 25, detail: '${recovery.sleepPts}/25'),
          _RecoveryRow(label: 'Activity Load', pts: recovery.activityLoadPts, maxPts: 20, detail: '${recovery.activityLoadPts}/20'),
        ]),
      ),
    );
  }
}

class _RecoveryRow extends StatelessWidget {
  final String label, detail;
  final int pts, maxPts;
  const _RecoveryRow({required this.label, required this.pts, required this.maxPts, required this.detail});

  @override
  Widget build(BuildContext context) {
    final pct = pts / maxPts;
    final color = pct >= 0.7 ? Colors.green : pct >= 0.4 ? Colors.orange : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('$pts/$maxPts', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: pct, minHeight: 6, color: color, backgroundColor: color.withValues(alpha: 0.12)),
        ),
        Text(detail, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
      ]),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final ExerciseSuggestion suggestion;
  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensityColor = switch (suggestion.intensity) {
      'Vigorous' || 'Moderate-to-Vigorous' => Colors.red,
      'Moderate' => Colors.orange,
      _ => Colors.green,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_typeIcon(suggestion.type), size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(suggestion.focus, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          ]),
          const SizedBox(height: 8),
          Text(suggestion.type, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: intensityColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(suggestion.intensity, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: intensityColor)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.timer, size: 14, color: cs.outline),
            const SizedBox(width: 4),
            Text('${suggestion.durationMin} min', style: TextStyle(fontSize: 12, color: cs.outline)),
          ]),
          const SizedBox(height: 8),
          Text(suggestion.rationale, style: TextStyle(fontSize: 12, color: cs.outline)),
        ]),
      ),
    );
  }

  IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('walk')) return Icons.directions_walk;
    if (t.contains('run') || t.contains('jog')) return Icons.directions_run;
    if (t.contains('cycl') || t.contains('bik')) return Icons.directions_bike;
    if (t.contains('swim')) return Icons.pool;
    if (t.contains('yoga') || t.contains('stretch')) return Icons.self_improvement;
    if (t.contains('weight') || t.contains('strength') || t.contains('body')) return Icons.fitness_center;
    if (t.contains('hiit') || t.contains('circuit')) return Icons.local_fire_department;
    return Icons.sports;
  }
}

class _WorkoutTile extends StatelessWidget {
  final ExerciseSession workout;
  const _WorkoutTile({required this.workout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final day = workout.start;
    final dayLabel = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
    final type = workout.exerciseType;
    final displayType = type.replaceAll('_', ' ');
    final firstLetter = displayType.isNotEmpty ? displayType[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: cs.primaryContainer,
          child: Text(firstLetter, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
        ),
        title: Text(displayType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(
          '$dayLabel ${day.day}/${day.month} | ${workout.durationMinutes} min',
          style: TextStyle(fontSize: 11, color: cs.outline),
        ),
        trailing: Text(
          '${workout.durationMinutes}m',
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
        ),
      ),
    );
  }
}
