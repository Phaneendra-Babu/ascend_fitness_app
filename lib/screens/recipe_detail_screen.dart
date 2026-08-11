import 'package:flutter/material.dart';
import '../models/my_recipe.dart';
import '../theme/app_colors.dart';

class RecipeDetailScreen extends StatelessWidget {
  final MyRecipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  // Placeholder colors for the header based on recipe name.
  static const _placeholders = [
    Color(0xFFFDE68A),
    Color(0xFFBBF7D0),
    Color(0xFFBFDBFE),
    Color(0xFFFECDD3),
    Color(0xFFDDD6FE),
    Color(0xFFFED7AA),
  ];

  Color get _bgColor =>
      _placeholders[recipe.title.hashCode.abs() % _placeholders.length];

  IconData get _foodIcon {
    final t = recipe.title.toLowerCase();
    if (t.contains('pancake') || t.contains('oat')) return Icons.circle;
    if (t.contains('chicken') || t.contains('grill')) return Icons.lunch_dining;
    if (t.contains('salad') || t.contains('bowl')) return Icons.eco;
    if (t.contains('salmon') || t.contains('fish')) return Icons.set_meal;
    if (t.contains('avocado') || t.contains('toast')) return Icons.bakery_dining;
    return Icons.restaurant;
  }

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
                  const SizedBox(height: 6),
                  _buildRatingRow(context),
                  const SizedBox(height: 16),
                  _buildNutritionRow(context),
                  const SizedBox(height: 16),
                  _buildIngredientsSection(context),
                  const SizedBox(height: 16),
                  _buildInstructionsSection(context),
                  const SizedBox(height: 16),
                  if (recipe.specialNutrients.isNotEmpty) ...[
                    _buildSpecialNutrients(context),
                    const SizedBox(height: 16),
                  ],
                  _buildAddToPlanButton(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image header ───────────────────────────────────────────────────

  Widget _buildImageHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: _bgColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border, color: Colors.white),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Favorites coming soon!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: _bgColor,
          child: Center(
            child: Icon(_foodIcon, size: 80, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      ),
    );
  }

  // ── Title ──────────────────────────────────────────────────────────

  Widget _buildTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        if (recipe.publisherName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Published by ${recipe.publisherName}',
            style: TextStyle(
              fontSize: 13,
              color: context.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  // ── Rating row ─────────────────────────────────────────────────────

  Widget _buildRatingRow(BuildContext context) {
    return Row(
      children: [
        // Star + rating
        const Icon(Icons.star, color: Color(0xFFF59E0B), size: 18),
        const SizedBox(width: 4),
        Text(
          recipe.rating > 0 ? recipe.rating.toStringAsFixed(1) : 'New',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        if (recipe.ratingCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '(${recipe.ratingCount})',
            style: TextStyle(fontSize: 13, color: context.textMuted),
          ),
        ],
        const SizedBox(width: 16),
        // Cook time
        Icon(Icons.access_time, size: 16, color: context.textMuted),
        const SizedBox(width: 4),
        Text(
          '${recipe.cookTime} mins',
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
        const Spacer(),
        // Likes
        const Icon(Icons.favorite, size: 16, color: Color(0xFFEF4444)),
        const SizedBox(width: 4),
        Text(
          '${recipe.likes}',
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
      ],
    );
  }

  // ── Nutrition row ──────────────────────────────────────────────────

  Widget _buildNutritionRow(BuildContext context) {
    return Row(
      children: [
        _nutritionTile(context, 'Calories', '${recipe.calories}', 'kcal', const Color(0xFFF97316)),
        const SizedBox(width: 10),
        _nutritionTile(context, 'Protein', '${recipe.protein}', 'g', const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        _nutritionTile(context, 'Carbs', '${recipe.carbs}', 'g', const Color(0xFFF59E0B)),
        const SizedBox(width: 10),
        _nutritionTile(context, 'Fat', '${recipe.fat}', 'g', const Color(0xFF3B82F6)),
      ],
    );
  }

  Widget _nutritionTile(BuildContext context, String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: context.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ingredients ────────────────────────────────────────────────────

  Widget _buildIngredientsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...recipe.ingredients.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ── Instructions (point-wise) ──────────────────────────────────────

  Widget _buildInstructionsSection(BuildContext context) {
    if (recipe.instructions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instructions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...recipe.instructions.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Special nutrients ──────────────────────────────────────────────

  Widget _buildSpecialNutrients(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Nutrients',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recipe.specialNutrients.map((n) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: context.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: context.success.withValues(alpha: 0.3)),
              ),
              child: Text(
                n,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.success,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Add to Meal Plan button ────────────────────────────────────────

  Widget _buildAddToPlanButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${recipe.title}" added to your Meal Plan!'),
              backgroundColor: context.accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Add to Meal Plan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
