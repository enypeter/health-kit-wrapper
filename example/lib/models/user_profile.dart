import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// User-editable profile and wellness goals.
///
/// Persisted to SharedPreferences. Values default to 0/empty
/// until the user sets them. Analytics code should fall back to
/// health-data-derived values when profile fields are unset.
class UserProfile {
  UserProfile({
    this.weightKg = 0,
    this.heightCm = 0,
    this.age = 0,
    this.gender = Gender.unset,
    this.weightGoalKg = 0,
    this.dailyStepGoal = 10000,
    this.dailyCalorieGoal = 2000,
    this.dailyWaterLiters = 2.5,
    this.name = '',
  });

  double weightKg;
  double heightCm;
  int age;
  Gender gender;
  double weightGoalKg;
  int dailyStepGoal;
  int dailyCalorieGoal;
  double dailyWaterLiters;
  String name;

  double get heightM => heightCm / 100;
  bool get hasWeight => weightKg > 0;
  bool get hasHeight => heightCm > 0;
  bool get hasBmi => hasWeight && hasHeight;

  double get bmi {
    if (!hasBmi) return 0;
    final h = heightM;
    return weightKg / (h * h);
  }

  String get bmiCategory => switch (bmi) {
    < 18.5 => 'Underweight',
    < 25.0 => 'Normal',
    < 30.0 => 'Overweight',
    < 35.0 => 'Obese I',
    _ => 'Obese',
  };

  double get weightDelta {
    if (weightGoalKg <= 0 || weightKg <= 0) return 0;
    return weightKg - weightGoalKg;
  }

  // ── Persistence ──────────────────────────────────────────

  static const _key = 'user_profile_v1';

  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return UserProfile();
    try {
      return UserProfile._fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return UserProfile();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
    'weightKg': weightKg,
    'heightCm': heightCm,
    'age': age,
    'gender': gender.name,
    'weightGoalKg': weightGoalKg,
    'dailyStepGoal': dailyStepGoal,
    'dailyCalorieGoal': dailyCalorieGoal,
    'dailyWaterLiters': dailyWaterLiters,
    'name': name,
  };

  factory UserProfile._fromJson(Map<String, dynamic> m) => UserProfile(
    weightKg: (m['weightKg'] as num?)?.toDouble() ?? 0,
    heightCm: (m['heightCm'] as num?)?.toDouble() ?? 0,
    age: (m['age'] as num?)?.toInt() ?? 0,
    gender: Gender.values.firstWhere(
      (g) => g.name == m['gender'],
      orElse: () => Gender.unset,
    ),
    weightGoalKg: (m['weightGoalKg'] as num?)?.toDouble() ?? 0,
    dailyStepGoal: (m['dailyStepGoal'] as num?)?.toInt() ?? 10000,
    dailyCalorieGoal: (m['dailyCalorieGoal'] as num?)?.toInt() ?? 2000,
    dailyWaterLiters: (m['dailyWaterLiters'] as num?)?.toDouble() ?? 2.5,
    name: m['name'] as String? ?? '',
  );
}

enum Gender {
  unset,
  male,
  female;

  String get label => switch (this) {
    unset => 'Not set',
    male => 'Male',
    female => 'Female',
  };
}
