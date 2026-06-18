/// An exercise/workout session with optional lap and segment data.
class ExerciseSession {
  const ExerciseSession({
    required this.exerciseType,
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.source,
    this.title = '',
    this.notes = '',
    this.device = '',
    this.laps = const [],
    this.segments = const [],
  });

  final String exerciseType;
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final String source;
  final String title;
  final String notes;
  final String device;
  final List<ExerciseLap> laps;
  final List<ExerciseSegment> segments;

  factory ExerciseSession.fromMap(Map<String, dynamic> m) {
    final lapsRaw = m['laps'] as List<dynamic>? ?? [];
    final segsRaw = m['segments'] as List<dynamic>? ?? [];

    return ExerciseSession(
      exerciseType:    m['exerciseType'] as String? ?? '',
      start:           DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
      end:             DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
      durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 0,
      source:          m['source'] as String? ?? '',
      title:           m['title'] as String? ?? '',
      notes:           m['notes'] as String? ?? '',
      device:          m['device'] as String? ?? '',
      laps: lapsRaw
          .map((l) => ExerciseLap.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
      segments: segsRaw
          .map((s) => ExerciseSegment.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

class ExerciseLap {
  const ExerciseLap({
    required this.start,
    required this.end,
    required this.lengthMeters,
  });

  final DateTime start;
  final DateTime end;
  final double lengthMeters;

  factory ExerciseLap.fromMap(Map<String, dynamic> m) => ExerciseLap(
    start:        DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
    end:          DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
    lengthMeters: (m['lengthM'] as num?)?.toDouble() ?? 0.0,
  );
}

class ExerciseSegment {
  const ExerciseSegment({
    required this.type,
    required this.start,
    required this.end,
    required this.repetitions,
  });

  final String type;
  final DateTime start;
  final DateTime end;
  final int repetitions;

  factory ExerciseSegment.fromMap(Map<String, dynamic> m) => ExerciseSegment(
    type:        m['type'] as String? ?? '',
    start:       DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
    end:         DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
    repetitions: (m['reps'] as num?)?.toInt() ?? 0,
  );
}
