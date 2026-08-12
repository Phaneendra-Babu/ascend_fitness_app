import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../models/xp_system.dart';
import '../services/local_storage.dart';
import '../services/notification_service.dart';

/// Single source of truth for XP, streak history and the habit list.
///
/// Provided at the [MainNavigationScreen] level so Home, Todos and Profile all
/// read and write the same state. XP/streak/habits are persisted locally
/// (per-account, via [LocalStorage] scoping) and mirrored to Firestore so the
/// Profile screen — which streams `users/{uid}` — updates live.
class ProgressController extends ChangeNotifier {
  // ── Default habits ──────────────────────────────────────────
  static final List<Habit> _defaultHabits = [
    const Habit(id: 'water', name: 'Drink 3L Water', icon: Icons.water_drop, color: Color(0xFF38BDF8)),
    const Habit(id: 'run', name: 'Run 5km', icon: Icons.directions_run, color: Color(0xFF10B981)),
    const Habit(id: 'stretch', name: '10min Stretching', icon: Icons.self_improvement, color: Color(0xFF8B5CF6)),
    const Habit(id: 'sleep', name: 'Sleep 8 Hours', icon: Icons.bedtime, color: Color(0xFFF59E0B)),
  ];

  // ── State ───────────────────────────────────────────────────
  int totalXP = 0;
  List<StreakDay> streakHistory = [];
  List<Habit> habits = List.of(_defaultHabits);

  /// Per-weekday (1=Mon, 7=Sun) completion map for the current week, loaded
  /// from the existing `habits_<weekId>_day<d>` storage keys.
  final Map<int, Map<String, bool>> _dayHabitCache = {};

  /// True once today's daily streak XP has been awarded, so re-toggling
  /// exercises/habits below and above the fire threshold never double-awards.
  bool _streakXPAwardedToday = false;

