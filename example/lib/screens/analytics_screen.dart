import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';
import '../services/health_analytics.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  SleepScore? _sleepScore;
  RecoveryScore? _recoveryScore;
  CalorieTrend? _calorieTrend;
  HydrationScore? _hydration;
  VitalsSnapshot? _vitals;
  BmiResult? _bmi;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      HealthKitWrapper.readSleep(from: today.subtract(const Duration(hours: 14)), to: now),
      HealthAnalytics.computeRecoveryScore(),
      HealthAnalytics.getCalorieTrend(7),
      HealthAnalytics.computeHydration(),
      HealthAnalytics.getVitalsSnapshot(),
      HealthAnalytics.computeBmi(),
    ]);

    if (!mounted) return;
    final sleepSessions = results[0] as List<SleepSession>;
    setState(() {
      _sleepScore = sleepSessions.isNotEmpty
          ? HealthAnalytics.computeSleepScore(sleepSessions.last)
          : null;
      _recoveryScore = results[1] as RecoveryScore;
      _calorieTrend = results[2] as CalorieTrend;
      _hydration = results[3] as HydrationScore;
      _vitals = results[4] as VitalsSnapshot;
      _bmi = results[5] as BmiResult?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Analytics'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Score Cards Row ──
                  Row(children: [
                    Expanded(child: _ScoreRing(
                      label: 'Sleep',
                      score: _sleepScore?.total ?? 0,
                      maxScore: 100,
                      subtitle: _sleepScore?.label ?? 'No data',
                      color: _scoreColor(_sleepScore?.total ?? 0),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ScoreRing(
                      label: 'Recovery',
                      score: _recoveryScore?.total ?? 0,
                      maxScore: 100,
                      subtitle: _recoveryScore?.label ?? 'No data',
                      color: _scoreColor(_recoveryScore?.total ?? 0),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ScoreRing(
                      label: 'BMI',
                      score: _bmi != null ? _bmi!.bmi.round() : 0,
                      maxScore: 40,
                      subtitle: _bmi?.category ?? 'No data',
                      color: _bmiColor(_bmi?.bmi ?? 0),
                      displayValue: _bmi?.bmi.toStringAsFixed(1) ?? '--',
                    )),
                  ]),
                  const SizedBox(height: 20),

                  // ── Hydration Progress ──
                  if (_hydration != null) ...[
                    _HydrationCard(hydration: _hydration!),
                    const SizedBox(height: 16),
                  ],

                  // ── Calorie Trend ──
                  if (_calorieTrend != null && _calorieTrend!.days.isNotEmpty) ...[
                    _CalorieTrendCard(trend: _calorieTrend!),
                    const SizedBox(height: 16),
                  ],

                  // ── Vitals Summary ──
                  if (_vitals != null) ...[
                    _VitalsCard(vitals: _vitals!),
                    const SizedBox(height: 16),
                  ],

                  // ── Disclaimer ──
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'For informational purposes only. Not medical advice. '
                      'Consult a healthcare provider for medical decisions.',
                      style: TextStyle(fontSize: 11, color: cs.outline),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Color _scoreColor(int score) => switch (score) {
    >= 85 => Colors.green,
    >= 70 => Colors.teal,
    >= 50 => Colors.orange,
    _ => Colors.red,
  };

  Color _bmiColor(double bmi) => switch (bmi) {
    >= 30 => Colors.red,
    >= 25 => Colors.orange,
    >= 18.5 => Colors.green,
    _ => Colors.blue,
  };
}

// ─────────────────────────────────────────────────────────────
// Score Ring Widget
// ─────────────────────────────────────────────────────────────

class _ScoreRing extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;
  final String subtitle;
  final Color color;
  final String? displayValue;
  const _ScoreRing({
    required this.label, required this.score, required this.maxScore,
    required this.subtitle, required this.color, this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          SizedBox(
            width: 64, height: 64,
            child: CustomPaint(
              painter: _RingPainter(
                progress: (score / maxScore).clamp(0.0, 1.0),
                color: color,
                bgColor: color.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  displayValue ?? '$score',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  _RingPainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(4);
    final bgPaint = Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    final fgPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bgPaint);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────
// Hydration Card
// ─────────────────────────────────────────────────────────────

class _HydrationCard extends StatelessWidget {
  final HydrationScore hydration;
  const _HydrationCard({required this.hydration});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = hydration.score >= 80 ? Colors.blue : hydration.score >= 50 ? Colors.orange : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.water_drop, color: color, size: 20),
            const SizedBox(width: 8),
            const Text('Hydration', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Text('${hydration.score}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (hydration.score / 100).clamp(0.0, 1.0),
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${hydration.actualLiters.toStringAsFixed(1)}L of ${hydration.targetLiters.toStringAsFixed(1)}L target',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Calorie Trend Card (Mini bar chart)
// ─────────────────────────────────────────────────────────────

class _CalorieTrendCard extends StatelessWidget {
  final CalorieTrend trend;
  const _CalorieTrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = trend.days.reversed.toList(); // oldest first
    final maxCal = days.map((d) => d.total).fold(0.0, math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 20),
            const SizedBox(width: 8),
            const Text('Calorie Burn (7 days)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Avg: ${trend.avgActive.toStringAsFixed(0)} active kcal/day',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((d) {
                final h = maxCal > 0 ? (d.total / maxCal * 80).clamp(4.0, 80.0) : 4.0;
                final activeH = maxCal > 0 ? (d.active / maxCal * 80).clamp(2.0, 80.0) : 2.0;
                final dayLabel = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.date.weekday - 1];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(d.steps > 999 ? '${(d.steps / 1000).toStringAsFixed(1)}k' : '${d.steps}',
                        style: TextStyle(fontSize: 8, color: cs.outline)),
                      const SizedBox(height: 2),
                      Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: activeH,
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dayLabel, style: TextStyle(fontSize: 9, color: cs.outline)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _LegendDot(color: Colors.deepOrange, label: 'Active'),
            const SizedBox(width: 12),
            _LegendDot(color: Colors.deepOrange.withValues(alpha: 0.2), label: 'Total'),
          ]),
        ]),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
  ]);
}

// ─────────────────────────────────────────────────────────────
// Vitals Summary Card
// ─────────────────────────────────────────────────────────────

class _VitalsCard extends StatelessWidget {
  final VitalsSnapshot vitals;
  const _VitalsCard({required this.vitals});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAny = vitals.avgHr != null || vitals.latestHrv != null ||
        vitals.latestSpO2 != null || vitals.latestBp != null;
    if (!hasAny) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.monitor_heart, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Vitals', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (vitals.avgHr != null)
              _VitalChip(label: 'Avg HR', value: '${vitals.avgHr} bpm', icon: Icons.favorite),
            if (vitals.restingHr != null)
              _VitalChip(label: 'Resting', value: '${vitals.restingHr} bpm', icon: Icons.hotel),
            if (vitals.latestHrv != null)
              _VitalChip(
                label: 'HRV (${vitals.hrvLabel})',
                value: '${vitals.latestHrv!.toStringAsFixed(1)} ms',
                icon: Icons.timeline,
              ),
            if (vitals.latestSpO2 != null)
              _VitalChip(label: 'SpO2', value: '${vitals.latestSpO2!.toStringAsFixed(0)}%', icon: Icons.air),
            if (vitals.latestBp != null) ...[
              _VitalChip(
                label: 'BP',
                value: '${vitals.latestBp!.systolicMmhg.round()}/${vitals.latestBp!.diastolicMmhg.round()}',
                icon: Icons.speed,
                subtitle: BpStage(systolic: vitals.latestBp!.systolicMmhg, diastolic: vitals.latestBp!.diastolicMmhg).category,
              ),
            ],
            if (vitals.latestVo2Max != null)
              _VitalChip(
                label: 'VO2 Max',
                value: vitals.latestVo2Max!.vo2Max.toStringAsFixed(1),
                icon: Icons.speed,
                subtitle: 'ml/min/kg',
              ),
            if (vitals.latestRespRate != null)
              _VitalChip(label: 'Resp', value: '${vitals.latestRespRate!.toStringAsFixed(0)}/min', icon: Icons.air),
            if (vitals.latestGlucose != null)
              _VitalChip(
                label: 'Glucose',
                value: '${vitals.latestGlucose!.mgPerDl.toStringAsFixed(0)} mg/dL',
                icon: Icons.bloodtype,
              ),
          ]),
          if (Platform.isIOS && vitals.latestHrv != null || !Platform.isIOS && vitals.latestHrv != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'HRV: ${Platform.isIOS ? "SDNN" : "RMSSD"} — not comparable across platforms',
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ),
        ]),
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final String? subtitle;
  const _VitalChip({required this.label, required this.value, required this.icon, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: cs.outline),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: cs.outline)),
        ]),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (subtitle != null)
          Text(subtitle!, style: TextStyle(fontSize: 9, color: cs.outline)),
      ]),
    );
  }
}
