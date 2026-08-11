import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// XP System Constants and Calculation Logic
/// Based on the ASCEND Hunter XP design spec
class XPSystem {
  // ════════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ════════════════════════════════════════════════════════════════════

  // Exercise / Todo difficulty
  static const int TODO_EASY = 15;
  static const int TODO_MEDIUM = 35;
  static const int TODO_HARD = 75;

  // Daily Missions (5 per day)
  static const int DAILY_MISSION_SINGLE = 40;
  static const int DAILY_MISSIONS_ALL_BONUS = 150;

  // Streak
  static const int DAILY_STREAK_BASE = 25;
  static const int STREAK_MILESTONE_7 = 150;
  static const int STREAK_MILESTONE_30 = 500;
  static const int STREAK_MILESTONE_100 = 2000;
  static const int HUNTER_MODE_UNLOCK_DAY = 0;  // Changed from 14 to 21
  static const int BEAST_MODE_UNLOCK_DAY = 0;

  // Cooldown System
  static const int COOLDOWNS_PER_WEEK = 2;  // 2 cooldowns per 7 days
  static const double STREAK_ACTIVATION_THRESHOLD = 0.75; // 75% missions required
  static const double STREAK_MAINTENANCE_THRESHOLD = 0.80; // 80% missions to maintain

  // Todo Bonuses
  static const int TODO_COMPLETION_BONUS = 25;
  static const int TODO_FIRST_OF_DAY_BONUS = 15;
  static const int TODO_PERFECT_FORM_BONUS = 10;

  // ════════════════════════════════════════════════════════════════════
  // MODES
  // ════════════════════════════════════════════════════════════════════

  /// App modes available
  static const List<AppMode> ALL_MODES = [
    AppMode.survival,
    AppMode.hunter,
    AppMode.beast,
  ];

  /// Get unlocked modes based on streak days
  static List<AppMode> getUnlockedModes(int streakDays) {
    final modes = <AppMode>[AppMode.survival];
    if (streakDays >= HUNTER_MODE_UNLOCK_DAY) {
      modes.add(AppMode.hunter);
    }
    if (streakDays >= BEAST_MODE_UNLOCK_DAY) {
      modes.add(AppMode.beast);
    }
    return modes;
  }

  /// Get mode color scheme
  static Map<String, int> getModeColors(AppMode mode, bool isDark) {
    switch (mode) {
      case AppMode.survival:
        return isDark
            ? {'primary': 0xFF38BDF8, 'secondary': 0xFF00CFFF, 'accent': 0xFF0EA5E9}
            : {'primary': 0xFF2563EB, 'secondary': 0xFF00CFFF, 'accent': 0xFF3B82F6};
      case AppMode.hunter:
        return isDark
            ? {'primary': 0xFFA855F7, 'secondary': 0xFFD946EF, 'accent': 0xFF9333EA}
            : {'primary': 0xFF9333EA, 'secondary': 0xFFC026D3, 'accent': 0xFF7E22CE};
      case AppMode.beast:
        return isDark
            ? {'primary': 0xFFF87171, 'secondary': 0xFFF43F5E, 'accent': 0xFFEF4444}
            : {'primary': 0xFFDC2626, 'secondary': 0xFFE11D48, 'accent': 0xFFB91C1C};
    }
  }

  /// Get mode display name
  static String getModeName(AppMode mode) {
    switch (mode) {
      case AppMode.survival:
        return 'Survival';
      case AppMode.hunter:
        return 'Hunter';
      case AppMode.beast:
        return 'Beast';
    }
  }

