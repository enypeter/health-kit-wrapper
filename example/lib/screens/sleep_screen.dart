import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';
import '../services/health_analytics.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});
  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  bool _loading = true;
  List<SleepSession> _sessions = [];
  List<SleepScore> _scores = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sessions = await HealthKitWrapper.getSleepHistory(7);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _scores = sessions.map(HealthAnalytics.computeSleepScore).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep Analysis')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No sleep data available'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Latest score hero
                      if (_scores.isNotEmpty) _SleepScoreHero(score: _scores.last),
                      const SizedBox(height: 16),

                      // Score breakdown
                      if (_scores.isNotEmpty) _ScoreBreakdown(score: _scores.last),
                      const SizedBox(height: 16),

                      // 7-day trend
                      if (_scores.length > 1) ...[
                        _SleepTrendCard(sessions: _sessions, scores: _scores),
                        const SizedBox(height: 16),
                      ],

                      // Stage distribution for latest session
                      if (_sessions.isNotEmpty) _StageDistribution(session: _sessions.last),
                      const SizedBox(height: 16),

                      // Tips
                      _SleepTips(score: _scores.isNotEmpty ? _scores.last : null),
                    ],
                  ),
                ),
    );
  }
}

class _SleepScoreHero extends StatelessWidget {
  final SleepScore score;
  const _SleepScoreHero({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _color(score.total);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          SizedBox(
            width: 120, height: 120,
            child: CustomPaint(
              painter: _ArcPainter(progress: score.total / 100, color: color),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${score.total}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color)),
                  Text(score.label, style: TextStyle(fontSize: 13, color: color)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Last Night: ${score.durationHours.toStringAsFixed(1)}h  |  '
            '${(score.efficiency * 100).toStringAsFixed(0)}% efficiency',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
          ),
        ]),
      ),
    );
  }

  Color _color(int s) => s >= 85 ? Colors.green : s >= 70 ? Colors.teal : s >= 50 ? Colors.orange : Colors.red;
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(8);
    final bg = Paint()..color = color.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    final fg = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0.75 * math.pi, 1.5 * math.pi, false, bg);
    canvas.drawArc(rect, 0.75 * math.pi, 1.5 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

class _ScoreBreakdown extends StatelessWidget {
  final SleepScore score;
  const _ScoreBreakdown({required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Score Breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          _BreakdownRow('Duration', score.durationPts, 25, '${score.durationHours.toStringAsFixed(1)}h'),
          _BreakdownRow('Efficiency', score.efficiencyPts, 25, '${(score.efficiency * 100).toStringAsFixed(0)}%'),
          _BreakdownRow('Deep Sleep', score.deepPts, 20, '${(score.deepPct * 100).toStringAsFixed(0)}%'),
          _BreakdownRow('REM Sleep', score.remPts, 20, '${(score.remPct * 100).toStringAsFixed(0)}%'),
          _BreakdownRow('Awake Penalty', score.awakePenaltyPts, 10, '${score.awakeMinutes}min'),
        ]),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int pts, maxPts;
  final String detail;
  const _BreakdownRow(this.label, this.pts, this.maxPts, this.detail);

  @override
  Widget build(BuildContext context) {
    final pct = pts / maxPts;
    final color = pct >= 0.8 ? Colors.green : pct >= 0.5 ? Colors.orange : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8, color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 50, child: Text('$pts/$maxPts', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        SizedBox(width: 40, child: Text(detail, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline), textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _SleepTrendCard extends StatelessWidget {
  final List<SleepSession> sessions;
  final List<SleepScore> scores;
  const _SleepTrendCard({required this.sessions, required this.scores});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('7-Night Trend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(scores.length, (i) {
                final s = scores[i];
                final h = (s.total / 100 * 60).clamp(8.0, 60.0);
                final color = s.total >= 85 ? Colors.green : s.total >= 70 ? Colors.teal : s.total >= 50 ? Colors.orange : Colors.red;
                final day = sessions[i].start;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${s.total}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
                      const SizedBox(height: 2),
                      Container(
                        height: h,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(height: 4),
                      Text('${day.day}/${day.month}', style: TextStyle(fontSize: 9, color: cs.outline)),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StageDistribution extends StatelessWidget {
  final SleepSession session;
  const _StageDistribution({required this.session});

  @override
  Widget build(BuildContext context) {
    final b = session.breakdown;
    final total = session.durationMinutes.clamp(1, 999999);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sleep Stages', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 24,
              child: Row(children: [
                _StageSeg(b.deepMinutes, total, Colors.indigo),
                _StageSeg(b.remMinutes, total, Colors.teal),
                _StageSeg(b.lightMinutes, total, Colors.blue.shade300),
                _StageSeg(b.awakeMinutes, total, Colors.orange),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _StageLegend('Deep', b.deepMinutes, Colors.indigo),
            _StageLegend('REM', b.remMinutes, Colors.teal),
            _StageLegend('Light', b.lightMinutes, Colors.blue.shade300),
            _StageLegend('Awake', b.awakeMinutes, Colors.orange),
          ]),
        ]),
      ),
    );
  }
}

class _StageSeg extends StatelessWidget {
  final int mins, total;
  final Color color;
  const _StageSeg(this.mins, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    if (mins == 0) return const SizedBox.shrink();
    return Expanded(
      flex: mins,
      child: Container(color: color),
    );
  }
}

class _StageLegend extends StatelessWidget {
  final String label;
  final int mins;
  final Color color;
  const _StageLegend(this.label, this.mins, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Flexible(child: Text('$label ${mins}m', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _SleepTips extends StatelessWidget {
  final SleepScore? score;
  const _SleepTips({required this.score});

  @override
  Widget build(BuildContext context) {
    final tips = <String>[];
    if (score == null) {
      tips.add('Wear your wearable to bed to track sleep stages.');
    } else {
      if (score!.durationHours < 7) tips.add('Aim for 7-9 hours. Try going to bed 30 minutes earlier.');
      if (score!.deepPct < 0.15) tips.add('Low deep sleep. Avoid alcohol and heavy meals before bed.');
      if (score!.remPct < 0.15) tips.add('Low REM. Maintain a consistent wake-up time to improve REM cycles.');
      if (score!.awakeMinutes > 30) tips.add('Frequent awakenings. Keep your room cool (18-20°C) and dark.');
      if (score!.efficiency < 0.85) tips.add('Low efficiency. Only go to bed when truly sleepy.');
      if (tips.isEmpty) tips.add('Great sleep! Keep your consistent schedule going.');
    }

    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.tips_and_updates, size: 18, color: Theme.of(context).colorScheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Text('Sleep Tips', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onTertiaryContainer)),
          ]),
          const SizedBox(height: 8),
          ...tips.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('  ', style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer)),
              Expanded(child: Text(t, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onTertiaryContainer))),
            ]),
          )),
        ]),
      ),
    );
  }
}
