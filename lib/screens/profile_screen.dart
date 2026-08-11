import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/theme_controller.dart';
import '../models/user_profile.dart';
import '../models/xp_system.dart';
import '../theme/app_colors.dart';
import '../widgets/flame_effect.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _editBodyStatsFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = context.background;
    final cardColor = context.cardColor;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final textMuted = context.textMuted;
    final dividerColor = context.divider;
    final shadowColor = context.shadow;
    final borderColor = context.border;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'HUNTER STATUS',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textPrimary),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: context.accent),
            );
          }
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return Center(child: Text('Could not load profile.', style: TextStyle(color: textSecondary)));
          }

          final userData = snapshot.data!.data()!;
          final name = userData['name'] as String? ?? 'Hunter';
          final email = userData['email'] as String? ?? user.email ?? '';
          final level = userData['level'] as int? ?? 1;
          final xp = userData['xp'] as int? ?? 0;
          final xpTarget = userData['xpTarget'] as int? ?? 1000;
          final bodyStats = userData['bodyStats'] as Map<String, dynamic>? ?? {};
          final dailyTargets = userData['dailyTargets'] as Map<String, dynamic>? ?? {};
          final fitnessGoal = userData['fitnessGoal'] as String? ?? 'Not set';
          final activityLevel = userData['activityLevel'] as String? ?? 'Not set';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildUserMetaHeader(name, email, level, xp, xpTarget, isDark, cardColor, textPrimary, textSecondary),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Body Stats', textPrimary),
                      const SizedBox(height: 8),
                      _buildBodyStatsCard(bodyStats, isDark, cardColor, textPrimary, textSecondary, textMuted, dividerColor, shadowColor, borderColor, user.uid),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Fitness & Activity', textPrimary),
                      const SizedBox(height: 8),
                      _buildFitnessInfoCard(fitnessGoal, activityLevel, isDark, cardColor, textPrimary, textSecondary, shadowColor, borderColor, user.uid),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Daily Targets', textPrimary),
                      const SizedBox(height: 8),
                      _buildDailyTargetsCard(dailyTargets, isDark, cardColor, textPrimary, textSecondary, shadowColor, borderColor),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserMetaHeader(
    String name,
    String email,
    int level,
    int xp,
    int xpTarget,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      width: double.infinity,
      color: cardColor,
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Column(
        children: [
          GlowRing(
            color: context.accent,
            glowRadius: 12,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.accent, width: 3),
                gradient: LinearGradient(
                  colors: [context.accent, Color(0xFF38BDF8)],
                ),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'H',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Level $level • Hunter Rank',
            style: TextStyle(
              fontSize: 14,
              color: context.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'XP',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
                    ),
                    Text(
                      'Target',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 8,
                    width: double.infinity,
                    color: context.progressTrack,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (xp / xpTarget).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textPrimary) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    );
  }

  Widget _buildBodyStatsCard(
    Map<String, dynamic> stats,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color dividerColor,
    Color shadowColor,
    Color borderColor,
    String uid,
  ) {
    final age = stats['age']?.toString() ?? '—';
    final height = stats['height']?.toString() ?? '—';
    final weight = stats['weight']?.toString() ?? '—';
    final bodyFat = stats['bodyFat']?.toString() ?? '—';
    final muscleMass = stats['muscleMass']?.toString() ?? '—';

    double? bmi;
    if (stats['height'] != null && stats['weight'] != null) {
      final h = (stats['height'] as num) / 100.0;
      bmi = (stats['weight'] as num) / (h * h);
    }
    final bmiLabel = bmi != null ? (bmi < 18.5 ? 'Underweight' : (bmi < 25 ? 'Normal' : 'Overweight')) : '—';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Body Stats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEditAllBodyStatsSheet(stats, uid),
                icon: Icon(Icons.edit_outlined, size: 18, color: context.accent),
                label: Text(
                  'Edit All',
                  style: TextStyle(color: context.accent, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: context.accent.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildEditableStatTile('Age', age, 'years', 'age', isDark, cardColor, textPrimary, textMuted),
              _buildEditableStatTile('Height', height, 'cm', 'height', isDark, cardColor, textPrimary, textMuted),
              _buildEditableStatTile('Weight', weight, 'kg', 'weight', isDark, cardColor, textPrimary, textMuted),
            ],
          ),
          Divider(height: 24, color: dividerColor),
          Row(
            children: [
              _buildEditableStatTile('Body Fat', '$bodyFat%', 'Optional', 'bodyFat', isDark, cardColor, textPrimary, textMuted),
              _buildEditableStatTile('Muscle Mass', '$muscleMass%', 'Optional', 'muscleMass', isDark, cardColor, textPrimary, textMuted),
              _buildStatDetailTile('BMI', bmi?.toStringAsFixed(1) ?? '—', bmiLabel, isDark, textPrimary, textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableStatTile(
    String label,
    String value,
    String subtitle,
    String statKey,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textMuted,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showEditStatDialog(label, statKey, value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 10, color: textMuted),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDetailTile(String label, String value, String subtitle, bool isDark, Color textPrimary, Color textMuted) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: textMuted),
          ),
        ],
      ),
    );
  }

  void _showEditStatDialog(String label, String statKey, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    final isPercentage = statKey == 'bodyFat' || statKey == 'muscleMass';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $label', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          keyboardType: isPercentage
              ? const TextInputType.numberWithOptions(decimal: true)
              : (statKey == 'age' ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true)),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            suffixText: isPercentage ? '%' : '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                if (isPercentage) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) await _updateBodyStat(statKey, parsed);
                } else {
                  final parsed = statKey == 'age' ? int.tryParse(val) : double.tryParse(val);
                  if (parsed != null) await _updateBodyStat(statKey, parsed);
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditAllBodyStatsSheet(Map<String, dynamic> currentStats, String uid) async {
    final ageController = TextEditingController(text: currentStats['age']?.toString() ?? '');
    final heightController = TextEditingController(text: currentStats['height']?.toString() ?? '');
    final weightController = TextEditingController(text: currentStats['weight']?.toString() ?? '');
    final bodyFatController = TextEditingController(text: currentStats['bodyFat']?.toString() ?? '');
    final muscleMassController = TextEditingController(text: currentStats['muscleMass']?.toString() ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _editBodyStatsFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Body Stats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age *',
                    hintText: 'e.g., 25',
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Height (cm) *',
                    hintText: 'e.g., 175',
                    prefixIcon: Icon(Icons.height_outlined),
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg) *',
                    hintText: 'e.g., 70.5',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: bodyFatController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Body Fat % (Optional)',
                    hintText: 'e.g., 18.5',
                    prefixIcon: Icon(Icons.percent_outlined),
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: muscleMassController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Muscle Mass % (Optional)',
                    hintText: 'e.g., 45.2',
                    prefixIcon: Icon(Icons.fitness_center_outlined),
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Body Stats'),
                    onPressed: () async {
                      if (!_editBodyStatsFormKey.currentState!.validate()) return;

                      Navigator.pop(sheetContext);
                      await _saveAllBodyStats(uid, {
                        'age': int.parse(ageController.text.trim()),
                        'height': double.parse(heightController.text.trim()),
                        'weight': double.parse(weightController.text.trim()),
                        if (bodyFatController.text.trim().isNotEmpty)
                          'bodyFat': double.parse(bodyFatController.text.trim()),
                        if (muscleMassController.text.trim().isNotEmpty)
                          'muscleMass': double.parse(muscleMassController.text.trim()),
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    bodyFatController.dispose();
    muscleMassController.dispose();
  }

  Future<void> _saveAllBodyStats(String uid, Map<String, dynamic> stats) async {
    try {
      final updates = <String, dynamic>{
        'bodyStats': stats,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).update(updates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Body stats updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update body stats: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateBodyStat(String key, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).update({'bodyStats.$key': value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating $key: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildFitnessInfoCard(
    String goal,
    String level,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color shadowColor,
    Color borderColor,
    String uid,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEditableInfoRow(
            Icons.flag_outlined,
            'Primary Goal',
            goal,
            'fitnessGoal',
            uid,
            isDark,
            cardColor,
            textPrimary,
            textSecondary,
          ),
          const SizedBox(height: 12),
          _buildEditableInfoRow(
            Icons.directions_run,
            'Activity Level',
            level,
            'activityLevel',
            uid,
            isDark,
            cardColor,
            textPrimary,
            textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(
    IconData icon,
    String label,
    String value,
    String fieldKey,
    String uid,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GestureDetector(
      onTap: () => _showEditFitnessField(label, fieldKey, value, uid),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: context.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
            ],
          ),
          Row(
            children: [
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textSecondary)),
              const SizedBox(width: 8),
              Icon(Icons.edit, size: 16, color: textSecondary.withValues(alpha: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditFitnessField(String label, String fieldKey, String currentValue, String uid) {
    final controller = TextEditingController(text: currentValue);
    final isGoal = fieldKey == 'fitnessGoal';

    final List<String> fitnessGoals = [
      'Lose Weight',
      'Build Muscle',
      'Improve Endurance',
      'Maintain Health',
      'Gain Weight',
    ];

    final List<String> activityLevels = [
      'Sedentary (Little to no exercise)',
      'Lightly Active (Light exercise 1-3 days/week)',
      'Moderately Active (Moderate exercise 3-5 days/week)',
      'Very Active (Hard exercise 6-7 days/week)',
      'Extremely Active (Very hard exercise, physical job)',
    ];

    final options = isGoal ? fitnessGoals : activityLevels;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit $label',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              if (isGoal) ...[
                ...options.map((option) {
                  final isSelected = currentValue == option;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    tileColor: context.cardColor,
                    title: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? context.accent : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: context.accent)
                        : null,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _updateFitnessField(uid, fieldKey, option);
                    },
                  );
                }),
              ] else ...[
                ...options.map((option) {
                  final isSelected = currentValue == option;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    tileColor: context.cardColor,
                    title: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? context.accent : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: context.accent)
                        : null,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _updateFitnessField(uid, fieldKey, option);
                    },
                  );
                }),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateFitnessField(String uid, String fieldKey, String value) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        fieldKey: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fieldKey updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating $fieldKey: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDailyTargetsCard(
    Map<String, dynamic> targets,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color shadowColor,
    Color borderColor,
  ) {
    final calories = targets['calories']?.toString() ?? '—';
    final protein = targets['protein']?.toString() ?? '—';
    final water = targets['water']?.toString() ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow(Icons.local_fire_department, 'Calorie Goal', '$calories kcal', isDark, textPrimary, textSecondary),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.fitness_center, 'Protein Goal', '$protein g', isDark, textPrimary, textSecondary),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.water_drop, 'Water Goal', '$water L', isDark, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: context.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textSecondary)),
      ],
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final themeController = Provider.of<ThemeController>(context, listen: false);
        final user = _auth.currentUser;
        final tileColor = context.cardColor;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    tileColor: tileColor,
                    secondary: Icon(Icons.dark_mode_outlined, color: context.textSecondary),
                    title: Text('Dark mode', style: TextStyle(color: context.textPrimary)),
                    subtitle: Text('Use a darker app theme', style: TextStyle(color: context.textMuted, fontSize: 12)),
                    value: isDark,
                    onChanged: (_) => themeController.toggleDark(),
                  ),
                  Divider(height: 12, color: context.divider),
                  _buildModesSection(themeController, user?.uid, isDark),
                  Divider(height: 12, color: context.divider),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    tileColor: tileColor,
                    leading: const Icon(
                      Icons.logout,
                      color: Color(0xFFDC2626),
                    ),
                    title: const Text(
                      'Sign out',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModesSection(ThemeController themeController, String? uid, bool isDark) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid != null
          ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final userData = snapshot.data?.data() ?? {};
        final streakDays = userData['streakDays'] as int? ?? 100;
        final currentModeName = userData['currentMode'] as String? ?? 'survival';
        final currentMode = AppMode.values.byName(currentModeName);
        final unlockedModes = themeController.getUnlockedModes(streakDays);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Text(
                  'Modes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Unlock new color themes with streak progress',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            ...AppMode.values.map((mode) {
              final isUnlocked = unlockedModes.contains(mode);
              final isSelected = currentMode == mode;
              final colors = XPSystem.getModeColors(mode, isDark);
              final primaryColor = Color(colors['primary']!);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryColor : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  tileColor: isSelected
                      ? primaryColor.withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isUnlocked ? primaryColor : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isUnlocked
                          ? Icon(
                              _getModeIcon(mode),
                              color: Colors.white,
                              size: 20,
                            )
                          : Icon(
                              Icons.lock,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              size: 18,
                            ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        XPSystem.getModeName(mode),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _getModeUnlockRequirement(mode),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    XPSystem.getModeDescription(mode),
                    style: TextStyle(
                      fontSize: 12,
                      color: isUnlocked
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: primaryColor, size: 24)
                      : isUnlocked
                          ? Icon(Icons.radio_button_unchecked, color: primaryColor)
                          : Icon(Icons.lock, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                  onTap: isUnlocked
                      ? () async {
                          await themeController.setMode(mode);
                          if (uid != null) {
                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'currentMode': mode.name,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          }
                          if (context.mounted) Navigator.pop(context);
                        }
                      : null,
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
            // Streak progress for next mode unlock
            if (!unlockedModes.contains(AppMode.hunter) || !unlockedModes.contains(AppMode.beast)) ...[
              const SizedBox(height: 12),
              _buildStreakProgressBar(streakDays, isDark),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStreakProgressBar(int streakDays, bool isDark) {
    final nextUnlock = streakDays < XPSystem.HUNTER_MODE_UNLOCK_DAY
        ? XPSystem.HUNTER_MODE_UNLOCK_DAY
        : streakDays < XPSystem.BEAST_MODE_UNLOCK_DAY
            ? XPSystem.BEAST_MODE_UNLOCK_DAY
            : null;

    if (nextUnlock == null) return const SizedBox.shrink();

    final progress = (streakDays / nextUnlock).clamp(0.0, 1.0);
    final nextMode = streakDays < XPSystem.HUNTER_MODE_UNLOCK_DAY ? AppMode.hunter : AppMode.beast;
    final colors = XPSystem.getModeColors(nextMode, isDark);
    final primaryColor = Color(colors['primary']!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${XPSystem.getModeName(nextMode)} unlocks in ${nextUnlock - streakDays} days',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                color: primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getModeIcon(AppMode mode) {
    switch (mode) {
      case AppMode.survival:
        return Icons.shield_outlined;
      case AppMode.hunter:
        return Icons.visibility_outlined;
      case AppMode.beast:
        return Icons.bolt;
    }
  }

  String _getModeUnlockRequirement(AppMode mode) {
    switch (mode) {
      case AppMode.survival:
        return 'Default';
      case AppMode.hunter:
        return '${XPSystem.HUNTER_MODE_UNLOCK_DAY} days streak';
      case AppMode.beast:
        return '${XPSystem.BEAST_MODE_UNLOCK_DAY} days streak';
    }
  }

  Future<void> _signOut() async {
    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
      await _auth.signOut();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not sign out: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}