  /// Get mode description
  static String getModeDescription(AppMode mode) {
    switch (mode) {
      case AppMode.survival:
        return 'Build foundations. Blue focus.';
      case AppMode.hunter:
        return 'Pursue mastery. Purple precision.';
      case AppMode.beast:
        return 'Unleash power. Red intensity.';
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // LEVEL CURVE
  // ════════════════════════════════════════════════════════════════════

  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (150 * pow(level.toDouble(), 1.6)).round();
  }

  static int levelForXP(int totalXP) {
    int level = 1;
    while (xpForLevel(level + 1) <= totalXP) {
      level++;
    }
    return level;
  }

  static double xpProgress(int totalXP) {
    final level = levelForXP(totalXP);
    final currentLevelXP = xpForLevel(level);
    final nextLevelXP = xpForLevel(level + 1);
    if (nextLevelXP <= currentLevelXP) return 1.0;
    return (totalXP - currentLevelXP) / (nextLevelXP - currentLevelXP);
  }

  static int xpRemaining(int totalXP) {
    final level = levelForXP(totalXP);
    final nextLevelXP = xpForLevel(level + 1);
    return nextLevelXP - totalXP;
  }

  static int xpTargetForLevel(int level) {
    return xpForLevel(level + 1);
  }

  // ════════════════════════════════════════════════════════════════════
  // STREAK & COOLDOWN LOGIC
  // ════════════════════════════════════════════════════════════════════

  /// Calculate streak status for a day
  static StreakDayResult calculateStreakDay({
    required int missionsCompleted,
    required int totalMissions,
    required List<StreakDay> streakHistory,
    required int cooldownsUsedThisWeek,
    required int currentStreak,
  }) {
    final completionRate = totalMissions > 0 ? missionsCompleted / totalMissions : 0.0;
    final isActivationDay = streakHistory.isEmpty || currentStreak == 0;
    final threshold = isActivationDay ? STREAK_ACTIVATION_THRESHOLD : STREAK_MAINTENANCE_THRESHOLD;

    // Check if streak activates/maintains
    if (completionRate >= threshold) {
      return StreakDayResult(
        status: StreakDayStatus.active,
        streakDay: currentStreak + 1,
        xpAwarded: DAILY_STREAK_BASE + _getMilestoneBonus(currentStreak + 1),
        cooldownUsed: false,
      );
    }

    // Check for cooldown availability
    final weekNumber = _getWeekNumber(streakHistory.length + 1);
    final cooldownsUsedInWeek = _getCooldownsUsedInWeek(streakHistory, weekNumber);

    if (cooldownsUsedInWeek < COOLDOWNS_PER_WEEK) {
      return StreakDayResult(
        status: StreakDayStatus.cooldown,
        streakDay: currentStreak, // Streak preserved
        xpAwarded: 0,
        cooldownUsed: true,
      );
    }

    // No cooldown left - streak breaks
    return StreakDayResult(
      status: StreakDayStatus.broken,
      streakDay: 0,
      xpAwarded: 0,
      cooldownUsed: false,
    );
  }

  static int _getMilestoneBonus(int streakDay) {
    if (streakDay % 100 == 0) return STREAK_MILESTONE_100;
    if (streakDay % 30 == 0) return STREAK_MILESTONE_30;
    if (streakDay % 7 == 0) return STREAK_MILESTONE_7;
    return 0;
  }

  static int _getWeekNumber(int dayIndex) {
    return (dayIndex / 7).ceil();
  }

  static int _getCooldownsUsedInWeek(List<StreakDay> history, int weekNumber) {
    final startIdx = (weekNumber - 1) * 7;
    final endIdx = min(startIdx + 7, history.length);
    return history.sublist(startIdx, endIdx)
        .where((d) => d.status == StreakDayStatus.cooldown)
        .length;
  }

  // ════════════════════════════════════════════════════════════════════
  // DAILY XP CALCULATION
  // ════════════════════════════════════════════════════════════════════

  static DailyXPResult calculateDailyXP({
    required List<XPTodo> todos,
    required DailyMissionsStatus dailyMissions,
    required int streakDay,
    required bool firstTodoOfDay,
  }) {
    final breakdown = <String, int>{};
    int total = 0;

    for (final todo in todos) {
      if (!todo.completed) continue;

      int baseXP;
      switch (todo.difficulty) {
        case XPTodoDifficulty.easy:
          baseXP = TODO_EASY;
          break;
        case XPTodoDifficulty.medium:
          baseXP = TODO_MEDIUM;
          break;
        case XPTodoDifficulty.hard:
          baseXP = TODO_HARD;
          break;
      }

      total += baseXP;
      breakdown['todo_${todo.difficulty.name}'] =
          (breakdown['todo_${todo.difficulty.name}'] ?? 0) + baseXP;

      if (todo.perfectForm && todo.difficulty == XPTodoDifficulty.hard) {
        total += TODO_PERFECT_FORM_BONUS;
        breakdown['todo_perfect_form'] =
            (breakdown['todo_perfect_form'] ?? 0) + TODO_PERFECT_FORM_BONUS;
      }
    }

    final completedTodos = todos.where((t) => t.completed).length;
    if (completedTodos > 0 && completedTodos == todos.length) {
      total += TODO_COMPLETION_BONUS;
      breakdown['todo_completion_bonus'] = TODO_COMPLETION_BONUS;
    }

    if (firstTodoOfDay && completedTodos > 0) {
      total += TODO_FIRST_OF_DAY_BONUS;
      breakdown['first_todo_bonus'] = TODO_FIRST_OF_DAY_BONUS;
    }

    total += dailyMissions.completedCount * DAILY_MISSION_SINGLE;
    breakdown['daily_missions'] = dailyMissions.completedCount * DAILY_MISSION_SINGLE;

    if (dailyMissions.allCompleted) {
      total += DAILY_MISSIONS_ALL_BONUS;
      breakdown['daily_missions_all_bonus'] = DAILY_MISSIONS_ALL_BONUS;
    }

    int streakXP = DAILY_STREAK_BASE;
    if (streakDay % 100 == 0) {
      streakXP += STREAK_MILESTONE_100;
    } else if (streakDay % 30 == 0) {
      streakXP += STREAK_MILESTONE_30;
    } else if (streakDay % 7 == 0) {
      streakXP += STREAK_MILESTONE_7;
    }

    total += streakXP;
    breakdown['daily_streak'] = streakXP;

    final hunterModeUnlocked = streakDay >= HUNTER_MODE_UNLOCK_DAY;
    final beastModeUnlocked = streakDay >= BEAST_MODE_UNLOCK_DAY;

    return DailyXPResult(
      total: total,
      breakdown: breakdown,
      hunterModeUnlocked: hunterModeUnlocked,
      beastModeUnlocked: beastModeUnlocked,
      streakDay: streakDay,
    );
  }

  static LevelUpResult checkLevelUp(int oldTotalXP, int newTotalXP) {
    final oldLevel = levelForXP(oldTotalXP);
    final newLevel = levelForXP(newTotalXP);
    return LevelUpResult(
      leveledUp: newLevel > oldLevel,
      oldLevel: oldLevel,
      newLevel: newLevel,
    );
  }

  static String hunterRank(int level) {
    if (level >= 50) return 'S-Rank Hunter';
    if (level >= 40) return 'A-Rank Hunter';
    if (level >= 30) return 'B-Rank Hunter';
    if (level >= 20) return 'C-Rank Hunter';
    if (level >= 15) return 'D-Rank Hunter';
    if (level >= 10) return 'E-Rank Hunter';
    if (level >= 5) return 'F-Rank Hunter';
    return 'Rookie Hunter';
  }

  static int rankColor(int level) {
    if (level >= 50) return 0xFF9B59B6;
    if (level >= 40) return 0xFFF39C12;
    if (level >= 30) return 0xFFE74C3C;
    if (level >= 20) return 0xFFE67E22;
    if (level >= 15) return 0xFF3498DB;
    if (level >= 10) return 0xFF2ECC71;
    if (level >= 5) return 0xFF95A5A6;
    return 0xFF7F8C8D;
  }
}

/// App modes
enum AppMode { survival, hunter, beast }

/// Streak day status
enum StreakDayStatus { active, cooldown, broken, incomplete }

/// A single day in streak history
class StreakDay {
  final DateTime date;
  final StreakDayStatus status;
  final int missionsCompleted;
  final int totalMissions;
  final int cooldownsUsed;

