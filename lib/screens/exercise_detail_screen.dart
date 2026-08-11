import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../theme/app_colors.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      body: CustomScrollView(
        slivers: [
          _buildImageHeader(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(context),
                  const SizedBox(height: 8),
                  _buildTags(context),
                  const SizedBox(height: 16),
                  _buildInfoGrid(context),
                  const SizedBox(height: 16),
                  _buildMusclesWorked(context),
                  const SizedBox(height: 16),
                  _buildHowToPerform(context),
                  const SizedBox(height: 20),
                  _buildActionButtons(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image header (placeholder) ─────────────────────────────────────

  Widget _buildImageHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF1E293B),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _muscleGroupIcon,
                  size: 64,
                  color: context.accent.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Exercise animation coming soon',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Title ──────────────────────────────────────────────────────────

  Widget _buildTitle(BuildContext context) {
    return Text(
      exercise.name,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: context.textPrimary,
      ),
    );
  }

  // ── Tags row ───────────────────────────────────────────────────────

  Widget _buildTags(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _tag(context, exercise.muscleGroup),
        _tag(context, exercise.typeDisplay),
        if (exercise.equipment.isNotEmpty) _tag(context, exercise.equipmentDisplay),
        _tag(context, exercise.difficultyDisplay),
      ],
    );
  }

  Widget _tag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.accent,
        ),
      ),
    );
  }

  // ── Info grid (Target · Type · Equipment · Difficulty) ─────────────

  Widget _buildInfoGrid(BuildContext context) {
    return Row(
      children: [
        _infoTile(context, Icons.adjust, 'Target', exercise.primaryMuscle.isNotEmpty
            ? exercise.muscleGroup
            : exercise.muscleGroup),
        const SizedBox(width: 10),
        _infoTile(context, Icons.category_outlined, 'Type', exercise.typeDisplay),
        const SizedBox(width: 10),
        _infoTile(context, Icons.fitness_center, 'Equipment',
            exercise.equipment.isNotEmpty ? exercise.equipment.first : '—'),
        const SizedBox(width: 10),
        _infoTile(context, Icons.signal_cellular_alt, 'Difficulty',
            exercise.difficultyDisplay),
      ],
    );
  }

  Widget _infoTile(BuildContext context, IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: context.shadowLight,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: context.accent),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: context.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Muscles worked ─────────────────────────────────────────────────

  Widget _buildMusclesWorked(BuildContext context) {
    final allMuscles = [
      exercise.primaryMuscle,
      ...exercise.secondaryMuscles,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Muscles Worked',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...allMuscles.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: m == exercise.primaryMuscle
                          ? context.accent
                          : context.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 14,
                        color: m == exercise.primaryMuscle
                            ? context.textPrimary
                            : context.textSecondary,
                        fontWeight: m == exercise.primaryMuscle
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (m == exercise.primaryMuscle)
                    Text(
                      'Primary',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      'Secondary',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                      ),
                    ),
                ],
              ),
            )),
      ],
    );
  }

  // ── How to perform (placeholder) ──────────────────────────────────

  Widget _buildHowToPerform(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.shadowLight,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to Perform',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Step-by-step instructions will be added soon.',
            style: TextStyle(
              fontSize: 13,
              color: context.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons (stubs) ────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // +XP button — stub
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('XP rewards coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.bolt, size: 18),
            label: const Text('+80 XP', overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Add to Today's Plan
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showAddToPlanDialog(context),
            icon: const Icon(Icons.add_task, size: 18),
            label: const Text("Add to Plan", overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.accent,
              side: BorderSide(color: context.accent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Add to Plan dialog ──────────────────────────────────────────

  void _showAddToPlanDialog(BuildContext context) {
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add ${exercise.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sets & Reps',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary),
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

              final planState = Provider.of<WorkoutPlanState>(context, listen: false);
              final today = DateTime.now().weekday;

              // Get or create today's workout day
              var day = planState.plan.days[today];
              if (day == null || day.label == 'Rest Day') {
                day = WorkoutDay(
                  label: 'Custom Day',
                  targetMuscles: exercise.muscleGroup,
                  exercises: [],
                );
                planState.plan.days[today] = day;
              }

              day.exercises.add(WorkoutExercise(
                exerciseId: exercise.id,
                name: exercise.name,
                sets: sets,
                reps: reps,
                muscleGroup: exercise.muscleGroup,
              ));

              planState.updatePlan(planState.plan);
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ "${exercise.name}" added to today\'s plan!'),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  IconData get _muscleGroupIcon {
    switch (exercise.muscleGroup) {
      case 'Chest':
        return Icons.accessibility_new;
      case 'Back':
        return Icons.accessibility_new;
      case 'Legs':
        return Icons.directions_run;
      case 'Shoulders':
        return Icons.accessibility_new;
      case 'Arms':
        return Icons.accessibility_new;
      case 'Core':
        return Icons.accessibility_new;
      case 'Cardio':
        return Icons.favorite;
      default:
        return Icons.fitness_center;
    }
  }
}
