import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/my_recipe.dart';
import '../theme/app_colors.dart';

/// Full-screen searchable list of recipes.
/// Returns the selected [MyRecipe] via Navigator.pop.
class RecipePickerScreen extends StatefulWidget {
  const RecipePickerScreen({super.key});

  @override
  State<RecipePickerScreen> createState() => _RecipePickerScreenState();
}

class _RecipePickerScreenState extends State<RecipePickerScreen> {
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
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((r) {
        if (r.title.toLowerCase().contains(q)) return true;
        if (r.description.toLowerCase().contains(q)) return true;
        if (r.ingredients.any((i) => i.toLowerCase().contains(q))) return true;
        return false;
      }).toList();
    }
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
          'Pick Recipe',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: context.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildRecipeList()),
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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

  Widget _buildRecipeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('public_recipes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: context.accent));
        }
        final recipes = snapshot.hasData
            ? snapshot.data!.docs.map((doc) => MyRecipe.fromFirestore(doc)).toList()
            : <MyRecipe>[];
        final filtered = _applyFilters(recipes);

        if (filtered.isEmpty) {
          return Center(
            child: Text('No recipes found', style: TextStyle(color: context.textMuted)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, index) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final r = filtered[i];
            return ListTile(
              onTap: () => Navigator.pop(context, r),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              tileColor: context.cardColor,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant, color: Color(0xFF10B981), size: 20),
              ),
              title: Text(
                r.title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
              ),
              subtitle: Text(
                '${r.calories} kcal · ${r.protein}g Protein',
                style: TextStyle(fontSize: 12, color: context.textMuted),
              ),
              trailing: Icon(Icons.chevron_right, color: context.textMuted),
            );
          },
        );
      },
    );
  }
}
