import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:ascend_app/models/xp_system.dart';
import 'package:ascend_app/models/workout_plan.dart';
import 'package:ascend_app/services/local_storage.dart';
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
  // Mission completion status (toggled on tap)
  List<bool> _missionsDone = [true, false, true, false, false];

  // Streak history with detailed status (managed internally, not user-editable)
  List<StreakDay> _streakHistory = [];

  // Notification panel open
  bool _showNotifications = false;

  // XP and Level state (using XP system)
  int _totalXP = 3420;
  int get _level => XPSystem.levelForXP(_totalXP);
  int get _xpTarget => XPSystem.xpForLevel(_level + 1);
  String get _hunterRank => XPSystem.hunterRank(_level);
  int get _rankColor => XPSystem.rankColor(_level);
  bool _showLevelUp = false;
  int _oldLevel = 1;

  // User info from Firestore
  String _userName = 'Hunter';
  String _userAvatarUrl = '';

  void _awardXP(int xp) {
    final oldLevel = _level;
    _totalXP += xp;
    final newLevel = XPSystem.levelForXP(_totalXP);
    if (newLevel > oldLevel) {
      _showLevelUpAnimation(newLevel);
    }
    _saveLocalState();
  }

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

  void _updateXPState() {
    setState(() {
      // Trigger rebuild with new computed values
    });
  }

  void _updateUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _userName = data['name'] as String? ?? 'Hunter';
          _userAvatarUrl = data['avatarUrl'] as String? ?? '';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLocalState();
    _updateUserInfo();
  }

  // ── Local persistence ────────────────────────────────────────

  void _loadLocalState() {
    _totalXP = LocalStorage.loadInt('totalXP', 3420);

    // Load missions done
    final missionsRaw = LocalStorage.loadJsonString('missionsDone');
    if (missionsRaw != null) {
      try {
        final list = (jsonDecode(missionsRaw) as List<dynamic>).cast<bool>();
        if (list.length == 5) _missionsDone = list;
      } catch (_) {}
    }

    // Load streak history
    final streakRaw = LocalStorage.loadJsonString('streakHistory');
    if (streakRaw != null) {
      try {
        final list = (jsonDecode(streakRaw) as List<dynamic>)
            .map((e) => StreakDay.fromJson(e as Map<String, dynamic>))
            .toList();
        _streakHistory = list;
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  void _saveLocalState() {
    LocalStorage.saveInt('totalXP', _totalXP);
    LocalStorage.saveJson('missionsDone', _missionsDone);
    LocalStorage.saveJson('streakHistory', _streakHistory.map((s) => s.toJson()).toList());
  }

  /// Update streak based on current mission completion and save to Firestore
  void _updateStreak() {
    final completed = _missionsCompleted;
    final total = _missionsDone.length;

    // Only process streak if we haven't already today
    final today = DateTime.now();
    final alreadyToday = _streakHistory.any((s) =>
        s.date.year == today.year &&
        s.date.month == today.month &&
        s.date.day == today.day);
    if (alreadyToday) return;

    _processDailyStreak(
      missionsCompleted: completed,
      totalMissions: total,
    );

    // Save streak to Firestore so profile page can read it
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'streakDays': _currentStreak,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Process daily streak with cooldown logic
  /// Called when user completes their daily check-in
  void _processDailyStreak({
    required int missionsCompleted,
    required int totalMissions,
  }) {
    setState(() {
      final result = XPSystem.calculateStreakDay(
        missionsCompleted: missionsCompleted,
        totalMissions: totalMissions,
        streakHistory: _streakHistory,
        cooldownsUsedThisWeek: 0,
        currentStreak: _currentStreak,
      );

      _streakHistory.add(StreakDay(
        date: DateTime.now(),
        status: result.status,
        missionsCompleted: missionsCompleted,
        totalMissions: totalMissions,
        cooldownsUsed: result.cooldownUsed ? 1 : 0,
      ));

      if (result.xpAwarded > 0) {
        _awardXP(result.xpAwarded);
      }
    });
    _saveLocalState();
  }

  /// Get current streak count
  int get _currentStreak {
    if (_streakHistory.isEmpty) return 0;
    int count = 0;
    for (int i = _streakHistory.length - 1; i >= 0; i--) {
      if (_streakHistory[i].status == StreakDayStatus.active) {
        count++;
      } else if (_streakHistory[i].status == StreakDayStatus.cooldown) {
        // Cooldown preserves streak, continue counting
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Get cooldowns used in current week
  int get _cooldownsUsedThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _streakHistory
        .where((d) => d.date.isAfter(weekStart) && d.status == StreakDayStatus.cooldown)
        .length;
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

              // 4. Daily Nutrition progress card
              _buildNutritionCard(),
              const SizedBox(height: 20),

              // 5. Health Sync Data Card
              _buildHealthStatsCard(),
              const SizedBox(height: 20),

              // 6. Daily Quests / Missions List
              _buildDailyMissionsSection(),
              const SizedBox(height: 20),

              // 7. Quick Actions Card
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
                  _hunterRank,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(_rankColor),
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
    final currentLevelXP = XPSystem.xpForLevel(_level);
    final progress = _level == 1 ? 0.0 : (_totalXP - currentLevelXP) / (_xpTarget - currentLevelXP);

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
                      color: Color(_rankColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield, color: Color(_rankColor), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'LVL $_level',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(_rankColor),
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
                '$_totalXP / $_xpTarget XP',
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
                'Progress to Level ${_level + 1}',
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
              Text(
                '${(_xpTarget - _totalXP).toStringAsFixed(0)} XP remaining',
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
    final List<String> days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final streakCount = _currentStreak;
    final cooldownsThisWeek = _cooldownsUsedThisWeek;

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
                  if (_cooldownsUsedThisWeek > 0)
                    Text(
                      '$_cooldownsUsedThisWeek/${XPSystem.COOLDOWNS_PER_WEEK} cooldowns this week',
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
              if (_streakHistory.length > index) {
                final historyIndex = _streakHistory.length - 7 + index;
                if (historyIndex >= 0 && historyIndex < _streakHistory.length) {
                  status = _streakHistory[historyIndex].status;
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
                  '$_currentStreak Days Streak',
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
              'Cooldowns used this week: $_cooldownsUsedThisWeek/${XPSystem.COOLDOWNS_PER_WEEK}',
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete ${XPSystem.STREAK_ACTIVATION_THRESHOLD * 100}% of daily missions to maintain your streak. You have ${XPSystem.COOLDOWNS_PER_WEEK - _cooldownsUsedThisWeek} cooldowns left this week.',
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
        return Icon(Icons.check, color: context.accent, size: 16);
      case StreakDayStatus.cooldown:
        return const Icon(Icons.pause, color: Color(0xFFF59E0B), size: 14);
      case StreakDayStatus.broken:
        return const Icon(Icons.close, color: Color(0xFFEF4444), size: 14);
      case StreakDayStatus.incomplete:
        return Icon(Icons.circle_outlined, color: context.textMuted, size: 10);
    }
  }


  Widget _buildNutritionCard() {
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
                    'Daily Nutrition Goals',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    'Today\'s target intake',
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 20, color: context.textSecondary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nutrition editing coming with Firebase!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 90,
                    width: 90,
                    child: CircularProgressIndicator(
                      value: 1450 / 2000,
                      strokeWidth: 8,
                      backgroundColor: context.divider,
                      color: context.accent,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '1,450',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        '/ 2000 kcal',
                        style: TextStyle(
                          fontSize: 9,
                          color: context.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildMacroRow('Protein', 94, 150, 'g', Colors.redAccent),
                    const SizedBox(height: 10),
                    _buildMacroRow('Carbs', 162, 250, 'g', Colors.orangeAccent),
                    const SizedBox(height: 10),
                    _buildMacroRow('Fats', 48, 70, 'g', Colors.green),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 30, color: context.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFooterMetric('Water Intake', '1.8L', '/ 3.0L', Icons.water_drop, Colors.blue),
              _buildFooterMetric('Fiber Intake', '22g', '/ 30g', Icons.grass, Colors.lightGreen),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMacroRow(String name, double value, double target, String unit, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary),
            ),
            Text(
              '${value.toInt()}/${target.toInt()}$unit',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 6,
            color: context.divider,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value / target,
              child: Container(color: barColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterMetric(String title, String current, String target, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, color: context.textMuted),
            ),
            Row(
              children: [
                Text(
                  current,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                Text(
                  target,
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ],
    );
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
                    onTap: () {
                      setState(() {
                        ex.completed = !ex.completed;
                        if (ex.completed) {
                          _totalXP += XPSystem.TODO_MEDIUM;
                        } else {
                          _totalXP -= XPSystem.TODO_MEDIUM;
                        }
                      });
                      _saveLocalState();
                      // Persist workout plan change
                      final planState = Provider.of<WorkoutPlanState>(context, listen: false);
                      planState.updatePlan(planState.plan);
                      _updateStreak();
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
                onTap: () {
                  setState(() {
                    _missionsDone[index] = !_missionsDone[index];
                    // Award / remove XP
                    if (_missionsDone[index]) {
                      _totalXP += missionXP[index];
                    } else {
                      _totalXP -= missionXP[index];
                    }
                  });
                  _saveLocalState();
                  _updateStreak();
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