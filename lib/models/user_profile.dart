import 'package:cloud_firestore/cloud_firestore.dart';
import 'xp_system.dart';

class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String name;
  final int level;
  final int xp;
  final int xpTarget;
  final int streakDays;
  final List<StreakDay> streakHistory; // Detailed streak history with status
  final int cooldownsUsedThisWeek; // Cooldowns used in current week
  final int lastStreakUpdateDay; // Day index of last streak update
  final Map<String, dynamic> bodyStats;
  final Map<String, dynamic> dailyTargets;
  final List<Map<String, dynamic>> missions;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> meals;
  final int hydrationGlasses;
  final int workoutsCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool onboardingCompleted;
  final bool hunterModeUnlocked;
  final bool beastModeUnlocked;
  final AppMode currentMode; // Currently active mode
  final int totalXPEarned;

  UserProfile({
    required this.uid,
    required this.email,
    this.username = '',
    required this.name,
    this.level = 1,
    this.xp = 0,
    this.xpTarget = 1000,
    this.streakDays = 0,
    List<StreakDay>? streakHistory,
    this.cooldownsUsedThisWeek = 0,
    this.lastStreakUpdateDay = -1,
    Map<String, dynamic>? bodyStats,
    Map<String, dynamic>? dailyTargets,
    List<Map<String, dynamic>>? missions,
    List<Map<String, dynamic>>? tasks,
    List<Map<String, dynamic>>? meals,
    this.hydrationGlasses = 0,
    this.workoutsCompleted = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.onboardingCompleted = false,
    this.hunterModeUnlocked = false,
    this.beastModeUnlocked = false,
    this.currentMode = AppMode.survival,
    this.totalXPEarned = 0,
  }) : streakHistory = streakHistory ?? [],
       bodyStats = bodyStats ?? {
         'age': 24,
         'height': 178,
         'weight': 72.0,
         'bodyFat': 14.0,
       },
       dailyTargets = dailyTargets ?? {
         'calories': 2000,
         'protein': 150,
         'water': 3.0,
       },
       missions = missions ?? [
         {'title': 'Complete Workout Plan', 'xp': 250, 'completed': false},
         {'title': 'Walk 10,000 Steps', 'xp': 120, 'completed': false},
         {'title': 'Drink 3L Water', 'xp': 50, 'completed': false},
         {'title': 'Reach Protein Goal', 'xp': 70, 'completed': false},
         {'title': 'Sleep 8 Hours', 'xp': 60, 'completed': false},
       ],
       tasks = tasks ?? [
         {'title': 'Morning mobility flow', 'subtitle': '10 min • unlocks energy', 'completed': true, 'icon': 'self_improvement', 'color': 0xFF2563EB},
         {'title': 'Hydrate 2 liters', 'subtitle': 'Stay sharp for the day', 'completed': false, 'icon': 'water_drop', 'color': 0xFF38BDF8},
         {'title': 'Prep high-protein lunch', 'subtitle': 'Chicken bowl + greens', 'completed': false, 'icon': 'restaurant', 'color': 0xFFFB923C},
         {'title': 'Evening stretch', 'subtitle': 'Recovery routine', 'completed': false, 'icon': 'sports_gymnastics', 'color': 0xFF10B981},
       ],
       meals = meals ?? [
         {'name': 'Breakfast', 'food': 'Oatmeal & Berries', 'time': '08:30 AM', 'calories': 420, 'icon': 'free_breakfast', 'color': 0xFFFFB74D, 'logged': true},
         {'name': 'Lunch', 'food': 'Grilled Chicken Bowl', 'time': '12:15 PM', 'calories': 680, 'icon': 'lunch_dining', 'color': 0xFF66BB6A, 'logged': true},
         {'name': 'Snack', 'food': 'Greek Yogurt + Nuts', 'time': '04:00 PM', 'calories': 350, 'icon': 'icecream', 'color': 0xFF26C6DA, 'logged': true},
         {'name': 'Dinner', 'food': 'Salmon & Quinoa', 'time': '—', 'calories': 0, 'icon': 'dinner_dining', 'color': 0xFFEF5350, 'logged': false},
       ],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      name: data['name'] ?? '',
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0,
      xpTarget: data['xpTarget'] ?? 1000,
      streakDays: data['streakDays'] ?? 0,
      streakHistory: (data['streakHistory'] as List<dynamic>?)
              ?.map((e) => StreakDay.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      cooldownsUsedThisWeek: data['cooldownsUsedThisWeek'] ?? 0,
      lastStreakUpdateDay: data['lastStreakUpdateDay'] ?? -1,
      bodyStats: Map<String, dynamic>.from(data['bodyStats'] ?? {}),
      dailyTargets: Map<String, dynamic>.from(data['dailyTargets'] ?? {}),
      missions: List<Map<String, dynamic>>.from(data['missions'] ?? []),
      tasks: List<Map<String, dynamic>>.from(data['tasks'] ?? []),
      meals: List<Map<String, dynamic>>.from(data['meals'] ?? []),
      hydrationGlasses: data['hydrationGlasses'] ?? 0,
      workoutsCompleted: data['workoutsCompleted'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      hunterModeUnlocked: data['hunterModeUnlocked'] ?? false,
      beastModeUnlocked: data['beastModeUnlocked'] ?? false,
      currentMode: AppMode.values.byName(data['currentMode'] ?? 'survival'),
      totalXPEarned: data['totalXPEarned'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'name': name,
      'level': level,
      'xp': xp,
      'xpTarget': xpTarget,
      'streakDays': streakDays,
      'streakHistory': streakHistory.map((e) => e.toMap()).toList(),
      'cooldownsUsedThisWeek': cooldownsUsedThisWeek,
      'lastStreakUpdateDay': lastStreakUpdateDay,
      'bodyStats': bodyStats,
      'dailyTargets': dailyTargets,
      'missions': missions,
      'tasks': tasks,
      'meals': meals,
      'hydrationGlasses': hydrationGlasses,
      'workoutsCompleted': workoutsCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'onboardingCompleted': onboardingCompleted,
      'hunterModeUnlocked': hunterModeUnlocked,
      'beastModeUnlocked': beastModeUnlocked,
      'currentMode': currentMode.name,
      'totalXPEarned': totalXPEarned,
    };
  }

  UserProfile copyWith({
    String? name,
    String? username,
    int? level,
    int? xp,
    int? xpTarget,
    int? streakDays,
    List<StreakDay>? streakHistory,
    int? cooldownsUsedThisWeek,
    int? lastStreakUpdateDay,
    Map<String, dynamic>? bodyStats,
    Map<String, dynamic>? dailyTargets,
    List<Map<String, dynamic>>? missions,
    List<Map<String, dynamic>>? tasks,
    List<Map<String, dynamic>>? meals,
    int? hydrationGlasses,
    int? workoutsCompleted,
    bool? onboardingCompleted,
    bool? hunterModeUnlocked,
    bool? beastModeUnlocked,
    AppMode? currentMode,
    int? totalXPEarned,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      username: username ?? this.username,
      name: name ?? this.name,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpTarget: xpTarget ?? this.xpTarget,
      streakDays: streakDays ?? this.streakDays,
      streakHistory: streakHistory ?? this.streakHistory,
      cooldownsUsedThisWeek: cooldownsUsedThisWeek ?? this.cooldownsUsedThisWeek,
      lastStreakUpdateDay: lastStreakUpdateDay ?? this.lastStreakUpdateDay,
      bodyStats: bodyStats ?? this.bodyStats,
      dailyTargets: dailyTargets ?? this.dailyTargets,
      missions: missions ?? this.missions,
      tasks: tasks ?? this.tasks,
      meals: meals ?? this.meals,
      hydrationGlasses: hydrationGlasses ?? this.hydrationGlasses,
      workoutsCompleted: workoutsCompleted ?? this.workoutsCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      hunterModeUnlocked: hunterModeUnlocked ?? this.hunterModeUnlocked,
      beastModeUnlocked: beastModeUnlocked ?? this.beastModeUnlocked,
      currentMode: currentMode ?? this.currentMode,
      totalXPEarned: totalXPEarned ?? this.totalXPEarned,
    );
  }
}