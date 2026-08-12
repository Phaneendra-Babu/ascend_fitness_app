import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/local_storage.dart';
import '../services/notification_service.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon.codePoint,
        'color': color.toARGB32(),
        'scheduleDays': scheduleDays,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: _iconFromCode(json['icon'] as int?),
        color: Color(json['color'] as int? ?? 0xFF38BDF8),
        scheduleDays: (json['scheduleDays'] as List<dynamic>? ?? const [])
            .cast<int>(),
      );

  /// Reconstruct a habit icon from a persisted code point. `IconData` marks
  /// its `codePoint` as `@mustBeConst` (for release icon tree-shaking), so a
  /// runtime reconstruction goes through a lookup of the known const icons
  /// rather than calling the constructor with a variable.
  static IconData _iconFromCode(int? codePoint) {
    if (codePoint == null) return Icons.check_circle_outline;
    return _knownIcons[codePoint] ?? Icons.check_circle_outline;
  }

  static final Map<int, IconData> _knownIcons = {
    Icons.water_drop.codePoint: Icons.water_drop,
    Icons.directions_run.codePoint: Icons.directions_run,
    Icons.self_improvement.codePoint: Icons.self_improvement,
    Icons.bedtime.codePoint: Icons.bedtime,
    Icons.check_circle_outline.codePoint: Icons.check_circle_outline,
  };
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

  /// Copy this plan with every exercise reset to unchecked. Used when rolling
  /// a plan into a new week so completion state never carries over.
  WeeklyPlan copyWithCompletionReset() {
    return WeeklyPlan(
      days: days.map((k, v) => MapEntry(
            k,
            WorkoutDay(
              label: v.label,
              targetMuscles: v.targetMuscles,
              exercises: v.exercises
                  .map((e) => WorkoutExercise(
                        exerciseId: e.exerciseId,
                        name: e.name,
                        sets: e.sets,
                        reps: e.reps,
                        muscleGroup: e.muscleGroup,
                        completed: false,
                      ))
                  .toList(),
            ),
          )),
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
///
/// The plan is stored per week under `workoutPlan_<weekId>` (Monday-of-week
/// date). When a new week starts with no saved plan, the most recent prior
/// week's plan is rolled forward with every exercise reset to unchecked — so
/// the next week automatically repeats this week's workout without carrying
/// stale checkmarks.
class WorkoutPlanState extends ChangeNotifier {
  static const _storageKeyPrefix = 'workoutPlan_';
  static const _legacyStorageKey = 'workoutPlan';

  WeeklyPlan _plan;
  WeeklyPlan? _nextWeekPlan;

  WorkoutPlanState({WeeklyPlan? plan}) : _plan = plan ?? WeeklyPlan.defaultPlan();

  WeeklyPlan get plan => _plan;

  /// Week-scoped storage key for the current week, e.g. `workoutPlan_2026-8-3`.
  static String get _currentStorageKey => '$_storageKeyPrefix$_weekId';

  /// Monday of the current week (same weekId scheme the habits use).
  static String get _weekId {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return '${weekStart.year}-${weekStart.month}-${weekStart.day}';
  }

  /// Load this week's plan. If it doesn't exist yet, roll the most recent
  /// prior week's plan forward with every checkbox reset to unchecked.
  void load() {
    final raw = LocalStorage.loadJsonString(_currentStorageKey);
    if (raw != null) {
      _plan = _parsePlan(raw);
    } else {
      _plan = _loadMostRecentPriorWeek()?.copyWithCompletionReset() ??
          (_loadLegacyPlan()?.copyWithCompletionReset() ?? _plan);
      // Persist the rolled-over plan under this week's key so edits and next
      // week's rollover both read from a clean copy.
      _save();
    }
    notifyListeners();
    // Schedule (or clear) today's workout reminder based on whether any
    // exercises are still unchecked.
    NotificationService.instance.syncWorkoutReminder(
        incomplete: todayWorkoutIncomplete);
  }

  /// Save current plan to this week's storage key.
  Future<void> _save() async {
    await LocalStorage.saveJson(_currentStorageKey, _plan.toJson());
  }

  /// Most recent prior week's plan (before this week), or null if none.
  WeeklyPlan? _loadMostRecentPriorWeek() {
    final currentWeekDate = _parseWeekDate(_weekId);
    String? bestKey;
    DateTime? bestDate;
    for (final key in LocalStorage.localKeysWithPrefix(_storageKeyPrefix)) {
      final date = _parseWeekDate(key.substring(_storageKeyPrefix.length));
      if (date == null) continue;
      if (currentWeekDate != null && !date.isBefore(currentWeekDate)) continue;
      if (bestDate == null || date.isAfter(bestDate)) {
        bestDate = date;
        bestKey = key;
      }
    }
    if (bestKey == null) return null;
    final raw = LocalStorage.loadJsonString(bestKey);
    return raw == null ? null : _parsePlan(raw);
  }

  /// Plan saved under the pre-week-scoping `workoutPlan` key.
  WeeklyPlan? _loadLegacyPlan() {
    final raw = LocalStorage.loadJsonString(_legacyStorageKey);
    return raw == null ? null : _parsePlan(raw);
  }

  static WeeklyPlan _parsePlan(String raw) {
    try {
      final json = Map<String, dynamic>.from(
          (jsonDecode(raw) as Map).cast<String, dynamic>());
      return WeeklyPlan.fromJson(json);
    } catch (_) {
      return WeeklyPlan.defaultPlan();
    }
  }

  static DateTime? _parseWeekDate(String weekId) {
    final parts = weekId.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Get the exercises for today's workout (used by Home screen Daily Missions).
  List<WorkoutExercise> get todayExercises {
    final today = DateTime.now().weekday;
    final day = _plan.days[today];
    return day?.exercises ?? [];
  }

  /// Whether today's workout still has unchecked exercises. False on rest
  /// days / when today's plan is empty, so no workout reminder is scheduled.
  bool get todayWorkoutIncomplete =>
      todayExercises.isNotEmpty &&
      !(_plan.days[DateTime.now().weekday]?.allComplete ?? false);

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
