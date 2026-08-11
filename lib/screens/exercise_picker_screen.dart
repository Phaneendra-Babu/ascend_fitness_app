import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';

/// Full-screen searchable list of exercises.
/// Returns the selected [Exercise] via Navigator.pop.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final ExerciseService _service = ExerciseService();
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedGroup;
  bool _loading = true;

  List<Exercise> get _results => _service.query(
        muscleGroup: _selectedGroup,
        searchText: _searchCtrl.text,
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Pick Exercise',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: context.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.accent))
          : Column(
              children: [
                _buildSearchBar(),
                _buildMuscleChips(),
                Expanded(child: _buildExerciseList()),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        autofocus: true,
        style: TextStyle(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search exercises...',
          hintStyle: TextStyle(color: context.textMuted),
          prefixIcon: Icon(Icons.search, color: context.textMuted, size: 22),
          filled: true,
          fillColor: context.inputFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
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

  Widget _buildMuscleChips() {
    final groups = ['All', ..._service.muscleGroups];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final g = groups[index];
          final isSelected = (g == 'All' && _selectedGroup == null) || g == _selectedGroup;
          return ChoiceChip(
            label: Text(g),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedGroup = g == 'All' ? null : g),
            selectedColor: context.accent,
            backgroundColor: context.chipBg,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : context.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            side: BorderSide(
              color: isSelected ? context.accent : context.chipBorder,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildExerciseList() {
    final results = _results;
    if (results.isEmpty) {
      return Center(
        child: Text('No exercises found', style: TextStyle(color: context.textMuted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, index) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final ex = results[i];
        return ListTile(
          onTap: () => Navigator.pop(context, ex),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          tileColor: context.cardColor,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.fitness_center, color: context.accent, size: 20),
          ),
          title: Text(
            ex.name,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
          ),
          subtitle: Text(
            '${ex.muscleGroup} · ${ex.typeDisplay} · ${ex.difficultyDisplay}',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
          trailing: Icon(Icons.chevron_right, color: context.textMuted),
        );
      },
    );
  }
}
