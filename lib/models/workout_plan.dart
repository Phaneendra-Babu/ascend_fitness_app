import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/local_storage.dart';

/// A single exercise within a workout day.
class WorkoutExercise {
  final String exerciseId;
  final String name;
  final int sets;
  final String reps;
  final String muscleGroup;
  bool completed;

  WorkoutExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.muscleGroup,
    this.completed = false,
  });

  WorkoutExercise copy() => WorkoutExercise(
        exerciseId: exerciseId,
        name: name,
        sets: sets,
        reps: reps,
        muscleGroup: muscleGroup,
        completed: completed,
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets,
        'reps': reps,
        'muscleGroup': muscleGroup,
        'completed': completed,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        exerciseId: json['exerciseId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sets: json['sets'] as int? ?? 3,
        reps: json['reps'] as String? ?? '10',
        muscleGroup: json['muscleGroup'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
      );
}

/// A single day's workout (e.g. "Push Day" with 6 exercises).
class WorkoutDay {
  final String label;
  final String targetMuscles;
  final List<WorkoutExercise> exercises;

  WorkoutDay({
    required this.label,
    required this.targetMuscles,
    required this.exercises,
  });

  int get completedCount => exercises.where((e) => e.completed).length;
  bool get allComplete => exercises.isNotEmpty && exercises.every((e) => e.completed);

  WorkoutDay copy() => WorkoutDay(
        label: label,
        targetMuscles: targetMuscles,
        exercises: exercises.map((e) => e.copy()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'targetMuscles': targetMuscles,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
        label: json['label'] as String? ?? 'Rest Day',
        targetMuscles: json['targetMuscles'] as String? ?? '',
        exercises: (json['exercises'] as List<dynamic>?)
                ?.map((e) =>
                    WorkoutExercise.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// A daily habit (e.g. "Drink Water", "Run 5km").
class Habit {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  /// Days of the week this habit is scheduled for.
  /// 1=Mon, 7=Sun. Empty list = everyday.
  final List<int> scheduleDays;

  const Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.scheduleDays = const [],
  });

  /// Whether this habit should appear on the given weekday (1=Mon, 7=Sun).
  bool isScheduledFor(int weekday) {
    if (scheduleDays.isEmpty) return true; // everyday
    return scheduleDays.contains(weekday);
  }

  /// Human-readable schedule label.
  String get scheduleLabel {
    if (scheduleDays.isEmpty) return 'Everyday';
    if (scheduleDays.length == 7) return 'Everyday';
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return scheduleDays.map((d) => dayNames[d - 1]).join(', ');
  }
}

/// The full week's workout plan.
class WeeklyPlan {
  /// weekday (1=Mon, 7=Sun) → WorkoutDay
  final Map<int, WorkoutDay> days;

  WeeklyPlan({required this.days});

  /// Create a default week with Push/Pull/Legs/Rest pattern.
  factory WeeklyPlan.defaultPlan() {
    return WeeklyPlan(days: {
      1: WorkoutDay(
        label: 'Push Day',
        targetMuscles: 'Chest, Shoulders, Triceps',
        exercises: [
          WorkoutExercise(exerciseId: 'barbell_bench_press', name: 'Bench Press', sets: 4, reps: '10', muscleGroup: 'Chest'),
          WorkoutExercise(exerciseId: 'incline_dumbbell_press', name: 'Incline Dumbbell Press', sets: 4, reps: '10', muscleGroup: 'Chest'),
          WorkoutExercise(exerciseId: 'shoulder_press', name: 'Shoulder Press', sets: 3, reps: '12', muscleGroup: 'Shoulders'),
          WorkoutExercise(exerciseId: 'cable_fly', name: 'Cable Fly', sets: 3, reps: '12', muscleGroup: 'Chest'),
          WorkoutExercise(exerciseId: 'tricep_pushdown', name: 'Tricep Pushdown', sets: 3, reps: '15', muscleGroup: 'Arms'),
          WorkoutExercise(exerciseId: 'plank', name: 'Plank', sets: 3, reps: '45 sec', muscleGroup: 'Core'),
        ],
      ),
      2: WorkoutDay(
        label: 'Pull Day',
        targetMuscles: 'Back, Biceps',
        exercises: [
          WorkoutExercise(exerciseId: 'deadlift', name: 'Deadlift', sets: 4, reps: '8', muscleGroup: 'Back'),
          WorkoutExercise(exerciseId: 'pull_up', name: 'Pull Up', sets: 4, reps: '10', muscleGroup: 'Back'),
          WorkoutExercise(exerciseId: 'barbell_row', name: 'Barbell Row', sets: 4, reps: '10', muscleGroup: 'Back'),
          WorkoutExercise(exerciseId: 'face_pull', name: 'Face Pull', sets: 3, reps: '15', muscleGroup: 'Back'),
          WorkoutExercise(exerciseId: 'bicep_curl', name: 'Bicep Curl', sets: 3, reps: '12', muscleGroup: 'Arms'),
        ],
      ),
      3: WorkoutDay(
        label: 'Leg Day',
        targetMuscles: 'Quads, Hamstrings, Glutes',
        exercises: [
          WorkoutExercise(exerciseId: 'barbell_squat', name: 'Barbell Squat', sets: 4, reps: '10', muscleGroup: 'Legs'),
          WorkoutExercise(exerciseId: 'romanian_deadlift', name: 'Romanian Deadlift', sets: 4, reps: '10', muscleGroup: 'Legs'),
          WorkoutExercise(exerciseId: 'leg_press', name: 'Leg Press', sets: 3, reps: '12', muscleGroup: 'Legs'),
          WorkoutExercise(exerciseId: 'leg_curl', name: 'Leg Curl', sets: 3, reps: '12', muscleGroup: 'Legs'),
          WorkoutExercise(exerciseId: 'calf_raise', name: 'Calf Raise', sets: 3, reps: '15', muscleGroup: 'Legs'),
        ],
      ),
      4: WorkoutDay(label: 'Rest Day', targetMuscles: 'Recovery', exercises: []),
      5: WorkoutDay(
        label: 'Push Day',
        targetMuscles: 'Chest, Shoulders, Triceps',
        exercises: [
          WorkoutExercise(exerciseId: 'barbell_bench_press', name: 'Bench Press', sets: 4, reps: '10', muscleGroup: 'Chest'),
          WorkoutExercise(exerciseId: 'incline_dumbbell_press', name: 'Incline Dumbbell Press', sets: 4, reps: '10', muscleGroup: 'Chest'),
          WorkoutExercise(exerciseId: 'shoulder_press', name: 'Shoulder Press', sets: 3, reps: '12', muscleGroup: 'Shoulders'),
          WorkoutExercise(exerciseId: 'cable_fly', name: 'Cable Fly', sets: 3, reps: '12', muscleGroup: 'Chest'),
          WorkoutExercise(exerciseId: 'tricep_pushdown', name: 'Tricep Pushdown', sets: 3, reps: '15', muscleGroup: 'Arms'),
        ],
      ),
      6: WorkoutDay(
        label: 'Pull Day',
        targetMuscles: 'Back, Biceps',
        exercises: [
          WorkoutExercise(exerciseId: 'deadlift', name: 'Deadlift', sets: 4, reps: '8', muscleGroup: 'Back'),
          WorkoutExercise(exerciseId: 'pull_up', name: 'Pull Up', sets: 4, reps: '10', muscleGroup: 'Back'),
          WorkoutExercise(exerciseId: 'barbell_row', name: 'Barbell Row', sets: 4, reps: '10', muscleGroup: 'Back'),
          WorkoutExercise(exerciseId: 'bicep_curl', name: 'Bicep Curl', sets: 3, reps: '12', muscleGroup: 'Arms'),
        ],
      ),
      7: WorkoutDay(label: 'Rest Day', targetMuscles: 'Recovery', exercises: []),
    });
  }

  WeeklyPlan copy() {
    return WeeklyPlan(
      days: days.map((k, v) => MapEntry(k, v.copy())),
    );
  }

  Map<String, dynamic> toJson() => {
        'days': days.map((k, v) => MapEntry(k.toString(), v.toJson())),
      };

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) {
    final daysMap = <int, WorkoutDay>{};
    final rawDays = json['days'] as Map<String, dynamic>?;
    if (rawDays != null) {
      rawDays.forEach((key, value) {
        daysMap[int.parse(key)] =
            WorkoutDay.fromJson(value as Map<String, dynamic>);
      });
    }
    return WeeklyPlan(days: daysMap);
  }

  /// Get the muscle groups active on a given weekday.
  Set<String> activeMusclesForDay(int weekday) {
    final day = days[weekday];
    if (day == null) return {};
    return day.exercises.map((e) => e.muscleGroup).toSet();
  }
}

/// Shared state for the workout plan, accessible across screens via Provider.
class WorkoutPlanState extends ChangeNotifier {
  static const _storageKey = 'workoutPlan';

  WeeklyPlan _plan;
  WeeklyPlan? _nextWeekPlan;

  WorkoutPlanState({WeeklyPlan? plan}) : _plan = plan ?? WeeklyPlan.defaultPlan();

  WeeklyPlan get plan => _plan;

  /// Load saved plan from local storage.
  void load() {
    final raw = LocalStorage.loadJsonString(_storageKey);
    if (raw != null) {
      try {
        final json = Map<String, dynamic>.from(
            (jsonDecode(raw) as Map).cast<String, dynamic>());
        _plan = WeeklyPlan.fromJson(json);
        notifyListeners();
      } catch (_) {
        // Keep default plan on parse error
      }
    }
  }

  /// Save current plan to local storage.
  Future<void> _save() async {
    await LocalStorage.saveJson(_storageKey, _plan.toJson());
  }

  /// Get the exercises for today's workout (used by Home screen Daily Missions).
  List<WorkoutExercise> get todayExercises {
    final today = DateTime.now().weekday;
    final day = _plan.days[today];
    return day?.exercises ?? [];
  }

  void updatePlan(WeeklyPlan plan) {
    _plan = plan;
    _save();
    notifyListeners();
  }

  void copyToNextWeek() {
    _nextWeekPlan = _plan.copy();
    notifyListeners();
  }

  bool get hasNextWeekPlan => _nextWeekPlan != null;
}
