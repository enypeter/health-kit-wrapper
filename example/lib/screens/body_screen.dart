import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';
import '../services/health_analytics.dart';

class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});
  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  bool _loading = true;
  BmiResult? _bmi;
  MacroBalance? _macros;
  HydrationScore? _hydration;
  BodyFatSample? _bodyFat;
  List<WeightSample> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final past90 = now.subtract(const Duration(days: 90));

    final results = await Future.wait([
      HealthAnalytics.computeBmi(),
      HealthAnalytics.computeMacros(),
      HealthAnalytics.computeHydration(),
      HealthKitWrapper.readBodyFat(from: past90, to: now),
      HealthKitWrapper.readWeight(from: past90, to: now),
    ]);

    if (!mounted) return;
    setState(() {
      _bmi = results[0] as BmiResult?;
      _macros = results[1] as MacroBalance?;
      _hydration = results[2] as HydrationScore;
      final bodyFatList = results[3] as List<BodyFatSample>;
      _bodyFat = bodyFatList.isNotEmpty ? bodyFatList.last : null;
      _weightHistory = results[4] as List<WeightSample>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Body & Nutrition')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // BMI + Body Fat row
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _BmiCard(bmi: _bmi)),
                    const SizedBox(width: 12),
                    Expanded(child: _BodyFatCard(bodyFat: _bodyFat)),
                  ]),
                  const SizedBox(height: 16),

                  // Weight trend
                  if (_weightHistory.length > 1) ...[
                    _WeightTrendCard(weights: _weightHistory),
                    const SizedBox(height: 16),
                  ],

                  // Macros
                  if (_macros != null) ...[
                    _MacroCard(macros: _macros!),
                    const SizedBox(height: 16),
                  ],

                  // Hydration
                  if (_hydration != null) ...[
                    _HydrationDetailCard(hydration: _hydration!),
                    const SizedBox(height: 16),
                  ],

                  // No nutrition data message
                  if (_macros == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 12),
                          Expanded(child: Text(
                            'Log meals in your health app to see nutrition analysis here.',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                          )),
                        ]),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'BMI does not account for muscle mass. Body fat % is more accurate for active individuals.',
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

// ─────────────────────────────────────────────────────────────
// BMI Card
// ─────────────────────────────────────────────────────────────

class _BmiCard extends StatelessWidget {
  final BmiResult? bmi;
  const _BmiCard({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (bmi == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(Icons.scale, size: 32, color: cs.outline),
            const SizedBox(height: 8),
            Text('BMI', style: TextStyle(fontWeight: FontWeight.w600, color: cs.outline)),
            Text('No weight/height data', style: TextStyle(fontSize: 11, color: cs.outline)),
          ]),
        ),
      );
    }

    final color = _bmiColor(bmi!.bmi);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(bmi!.bmi.toStringAsFixed(1),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text(bmi!.category, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 8),
          // BMI scale indicator
          _BmiScale(bmi: bmi!.bmi),
          const SizedBox(height: 8),
          Text('${bmi!.weightKg.toStringAsFixed(1)} kg | ${(bmi!.heightM * 100).toStringAsFixed(0)} cm',
            style: TextStyle(fontSize: 11, color: cs.outline)),
        ]),
      ),
    );
  }

  Color _bmiColor(double v) => v >= 30 ? Colors.red : v >= 25 ? Colors.orange : v >= 18.5 ? Colors.green : Colors.blue;
}

class _BmiScale extends StatelessWidget {
  final double bmi;
  const _BmiScale({required this.bmi});

  @override
  Widget build(BuildContext context) {
    // Scale from 15 to 40
    final pos = ((bmi - 15) / 25).clamp(0.0, 1.0);
    return SizedBox(
      height: 16,
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(children: [
            Expanded(flex: 35, child: Container(color: Colors.blue.shade200)), // < 18.5
            Expanded(flex: 65, child: Container(color: Colors.green.shade300)), // 18.5-24.9
            Expanded(flex: 50, child: Container(color: Colors.orange.shade300)), // 25-29.9
            Expanded(flex: 100, child: Container(color: Colors.red.shade300)), // 30+
          ]),
        ),
        Positioned(
          left: pos * (MediaQuery.of(context).size.width / 2 - 48), // approximate
          top: 0,
          child: Container(
            width: 4, height: 16,
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Body Fat Card
// ─────────────────────────────────────────────────────────────

class _BodyFatCard extends StatelessWidget {
  final BodyFatSample? bodyFat;
  const _BodyFatCard({required this.bodyFat});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (bodyFat == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(Icons.person, size: 32, color: cs.outline),
            const SizedBox(height: 8),
            Text('Body Fat', style: TextStyle(fontWeight: FontWeight.w600, color: cs.outline)),
            Text('No data', style: TextStyle(fontSize: 11, color: cs.outline)),
          ]),
        ),
      );
    }

