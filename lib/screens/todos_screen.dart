import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ascend_app/models/xp_system.dart';
import 'package:ascend_app/models/workout_plan.dart';
import 'package:ascend_app/models/exercise.dart';
import 'package:ascend_app/widgets/body_map.dart';
import '../controllers/progress_controller.dart';
import '../services/notification_service.dart';
import 'exercise_picker_screen.dart';
import '../theme/app_colors.dart';

class TodosScreen extends StatefulWidget {
  final WeeklyPlan? weeklyPlan;
  final void Function(WeeklyPlan plan)? onPlanChanged;

  const TodosScreen({super.key, this.weeklyPlan, this.onPlanChanged});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon

  // ── Local state ──────────────────────────────────────────────
  late WeeklyPlan _plan;

  int? _swipedExerciseIndex;
  String? _swipedHabitId;

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _plan = widget.weeklyPlan ?? WeeklyPlan.defaultPlan();
    // Mark today as index 0 = Mon
    final today = DateTime.now().weekday; // 1=Mon
    _selectedDay = today - 1;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────

  WorkoutDay? get _currentDay => _plan.days[_selectedDay + 1];

  /// Muscle group name → number of exercises targeting it.
  Map<String, int> get _activeMuscleCounts {
    final day = _currentDay;
    if (day == null) return {};
    final counts = <String, int>{};
    for (final ex in day.exercises) {
      counts[ex.muscleGroup] = (counts[ex.muscleGroup] ?? 0) + 1;
    }
    return counts;
  }

  /// Generate a dynamic day name based on the muscle groups present.
  String _dynamicDayName(WorkoutDay day) {
    if (day.exercises.isEmpty) return 'Rest Day';
    final groups = day.exercises.map((e) => e.muscleGroup).toSet();
    if (groups.contains('Cardio') && groups.length == 1) return 'Cardio Day';
    if (groups.length >= 4) return 'Full Body Day';
    if (groups.length == 1) {
      final g = groups.first;
      if (g == 'Legs') return 'Leg Day';
      if (g == 'Chest') return 'Chest Day';
      if (g == 'Back') return 'Back Day';
      if (g == 'Arms') return 'Arms Day';
      if (g == 'Core') return 'Core Day';
      if (g == 'Shoulders') return 'Shoulders Day';
      return '$g Day';
    }
    final sorted = groups.toList()..sort();
    return '${sorted.join(" + ")} Day';
  }

  Future<void> _toggleExercise(int index) async {
    final day = _currentDay;
    if (day == null || index >= day.exercises.length) return;
    // Only allow toggling for today's workouts
    final today = DateTime.now().weekday; // 1=Mon
    if (_selectedDay + 1 != today) return;
    final progress = Provider.of<ProgressController>(context, listen: false);
    final ex = day.exercises[index];
    final wasComplete = ex.completed;
    setState(() {
      ex.completed = !ex.completed;
    });
    final leveledUp = await progress.awardXP(
        wasComplete ? -XPSystem.TODO_MEDIUM : XPSystem.TODO_MEDIUM);
    _notifyPlanChanged();
    // Keep today's workout reminder in sync with the toggled completion.
    _syncWorkoutReminder();
    if (!mounted) return;
    _recordDayProgress(progress);
    if (ex.completed && !wasComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${ex.name}" complete! +${XPSystem.TODO_MEDIUM} XP'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    if (leveledUp) {
      _showLevelUpSnackBar(XPSystem.levelForXP(progress.totalXP));
    }
  }

  /// Recompute today's streak/fire status after any exercise or habit toggle.
  void _recordDayProgress(ProgressController progress) {
    final today = DateTime.now().weekday;
    final day = _plan.days[today];
    final exercises = day?.exercises ?? [];
    progress.recordDayProgress(
      exercisesCompleted: exercises.where((e) => e.completed).length,
      exercisesTotal: exercises.length,
    );
  }

  /// Keep today's workout reminder in sync with today's completion state
  /// (schedules it when exercises remain, cancels when all are done).
  void _syncWorkoutReminder() {
    final todayDay = _plan.days[DateTime.now().weekday];
    final workoutIncomplete =
        (todayDay?.exercises.isNotEmpty ?? false) && !(todayDay?.allComplete ?? false);
    NotificationService.instance.syncWorkoutReminder(incomplete: workoutIncomplete);
  }

  void _showLevelUpSnackBar(int newLevel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '🎉 LEVEL UP! You reached Level $newLevel — ${XPSystem.hunterRank(newLevel)}'),
        backgroundColor: context.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleHabit(Habit habit) async {
    // Only allow toggling for today's habits
    final today = DateTime.now().weekday;
    if (_selectedDay + 1 != today) return;
    final progress = Provider.of<ProgressController>(context, listen: false);
    await progress.toggleHabit(today, habit.id);
  }

