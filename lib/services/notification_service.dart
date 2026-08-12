import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/workout_plan.dart';
import 'local_storage.dart';

/// Schedules local "pending reminder" notifications for the current day.
///
/// Two kinds of reminders, each only for items still unchecked at schedule
/// time:
///  - one notification per unchecked habit, each at its own random time of
///    day (never all at once);
///  - one notification for the workout if any of today's exercises are left
///    (never one per exercise).
///
/// Reminders are one-shot for today and are cancelled the moment the matching
/// item is completed. A per-day marker (stored via [LocalStorage], already
/// scoped per-account) makes scheduling idempotent, so reopening the app the
/// same day never duplicates a reminder that was already scheduled.
///
/// Every plugin call is guarded by the `_initialized` flag and wrapped in
/// try/catch: before [init] has run (e.g. in unit tests) or when a schedule
/// fails, the service is a no-op so a notification failure never crashes the
/// app.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _workoutId = 100;
  static const String _channelId = 'daily_reminders';
  static const String _habitDayKey = 'notifHabitDay';
  static const String _workoutDayKey = 'notifWorkoutDay';

  /// Deterministic notification id for a habit, stable across app runs so a
  /// later cancel targets the same id.
  static int _habitId(String habitId) =>
      1000 + (habitId.hashCode & 0x7fffffff) % 1_000_000;

  /// `yyyymmdd` int for today — the per-day marker value.
  static int get _todayCode {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  /// Initialise the plugin + timezone database and request the Android 13+
  /// notification permission. Called once from main() before runApp.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings: settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {
      // Leave _initialized false — scheduling stays a no-op.
    }
  }

  // ── Habit reminders ──────────────────────────────────────────

  /// Schedule today's reminder for every habit that is scheduled for today
  /// and still unchecked. Called from [ProgressController.load]. Idempotent
  /// per day.
  Future<void> scheduleHabitReminders({
    required List<Habit> habits,
    required int weekday,
    required bool Function(String habitId) isDone,
  }) async {
    if (!_initialized) return;
    if (LocalStorage.loadInt(_habitDayKey, 0) == _todayCode) return;
    try {
      for (final h in habits) {
        await _plugin.cancel(id: _habitId(h.id));
      }
      final pending = habits
          .where((h) => h.isScheduledFor(weekday) && !isDone(h.id))
          .toList();
      final delays = _randomDelays(pending.length);
      for (var i = 0; i < pending.length; i++) {
        await _scheduleOnce(
          _habitId(pending[i].id),
          'Habit Reminder',
          'You have a pending or incomplete habit: ${pending[i].name}',
          delays[i],
        );
      }
      await LocalStorage.saveInt(_habitDayKey, _todayCode);
    } catch (_) {}
  }

  /// Update a single habit's notification after its completion flipped:
  /// done → cancel its pending reminder; undone → schedule a new random one.
  Future<void> updateHabitReminder({
    required Habit habit,
    required bool done,
  }) async {
    if (!_initialized) return;
    try {
      if (done) {
        await _plugin.cancel(id: _habitId(habit.id));
      } else {
        await _scheduleOnce(
          _habitId(habit.id),
          'Habit Reminder',
          'You have a pending or incomplete habit: ${habit.name}',
          _randomDelays(1).first,
        );
      }
    } catch (_) {}
  }

  // ── Workout reminder ─────────────────────────────────────────

  /// Schedule or cancel today's single workout reminder. Called from
  /// [WorkoutPlanState.load] and after every exercise toggle.
  ///
  /// Idempotent: once scheduled for today it is not re-randomised (a reminder
  /// that already fired never re-fires), and completing the workout cancels
  /// it.
  Future<void> syncWorkoutReminder({required bool incomplete}) async {
    if (!_initialized) return;
    try {
      if (!incomplete) {
        await _plugin.cancel(id: _workoutId);
        await LocalStorage.remove(_workoutDayKey);
        return;
      }
      if (LocalStorage.loadInt(_workoutDayKey, 0) == _todayCode) return;
      await _plugin.cancel(id: _workoutId);
      await _scheduleOnce(
        _workoutId,
        'Workout Reminder',
        "You have pending exercises in today's workout. Let's get moving! 💪",
        _randomDelays(1).first,
      );
      await LocalStorage.saveInt(_workoutDayKey, _todayCode);
    } catch (_) {}
  }

  /// Cancel all pending reminders and clear the per-day markers. Called when
  /// the main navigation screen is disposed (account switch / logout) so the
  /// previous account's reminders don't fire and a same-day re-login can
  /// schedule fresh ones.
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    await LocalStorage.remove(_habitDayKey);
    await LocalStorage.remove(_workoutDayKey);
  }

  // ── Scheduling helpers ───────────────────────────────────────

  Future<void> _scheduleOnce(
      int id, String title, String body, Duration delay) async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Daily Reminders',
        channelDescription: 'Reminders for pending habits and workouts',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    // Schedule relative to now (never a wall-clock time) so the absolute
    // firing instant is correct regardless of the device timezone.
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// `count` distinct future delays in [now+15min, 10pm], generated by
  /// splitting the window into buckets so reminders never arrive at the same
  /// moment. If it's already late in the day, still nudge each a few minutes
  /// apart so they never arrive together.
  List<Duration> _randomDelays(int count) {
    if (count <= 0) return const [];
    final now = DateTime.now();
    final latest = DateTime(now.year, now.month, now.day, 22);
    const minMinutes = 15;
    final windowMinutes =
        latest.difference(now).inMinutes - minMinutes;
    if (windowMinutes < count) {
      return [
        for (var i = 0; i < count; i++) Duration(minutes: minMinutes + i),
      ];
    }
    final bucket = windowMinutes ~/ count;
    final delays = <Duration>[];
    for (var i = 0; i < count; i++) {
      final minutes = minMinutes +
          (bucket * i) +
          (bucket > 0 ? Random().nextInt(bucket) : 0);
      delays.add(Duration(minutes: minutes));
    }
    delays.shuffle();
    return delays;
  }
}
