import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/my_recipe.dart';
import '../theme/app_colors.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'All';

  static const _filters = ['All', 'High Protein', 'Low Calorie', 'Quick'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MyRecipe> _applyFilters(List<MyRecipe> recipes) {
    var result = recipes;

    // Text search
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((r) {
        if (r.title.toLowerCase().contains(q)) return true;
        if (r.description.toLowerCase().contains(q)) return true;
        if (r.ingredients.any((i) => i.toLowerCase().contains(q))) return true;
        return false;
      }).toList();
    }

    // Tag filter
    if (_selectedFilter != 'All') {
      result = result.where((r) => r.matchesTag(_selectedFilter)).toList();
    }

    return result;
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
          'Recipes',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: context.textSecondary),
            onPressed: () {
              // Placeholder for advanced filters
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Advanced filters coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('public_recipes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: context.accent),
            );
          }

          final recipes = snapshot.hasData
              ? snapshot.data!.docs
                  .map((doc) => MyRecipe.fromFirestore(doc))
                  .toList()
              : <MyRecipe>[];

          final filtered = _applyFilters(recipes);

          return Column(
            children: [
              _buildSearchBar(),
              _buildFilterChips(),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : _buildRecipeGrid(filtered),
              ),
            ],
          );
        },
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
          hintText: 'Search recipes, ingredients...',
          hintStyle: TextStyle(color: context.textMuted),
          prefixIcon: Icon(Icons.search, color: context.textMuted, size: 22),
          filled: true,
          fillColor: context.inputFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  // ── Filter chips ───────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final f = _filters[index];
          final isSelected = f == _selectedFilter;
          return ChoiceChip(
            label: Text(f),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedFilter = f),
            selectedColor: context.accent,
            backgroundColor: context.chipBg,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : context.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected ? context.accent : context.chipBorder,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  // ── Recipe grid ────────────────────────────────────────────────────

  Widget _buildRecipeGrid(List<MyRecipe> recipes) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _RecipeCard(recipe: recipes[index]),
              childCount: recipes.length,
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu, size: 48, color: context.textMuted),
          SizedBox(height: 12),
          Text(
            'No recipes found',
            style: TextStyle(color: context.textMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Recipe card ──────────────────────────────────────────────────────

class _RecipeCard extends StatefulWidget {
  final MyRecipe recipe;
  const _RecipeCard({required this.recipe});

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  static const _placeholders = [
    Color(0xFFFDE68A),
    Color(0xFFBBF7D0),
    Color(0xFFBFDBFE),
    Color(0xFFFECDD3),
    Color(0xFFDDD6FE),
    Color(0xFFFED7AA),
  ];

  Color get _bgColor =>
      _placeholders[widget.recipe.title.hashCode.abs() % _placeholders.length];

  IconData get _foodIcon {
    final t = widget.recipe.title.toLowerCase();
    if (t.contains('pancake') || t.contains('oat')) return Icons.circle;
    if (t.contains('chicken') || t.contains('grill')) return Icons.lunch_dining;
    if (t.contains('salad') || t.contains('bowl')) return Icons.eco;
    if (t.contains('salmon') || t.contains('fish')) return Icons.set_meal;
    if (t.contains('avocado') || t.contains('toast')) return Icons.bakery_dining;
    return Icons.restaurant;
  }

  /// Check if the current user is the creator of this recipe.
  bool get _isOwner {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.uid == widget.recipe.createdBy;
  }

  Future<void> _deleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${widget.recipe.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Remove from public_recipes
      await FirebaseFirestore.instance
          .collection('public_recipes')
          .doc(widget.recipe.id)
          .delete();

      // Remove from user's my_recipes
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_recipes')
          .doc(widget.recipe.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${widget.recipe.title}" deleted'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: widget.recipe)),
      ),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _bgColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Center(
                      child: Icon(_foodIcon, size: 48, color: Colors.white70),
                    ),
                  ),
                  // Delete button — only visible to the recipe owner
                  if (_isOwner)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _deleteRecipe,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.cardColor.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recipe.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.recipe.calories} kcal • ${widget.recipe.protein}g Protein',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