  const StreakDay({
    required this.date,
    required this.status,
    required this.missionsCompleted,
    required this.totalMissions,
    this.cooldownsUsed = 0,
  });

  factory StreakDay.fromMap(Map<String, dynamic> map) {
    return StreakDay(
      date: (map['date'] as Timestamp).toDate(),
      status: StreakDayStatus.values.byName(map['status']),
      missionsCompleted: map['missionsCompleted'] ?? 0,
      totalMissions: map['totalMissions'] ?? 5,
      cooldownsUsed: map['cooldownsUsed'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'status': status.name,
      'missionsCompleted': missionsCompleted,
      'totalMissions': totalMissions,
      'cooldownsUsed': cooldownsUsed,
    };
  }

  /// Local JSON serialization (uses ISO-8601 string instead of Firestore Timestamp).
  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'status': status.name,
        'missionsCompleted': missionsCompleted,
        'totalMissions': totalMissions,
        'cooldownsUsed': cooldownsUsed,
      };

  factory StreakDay.fromJson(Map<String, dynamic> json) => StreakDay(
        date: DateTime.parse(json['date'] as String),
        status: StreakDayStatus.values.byName(json['status'] as String),
        missionsCompleted: json['missionsCompleted'] as int? ?? 0,
        totalMissions: json['totalMissions'] as int? ?? 5,
        cooldownsUsed: json['cooldownsUsed'] as int? ?? 0,
      );
}

/// Result of streak day calculation
class StreakDayResult {
  final StreakDayStatus status;
  final int streakDay;
  final int xpAwarded;
  final bool cooldownUsed;

