import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascend_app/controllers/progress_controller.dart';
import 'package:ascend_app/models/xp_system.dart';
import 'package:ascend_app/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('habit toggle awards and revokes +80 XP', () async {
    await LocalStorage.init();
    final progress = ProgressController();
    await progress.load();
    final today = DateTime.now().weekday;
    final before = progress.totalXP;

    await progress.toggleHabit(today, 'water');
    expect(progress.totalXP, before + XPSystem.HABIT_XP);
    expect(progress.isHabitDone(today, 'water'), isTrue);

    await progress.toggleHabit(today, 'water');
    expect(progress.totalXP, before);
    expect(progress.isHabitDone(today, 'water'), isFalse);
  });

  test('reorderHabits persists the new order without touching completion state',
      () async {
    await LocalStorage.init();
    final progress = ProgressController();
    await progress.load();
    final today = DateTime.now().weekday;
    final original = progress.habits.map((h) => h.id).toList();

    // Mark one habit done, then reorder the list.
    await progress.toggleHabit(today, original.first);
    final reordered = progress.habits.reversed.toList();
    await progress.reorderHabits(reordered);

    // Fresh controller (as after a restart) reads the saved order back.
    final reloaded = ProgressController();
    await reloaded.load();
    expect(reloaded.habits.map((h) => h.id).toList(),
        progress.habits.map((h) => h.id).toList(),
        reason: 'habit order must survive a reload');
    expect(reloaded.isHabitDone(today, original.first), isTrue,
        reason: 'completion state must not change when reordering');
  });

  test('80% of combined exercises+habits marks the day active and awards streak XP once',
      () async {
    await LocalStorage.init();
    final progress = ProgressController();
    await progress.load();
    final today = DateTime.now().weekday;

    // Complete all default habits so the combined rate can reach 80%+.
    for (final habit in progress.habits) {
      await progress.toggleHabit(today, habit.id);
    }

    final xpBeforeStreak = progress.totalXP;

    // 4 exercises + 4 habits done out of 5 + 4 total = 8/9 ≈ 89% ≥ 75%.
    await progress.recordDayProgress(exercisesCompleted: 4, exercisesTotal: 5);
    expect(progress.streakHistory.last.status, StreakDayStatus.active);
    expect(progress.currentStreak, 1);
    expect(progress.totalXP, xpBeforeStreak + XPSystem.DAILY_STREAK_BASE,
        reason: 'daily streak XP must be awarded on the first fire day');

    // Re-reporting the same state must not double-award.
    await progress.recordDayProgress(exercisesCompleted: 4, exercisesTotal: 5);
    expect(progress.streakHistory.length, 1,
        reason: 'today must stay a single streak-history entry');
    expect(progress.totalXP, xpBeforeStreak + XPSystem.DAILY_STREAK_BASE);

    // Dropping below the threshold flips today to a cooldown (one is available).
    await progress.recordDayProgress(exercisesCompleted: 0, exercisesTotal: 5);
    expect(progress.streakHistory.last.status, StreakDayStatus.cooldown);
    expect(progress.totalXP, xpBeforeStreak + XPSystem.DAILY_STREAK_BASE,
        reason: 'cooldown days award no XP');

    // Returning above the threshold re-fires the day but awards streak XP only once.
    await progress.recordDayProgress(exercisesCompleted: 4, exercisesTotal: 5);
    expect(progress.streakHistory.last.status, StreakDayStatus.active);
    expect(progress.totalXP, xpBeforeStreak + XPSystem.DAILY_STREAK_BASE,
        reason: 'daily streak XP must not be re-awarded the same day');
  });
}
