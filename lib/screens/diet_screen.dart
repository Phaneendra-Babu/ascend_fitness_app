import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ascend_app/models/diet_plan.dart';
import 'package:ascend_app/models/my_recipe.dart';
import 'create_recipe_screen.dart';
import 'recipe_picker_screen.dart';
import 'recipe_detail_screen.dart';
import '../theme/app_colors.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  int _selectedDay = DateTime.now().weekday - 1;
  String? _swipedMealKey;

  DayDietPlan get _currentPlan => Provider.of<DietPlanState>(context, listen: false).getPlanForDay(_selectedDay + 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Diet Plan',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: context.textPrimary),
            onPressed: () {},
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
              _buildDateSelector(),
              const SizedBox(height: 16),
              _buildIntakeSummary(),
              const SizedBox(height: 16),
              ...MealType.values.map((type) => _buildMealSection(type)),
              const SizedBox(height: 16),
              _buildAddRecipeButton(),
              const SizedBox(height: 16),
              _buildCreateRecipeCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Date Selector ────────────────────────────────────────────

  Widget _buildDateSelector() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final dayDate = today.subtract(Duration(days: today.weekday - 1 - index));
          final isSelected = index == _selectedDay;
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
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Today's Intake Summary ──────────────────────────────────

  Widget _buildIntakeSummary() {
    // Watched so the card rebuilds when meals OR goals change.
    final planState = Provider.of<DietPlanState>(context);
    final plan = _currentPlan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: context.shadowLight, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Intake", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                  Text('Daily Nutrition Goals', style: TextStyle(fontSize: 11, color: context.textMuted)),
                ],
              ),
              GestureDetector(
                onTap: _editNutritionGoals,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Edit Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.accent)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Calories progress ring
              SizedBox(
                height: 92,
                width: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: CircularProgressIndicator(
                        value: planState.calories > 0
                            ? (plan.totalCalories / planState.calories).clamp(0.0, 1.0)
                            : 0.0,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: context.divider,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${plan.totalCalories}',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: context.textPrimary),
                        ),
                        Text(
                          '/ ${planState.calories} kcal',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Macro goal bars
              Expanded(
                child: Column(
                  children: [
                    _buildGoalBar('Protein', plan.totalProtein, planState.protein, 'g', const Color(0xFFEF4444)),
                    const SizedBox(height: 9),
                    _buildGoalBar('Carbs', plan.totalCarbs, planState.carbs, 'g', const Color(0xFFF59E0B)),
                    const SizedBox(height: 9),
                    _buildGoalBar('Fat', plan.totalFat, planState.fat, 'g', const Color(0xFF3B82F6)),
                    const SizedBox(height: 9),
                    _buildGoalBar('Fiber', plan.totalFiber, planState.fiber, 'g', const Color(0xFF10B981)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalBar(String name, int value, int target, String unit, Color color) {
    final fraction = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.textSecondary)),
            Text('$value/$target$unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.textSecondary)),
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
              widthFactor: fraction,
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }

  // ── Edit Nutrition Goals ────────────────────────────────────

  Future<void> _editNutritionGoals() async {
    final planState = Provider.of<DietPlanState>(context, listen: false);
    final calCtrl = TextEditingController(text: planState.calories.toString());
    final proteinCtrl = TextEditingController(text: planState.protein.toString());
    final carbsCtrl = TextEditingController(text: planState.carbs.toString());
    final fatCtrl = TextEditingController(text: planState.fat.toString());
    final fiberCtrl = TextEditingController(text: planState.fiber.toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.cardColor,
        title: Text('Edit Nutrition Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _goalField('Calories (kcal)', calCtrl),
              const SizedBox(height: 12),
              _goalField('Protein (g)', proteinCtrl),
              const SizedBox(height: 12),
              _goalField('Carbs (g)', carbsCtrl),
              const SizedBox(height: 12),
              _goalField('Fat (g)', fatCtrl),
              const SizedBox(height: 12),
              _goalField('Fiber (g)', fiberCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              planState.updateGoals(
                calories: int.tryParse(calCtrl.text) ?? planState.calories,
                protein: int.tryParse(proteinCtrl.text) ?? planState.protein,
                carbs: int.tryParse(carbsCtrl.text) ?? planState.carbs,
                fat: int.tryParse(fatCtrl.text) ?? planState.fat,
                fiber: int.tryParse(fiberCtrl.text) ?? planState.fiber,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _goalField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textMuted),
        filled: true,
        fillColor: context.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.border),
        ),
      ),
    );
  }

  // ── Meal Section ────────────────────────────────────────────

  Widget _buildMealSection(MealType type) {
    final items = _currentPlan.mealsForType(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: context.shadowLight, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header (no "+" button)
          Row(
            children: [
              Icon(type.icon, size: 18, color: type.color),
              const SizedBox(width: 8),
              Text(
                type.label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: type.color),
              ),
            ],
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No meals added yet',
                style: TextStyle(fontSize: 12, color: context.textMuted),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final mealKey = '${item.recipeId}_$i';
              final isSwiped = _swipedMealKey == mealKey;

              return GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                    setState(() => _swipedMealKey = mealKey);
                  } else if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                    setState(() => _swipedMealKey = null);
                  }
                },
                onTap: () => _openRecipeDetail(item.recipeId),
                child: Row(
                  children: [
                    // Main content card
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        transform: Matrix4.translationValues(isSwiped ? -64 : 0, 0, 0),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.cardColorAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          children: [
                            // Recipe icon placeholder
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: type.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(type.icon, color: type.color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            // Recipe info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.recipeName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _nutritionChip('${item.calories} kcal', const Color(0xFFF97316)),
                                      _nutritionChip('${item.protein}g Protein', const Color(0xFFEF4444)),
                                      _nutritionChip('${item.carbs}g Carbs', const Color(0xFFF59E0B)),
                                      _nutritionChip('${item.fat}g Fat', const Color(0xFF3B82F6)),
                                      _nutritionChip('${item.fiber}g Fiber', const Color(0xFF10B981)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: context.textMuted, size: 20),
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
                                setState(() {
                                  Provider.of<DietPlanState>(context, listen: false).removeMeal(_selectedDay + 1, type, i);
                                  _swipedMealKey = null;
                                });
                              },
                              child: Container(
                                width: 60,
                                height: 64,
                                margin: const EdgeInsets.only(left: 4, bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                              ),
                            )
                          : const SizedBox(width: 0),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _nutritionChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ── Open Recipe Detail ──────────────────────────────────────

  Future<void> _openRecipeDetail(String recipeId) async {
    if (recipeId.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: context.accent)),
    );

    try {
      final doc = await FirebaseFirestore.instance
          .collection('public_recipes')
          .doc(recipeId)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (doc.exists) {
        final recipe = MyRecipe.fromFirestore(doc);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe not found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading recipe: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Add Recipe Button ────────────────────────────────────────

  Widget _buildAddRecipeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addRecipeFromPicker,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Recipe'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.accent,
          side: BorderSide(color: context.accent, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _addRecipeFromPicker() async {
    final picked = await Navigator.push<MyRecipe>(
      context,
      MaterialPageRoute(builder: (_) => const RecipePickerScreen()),
    );
    if (picked == null || !mounted) return;

    // Show meal type picker dialog
    final mealType = await _showMealTypePickerDialog();
    if (mealType == null || !mounted) return;

    setState(() {
      Provider.of<DietPlanState>(context, listen: false).addMeal(
        _selectedDay + 1,
        mealType,
        MealItem(
          recipeId: picked.id ?? '',
          recipeName: picked.title,
          calories: picked.calories,
          protein: picked.protein,
          carbs: picked.carbs,
          fat: picked.fat,
          fiber: picked.fiber,
        ),
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${picked.title}" added to ${mealType.label}!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<MealType?> _showMealTypePickerDialog() async {
    return showDialog<MealType>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.cardColor,
        title: const Text('Add to which meal?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MealType.values.map((type) {
            return ListTile(
              leading: Icon(type.icon, color: type.color),
              title: Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, type),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Create Recipe Card ──────────────────────────────────────

  Widget _buildCreateRecipeCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRecipeScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.accent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: context.accent, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Your Own Recipe',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                  Text('Add your personal meal to your diet plan and publish it.',
                      style: TextStyle(fontSize: 13, color: context.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: context.accent),
          ],
        ),
      ),
    );
  }
}