  void _notifyPlanChanged() {
    widget.onPlanChanged?.call(_plan);
  }

  void _onReorder(int oldIndex, int newIndex) {
    final day = _currentDay;
    if (day == null) return;
    setState(() {
      // onReorderItem passes newIndex already adjusted for the removed item,
      // so no off-by-one fix is needed here.
      final item = day.exercises.removeAt(oldIndex);
      day.exercises.insert(newIndex, item);
    });
    _notifyPlanChanged();
  }

  /// Reorder habits. The list on screen only shows habits scheduled for the
  /// selected day, so the reorder is applied to the visible subset and then
  /// merged back into the full list keeping non-visible habits in place.
  void _onHabitReorder(int oldIndex, int newIndex) {
    final progress = Provider.of<ProgressController>(context, listen: false);
    final weekday = _selectedDay + 1;
    final all = List<Habit>.of(progress.habits);
    final visible = all.where((h) => h.isScheduledFor(weekday)).toList();
    if (visible.isEmpty) return;

    final moved = visible.removeAt(oldIndex);
    visible.insert(newIndex.clamp(0, visible.length), moved);

    // Rebuild the full list: visible habits in their new order, others keep
    // their original slots.
    final newOrder = <Habit>[];
    var v = 0;
    for (final h in all) {
      if (h.isScheduledFor(weekday)) {
        newOrder.add(visible[v++]);
      } else {
        newOrder.add(h);
      }
    }
    progress.reorderHabits(newOrder);
  }

