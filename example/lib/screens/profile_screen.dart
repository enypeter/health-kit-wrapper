import 'package:flutter/material.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = UserProfile();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await UserProfile.load();

    // Pre-fill from health data if profile fields are empty
    if (!profile.hasWeight || !profile.hasHeight) {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 90));
      final results = await Future.wait([
        HealthKitWrapper.readWeight(from: past, to: now),
        HealthKitWrapper.readHeight(from: past, to: now),
      ]);
      final weights = results[0] as List<WeightSample>;
      final heights = results[1] as List<HeightSample>;

      if (!profile.hasWeight && weights.isNotEmpty) {
        profile.weightKg = weights.last.kg;
      }
      if (!profile.hasHeight && heights.isNotEmpty) {
        profile.heightCm = heights.last.centimeters;
      }
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _profile.save();
    setState(() => _dirty = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved'), duration: Duration(seconds: 2)),
    );
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Goals'),
        actions: [
          if (_dirty)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Avatar + Name ──
                Center(
                  child: Column(children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        _profile.name.isNotEmpty ? _profile.name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_profile.hasBmi)
                      Text(
                        'BMI: ${_profile.bmi.toStringAsFixed(1)} (${_profile.bmiCategory})',
                        style: TextStyle(fontSize: 13, color: cs.outline),
                      ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Personal Info ──
                _SectionHeader(title: 'Personal Info', icon: Icons.person),
                const SizedBox(height: 8),
                _TextFieldRow(
                  label: 'Name',
                  value: _profile.name,
                  onChanged: (v) => _update(() => _profile.name = v),
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _NumberFieldRow(
                    label: 'Age',
                    value: _profile.age > 0 ? _profile.age.toDouble() : null,
                    suffix: 'years',
                    onChanged: (v) => _update(() => _profile.age = v.toInt()),
                    decimals: 0,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _GenderSelector(
                    value: _profile.gender,
                    onChanged: (v) => _update(() => _profile.gender = v),
                  )),
                ]),
                const SizedBox(height: 24),

                // ── Body Measurements ──
                _SectionHeader(title: 'Body Measurements', icon: Icons.straighten),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _NumberFieldRow(
                    label: 'Weight',
                    value: _profile.weightKg > 0 ? _profile.weightKg : null,
                    suffix: 'kg',
                    onChanged: (v) => _update(() => _profile.weightKg = v),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _NumberFieldRow(
                    label: 'Height',
                    value: _profile.heightCm > 0 ? _profile.heightCm : null,
                    suffix: 'cm',
                    onChanged: (v) => _update(() => _profile.heightCm = v),
                    decimals: 0,
                  )),
                ]),
                const SizedBox(height: 24),

                // ── Goals ──
                _SectionHeader(title: 'Goals', icon: Icons.flag),
                const SizedBox(height: 8),
                _NumberFieldRow(
                  label: 'Weight Goal',
                  value: _profile.weightGoalKg > 0 ? _profile.weightGoalKg : null,
                  suffix: 'kg',
                  onChanged: (v) => _update(() => _profile.weightGoalKg = v),
                ),
                if (_profile.weightDelta != 0) ...[
                  const SizedBox(height: 4),
                  _GoalDelta(
                    current: _profile.weightKg,
                    goal: _profile.weightGoalKg,
                  ),
                ],
                const SizedBox(height: 8),
                _NumberFieldRow(
                  label: 'Daily Steps',
                  value: _profile.dailyStepGoal.toDouble(),
                  suffix: 'steps',
                  onChanged: (v) => _update(() => _profile.dailyStepGoal = v.toInt()),
                  decimals: 0,
                ),
                const SizedBox(height: 8),
                _NumberFieldRow(
                  label: 'Daily Calories',
                  value: _profile.dailyCalorieGoal.toDouble(),
                  suffix: 'kcal',
                  onChanged: (v) => _update(() => _profile.dailyCalorieGoal = v.toInt()),
                  decimals: 0,
                ),
                const SizedBox(height: 8),
                _NumberFieldRow(
                  label: 'Daily Water',
                  value: _profile.dailyWaterLiters,
                  suffix: 'liters',
                  onChanged: (v) => _update(() => _profile.dailyWaterLiters = v),
                ),
                const SizedBox(height: 32),

                // ── Save Button ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _dirty ? _save : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your profile is stored locally on this device.',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 18, color: cs.primary),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.primary)),
    ]);
  }
}

class _TextFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  const _TextFieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }
}

class _NumberFieldRow extends StatelessWidget {
  final String label;
  final double? value;
  final String suffix;
  final ValueChanged<double> onChanged;
  final int decimals;
  const _NumberFieldRow({
    required this.label,
    required this.value,
    required this.suffix,
    required this.onChanged,
    this.decimals = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value != null
          ? (decimals == 0 ? value!.toInt().toString() : value!.toStringAsFixed(decimals))
          : '',
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final Gender value;
  final ValueChanged<Gender> onChanged;
  const _GenderSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Gender',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Gender>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: Gender.values.map((g) => DropdownMenuItem(
            value: g,
            child: Text(g.label, style: const TextStyle(fontSize: 14)),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

class _GoalDelta extends StatelessWidget {
  final double current, goal;
  const _GoalDelta({required this.current, required this.goal});

  @override
  Widget build(BuildContext context) {
    final delta = current - goal;
    final isLoss = delta > 0;
    final color = delta.abs() < 0.5 ? Colors.green : (isLoss ? Colors.orange : Colors.blue);
    final label = delta.abs() < 0.5
        ? 'At goal weight!'
        : isLoss
            ? '${delta.toStringAsFixed(1)} kg to lose'
            : '${delta.abs().toStringAsFixed(1)} kg to gain';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          delta.abs() < 0.5 ? Icons.check_circle : Icons.trending_flat,
          size: 16, color: color,
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
