import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Page 1: Basic Info
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Page 2: Optional Body Stats
  final _bodyFatController = TextEditingController();
  final _muscleMassController = TextEditingController();

  // Page 3: Fitness Goals
  String _fitnessGoal = '';
  String _activityLevel = '';

  final List<String> _fitnessGoals = [
    'Lose Weight',
    'Build Muscle',
    'Improve Endurance',
    'Maintain Health',
    'Gain Weight',
  ];

  final List<String> _activityLevels = [
    'Sedentary (Little to no exercise)',
    'Lightly Active (Light exercise 1-3 days/week)',
    'Moderately Active (Moderate exercise 3-5 days/week)',
    'Very Active (Hard exercise 6-7 days/week)',
    'Extremely Active (Very hard exercise, physical job)',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    _muscleMassController.dispose();
    super.dispose();
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final bodyStats = <String, dynamic>{
        'age': int.parse(_ageController.text.trim()),
        'height': double.parse(_heightController.text.trim()),
        'weight': double.parse(_weightController.text.trim()),
      };

      if (_bodyFatController.text.trim().isNotEmpty) {
        bodyStats['bodyFat'] = double.parse(_bodyFatController.text.trim());
      }
      if (_muscleMassController.text.trim().isNotEmpty) {
        bodyStats['muscleMass'] = double.parse(_muscleMassController.text.trim());
      }

      final updates = <String, dynamic>{
        'bodyStats': bodyStats,
        'fitnessGoal': _fitnessGoal,
        'activityLevel': _activityLevel,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update(updates);

      if (!mounted) return;
      // AuthGate will handle routing to MainNavigationScreen since onboardingCompleted is now true
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save onboarding: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: index <= _currentPage
                              ? context.accent
                              : context.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildPage1BasicInfo(),
                    _buildPage2OptionalStats(),
                    _buildPage3FitnessGoals(),
                  ],
                ),
              ),

              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousPage,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading
                            ? null
                            : (_currentPage < 2 ? _nextPage : _submitOnboarding),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _currentPage < 2 ? 'Continue' : 'Complete Setup',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let\'s Get to Know You',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us a bit about yourself so we can personalize your experience.',
            style: TextStyle(fontSize: 16, color: context.textSecondary),
          ),
          const SizedBox(height: 32),

          // Age
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Age *',
              hintText: 'e.g., 25',
              prefixIcon: const Icon(Icons.cake_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: context.inputFill,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Age is required';
              }
              final age = int.tryParse(value.trim());
              if (age == null || age < 13 || age > 100) {
                return 'Please enter a valid age (13-100)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Height
          TextFormField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Height (cm) *',
              hintText: 'e.g., 175',
              prefixIcon: const Icon(Icons.height_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: context.inputFill,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Height is required';
              }
              final height = double.tryParse(value.trim());
              if (height == null || height < 50 || height > 300) {
                return 'Please enter a valid height (50-300 cm)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Weight
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Weight (kg) *',
              hintText: 'e.g., 70.5',
              prefixIcon: const Icon(Icons.monitor_weight_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: context.inputFill,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Weight is required';
              }
              final weight = double.tryParse(value.trim());
              if (weight == null || weight < 20 || weight > 500) {
                return 'Please enter a valid weight (20-500 kg)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPage2OptionalStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Optional: Body Composition',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These are optional but help us give better recommendations.',
            style: TextStyle(fontSize: 16, color: context.textSecondary),
          ),
          const SizedBox(height: 32),

          // Body Fat %
          TextFormField(
            controller: _bodyFatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Body Fat % (Optional)',
              hintText: 'e.g., 18.5',
              prefixIcon: const Icon(Icons.percent_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: context.inputFill,
              helperText: 'Leave blank if unknown',
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final val = double.tryParse(value.trim());
                if (val == null || val < 2 || val > 60) {
                  return 'Please enter a valid percentage (2-60)';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Muscle Mass %
          TextFormField(
            controller: _muscleMassController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Muscle Mass % (Optional)',
              hintText: 'e.g., 45.2',
              prefixIcon: const Icon(Icons.fitness_center_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: context.inputFill,
              helperText: 'Leave blank if unknown',
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final val = double.tryParse(value.trim());
                if (val == null || val < 10 || val > 90) {
                  return 'Please enter a valid percentage (10-90)';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.accent.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: context.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Why do we ask?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Body composition metrics help us calculate your calorie needs, macro targets, and provide personalized workout recommendations.',
                  style: TextStyle(fontSize: 14, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3FitnessGoals() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What Are Your Goals?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us customize your workout and nutrition plans.',
            style: TextStyle(fontSize: 16, color: context.textSecondary),
          ),
          const SizedBox(height: 32),

          // Fitness Goal
          Text(
            'Primary Fitness Goal *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _fitnessGoals.map((goal) {
              final isSelected = _fitnessGoal == goal;
              return FilterChip(
                label: Text(goal),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _fitnessGoal = selected ? goal : '');
                },
                selectedColor: context.accent.withAlpha(51),
                checkmarkColor: context.accent,
                labelStyle: TextStyle(
                  color: isSelected ? context.accent : context.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? context.accent : context.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
          if (_fitnessGoal.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Please select a fitness goal',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 32),

          // Activity Level
          Text(
            'Activity Level *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: _activityLevels.map((level) {
              final isSelected = _activityLevel == level;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _activityLevel = isSelected ? '' : level),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _activityLevel == level
                          ? context.accent.withValues(alpha: 0.08)
                          : context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _activityLevel == level
                            ? context.accent
                            : context.border,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _activityLevel == level
                                ? context.accent
                                : Colors.transparent,
                            border: Border.all(
                              color: _activityLevel == level
                                  ? context.accent
                                  : context.border,
                              width: 2,
                            ),
                          ),
                          child: _activityLevel == level
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            level,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _activityLevel == level
                                  ? context.textPrimary
                                  : context.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_activityLevel.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Please select your activity level',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}