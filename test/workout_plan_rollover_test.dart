import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascend_app/models/workout_plan.dart';
import 'package:ascend_app/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// The `workoutPlan_<weekId>` storage key for the week before this one.
  String pastWeekKey() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final pastStart = weekStart.subtract(const Duration(days: 7));
    return 'workoutPlan_${pastStart.year}-${pastStart.month}-${pastStart.day}';
  }

  test('copyWithCompletionReset keeps exercises but clears all checkboxes', () {
    final plan = WeeklyPlan.defaultPlan();
    for (final e in plan.days[1]!.exercises) {
      e.completed = true;
    }

    final reset = plan.copyWithCompletionReset();

    expect(reset.days[1]!.exercises.length, plan.days[1]!.exercises.length);
    expect(reset.days[1]!.exercises.every((e) => !e.completed), isTrue,
        reason: 'every exercise must be reset to unchecked');
    expect(reset.days[1]!.exercises.first.name, plan.days[1]!.exercises.first.name,
        reason: 'exercise names must be preserved');
  });

  test('loading a new week rolls the most recent prior plan forward with checkboxes reset',
      () async {
    await LocalStorage.init();

    // Seed a plan from last week with some exercises already completed.
    final seedPlan = WeeklyPlan(days: {
      1: WorkoutDay(
        label: 'Push Day',
        targetMuscles: 'Chest',
        exercises: [
          WorkoutExercise(
            exerciseId: 'bench',
            name: 'Bench Press',
            sets: 4,
            reps: '10',
            muscleGroup: 'Chest',
            completed: true,
          ),
          WorkoutExercise(
            exerciseId: 'press',
            name: 'Shoulder Press',
            sets: 3,
            reps: '12',
            muscleGroup: 'Shoulders',
            completed: true,
          ),
        ],
      ),
    });
    await LocalStorage.saveJson(pastWeekKey(), seedPlan.toJson());

    final state = WorkoutPlanState();
    state.load();

    final rolled = state.plan.days[1]!;
    expect(rolled.label, 'Push Day');
    expect(rolled.exercises.length, 2);
    expect(rolled.exercises.map((e) => e.name), ['Bench Press', 'Shoulder Press']);
    expect(rolled.exercises.every((e) => !e.completed), isTrue,
        reason: 'completion state must not carry into the next week');
  });
}
