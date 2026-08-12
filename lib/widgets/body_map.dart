import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Interactive body map built from stacked transparent PNG overlays.
///
/// The base body outline (`front_body_base.png`) is always drawn. Each muscle
/// group is a separate transparent PNG layered on top of the same canvas, so
/// any group present in [muscleCounts] is recolored with [accentColor] using
/// [BlendMode.srcATop] (tint where the overlay has pixels, keep transparency
/// elsewhere).
///
/// Opacity scales with the exercise count per muscle group: more exercises
/// = more intense highlight.
class BodyMapWidget extends StatefulWidget {
  /// Muscle group name → number of exercises targeting it.
  /// Keys use app-level names: Chest, Shoulders, Arms, Core, Back, Legs, etc.
  final Map<String, int> muscleCounts;
  final Color accentColor;

  const BodyMapWidget({
    super.key,
    required this.muscleCounts,
    this.accentColor = const Color(0xFF2563EB),
  });

  @override
  State<BodyMapWidget> createState() => _BodyMapWidgetState();
}

class _BodyMapWidgetState extends State<BodyMapWidget>
    with SingleTickerProviderStateMixin {
  static const _frontAssetDir = 'assets/body_map/muscles_front';

  /// App-level muscle group → front-view overlay PNGs that light up for it.
  static const _frontOverlays = <String, List<String>>{
    'chest': ['$_frontAssetDir/chest.png'],
    'shoulders': [
      '$_frontAssetDir/shoulders.png',
      '$_frontAssetDir/traps.png',
    ],
    'biceps': ['$_frontAssetDir/biceps.png'],
    'arms': ['$_frontAssetDir/forearms.png'], // forearms labeled as "Arms"
    'abs': ['$_frontAssetDir/abs.png'],
    'obliques': ['$_frontAssetDir/obliques.png'],
    'legs': [
      '$_frontAssetDir/quads.png',
      '$_frontAssetDir/calves.png',
    ],
  };

  /// Maps app-level muscleGroup strings (from exercises) to overlay keys.
  /// One exercise muscleGroup can light up multiple overlay keys.
  static const _muscleGroupToOverlays = <String, List<String>>{
    'Chest': ['chest'],
    'Shoulders': ['shoulders'],
    'Arms': ['biceps', 'arms'], // biceps + forearms
    'Core': ['abs', 'obliques'], // abs + obliques
    'Legs': ['legs'],
    // Back, Cardio → no front overlays yet
  };

  /// Maps display labels to overlay keys for active-status checking.
  static const _labelToOverlayKey = {
    'Chest': 'chest',
    'Shoulders': 'shoulders',
    'Bicep': 'biceps',
    'Abs': 'abs',
    'Obliques': 'obliques',
    'Arms': 'arms',
    'Legs': 'legs',
    'Back': 'back',
  };

  int _currentViewIndex = 0; // 0=front, 1=side, 2=back
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  double _dragStartX = 0;
  bool _isDragging = false;

  static const _viewLabels = ['Front', 'Side', 'Back'];

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _isDragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final dx = details.globalPosition.dx - _dragStartX;
    if (dx.abs() > 60) {
      final direction = dx > 0 ? -1 : 1;
      final newIndex = (_currentViewIndex + direction).clamp(0, 2);
      if (newIndex != _currentViewIndex) {
        _rotateToView(newIndex, direction);
      }
      _dragStartX = details.globalPosition.dx;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
  }

  void _rotateToView(int newIndex, int direction) {
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: direction * pi * 0.4,
    ).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic),
    );
    _rotationController.forward(from: 0).then((_) {
      setState(() => _currentViewIndex = newIndex);
      _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _rotationController, curve: Curves.easeOut),
      );
    });
    setState(() {});
  }

  /// Compute per-overlay-key counts by mapping exercise muscleGroups → overlay keys.
  Map<String, int> _buildOverlayCounts() {
    final overlayCounts = <String, int>{};
    for (final entry in widget.muscleCounts.entries) {
      final overlayKeys = _muscleGroupToOverlays[entry.key] ?? [];
      for (final key in overlayKeys) {
        overlayCounts[key] = (overlayCounts[key] ?? 0) + entry.value;
      }
    }
    return overlayCounts;
  }

  /// Opacity for a muscle overlay based on its exercise count.
  double _muscleOpacity(String overlayKey, Map<String, int> overlayCounts) {
    final count = overlayCounts[overlayKey] ?? 0;
    if (count == 0) return 0.0;
    return (0.35 + 0.2 * count).clamp(0.35, 0.95);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final overlayCounts = _buildOverlayCounts();

    // Active muscle groups (those with at least one exercise).
    final activeGroups = overlayCounts.keys
        .where((k) => (overlayCounts[k] ?? 0) > 0)
        .toSet();

    return Column(
      children: [
        // View label
        Text(
          _viewLabels[_currentViewIndex],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: accent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        // Main body area: labels left + body right
        SizedBox(
          height: 340,
          child: Row(
            children: [
              // Left: Muscle labels
              SizedBox(
                width: 100,
                child: _buildMuscleLabels(activeGroups, overlayCounts, accent),
              ),
              // Right: Body model
              Expanded(
                child: GestureDetector(
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      final skew = _rotationAnimation.value;
                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // perspective
                          ..rotateY(skew),
                        alignment: Alignment.center,
                        child: _buildBody(activeGroups, overlayCounts, accent),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        // Swipe hint
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Container(
              width: i == _currentViewIndex ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == _currentViewIndex
                    ? accent
                    : accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        Text(
          '← Swipe to rotate →',
          style: TextStyle(fontSize: 10, color: context.textMuted),
        ),
      ],
    );
  }

  /// Stacked image body: base outline + recolored muscle overlays.
  Widget _buildBody(
      Set<String> activeGroups, Map<String, int> overlayCounts, Color accent) {
    if (_currentViewIndex != 0) {
      return _buildComingSoon(accent);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base body outline
        _baseImage(isDark),
        // Active muscle overlays, tinted with the accent color.
        for (final entry in _frontOverlays.entries)
          if (activeGroups.contains(entry.key))
            for (final asset in entry.value)
              Image.asset(
                asset,
                fit: BoxFit.contain,
                color: accent.withValues(
                    alpha: _muscleOpacity(entry.key, overlayCounts)),
                colorBlendMode: BlendMode.srcATop,
              ),
      ],
    );
  }

  Widget _baseImage(bool isDark) {
    final image = Image.asset(
      'assets/body_map/front_body_base.png',
      fit: BoxFit.contain,
    );
    if (!isDark) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.72, 0, 0, 0, 0, //
        0, 0.72, 0, 0, 0, //
        0, 0, 0.72, 0, 0, //
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }

  Widget _buildComingSoon(Color accent) {
    final viewName = _viewLabels[_currentViewIndex];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction,
              size: 40, color: accent.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            '$viewName view coming soon',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overlay images will be added next.',
            style: TextStyle(fontSize: 11, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleLabels(
      Set<String> activeGroups, Map<String, int> overlayCounts, Color accent) {
    final muscles = _getVisibleMuscles();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: muscles.map((muscle) {
        final overlayKey = _labelToOverlayKey[muscle];
        final isActive = overlayKey != null && activeGroups.contains(overlayKey);
        final count = overlayKey != null ? (overlayCounts[overlayKey] ?? 0) : 0;
        final dotOpacity =
            count > 0 ? (0.5 + 0.15 * count).clamp(0.5, 1.0) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? accent
                      : context.textMuted.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: dotOpacity),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  muscle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? accent : context.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<String> _getVisibleMuscles() {
    switch (_currentViewIndex) {
      case 0: // Front
        return ['Chest', 'Shoulders', 'Bicep', 'Abs', 'Obliques', 'Arms', 'Legs'];
      case 1: // Side
        return ['Shoulders', 'Chest', 'Bicep', 'Abs', 'Obliques', 'Arms', 'Legs'];
      case 2: // Back
        return ['Back', 'Shoulders', 'Bicep', 'Abs', 'Obliques', 'Arms', 'Legs'];
      default:
        return [];
    }
  }
}
