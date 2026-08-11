import 'package:ascend_app/models/my_recipe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  bool _isPublished = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to create a recipe.')),
        );
      }
      return;
    }

    // Fetch username from Firestore
    String publisherName = '';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      publisherName = userDoc.data()?['username'] ?? userDoc.data()?['name'] ?? '';
    } catch (_) {}

    final newRecipe = MyRecipe(
      title: _titleController.text,
      description: _descriptionController.text,
      ingredients: _ingredientsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
      instructions: _instructionsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
      calories: int.tryParse(_caloriesController.text) ?? 0,
      protein: int.tryParse(_proteinController.text) ?? 0,
      carbs: int.tryParse(_carbsController.text) ?? 0,
      fat: int.tryParse(_fatController.text) ?? 0,
      isPublished: _isPublished,
      createdBy: user.uid,
      publisherName: publisherName,
    );

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_recipes')
          .add(newRecipe.toFirestore());

      if (_isPublished) {
        await FirebaseFirestore.instance
            .collection('public_recipes')
            .doc(docRef.id)
            .set(newRecipe.toFirestore());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recipe: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Recipe'),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Recipe Details'),
              _buildTextFormField(_titleController, 'Title', 'e.g., Protein Power Bowl'),
              _buildTextFormField(_descriptionController, 'Description', 'A short and enticing description.'),
              const SizedBox(height: 16),

              _buildSectionTitle('Ingredients'),
              _buildTextFormField(_ingredientsController, 'Ingredients', 'One ingredient per line.', maxLines: 5),
              const SizedBox(height: 16),

              _buildSectionTitle('Instructions'),
              _buildTextFormField(_instructionsController, 'Instructions', 'One step per line.', maxLines: 8),
              const SizedBox(height: 16),

              _buildSectionTitle('Nutritional Information (per serving)'),
              Row(
                children: [
                  Expanded(child: _buildTextFormField(_caloriesController, 'Calories', 'kcal', isNumber: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextFormField(_proteinController, 'Protein', 'g', isNumber: true)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTextFormField(_carbsController, 'Carbs', 'g', isNumber: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextFormField(_fatController, 'Fat', 'g', isNumber: true)),
                ],
              ),
              const SizedBox(height: 24),

              _buildPublishToggle(),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveRecipe,
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.save),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Recipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label, String hint, {int maxLines = 1, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.multiline,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: context.inputFill,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a $label';
          }
          if (isNumber && int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPublishToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                'Visibility *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.warning),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose who can see this recipe',
            style: TextStyle(fontSize: 12, color: context.warning.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isPublished = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isPublished ? context.accent : context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isPublished ? context.accent : const Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.public,
                          size: 18,
                          color: _isPublished ? Colors.white : context.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Publish',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isPublished ? Colors.white : context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isPublished = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isPublished ? context.accent : context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_isPublished ? context.accent : const Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: !_isPublished ? Colors.white : context.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Private',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isPublished ? Colors.white : context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