  const StreakDayResult({
    required this.status,
    required this.streakDay,
    required this.xpAwarded,
    required this.cooldownUsed,
  });
}

/// Result of daily XP calculation
class DailyXPResult {
  final int total;
  final Map<String, int> breakdown;
  final bool hunterModeUnlocked;
  final bool beastModeUnlocked;
  final int streakDay;

  const DailyXPResult({
    required this.total,
    required this.breakdown,
    required this.hunterModeUnlocked,
    required this.beastModeUnlocked,
    required this.streakDay,
  });
}

/// Result of level up check
class LevelUpResult {
  final bool leveledUp;
  final int oldLevel;
  final int newLevel;

  const LevelUpResult({
    required this.leveledUp,
    required this.oldLevel,
    required this.newLevel,
  });
}

/// Difficulty levels for todos/exercises
enum XPTodoDifficulty { easy, medium, hard }

/// A todo item with XP properties
class XPTodo {
  final String id;
  final String title;
  final XPTodoDifficulty difficulty;
  final bool completed;
  final bool perfectForm;

  const XPTodo({
    required this.id,
    required this.title,
    required this.difficulty,
    this.completed = false,
    this.perfectForm = false,
  });

  XPTodo copyWith({
    String? id,
    String? title,
    XPTodoDifficulty? difficulty,
    bool? completed,
    bool? perfectForm,
  }) {
    return XPTodo(
      id: id ?? this.id,
      title: title ?? this.title,
      difficulty: difficulty ?? this.difficulty,
      completed: completed ?? this.completed,
      perfectForm: perfectForm ?? this.perfectForm,
    );
  }
}

/// Daily missions completion status
class DailyMissionsStatus {
  final int completedCount;
  final int totalCount;
  final bool allCompleted;

  const DailyMissionsStatus({
    required this.completedCount,
    required this.totalCount,
  }) : allCompleted = completedCount >= totalCount;

  factory DailyMissionsStatus.fromMissions(List<Map<String, dynamic>> missions) {
    final completed = missions.where((m) => m['completed'] == true).length;
    return DailyMissionsStatus(
      completedCount: completed,
      totalCount: missions.length,
    );
  }
}