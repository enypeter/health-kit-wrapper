import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';
import 'setup_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SdkStatus? _sdkStatus;
  bool _hasPermissions = false;
  bool _loading = false;

  /// The date the user is viewing. Defaults to today (local timezone).
  late DateTime _selectedDate;

  AggregatedActivity? _todayActivity;
  List<SleepSession> _recentSleep = [];
  List<HeartRateSample> _heartRate = [];
  List<HrvSample> _hrv = [];
  final List<String> _observerLog = [];

  StreamSubscription<ObserverUpdate>? _observerSub;

  static const _readTypes = [
    RecordType.steps,
    RecordType.distance,
    RecordType.floors,
    RecordType.activeCalories,
    RecordType.totalCalories,
    RecordType.exercise,
    RecordType.sleep,
    RecordType.heartRate,
    RecordType.restingHeartRate,
    RecordType.heartRateVariability,
    RecordType.oxygenSaturation,
    RecordType.bloodPressure,
    RecordType.respiratoryRate,
    RecordType.weight,
    RecordType.height,
    RecordType.bodyFat,
  ];

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _checkStatus();
  }

  @override
  void dispose() {
    _observerSub?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);

    final status = await HealthKitWrapper.getSdkStatus();
    final hasPerm = await HealthKitWrapper.hasPermissions(readTypes: _readTypes);

    setState(() {
      _sdkStatus = status;
      _hasPermissions = hasPerm;
      _loading = false;
    });

    if (status == SdkStatus.available && hasPerm) {
      _loadAllData();
      _startObserver();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _loading = true);
    final granted = await HealthKitWrapper.requestPermissions(readTypes: _readTypes);
    setState(() {
      _hasPermissions = granted;
      _loading = false;
    });
    if (granted) {
      _loadAllData();
      _startObserver();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
      _loadAllData();
    }
  }

  void _goToPreviousDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadAllData();
  }

  void _goToNextDay() {
    if (_isToday) return;
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // Day boundaries in the phone's local timezone
    final dayStart = _selectedDate; // 00:00 local
    final dayEnd = _isToday
        ? DateTime.now() // up to current moment for today
        : _selectedDate.add(const Duration(days: 1)); // full day for past dates

    // Sleep: look back from the previous night into this morning
    final sleepStart = dayStart.subtract(const Duration(hours: 12));

    final results = await Future.wait([
      HealthKitWrapper.aggregateActivity(from: dayStart, to: dayEnd),
      HealthKitWrapper.readSleep(from: sleepStart, to: dayEnd),
      HealthKitWrapper.readHeartRate(from: dayStart, to: dayEnd),
      HealthKitWrapper.readHeartRateVariability(from: dayStart, to: dayEnd),
    ]);

    if (!mounted) return;
    setState(() {
      _todayActivity = results[0] as AggregatedActivity;
      _recentSleep = results[1] as List<SleepSession>;
      _heartRate = results[2] as List<HeartRateSample>;
      _hrv = results[3] as List<HrvSample>;
    });
  }

  void _startObserver() {
    _observerSub?.cancel();
    _observerSub = HealthKitWrapper.observerQuery(
      types: [RecordType.steps, RecordType.heartRate, RecordType.sleep],
      intervalMs: 30000,
      observerId: 'home_screen',
      onUpdate: (update) {
        setState(() {
          _observerLog.insert(
            0,
            '${update.timestamp.toLocal().toString().substring(11, 19)} '
            '- ${update.insertedTypes.join(', ')} updated',
          );
          if (_observerLog.length > 10) _observerLog.removeLast();
        });
        _loadAllData();
      },
    );
  }

  String get _dateLabel {
    if (_isToday) return 'Today';
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    if (_selectedDate == yesterday) return 'Yesterday';
    return '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Platform.isIOS ? 'HealthKit' : 'Health Connect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Setup Guide',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SetupGuideScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAllData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_sdkStatus == SdkStatus.unavailable) {
      return _StatusMessage(
        icon: Icons.error_outline,
        message: Platform.isIOS
            ? 'HealthKit is not available on this device.'
            : 'Health Connect is not supported on this device.',
      );
    }

    if (_sdkStatus == SdkStatus.notInstalled) {
      return _HealthConnectInstallPrompt();
    }

    if (!_hasPermissions) {
      return _StatusMessage(
        icon: Icons.health_and_safety,
        message: Platform.isIOS
            ? 'Grant access to Apple Health data.'
            : 'Health Connect permissions are required.',
        action: Column(
          children: [
            FilledButton(
              onPressed: _requestPermissions,
              child: const Text('Grant Permissions'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SetupGuideScreen()),
              ),
              child: const Text('View Setup Guide'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _goToPreviousDay,
              ),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        _dateLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _isToday ? null : _goToNextDay,
              ),
            ],
          ),
          // Platform badge
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Center(
              child: Text(
                Platform.isIOS ? 'Apple HealthKit' : 'Health Connect',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
          _ActivitySection(activity: _todayActivity),
          const SizedBox(height: 20),
          _SleepSection(sessions: _recentSleep),
          const SizedBox(height: 20),
          _HeartRateSection(samples: _heartRate, hrv: _hrv),
          const SizedBox(height: 20),
          _ObserverSection(log: _observerLog),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Activity section
// ─────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  final AggregatedActivity? activity;
  const _ActivitySection({this.activity});

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return _Section(
      title: 'Activity',
      child: a == null
          ? const Text('No data yet')
          : Column(
              children: [
                Row(children: [
                  _Metric('Steps', a.steps.toString(), 'count'),
                  _Metric('Calories', a.activeCaloriesKcal.toStringAsFixed(0), 'kcal'),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _Metric('Distance', a.distanceKm.toStringAsFixed(2), 'km'),
                  _Metric('Floors', a.floors.toStringAsFixed(0), 'floors'),
                ]),
                if (a.dataOrigins.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SourceChips(sources: a.dataOrigins),
                ],
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sleep section
// ─────────────────────────────────────────────────────────────

class _SleepSection extends StatelessWidget {
  final List<SleepSession> sessions;
  const _SleepSection({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Sleep',
      child: sessions.isEmpty
          ? const Text('No sleep data')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sessions.map((s) => _SleepCard(session: s)).toList(),
            ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  final SleepSession session;
  const _SleepCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final b = session.breakdown;
    final bedStr = _fmt(session.start);
    final wakeStr = _fmt(session.end);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$bedStr -> $wakeStr',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(session.source,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 10),
            _SleepBar(label: 'Deep', mins: b.deepMinutes, color: Colors.indigo),
            _SleepBar(label: 'REM', mins: b.remMinutes, color: Colors.teal),
            _SleepBar(label: 'Light', mins: b.lightMinutes, color: Colors.blue),
            _SleepBar(label: 'Awake', mins: b.awakeMinutes, color: Colors.orange),
            const SizedBox(height: 6),
            Text(
              'Total: ${b.totalSleepMinutes ~/ 60}h ${b.totalSleepMinutes % 60}m  '
              '|  Efficiency: ${(session.efficiency * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _SleepBar extends StatelessWidget {
  final String label;
  final int mins;
  final Color color;
  const _SleepBar(
      {required this.label, required this.mins, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
            width: 44,
            child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (mins / 120).clamp(0, 1),
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
            width: 36,
            child: Text('${mins}m',
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.right)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Heart rate section
// ─────────────────────────────────────────────────────────────

class _HeartRateSection extends StatelessWidget {
  final List<HeartRateSample> samples;
  final List<HrvSample> hrv;
  const _HeartRateSection({required this.samples, required this.hrv});

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return _Section(
        title: 'Vitals',
        child: const Text('No vitals data - wearable required for HR/HRV'),
      );
    }

    final bpms = samples.map((s) => s.bpm).toList();
    final minBpm = bpms.reduce((a, b) => a < b ? a : b);
    final maxBpm = bpms.reduce((a, b) => a > b ? a : b);
    final avgBpm = (bpms.fold(0, (s, b) => s + b) / bpms.length).round();

    final latestHrv =
        hrv.isNotEmpty ? hrv.last.valueMs.toStringAsFixed(1) : '--';
    final hrvLabel = Platform.isIOS ? 'ms SDNN' : 'ms RMSSD';

    return _Section(
      title: 'Vitals',
      child: Column(
        children: [
          Row(children: [
            _Metric('Avg HR', '$avgBpm', 'bpm'),
            _Metric('Min HR', '$minBpm', 'bpm'),
            _Metric('Max HR', '$maxBpm', 'bpm'),
            _Metric('HRV', latestHrv, hrvLabel),
          ]),
          const SizedBox(height: 8),
          Text(
            'HRV: ${Platform.isIOS ? "SDNN (iOS)" : "RMSSD (Android)"} '
            '- not comparable across platforms',
            style: TextStyle(
                fontSize: 11, color: Theme.of(context).colorScheme.outline),
          ),
          if (samples.isNotEmpty)
            _SourceChips(sources: samples.map((s) => s.source).toSet().toList()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Observer section
// ─────────────────────────────────────────────────────────────

class _ObserverSection extends StatelessWidget {
  final List<String> log;
  const _ObserverSection({required this.log});

  @override
  Widget build(BuildContext context) {
    final label = Platform.isIOS
        ? 'Live observer (push)'
        : 'Live observer (30s polling)';

    return _Section(
      title: label,
      child: log.isEmpty
          ? const Text('Watching for changes...',
              style: TextStyle(fontSize: 12))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: log
                  .map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(l, style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared UI components
// ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _Metric(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            Text(unit,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _SourceChips extends StatelessWidget {
  final List<String> sources;
  const _SourceChips({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: sources.map((s) {
        final label = s.split('.').last;
        return Chip(
          label: Text(label, style: const TextStyle(fontSize: 10)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const _StatusMessage(
      {required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthConnectInstallPrompt extends StatefulWidget {
  @override
  State<_HealthConnectInstallPrompt> createState() =>
      _HealthConnectInstallPromptState();
}

class _HealthConnectInstallPromptState
    extends State<_HealthConnectInstallPrompt> {
  String _appName = '';
  String _appDescription = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    final suggestion = await HealthKitWrapper.suggestedHealthApp();
    if (!mounted) return;
    setState(() {
      _appName = suggestion.appName;
      _appDescription = suggestion.description;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Health Connect needs to be installed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: HealthKitWrapper.installHealthConnect,
              icon: const Icon(Icons.store),
              label: const Text('Install from Play Store'),
            ),
            if (_loaded) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.lightbulb_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Recommended: $_appName',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        _appDescription,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