    final pct = bodyFat!.percentage;
    final color = pct > 32 ? Colors.red : pct > 25 ? Colors.orange : pct > 14 ? Colors.green : Colors.blue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text('${pct.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text('Body Fat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 8),
          SizedBox(
            width: 60, height: 60,
            child: CustomPaint(
              painter: _GaugePainter(value: pct / 50, color: color),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(4);
    final bg = Paint()..color = color.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    final fg = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0.75 * math.pi, 1.5 * math.pi, false, bg);
    canvas.drawArc(rect, 0.75 * math.pi, 1.5 * math.pi * value.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}

// ─────────────────────────────────────────────────────────────
// Weight Trend Card
// ─────────────────────────────────────────────────────────────

class _WeightTrendCard extends StatelessWidget {
  final List<WeightSample> weights;
  const _WeightTrendCard({required this.weights});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = weights.first.kg;
    final last = weights.last.kg;
    final change = last - first;
    final changeStr = change >= 0 ? '+${change.toStringAsFixed(1)}' : change.toStringAsFixed(1);
    final color = change.abs() < 0.5 ? Colors.green : (change > 0 ? Colors.orange : Colors.blue);

    final minW = weights.map((w) => w.kg).reduce(math.min);
    final maxW = weights.map((w) => w.kg).reduce(math.max);
    final range = (maxW - minW).clamp(1.0, 999.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Weight Trend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Text('$changeStr kg', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ]),
          const SizedBox(height: 4),
          Text(
            '${first.toStringAsFixed(1)} kg -> ${last.toStringAsFixed(1)} kg (${weights.length} readings)',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _LinePainter(
                points: weights.map((w) => (w.kg - minW) / range).toList(),
                color: color,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _LinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color.withValues(alpha: 0.08)..style = PaintingStyle.fill;
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = size.height - (points[i] * size.height * 0.8 + size.height * 0.1);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, paint);

    // Dots at start and end
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    final firstY = size.height - (points.first * size.height * 0.8 + size.height * 0.1);
    final lastY = size.height - (points.last * size.height * 0.8 + size.height * 0.1);
    canvas.drawCircle(Offset(0, firstY), 4, dotPaint);
    canvas.drawCircle(Offset(size.width, lastY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}

// ─────────────────────────────────────────────────────────────
// Macro Balance Card
// ─────────────────────────────────────────────────────────────

class _MacroCard extends StatelessWidget {
  final MacroBalance macros;
  const _MacroCard({required this.macros});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.restaurant, size: 20, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Today\'s Nutrition', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Text('${macros.totalKcal.toStringAsFixed(0)} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 16),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 20,
              child: Row(children: [
                if (macros.proteinPct > 0) Expanded(flex: macros.proteinPct.round().clamp(1, 100), child: Container(color: Colors.blue)),
                if (macros.carbsPct > 0) Expanded(flex: macros.carbsPct.round().clamp(1, 100), child: Container(color: Colors.amber)),
                if (macros.fatPct > 0) Expanded(flex: macros.fatPct.round().clamp(1, 100), child: Container(color: Colors.red.shade300)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _MacroLegend('Protein', macros.proteinG, macros.proteinPct, Colors.blue, '25-35%'),
            _MacroLegend('Carbs', macros.carbsG, macros.carbsPct, Colors.amber, '40-55%'),
            _MacroLegend('Fat', macros.fatG, macros.fatPct, Colors.red.shade300, '20-35%'),
          ]),
        ]),
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  final String label;
  final double grams, pct;
  final Color color;
  final String target;
  const _MacroLegend(this.label, this.grams, this.pct, this.color, this.target);

  @override
  Widget build(BuildContext context) {
    final inRange = _isInRange();
    return Expanded(
      child: Column(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        Text('${grams.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        Text('${pct.toStringAsFixed(0)}%', style: TextStyle(
          fontSize: 11,
          color: inRange ? Colors.green : Colors.orange,
          fontWeight: FontWeight.w600,
        )),
        Text(target, style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.outline)),
      ]),
    );
  }

  bool _isInRange() {
    if (label == 'Protein') return pct >= 25 && pct <= 35;
    if (label == 'Carbs') return pct >= 40 && pct <= 55;
    return pct >= 20 && pct <= 35;
  }
}

// ─────────────────────────────────────────────────────────────
// Hydration Detail Card
// ─────────────────────────────────────────────────────────────

class _HydrationDetailCard extends StatelessWidget {
  final HydrationScore hydration;
  const _HydrationDetailCard({required this.hydration});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glasses = (hydration.actualLiters / 0.25).round(); // 250ml glasses
    final targetGlasses = (hydration.targetLiters / 0.25).round();
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
            Text('${hydration.actualLiters.toStringAsFixed(1)}L', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          ]),
          const SizedBox(height: 12),
          // Water glass icons
          Wrap(spacing: 4, runSpacing: 4, children: List.generate(
            targetGlasses.clamp(0, 16),
            (i) => Icon(
              Icons.water_drop,
              size: 18,
              color: i < glasses ? color : color.withValues(alpha: 0.15),
            ),
          )),
          const SizedBox(height: 8),
          Text(
            '$glasses of $targetGlasses glasses (250ml each)',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ]),
      ),
    );
  }
}
