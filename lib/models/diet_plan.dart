import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/local_storage.dart';

/// Meal sections in the diet plan.
enum MealType { breakfast, lunch, snacks, dinner, drinks }

extension MealTypeExtension on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.snacks:
        return 'Snacks';
      case MealType.dinner:
        return 'Dinner';
      case MealType.drinks:
        return 'Drinks';
    }
  }

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.free_breakfast;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.snacks:
        return Icons.cookie;
      case MealType.dinner:
        return Icons.dinner_dining;
      case MealType.drinks:
        return Icons.local_cafe;
    }
  }

  Color get color {
    switch (this) {
      case MealType.breakfast:
        return const Color(0xFFF59E0B);
      case MealType.lunch:
        return const Color(0xFF10B981);
      case MealType.snacks:
        return const Color(0xFF8B5CF6);
      case MealType.dinner:
        return const Color(0xFFEF4444);
      case MealType.drinks:
        return const Color(0xFF3B82F6);
    }
  }
}

/// A single meal item in the diet plan.
class MealItem {
  final String recipeId;
  final String recipeName;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const MealItem({
    required this.recipeId,
    required this.recipeName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'recipeName': recipeName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory MealItem.fromJson(Map<String, dynamic> json) => MealItem(
        recipeId: json['recipeId'] as String? ?? '',
        recipeName: json['recipeName'] as String? ?? '',
        calories: json['calories'] as int? ?? 0,
        protein: json['protein'] as int? ?? 0,
        carbs: json['carbs'] as int? ?? 0,
        fat: json['fat'] as int? ?? 0,
      );
}

/// Diet plan for a single day.
class DayDietPlan {
  final Map<MealType, List<MealItem>> meals;

  DayDietPlan({Map<MealType, List<MealItem>>? meals})
      : meals = meals ?? {for (final t in MealType.values) t: []};

  List<MealItem> mealsForType(MealType type) => meals[type] ?? [];

  int get totalCalories =>
      meals.values.expand((m) => m).fold(0, (s, m) => s + m.calories);
  int get totalProtein =>
      meals.values.expand((m) => m).fold(0, (s, m) => s + m.protein);
  int get totalCarbs =>
      meals.values.expand((m) => m).fold(0, (s, m) => s + m.carbs);
  int get totalFat =>
      meals.values.expand((m) => m).fold(0, (s, m) => s + m.fat);

  DayDietPlan copy() {
    return DayDietPlan(
      meals: meals.map((k, v) => MapEntry(k, List<MealItem>.from(v))),
    );
  }

  Map<String, dynamic> toJson() => {
        'meals': meals.map((k, v) =>
            MapEntry(k.name, v.map((m) => m.toJson()).toList())),
      };

  factory DayDietPlan.fromJson(Map<String, dynamic> json) {
    final mealsMap = <MealType, List<MealItem>>{};
    for (final t in MealType.values) {
      mealsMap[t] = [];
    }
    final rawMeals = json['meals'] as Map<String, dynamic>?;
    if (rawMeals != null) {
      rawMeals.forEach((key, value) {
        final type = MealType.values.byName(key);
        mealsMap[type] = (value as List<dynamic>?)
                ?.map((m) => MealItem.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [];
      });
    }
    return DayDietPlan(meals: mealsMap);
  }
}

/// Shared state for the diet plan across screens.
class DietPlanState extends ChangeNotifier {
  static const _storageKey = 'dietPlan';

  /// weekday (1=Mon, 7=Sun) → DayDietPlan
  final Map<int, DayDietPlan> _weeklyPlans = {};

  /// Load saved diet plan from local storage.
  void load() {
    final raw = LocalStorage.loadJsonString(_storageKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
        for (final item in list) {
          _weeklyPlans[item['weekday'] as int] =
              DayDietPlan.fromJson(item['plan'] as Map<String, dynamic>);
        }
        notifyListeners();
      } catch (_) {
        // Keep empty plans on parse error
      }
    }
  }

  /// Save current diet plan to local storage.
  Future<void> _save() async {
    final list = _weeklyPlans.entries
        .map((e) => {'weekday': e.key, 'plan': e.value.toJson()})
        .toList();
    await LocalStorage.saveJson(_storageKey, list);
  }

  DayDietPlan getPlanForDay(int weekday) {
    return _weeklyPlans[weekday] ?? DayDietPlan();
  }

  void addMeal(int weekday, MealType mealType, MealItem item) {
    final plan = _weeklyPlans[weekday] ?? DayDietPlan();
    plan.meals[mealType] = [...(plan.meals[mealType] ?? []), item];
    _weeklyPlans[weekday] = plan;
    _save();
    notifyListeners();
  }

  void removeMeal(int weekday, MealType mealType, int index) {
    final plan = _weeklyPlans[weekday];
    if (plan == null) return;
    final meals = plan.meals[mealType];
    if (meals == null || index >= meals.length) return;
    final newList = List<MealItem>.from(meals)..removeAt(index);
    plan.meals[mealType] = newList;
    _save();
    notifyListeners();
  }
}