  /// Smooth the drag proxy: the picked-up card grows slightly as it lifts and
  /// keeps its own rounded corners + shadow instead of the default plain
  /// Material, so it floats instead of snapping.
  Widget _dragProxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOut.transform(animation.value);
        return Transform.scale(
          scale: 1.0 + (0.04 * t),
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        );
      },
    );
  }

  void _showAddHabitDialog() {
    final ctrl = TextEditingController();
    final selectedDays = <int>{}; // empty = everyday
    bool isEveryday = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Habit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: 'Habit name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Set habit for',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                // Everyday toggle
                GestureDetector(
                  onTap: () {
                    setDialogState(() {
                      isEveryday = true;
                      selectedDays.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isEveryday
                          ? context.accent.withValues(alpha: 0.15)
                          : context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isEveryday ? context.accent : context.border,
                        width: isEveryday ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isEveryday ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isEveryday ? context.accent : context.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Everyday',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isEveryday ? context.accent : context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Custom days
                GestureDetector(
                  onTap: () {
                    setDialogState(() {
                      isEveryday = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: !isEveryday
                          ? context.accent.withValues(alpha: 0.15)
                          : context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !isEveryday ? context.accent : context.border,
                        width: !isEveryday ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !isEveryday ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: !isEveryday ? context.accent : context.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Custom days',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: !isEveryday ? context.accent : context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Day chips (visible when custom is selected)
                if (!isEveryday) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (i) {
                      final dayNum = i + 1;
                      final dayLabel = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i];
                      final isSelected = selectedDays.contains(dayNum);
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              selectedDays.remove(dayNum);
                            } else {
                              selectedDays.add(dayNum);
                            }
                          });
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.accent
                                : context.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? context.accent : context.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              dayLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : context.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  final schedule = isEveryday ? <int>[] : selectedDays.toList()..sort();
                  Provider.of<ProgressController>(context, listen: false).addHabit(
                    Habit(
                      id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
                      name: ctrl.text.trim(),
                      icon: Icons.check_circle_outline,
                      color: context.accent,
                      scheduleDays: schedule,
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'TODOS / WORKOUTS',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: context.cardColor,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: context.accent,
              unselectedLabelColor: context.textMuted,
              indicatorColor: context.accent,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Workout'),
                Tab(text: 'Habit'),
              ],
            ),
          ),
          // Tab content (each tab has its own calendar)
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildWorkoutTab(),
                _buildHabitTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Week Calendar ────────────────────────────────────────────

  // ── Workout Tab (calendar + workout list) ────────────────────

  Widget _buildWorkoutTab() {
    return Column(
      children: [
        _buildWorkoutWeekCalendar(),
        Expanded(child: _buildWorkoutView()),
      ],
    );
  }

  // ── Habit Tab (calendar + habit list) ────────────────────────

  Widget _buildHabitTab() {
    return Column(
      children: [
        _buildHabitWeekCalendar(),
        Expanded(child: _buildHabitView()),
      ],
    );
  }

  // ── Workout Week Calendar ───────────────────────────────────

  Widget _buildWorkoutWeekCalendar() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(bottom: BorderSide(color: context.divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final dayDate = today.subtract(Duration(days: today.weekday - 1 - index));
          final isSelected = index == _selectedDay;
          final dayPlan = _plan.days[index + 1];
          final hasWorkout = dayPlan != null && dayPlan.exercises.isNotEmpty;
          final isWorkoutComplete = dayPlan?.allComplete ?? false;

          Color? dotColor;
          if (isWorkoutComplete) {
            dotColor = const Color(0xFF10B981);
          } else if (hasWorkout) {
            dotColor = context.accent;
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = index),
            child: Column(
              children: [
                Text(
                  days[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? context.accent : context.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? context.accent : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      '${dayDate.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : context.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Habit Week Calendar ─────────────────────────────────────

  Widget _buildHabitWeekCalendar() {
    final progress = context.watch<ProgressController>();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(bottom: BorderSide(color: context.divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final dayDate = today.subtract(Duration(days: today.weekday - 1 - index));
          final isSelected = index == _selectedDay;
          final isHabitComplete = progress.areAllScheduledHabitsDone(index + 1);
          final hasHabit = progress.hasAnyHabitDone(index + 1);

          Color? dotColor;
          if (isHabitComplete) {
            dotColor = const Color(0xFF10B981);
          } else if (hasHabit) {
            dotColor = context.accent;
          }

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDay = index);
            },
            child: Column(
              children: [
                Text(
                  days[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? context.accent : context.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? context.accent : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      '${dayDate.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : context.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Workout View ─────────────────────────────────────────────

  Widget _buildWorkoutView() {
    final day = _currentDay;
    if (day == null) {
      return const Center(child: Text('No plan for this day'));
    }

    final completed = day.completedCount;
    final total = day.exercises.length;
    final progress = total > 0 ? completed / total : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Body figure
          _buildBodyFigure(),
          const SizedBox(height: 16),
          // Day label + target muscles
          _buildDayHeader(day),
          const SizedBox(height: 16),
          // Exercise list
          if (day.exercises.isEmpty)
            _buildRestDayCard()
          else ...[
            SizedBox(
              height: day.exercises.length * 80.0,
              child: ReorderableListView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: day.exercises.length,
                onReorderItem: _onReorder,
                proxyDecorator: _dragProxyDecorator,
                itemBuilder: (_, i) => KeyedSubtree(
                  key: ValueKey('exercise_${day.exercises[i].exerciseId}_$i'),
                  child: _buildExerciseTile(i, day.exercises[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Progress bar + XP
            _buildWorkoutProgress(completed, total, progress),
            const SizedBox(height: 16),
          ],
          // Add Exercise button (always visible)
          _buildAddExerciseButton(),
        ],
      ),
    );
  }

  // ── Body Figure ──────────────────────────────────────────────

  Widget _buildBodyFigure() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BodyMapWidget(muscleCounts: _activeMuscleCounts, accentColor: context.accent),
    );
  }

  // ── Day Header ───────────────────────────────────────────────

  Widget _buildDayHeader(WorkoutDay day) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _dynamicDayName(day),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        if (day.exercises.isNotEmpty)
          Text(
            '${day.exercises.length} Exercises',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
      ],
    );
  }

  // ── Add Exercise Button ────────────────────────────────────────

  Widget _buildAddExerciseButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addExerciseFromPicker,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Exercise'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.accent,
          side: BorderSide(color: context.accent, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _addExerciseFromPicker() async {
    final picked = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (picked == null || !mounted) return;

    // Show sets/reps dialog
    final result = await _showSetsRepsDialog(picked);
    if (result == null || !mounted) return;

    final day = _currentDay;
    if (day == null) return;

    setState(() {
      day.exercises.add(WorkoutExercise(
        exerciseId: picked.id,
        name: picked.name,
        sets: result.sets,
        reps: result.reps,
        muscleGroup: picked.muscleGroup,
      ));
    });
    _notifyPlanChanged();
    // A newly added exercise makes the workout incomplete, so make sure a
    // reminder is scheduled for it (no-op when the add was to another day).
    _syncWorkoutReminder();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${picked.name}" added to ${day.label}!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<_SetsRepsResult?> _showSetsRepsDialog(Exercise exercise) async {
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');

    return showDialog<_SetsRepsResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add ${exercise.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              exercise.muscleGroup,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Sets',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: repsCtrl,
                    decoration: InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final sets = int.tryParse(setsCtrl.text) ?? 3;
              final reps = repsCtrl.text.trim().isEmpty ? '10' : repsCtrl.text.trim();
              Navigator.pop(ctx, _SetsRepsResult(sets, reps));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Rest Day Card ────────────────────────────────────────────

  Widget _buildRestDayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.self_improvement, size: 48, color: const Color(0xFF10B981).withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Rest & Recovery',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Your muscles grow during rest. Hydrate, stretch, and sleep well.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Exercise Tile ────────────────────────────────────────────

  Widget _buildExerciseTile(int index, WorkoutExercise ex) {
    final isSwiped = _swipedExerciseIndex == index;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
          setState(() => _swipedExerciseIndex = index);
        } else if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
          setState(() => _swipedExerciseIndex = null);
        }
      },
      onTap: () {
        if (isSwiped) {
          setState(() => _swipedExerciseIndex = null);
        } else {
          _toggleExercise(index);
        }
      },
      child: Row(
        children: [
          // Main content (slides left when swiped)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(isSwiped ? -72 : 0, 0, 0),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ex.completed ? context.success.withValues(alpha: 0.08) : context.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: context.shadowLight,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Drag handle for reorder
                  Icon(Icons.drag_handle, size: 18, color: context.textMuted),
                  const SizedBox(width: 6),
                  // Checkbox
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      ex.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      key: ValueKey(ex.completed),
                      color: ex.completed ? const Color(0xFF10B981) : context.textMuted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Exercise info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: ex.completed ? context.textMuted : context.textPrimary,
                            decoration: ex.completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ex.sets} sets × ${ex.reps}',
                          style: TextStyle(
                            fontSize: 12,
                            color: ex.completed ? context.textMuted : context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Muscle group chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ex.muscleGroup,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Red delete button (revealed on swipe)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: isSwiped
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentDay?.exercises.removeAt(index);
                        _swipedExerciseIndex = null;
                      });
                      _notifyPlanChanged();
                    },
                    child: Container(
                      width: 68,
                      height: 56,
                      margin: const EdgeInsets.only(bottom: 8, left: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, color: Colors.white, size: 20),
                          SizedBox(height: 2),
                          Text('Delete', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: 0),
          ),
        ],
      ),
    );
  }

  // ── Workout Progress ─────────────────────────────────────────

  Widget _buildWorkoutProgress(int completed, int total, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: context.shadowLight,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workout Progress',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: context.border,
                    valueColor: AlwaysStoppedAnimation<Color>(context.accent),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed / $total Completed',
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+${completed * XPSystem.TODO_MEDIUM} XP',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Habit View ───────────────────────────────────────────────

  Widget _buildHabitView() {
    // Filter habits to only show those scheduled for the selected day
    final progress = context.watch<ProgressController>();
    final allHabits = progress.habits;
    final weekday = _selectedDay + 1; // 1=Mon, 7=Sun
    final todayHabits = allHabits.where((h) => h.isScheduledFor(weekday)).toList();

    if (allHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_task, size: 48, color: context.textMuted),
            const SizedBox(height: 12),
            Text(
              'No habits yet.\nTap "Add Habit" to create one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (todayHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 48, color: context.textMuted),
            const SizedBox(height: 12),
            Text(
              'No habits scheduled for this day.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: todayHabits.length,
            onReorderItem: _onHabitReorder,
            proxyDecorator: _dragProxyDecorator,
            itemBuilder: (_, i) => KeyedSubtree(
              key: ValueKey('habit_${todayHabits[i].id}'),
              child: _buildHabitTile(todayHabits[i], weekday),
            ),
          ),
        ),
        // Add Habit button (always visible at the bottom)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddHabitDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Habit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.accent,
                side: BorderSide(color: context.accent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitTile(Habit habit, int weekday) {
    final isDone = Provider.of<ProgressController>(context, listen: false)
        .isHabitDone(weekday, habit.id);
    final isSwiped = _swipedHabitId == habit.id;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
          setState(() => _swipedHabitId = habit.id);
        } else if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
          setState(() => _swipedHabitId = null);
        }
      },
      onTap: () {
        if (isSwiped) {
          setState(() => _swipedHabitId = null);
        } else {
          _toggleHabit(habit);
        }
      },
      child: Row(
        children: [
          // Main content
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(isSwiped ? -72 : 0, 0, 0),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDone ? context.success.withValues(alpha: 0.08) : context.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: context.shadowLight,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Drag handle for reorder
                  Icon(Icons.drag_handle, size: 18, color: context.textMuted),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: habit.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(habit.icon, color: habit.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDone ? context.textMuted : context.textPrimary,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (habit.scheduleDays.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            habit.scheduleLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      key: ValueKey(isDone),
                      color: isDone ? const Color(0xFF10B981) : context.textMuted,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Red delete button
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: isSwiped
                ? GestureDetector(
                    onTap: () {
                      setState(() => _swipedHabitId = null);
                      Provider.of<ProgressController>(context, listen: false)
                          .removeHabit(habit.id);
                    },
                    child: Container(
                      width: 68,
                      height: 52,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, color: Colors.white, size: 20),
                          SizedBox(height: 2),
                          Text('Delete', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: 0),
          ),
        ],
      ),
    );
  }
}

class _SetsRepsResult {
  final int sets;
  final String reps;
  const _SetsRepsResult(this.sets, this.reps);
}
