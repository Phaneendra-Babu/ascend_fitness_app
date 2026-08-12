import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:ascend_app/models/xp_system.dart';
import 'package:ascend_app/models/workout_plan.dart';
import 'package:ascend_app/services/local_storage.dart';
import '../controllers/progress_controller.dart';
import '../services/notification_service.dart';
import 'profile_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/flame_effect.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Local state ──────────────────────────────────────────────
  // Fallback mission completion status (toggled on tap). Only used when there
  // is no workout plan for today.
  List<bool> _missionsDone = [true, false, true, false, false];

  // Notification panel open
  bool _showNotifications = false;

  void _showLevelUpAnimation(int newLevel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉 LEVEL UP!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('You reached Level $newLevel — ${XPSystem.hunterRank(newLevel)}', style: const TextStyle(fontSize: 14)),
          ],
        ),
        backgroundColor: context.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  // ── Local persistence ────────────────────────────────────────

  void _loadLocalState() {
    final missionsRaw = LocalStorage.loadJsonString('missionsDone');
    if (missionsRaw != null) {
      try {
        final list = (jsonDecode(missionsRaw) as List<dynamic>).cast<bool>();
        if (list.length == 5) _missionsDone = list;
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _saveMissions() {
    LocalStorage.saveJson('missionsDone', _missionsDone);
  }

  /// Feed today's combined exercise + habit progress into the shared
  /// ProgressController so the streak / fire mark updates live.
  void _recordDayProgress(ProgressController progress) {
    final planState = Provider.of<WorkoutPlanState>(context, listen: false);
    final exercises = planState.todayExercises;
    if (exercises.isEmpty) {
      // No plan for today → the 5 fallback missions stand in for exercises.
      progress.recordDayProgress(
        exercisesCompleted: _missionsCompleted,
        exercisesTotal: _missionsDone.length,
      );
    } else {
      progress.recordDayProgress(
        exercisesCompleted: exercises.where((e) => e.completed).length,
        exercisesTotal: exercises.length,
      );
    }
  }

  // Computed helpers
  int get _missionsCompleted => _missionsDone.where((d) => d).length;
  String get _greeting {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.flash_on, color: context.accent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ASCEND',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'HUNTER SYSTEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: context.textSecondary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${3 - _missionsCompleted > 0 ? 3 - _missionsCompleted : 0}'),
              child: Icon(Icons.notifications_none, color: context.textPrimary),
            ),
            onPressed: () {
              setState(() => _showNotifications = !_showNotifications);
            },
          ),
          const SizedBox(width: 8),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              String name = 'Hunter';
              String avatarUrl = '';
              if (snapshot.hasData && snapshot.data?.data() != null) {
                final data = snapshot.data!.data()!;
                name = data['name'] as String? ?? 'Hunter';
                avatarUrl = data['avatarUrl'] as String? ?? '';
              }
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.accent, width: 2),
                    gradient: LinearGradient(
                      colors: [context.accent, Color(0xFF38BDF8)],
                    ),
                  ),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'H',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'H',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification dropdown
              if (_showNotifications) _buildNotificationsPanel(),

              // 1. Personalized Greeting & Quick Stats
              _buildHeaderSection(),
              const SizedBox(height: 20),

              // 2. XP & Leveling Card
              _buildXPCard(),
              const SizedBox(height: 20),

              // 3. Weekly Streak Card
              _buildStreakCard(),
              const SizedBox(height: 20),

              // 4. Health Sync Data Card
              _buildHealthStatsCard(),
              const SizedBox(height: 20),

              // 5. Daily Quests / Missions List
              _buildDailyMissionsSection(),
              const SizedBox(height: 20),

              // 6. Quick Actions Card
              _buildQuickAccessSection(context),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notifications Panel ────────────────────────────────────
  Widget _buildNotificationsPanel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notifications',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
              GestureDetector(
                onTap: () => setState(() => _showNotifications = false),
                child: Icon(Icons.close, size: 18, color: context.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNotificationItem('🔥 Keep your streak alive!', 'Complete today\'s mission to hit 10 days.'),
          _buildNotificationItem('💧 Water reminder', 'You\'re 1.2L away from your daily goal.'),
          _buildNotificationItem('🏋️ Workout time', 'Upper Body Forge is scheduled for today.'),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: context.accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text(body, style: TextStyle(fontSize: 11, color: context.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeaderSection() {
    final p = context.watch<ProgressController>();
    final level = XPSystem.levelForXP(p.totalXP);
    final hunterRank = XPSystem.hunterRank(level);
    final rankColor = XPSystem.rankColor(level);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String name = 'Hunter';
        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data()!;
          name = data['name'] as String? ?? 'Hunter';
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.bolt, color: Colors.amber, size: 28),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RANK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: context.textMuted,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  hunterRank,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(rankColor),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── XP Card ────────────────────────────────────────────────
  Widget _buildXPCard() {
    final p = context.watch<ProgressController>();
    final level = XPSystem.levelForXP(p.totalXP);
    final xpTarget = XPSystem.xpForLevel(level + 1);
    final rankColor = XPSystem.rankColor(level);
    final currentLevelXP = XPSystem.xpForLevel(level);
    final xpInLevel = xpTarget - currentLevelXP;
    final progress = xpInLevel > 0
        ? (p.totalXP - currentLevelXP) / xpInLevel
        : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(rankColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield, color: Color(rankColor), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'LVL $level',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(rankColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hunter Level',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${p.totalXP} / $xpTarget XP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Animated progress bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 10,
                  width: double.infinity,
                  color: context.border,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.accent, Color(0xFF00CFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress to Level ${level + 1}',
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
              Text(
                '${(xpTarget - p.totalXP).toStringAsFixed(0)} XP remaining',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.accent),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ── Streak Card (tappable days) ────────────────────────────
  Widget _buildStreakCard() {
    final progress = context.watch<ProgressController>();
    final streakCount = progress.currentStreak;
    final cooldownsThisWeek = progress.cooldownsUsedThisWeek;

    // Calculate streak XP using XP system
    int streakXP = XPSystem.DAILY_STREAK_BASE;
    if (streakCount > 0) {
      if (streakCount % 100 == 0) streakXP += XPSystem.STREAK_MILESTONE_100;
      else if (streakCount % 30 == 0) streakXP += XPSystem.STREAK_MILESTONE_30;
      else if (streakCount % 7 == 0) streakXP += XPSystem.STREAK_MILESTONE_7;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FlameGlow(
                    color: context.accent,
                    size: 28,
                    child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$streakCount Days Streak',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+$streakXP XP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.accent,
                    ),
                  ),
                  if (cooldownsThisWeek > 0)
                    Text(
                      '$cooldownsThisWeek/${XPSystem.COOLDOWNS_PER_WEEK} cooldowns this week',
                      style: TextStyle(fontSize: 10, color: context.textMuted),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              // Get streak history for this day of week (last 7 days)
              StreakDayStatus status = StreakDayStatus.incomplete;
              final history = progress.streakHistory;
              if (history.length > index) {
                final historyIndex = history.length - 7 + index;
                if (historyIndex >= 0 && historyIndex < history.length) {
                  status = history[historyIndex].status;
                }
              }

              final isToday = index == DateTime.now().weekday - 1;

              return GestureDetector(
                // User cannot edit streaks - they're managed internally
                onTap: isToday ? () => _showStreakDetail(context) : null,
                child: Column(
                  children: [
                    Text(
                      ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getStreakDayColor(status),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getStreakDayBorderColor(status),
                          width: status == StreakDayStatus.active ? 2 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _getStreakDayIcon(status),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  void _showStreakDetail(BuildContext context) {
    final progress = Provider.of<ProgressController>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  '${progress.currentStreak} Days Streak',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Cooldowns used this week: ${progress.cooldownsUsedThisWeek}/${XPSystem.COOLDOWNS_PER_WEEK}',
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete ${XPSystem.STREAK_ACTIVATION_THRESHOLD * 100}% of daily missions to maintain your streak. You have ${XPSystem.COOLDOWNS_PER_WEEK - progress.cooldownsUsedThisWeek} cooldowns left this week.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: context.accent,
              ),
              child: const Text('Got it', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper methods for Streak Card ──────────────────────────
  Color _getStreakDayColor(StreakDayStatus status) {
    switch (status) {
      case StreakDayStatus.active:
        return context.accent.withValues(alpha: 0.1);
      case StreakDayStatus.cooldown:
        return const Color(0xFFF59E0B).withValues(alpha: 0.1);
      case StreakDayStatus.broken:
        return const Color(0xFFEF4444).withValues(alpha: 0.1);
      case StreakDayStatus.incomplete:
        return context.divider;
    }
  }

  Color _getStreakDayBorderColor(StreakDayStatus status) {
    switch (status) {
      case StreakDayStatus.active:
        return context.accent;
      case StreakDayStatus.cooldown:
        return const Color(0xFFF59E0B);
      case StreakDayStatus.broken:
        return const Color(0xFFEF4444);
      case StreakDayStatus.incomplete:
        return Colors.transparent;
    }
  }

  Widget _getStreakDayIcon(StreakDayStatus status) {
    switch (status) {
      case StreakDayStatus.active:
        // 🔥 Fire mark for days that hit the completion threshold.
        return const Icon(Icons.local_fire_department, color: Colors.orange, size: 16);
      case StreakDayStatus.cooldown:
        // ❄️ Distinct snowflake symbol for cooldown days.
        return const Icon(Icons.ac_unit, color: Color(0xFFF59E0B), size: 14);
      case StreakDayStatus.broken:
        return const Icon(Icons.close, color: Color(0xFFEF4444), size: 14);
      case StreakDayStatus.incomplete:
        return Icon(Icons.circle_outlined, color: context.textMuted, size: 10);
    }
  }


  // ── Health Stats Card ──────────────────────────────────────
  Widget _buildHealthStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Activity Sync',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildStatTile('Steps', '8,452', '/10k steps', Icons.directions_walk, Colors.blue),
              _buildStatTile('Heart Rate', '72 bpm', 'Active Avg', Icons.favorite, Colors.redAccent),
              _buildStatTile('Active Calories', '520 kcal', 'Daily Burn', Icons.local_fire_department, Colors.orange),
              _buildStatTile('Active Minutes', '68 min', 'Goal 60 Min', Icons.timer, Colors.cyan),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, String target, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColorAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.textSecondary),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              Text(
                target,
                style: TextStyle(fontSize: 10, color: context.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Daily Missions (tappable to toggle) ────────────────────
  Widget _buildDailyMissionsSection() {
    return Consumer<WorkoutPlanState>(
      builder: (context, planState, _) {
        final exercises = planState.todayExercises;
        // Fall back to hardcoded missions if no workout plan for today
        if (exercises.isEmpty) {
          return _buildFallbackMissions();
        }

        return Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Missions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                      ),
                      Text(
                        'Today\'s workout exercises',
                        style: TextStyle(fontSize: 11, color: context.textMuted),
                      ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(exercises.where((e) => e.completed).length),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${exercises.where((e) => e.completed).length}/${exercises.length} Completed',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.accent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final ex = exercises[index];
                  return GestureDetector(
                    onTap: () async {
                      final progress = Provider.of<ProgressController>(context, listen: false);
                      final planState = Provider.of<WorkoutPlanState>(context, listen: false);
                      final wasCompleted = ex.completed;
                      setState(() {
                        ex.completed = !ex.completed;
                      });
                      final leveledUp = await progress.awardXP(
                          wasCompleted ? -XPSystem.TODO_MEDIUM : XPSystem.TODO_MEDIUM);
                      // Persist workout plan change
                      planState.updatePlan(planState.plan);
                      // Keep today's workout reminder in sync with completion.
                      NotificationService.instance.syncWorkoutReminder(
                          incomplete: planState.todayWorkoutIncomplete);
                      if (!mounted) return;
                      _recordDayProgress(progress);
                      if (leveledUp) {
                        _showLevelUpAnimation(XPSystem.levelForXP(progress.totalXP));
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ex.completed ? context.cardColorAlt : context.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ex.completed ? Colors.transparent : context.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              ex.completed ? Icons.check_circle : Icons.circle_outlined,
                              key: ValueKey(ex.completed),
                              color: ex.completed ? context.accent : context.textMuted,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ex.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ex.completed ? context.textMuted : context.textPrimary,
                                decoration: ex.completed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ex.completed
                                  ? Colors.green.withOpacity(0.1)
                                  : context.accent.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${XPSystem.TODO_MEDIUM} XP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ex.completed ? Colors.green : context.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        );
      },
    );
  }

  /// Fallback when no workout plan is set for today.
  Widget _buildFallbackMissions() {
    final missionTitles = [
      'Complete Workout Plan',
      'Walk 10,000 Steps',
      'Drink 3L Water',
      'Reach Protein Goal',
      'Sleep 8 Hours',
    ];
    final missionXP = [250, 120, 50, 70, 60];

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Missions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    'RPG quests for today',
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_missionsCompleted),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_missionsCompleted/${_missionsDone.length} Completed',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: missionTitles.length,
            itemBuilder: (context, index) {
              final isDone = _missionsDone[index];
              return GestureDetector(
                onTap: () async {
                  final progress = Provider.of<ProgressController>(context, listen: false);
                  final wasDone = _missionsDone[index];
                  setState(() {
                    _missionsDone[index] = !_missionsDone[index];
                  });
                  final leveledUp = await progress.awardXP(
                      wasDone ? -missionXP[index] : missionXP[index]);
                  _saveMissions();
                  if (!mounted) return;
                  _recordDayProgress(progress);
                  if (leveledUp) {
                    _showLevelUpAnimation(XPSystem.levelForXP(progress.totalXP));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDone ? context.cardColorAlt : context.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDone ? Colors.transparent : context.border,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isDone ? Icons.check_circle : Icons.circle_outlined,
                          key: ValueKey(isDone),
                          color: isDone ? context.accent : context.textMuted,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          missionTitles[index],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDone ? context.textMuted : context.textPrimary,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDone
                              ? Colors.green.withOpacity(0.1)
                              : context.accent.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${missionXP[index]} XP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDone ? Colors.green : context.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  // ── Quick Access Actions (navigate to tabs) ────────────────
  Widget _buildQuickAccessSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionCard(
              context,
              'Workout Tracker',
              Icons.fitness_center,
              context.accent,
              tabIndex: 4,
            ),
            _buildActionCard(
              context,
              'Diet Planner',
              Icons.restaurant_menu,
              const Color(0xFF00CFFF),
              tabIndex: 1,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String text, IconData icon, Color color, {required int tabIndex}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          widget.onNavigateToTab?.call(tabIndex);
        },
        child: Card(
          color: context.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 12, color: context.textMuted),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}