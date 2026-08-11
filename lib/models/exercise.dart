/// Exercise model backed by the local exercises.json asset.
class Exercise {
  final String id;
  final String name;
  final String category;
  final List<String> equipment;
  final String type;
  final List<String> goal;
  final String muscleGroup;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final List<String> keywords;
  final String difficulty;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.equipment,
    required this.type,
    required this.goal,
    required this.muscleGroup,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.keywords,
    required this.difficulty,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? '',
      equipment: (json['equipment'] as List<dynamic>?)?.cast<String>() ?? [],
      type: json['type'] as String? ?? '',
      goal: (json['goal'] as List<dynamic>?)?.cast<String>() ?? [],
      muscleGroup: json['muscle_group'] as String? ?? '',
      primaryMuscle: json['primary_muscle'] as String? ?? '',
      secondaryMuscles:
          (json['secondary_muscles'] as List<dynamic>?)?.cast<String>() ?? [],
      keywords: (json['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
      difficulty: json['difficulty'] as String? ?? '',
    );
  }

  /// Equipment list formatted for display, e.g. "Barbell · Bench"
  String get equipmentDisplay =>
      equipment.map((e) => e[0].toUpperCase() + e.substring(1)).join(' · ');

  /// Human-readable type, e.g. "Strength"
  String get typeDisplay =>
      type.isEmpty ? '' : type[0].toUpperCase() + type.substring(1);

  /// Human-readable difficulty, e.g. "Intermediate"
  String get difficultyDisplay =>
      difficulty.isEmpty
          ? ''
          : difficulty[0].toUpperCase() + difficulty.substring(1);
}
