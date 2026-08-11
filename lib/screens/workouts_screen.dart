import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';
import 'exercise_detail_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final ExerciseService _service = ExerciseService();
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedGroup;
  bool _loading = true;

  // ── Derived lists ──────────────────────────────────────────────────

  List<Exercise> get _results => _service.query(
        muscleGroup: _selectedGroup,
        searchText: _searchCtrl.text,
      );

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _service.load();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'WORKOUTS',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: context.accent))
          : Column(
              children: [
                _buildSearchBar(),
                _buildCategoryChips(),
                Expanded(child: _buildExerciseList()),
              ],
            ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search exercises...',
          hintStyle: TextStyle(color: context.textMuted),
          prefixIcon:
              Icon(Icons.search, color: context.textMuted, size: 22),
          filled: true,
          fillColor: context.inputFill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Category chips ─────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    final groups = ['All', ..._service.muscleGroups];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = groups[i];
          final isSelected =
              (g == 'All' && _selectedGroup == null) || g == _selectedGroup;
          return ChoiceChip(
            label: Text(g),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedGroup = g == 'All' ? null : g;
              });
            },
            selectedColor: context.accent,
            backgroundColor: context.chipBg,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : context.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected
                  ? context.accent
                  : context.chipBorder,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  // ── Exercise list ──────────────────────────────────────────────────

  Widget _buildExerciseList() {
    final results = _results;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: context.textMuted),
            SizedBox(height: 12),
            Text(
              'No exercises found',
              style: TextStyle(color: context.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ExerciseCard(
        exercise: results[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(exercise: results[i]),
          ),
        ),
      ),
    );
  }
}

// ── Exercise card ──────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.shadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Play badge (placeholder — no GIFs available yet)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: context.accent,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      exercise.muscleGroup,
                      exercise.typeDisplay,
                      if (exercise.equipment.isNotEmpty) exercise.equipmentDisplay,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textMuted),
          ],
        ),
      ),
    );
  }
}
