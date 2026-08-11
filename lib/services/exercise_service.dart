import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/exercise.dart';

/// Loads exercises from the bundled asset and provides search/filter queries.
class ExerciseService {
  List<Exercise> _exercises = [];
  bool _loaded = false;

  /// All exercises currently loaded.
  List<Exercise> get exercises => List.unmodifiable(_exercises);

  /// Unique muscle groups found across all exercises.
  List<String> get muscleGroups {
    final set = <String>{};
    for (final e in _exercises) {
      if (e.muscleGroup.isNotEmpty) set.add(e.muscleGroup);
    }
    final sorted = set.toList()..sort();
    return sorted;
  }

  /// Returns true once [load] has completed successfully.
  bool get isLoaded => _loaded;

  // ── Load ────────────────────────────────────────────────────────────

  /// Parse exercises.json from the asset bundle.
  /// Safe to call multiple times — only loads once.
  Future<void> load() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString('assets/exercises.json');
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final list = decoded['exercises'] as List<dynamic>;
    _exercises = list
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
    _loaded = true;
  }

  // ── Query ───────────────────────────────────────────────────────────

  /// Filter by muscle group (pass null or empty for all).
  List<Exercise> byMuscleGroup(String? group) {
    if (group == null || group.isEmpty) return _exercises;
    return _exercises
        .where((e) => e.muscleGroup.toLowerCase() == group.toLowerCase())
        .toList();
  }

  /// Free-text search over name, keywords, primary muscle, and equipment.
  List<Exercise> search(String query) {
    if (query.trim().isEmpty) return _exercises;
    final q = query.toLowerCase();
    return _exercises.where((e) {
      if (e.name.toLowerCase().contains(q)) return true;
      if (e.primaryMuscle.toLowerCase().contains(q)) return true;
      if (e.muscleGroup.toLowerCase().contains(q)) return true;
      if (e.equipment.any((eq) => eq.toLowerCase().contains(q))) return true;
      if (e.keywords.any((kw) => kw.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }

  /// Combined: filter by muscle group then search within results.
  List<Exercise> query({String? muscleGroup, String? searchText}) {
    var results = byMuscleGroup(muscleGroup);
    if (searchText != null && searchText.trim().isNotEmpty) {
      final q = searchText.toLowerCase();
      results = results.where((e) {
        if (e.name.toLowerCase().contains(q)) return true;
        if (e.primaryMuscle.toLowerCase().contains(q)) return true;
        if (e.muscleGroup.toLowerCase().contains(q)) return true;
        if (e.equipment.any((eq) => eq.toLowerCase().contains(q))) return true;
        if (e.keywords.any((kw) => kw.toLowerCase().contains(q))) return true;
        return false;
      }).toList();
    }
    return results;
  }

  /// Lookup a single exercise by its id.
  Exercise? byId(String id) {
    try {
      return _exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