  // ── Week helpers ─────────────────────────────────────────────
  String get _weekId {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return '${weekStart.year}-${weekStart.month}-${weekStart.day}';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime get _today => _dateOnly(DateTime.now());
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Load / persistence ───────────────────────────────────────
  Future<void> load() async {
    totalXP = LocalStorage.loadInt('totalXP', 0);

    final streakRaw = LocalStorage.loadJsonString('streakHistory');
    if (streakRaw != null) {
      try {
        streakHistory = (jsonDecode(streakRaw) as List<dynamic>)
            .map((e) => StreakDay.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        streakHistory = [];
      }
    } else {
      streakHistory = [];
    }

    final habitsRaw = LocalStorage.loadJsonString('habitsList');
    if (habitsRaw != null) {
      try {
        final list = (jsonDecode(habitsRaw) as List<dynamic>)
            .map((e) => Habit.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) habits = list;
      } catch (_) {}
    }

    _loadWeekHabitCache();
    _backfillMissedDays();
    _streakXPAwardedToday = _isTodayActive();

    await _saveLocal();
    await _syncToFirestore();
    // Schedule today's reminders for any habits still unchecked.
    final today = DateTime.now().weekday;
    await NotificationService.instance.scheduleHabitReminders(
      habits: habits,
      weekday: today,
      isDone: (id) => isHabitDone(today, id),
    );
    notifyListeners();
  }

  /// Load each day's habit completion for the current week into the cache.
  void _loadWeekHabitCache() {
    _dayHabitCache.clear();
    for (int weekday = 1; weekday <= 7; weekday++) {
      final raw = LocalStorage.loadJsonString('habits_${_weekId}_day$weekday');
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _dayHabitCache[weekday] = map.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }
  }

  Future<void> _saveHabitsForDay(int weekday) async {
    await LocalStorage.saveJson(
        'habits_${_weekId}_day$weekday', _dayHabitCache[weekday] ?? {});
  }

  Future<void> _saveHabitsList() async {
    await LocalStorage.saveJson(
        'habitsList', habits.map((h) => h.toJson()).toList());
  }

  Future<void> _saveLocal() async {
    await LocalStorage.saveInt('totalXP', totalXP);
    await LocalStorage.saveJson(
        'streakHistory', streakHistory.map((s) => s.toJson()).toList());
    await _saveHabitsList();
  }

  // ── Firestore sync (Profile reads these live) ────────────────
  Future<void> _syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final level = XPSystem.levelForXP(totalXP);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'xp': totalXP,
        'level': level,
        'xpTarget': XPSystem.xpForLevel(level + 1),
        'totalXPEarned': totalXP,
        'streakDays': currentStreak,
        'streakHistory': streakHistory.map((s) => s.toMap()).toList(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline / Firebase not initialized — local storage stays authoritative.
    }
  }

  // ── Habit list ───────────────────────────────────────────────
  Future<void> addHabit(Habit habit) async {
    habits = [...habits, habit];
    await _saveHabitsList();
    notifyListeners();
  }

  Future<void> removeHabit(String habitId) async {
    habits = habits.where((h) => h.id != habitId).toList();
    final today = DateTime.now().weekday;
    _dayHabitCache[today]?.remove(habitId);
    await _saveHabitsForDay(today);
    await _saveHabitsList();
    notifyListeners();
  }

  /// Replace the habit list with a reordered copy (used by the Todos screen's
  /// drag-to-reorder). Completion state is keyed by habit id, so reordering
  /// never affects which habits are marked done.
  Future<void> reorderHabits(List<Habit> newOrder) async {
    habits = List<Habit>.of(newOrder);
    await _saveHabitsList();
    notifyListeners();
  }

  // ── Habit completion (day-aware) ─────────────────────────────
  bool isHabitDone(int weekday, String habitId) =>
      _dayHabitCache[weekday]?[habitId] ?? false;

  bool hasAnyHabitDone(int weekday) =>
      _dayHabitCache[weekday]?.values.any((v) => v) ?? false;

  bool areAllScheduledHabitsDone(int weekday) {
    final scheduled = habits.where((h) => h.isScheduledFor(weekday)).toList();
    if (scheduled.isEmpty) return false;
    final map = _dayHabitCache[weekday] ?? {};
    return scheduled.every((h) => map[h.id] ?? false);
  }

  List<Habit> get todayHabits {
    final today = DateTime.now().weekday;
    return habits.where((h) => h.isScheduledFor(today)).toList();
  }

  int get todayHabitsDone {
    final today = DateTime.now().weekday;
    final map = _dayHabitCache[today] ?? {};
    return todayHabits.where((h) => map[h.id] ?? false).length;
  }

  /// Toggle a habit's completion for [weekday] (only today can be toggled) and
  /// award/revoke +80 XP.
  Future<void> toggleHabit(int weekday, String habitId) async {
    if (weekday != DateTime.now().weekday) return;
    final map = _dayHabitCache[weekday] ??= {};
    final wasDone = map[habitId] ?? false;
    map[habitId] = !wasDone;
    await _saveHabitsForDay(weekday);
    await awardXP(wasDone ? -XPSystem.HABIT_XP : XPSystem.HABIT_XP);
    notifyListeners();
    // Keep the habit's pending reminder in sync: checking it cancels the
    // notification, un-checking it schedules a fresh random one.
    for (final h in habits) {
      if (h.id == habitId) {
        await NotificationService.instance
            .updateHabitReminder(habit: h, done: map[habitId]!);
        break;
      }
    }
  }

  // ── XP ───────────────────────────────────────────────────────
  /// Add (or subtract) XP. Returns true if a level-up happened.
  Future<bool> awardXP(int delta) async {
    final oldLevel = XPSystem.levelForXP(totalXP);
    totalXP = max(0, totalXP + delta);
    final newLevel = XPSystem.levelForXP(totalXP);
    await _saveLocal();
    await _syncToFirestore();
    notifyListeners();
    return newLevel > oldLevel;
  }

  // ── Daily streak / fire logic ────────────────────────────────
  /// Recompute today's streak status from the combined exercise + habit
  /// completion rate. Called by screens after any exercise or habit toggle.
  Future<void> recordDayProgress({
    required int exercisesCompleted,
    required int exercisesTotal,
  }) async {
    final today = _today;
    final habitsDone = todayHabitsDone;
    final habitsTotal = todayHabits.length;
    final combinedDone = exercisesCompleted + habitsDone;
    final combinedTotal = exercisesTotal + habitsTotal;

    final historyWithoutToday = _historyWithoutToday;
    final result = XPSystem.calculateStreakDay(
      missionsCompleted: combinedDone,
      totalMissions: combinedTotal,
      streakHistory: historyWithoutToday,
      cooldownsUsedThisWeek: 0,
      currentStreak: _streakOf(historyWithoutToday),
    );

    final existingIndex = _indexOfDay(today);
    if (existingIndex == null) {
      _streakXPAwardedToday = false;
      streakHistory.add(StreakDay(
        date: today,
        status: result.status,
        missionsCompleted: combinedDone,
        totalMissions: combinedTotal,
        cooldownsUsed: result.cooldownUsed ? 1 : 0,
      ));
      if (result.xpAwarded > 0 && !_streakXPAwardedToday) {
        _streakXPAwardedToday = true;
        await awardXP(result.xpAwarded);
      }
    } else {
      final wasActive =
          streakHistory[existingIndex].status == StreakDayStatus.active;
      streakHistory[existingIndex] = StreakDay(
        date: today,
        status: result.status,
        missionsCompleted: combinedDone,
        totalMissions: combinedTotal,
        cooldownsUsed: result.cooldownUsed ? 1 : 0,
      );
      // Award the daily streak XP once — only on the first flip to active.
      if (result.status == StreakDayStatus.active &&
          !wasActive &&
          !_streakXPAwardedToday) {
        _streakXPAwardedToday = true;
        await awardXP(result.xpAwarded);
      }
    }

    await _saveLocal();
    await _syncToFirestore();
    notifyListeners();
  }

  List<StreakDay> get _historyWithoutToday =>
      streakHistory.where((s) => !_sameDay(s.date, _today)).toList();

  int? _indexOfDay(DateTime date) {
    for (int i = 0; i < streakHistory.length; i++) {
      if (_sameDay(streakHistory[i].date, date)) return i;
    }
    return null;
  }

  bool _isTodayActive() {
    final idx = _indexOfDay(_today);
    return idx != null && streakHistory[idx].status == StreakDayStatus.active;
  }

  /// Insert `broken` entries for days skipped between the last recorded day
  /// and today, so gaps in the streak are represented in history.
  void _backfillMissedDays() {
    if (streakHistory.isEmpty) return;
    streakHistory.sort((a, b) => a.date.compareTo(b.date));
    final last = _dateOnly(streakHistory.last.date);
    var cursor = last.add(const Duration(days: 1));
    while (cursor.isBefore(_today)) {
      streakHistory.add(StreakDay(
        date: cursor,
        status: StreakDayStatus.broken,
        missionsCompleted: 0,
        totalMissions: 5,
      ));
      cursor = cursor.add(const Duration(days: 1));
    }
    streakHistory.sort((a, b) => a.date.compareTo(b.date));
  }

  // ── Getters for UI ───────────────────────────────────────────
  /// Consecutive active/cooldown days counted from the most recent day.
  int get currentStreak => _streakOf(streakHistory);

  static int _streakOf(List<StreakDay> history) {
    int count = 0;
    for (int i = history.length - 1; i >= 0; i--) {
      final s = history[i].status;
      if (s == StreakDayStatus.active || s == StreakDayStatus.cooldown) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  int get cooldownsUsedThisWeek {
    final weekStart =
        _today.subtract(Duration(days: DateTime.now().weekday - 1));
    return streakHistory
        .where((d) =>
            !d.date.isBefore(weekStart) &&
            d.status == StreakDayStatus.cooldown)
        .length;
  }
}
