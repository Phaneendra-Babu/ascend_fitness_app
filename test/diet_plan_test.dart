import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascend_app/models/diet_plan.dart';
import 'package:ascend_app/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('MealItem fiber survives serialization', () {
    const item = MealItem(
      recipeId: 'r1',
      recipeName: 'Oatmeal',
      calories: 300,
      protein: 10,
      carbs: 50,
      fat: 5,
      fiber: 8,
    );

    final restored = MealItem.fromJson(item.toJson());

    expect(restored.fiber, 8);
    expect(restored.calories, 300);
  });

  test('DayDietPlan.totalFiber sums all meal items', () {
    final plan = DayDietPlan(meals: {
      MealType.breakfast: [
        const MealItem(recipeId: 'a', recipeName: 'A', calories: 100, protein: 1, carbs: 1, fat: 1, fiber: 4),
        const MealItem(recipeId: 'b', recipeName: 'B', calories: 200, protein: 2, carbs: 2, fat: 2, fiber: 6),
      ],
      MealType.lunch: [
        const MealItem(recipeId: 'c', recipeName: 'C', calories: 300, protein: 3, carbs: 3, fat: 3, fiber: 2),
      ],
    });

    expect(plan.totalFiber, 12);
  });

  test('DietPlanState.updateGoals persists and reloads editable goals', () async {
    await LocalStorage.init();
    LocalStorage.setUserId('user-diet');

    final state = DietPlanState();
    state.load();
    expect(state.calories, 2000);
    expect(state.fiber, 30);

    await state.updateGoals(
      calories: 1800,
      protein: 120,
      carbs: 200,
      fat: 60,
      fiber: 35,
    );
    expect(state.calories, 1800);
    expect(state.fiber, 35);

    // A fresh state (as after a restart) must read the saved goals back.
    final reloaded = DietPlanState();
    reloaded.load();
    expect(reloaded.calories, 1800);
    expect(reloaded.protein, 120);
    expect(reloaded.carbs, 200);
    expect(reloaded.fat, 60);
    expect(reloaded.fiber, 35);
  });
}
