import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 3D-style rotatable body map with detailed muscle highlighting.
/// Swipe left/right to rotate between front, side, and back views.
/// Active muscles glow with the mode's accent color.
class BodyMapWidget extends StatefulWidget {
  final Set<String> activeMuscles;
  final Color accentColor;

  const BodyMapWidget({
    super.key,
    required this.activeMuscles,
    this.accentColor = const Color(0xFF2563EB),
  });

  @override
  State<BodyMapWidget> createState() => _BodyMapWidgetState();
}

class _BodyMapWidgetState extends State<BodyMapWidget>
    with SingleTickerProviderStateMixin {
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
    // Need a significant swipe to rotate
    if (dx.abs() > 60) {
      final direction = dx > 0 ? -1 : 1; // swipe right = previous view
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

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get active muscle groups with proper labels
    final activeGroups = widget.activeMuscles.map((m) => m.toLowerCase()).toSet();

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
                child: _buildMuscleLabels(activeGroups, accent),
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
                        child: CustomPaint(
                          painter: _BodyPainter(
                            viewIndex: _currentViewIndex,
                            activeMuscles: activeGroups,
                            accentColor: accent,
                            isDark: isDark,
                          ),
                          size: Size.infinite,
                        ),
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

  Widget _buildMuscleLabels(Set<String> activeGroups, Color accent) {
    final muscles = _getVisibleMuscles();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: muscles.map((muscle) {
        final isActive = activeGroups.contains(muscle.toLowerCase());
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? accent : context.textMuted.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 6)]
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
        return ['Chest', 'Shoulders', 'Biceps', 'Core', 'Quads'];
      case 1: // Side
        return ['Shoulders', 'Chest', 'Triceps', 'Core', 'Abs'];
      case 2: // Back
        return ['Back', 'Traps', 'Lats', 'Triceps', 'Hamstrings'];
      default:
        return [];
    }
  }
}

/// Detailed anatomical body painter with gradient shading.
class _BodyPainter extends CustomPainter {
  final int viewIndex;
  final Set<String> activeMuscles;
  final Color accentColor;
  final bool isDark;

  _BodyPainter({
    required this.viewIndex,
    required this.activeMuscles,
    required this.accentColor,
    required this.isDark,
  });

  // Colors
  Color get _skinBase => isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE8DDD3);
  Color get _muscleBase => isDark ? const Color(0xFF252540) : const Color(0xFFD4BFA8);
  Color get _outline => isDark ? const Color(0xFF3A3A5C) : const Color(0xFFBBA890);
  Color get _glowColor => accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    switch (viewIndex) {
      case 0:
        _paintFront(canvas, w, h, cx);
        break;
      case 1:
        _paintSide(canvas, w, h, cx);
        break;
      case 2:
        _paintBack(canvas, w, h, cx);
        break;
    }
  }

  void _paintFront(Canvas canvas, double w, double h, double cx) {
    // Shadow underneath body
    _drawBodyShadow(canvas, w, h, cx);

    // Body outline (filled)
    final bodyPath = _frontBodyPath(w, h, cx);
    canvas.drawPath(bodyPath, Paint()..color = _skinBase..style = PaintingStyle.fill);

    // Muscle detail overlays
    _drawMuscleGroup(canvas, 'chest', _chestPath(w, h, cx));
    _drawMuscleGroup(canvas, 'shoulders', _frontShouldersPath(w, h, cx));
    _drawMuscleGroup(canvas, 'biceps', _frontBicepsPath(w, h, cx));
    _drawMuscleGroup(canvas, 'core', _corePath(w, h, cx));
    _drawMuscleGroup(canvas, 'quads', _frontQuadsPath(w, h, cx));
    _drawMuscleGroup(canvas, 'abs', _absPath(w, h, cx));

    // Outline
    canvas.drawPath(bodyPath, Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Detail lines (pec separation, abs lines)
    _drawFrontDetails(canvas, w, h, cx);
  }

  void _paintSide(Canvas canvas, double w, double h, double cx) {
    _drawBodyShadow(canvas, w, h, cx);

    final bodyPath = _sideBodyPath(w, h, cx);
    canvas.drawPath(bodyPath, Paint()..color = _skinBase..style = PaintingStyle.fill);

    _drawMuscleGroup(canvas, 'shoulders', _sideShouldersPath(w, h, cx));
    _drawMuscleGroup(canvas, 'chest', _sideChestPath(w, h, cx));
    _drawMuscleGroup(canvas, 'triceps', _sideTricepsPath(w, h, cx));
    _drawMuscleGroup(canvas, 'core', _sideCorePath(w, h, cx));
    _drawMuscleGroup(canvas, 'abs', _sideAbsPath(w, h, cx));

    canvas.drawPath(bodyPath, Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  void _paintBack(Canvas canvas, double w, double h, double cx) {
    _drawBodyShadow(canvas, w, h, cx);

    final bodyPath = _frontBodyPath(w, h, cx); // same silhouette
    canvas.drawPath(bodyPath, Paint()..color = _skinBase..style = PaintingStyle.fill);

    _drawMuscleGroup(canvas, 'back', _backPath(w, h, cx));
    _drawMuscleGroup(canvas, 'traps', _trapsPath(w, h, cx));
    _drawMuscleGroup(canvas, 'lats', _latsPath(w, h, cx));
    _drawMuscleGroup(canvas, 'triceps', _backTricepsPath(w, h, cx));
    _drawMuscleGroup(canvas, 'hamstrings', _backHamstringsPath(w, h, cx));

    canvas.drawPath(bodyPath, Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    _drawBackDetails(canvas, w, h, cx);
  }

  // ── Shadow ─────────────────────────────────────────────────

  void _drawBodyShadow(Canvas canvas, double w, double h, double cx) {
    final shadowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.5), width: w * 0.5, height: h * 0.85),
      shadowPaint,
    );
  }

  // ── Muscle Group Drawing ───────────────────────────────────

  void _drawMuscleGroup(Canvas canvas, String name, Path path) {
    final isActive = activeMuscles.contains(name);

    if (isActive) {
      // Glow effect
      final glowPaint = Paint()
        ..color = _glowColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, glowPaint);

      // Active fill
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.7),
          accentColor.withValues(alpha: 0.4),
        ],
      );
      canvas.drawPath(path, Paint()
        ..shader = gradient.createShader(path.getBounds())
        ..style = PaintingStyle.fill);

      // Border
      canvas.drawPath(path, Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    } else {
      // Inactive muscle detail
      canvas.drawPath(path, Paint()
        ..color = _muscleBase
        ..style = PaintingStyle.fill);

      canvas.drawPath(path, Paint()
        ..color = _outline.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5);
    }
  }

  // ── Body Paths ─────────────────────────────────────────────

  Path _frontBodyPath(double w, double h, double cx) {
    final p = Path();
    final headR = w * 0.1;
    final headY = h * 0.08;

    // Head
    p.addOval(Rect.fromCircle(center: Offset(cx, headY), radius: headR));

    // Neck
    final neckTop = headY + headR;
    p.moveTo(cx - w * 0.05, neckTop);
    p.lineTo(cx + w * 0.05, neckTop);
    p.lineTo(cx + w * 0.06, neckTop + h * 0.04);
    p.lineTo(cx - w * 0.06, neckTop + h * 0.04);
    p.close();

    // Torso + arms + legs as one shape
    final shoulderY = neckTop + h * 0.04;
    final shoulderW = w * 0.38;
    final hipY = h * 0.58;
    final hipW = w * 0.22;

    // Main torso
    final torso = Path();
    torso.moveTo(cx - shoulderW, shoulderY);
    torso.lineTo(cx + shoulderW, shoulderY);
    torso.quadraticBezierTo(cx + shoulderW + w * 0.01, h * 0.32, cx + hipW, hipY);
    torso.lineTo(cx + w * 0.03, hipY + h * 0.03);
    torso.lineTo(cx - w * 0.03, hipY + h * 0.03);
    torso.lineTo(cx - hipW, hipY);
    torso.quadraticBezierTo(cx - shoulderW - w * 0.01, h * 0.32, cx - shoulderW, shoulderY);
    torso.close();

    // Left arm
    final lArm = Path();
    lArm.moveTo(cx - shoulderW, shoulderY);
    lArm.lineTo(cx - shoulderW - w * 0.08, shoulderY + h * 0.02);
    lArm.lineTo(cx - shoulderW - w * 0.06, h * 0.36); // elbow
    lArm.lineTo(cx - shoulderW - w * 0.1, h * 0.52); // wrist
    lArm.lineTo(cx - shoulderW - w * 0.04, h * 0.52);
    lArm.lineTo(cx - shoulderW + w * 0.0, h * 0.36);
    lArm.lineTo(cx - shoulderW + w * 0.02, shoulderY + h * 0.02);
    lArm.close();

    // Right arm
    final rArm = Path();
    rArm.moveTo(cx + shoulderW, shoulderY);
    rArm.lineTo(cx + shoulderW + w * 0.08, shoulderY + h * 0.02);
    rArm.lineTo(cx + shoulderW + w * 0.06, h * 0.36);
    rArm.lineTo(cx + shoulderW + w * 0.1, h * 0.52);
    rArm.lineTo(cx + shoulderW + w * 0.04, h * 0.52);
    rArm.lineTo(cx + shoulderW + w * 0.0, h * 0.36);
    rArm.lineTo(cx + shoulderW - w * 0.02, shoulderY + h * 0.02);
    rArm.close();

    // Left leg
    final lLeg = Path();
    lLeg.moveTo(cx - hipW * 0.5, hipY);
    lLeg.lineTo(cx - w * 0.02, hipY + h * 0.02);
    lLeg.lineTo(cx - w * 0.04, h * 0.96);
    lLeg.lineTo(cx - hipW * 0.8, h * 0.96);
    lLeg.lineTo(cx - hipW * 0.9, hipY + h * 0.02);
    lLeg.close();

    // Right leg
    final rLeg = Path();
    rLeg.moveTo(cx + hipW * 0.5, hipY);
    rLeg.lineTo(cx + w * 0.02, hipY + h * 0.02);
    rLeg.lineTo(cx + w * 0.04, h * 0.96);
    rLeg.lineTo(cx + hipW * 0.8, h * 0.96);
    rLeg.lineTo(cx + hipW * 0.9, hipY + h * 0.02);
    rLeg.close();

    // Combine all
    final combined = Path.combine(PathOperation.union, torso, lArm);
    final combined2 = Path.combine(PathOperation.union, combined, rArm);
    final combined3 = Path.combine(PathOperation.union, combined2, lLeg);
    return Path.combine(PathOperation.union, combined3, rLeg);
  }

  Path _sideBodyPath(double w, double h, double cx) {
    final p = Path();
    final headR = w * 0.09;
    final headY = h * 0.08;

    p.addOval(Rect.fromCircle(center: Offset(cx + w * 0.03, headY), radius: headR));

    final neckY = headY + headR;
    final shoulderY = neckY + h * 0.03;
    final chestDepth = w * 0.16;
    final hipY = h * 0.58;

    // Torso side profile
    p.moveTo(cx - chestDepth * 0.2, shoulderY);
    p.quadraticBezierTo(cx + chestDepth, h * 0.22, cx + chestDepth * 0.8, hipY);
    p.lineTo(cx + chestDepth * 0.6, hipY + h * 0.04);
    p.lineTo(cx + w * 0.06, h * 0.96);
    p.lineTo(cx - w * 0.04, h * 0.96);
    p.lineTo(cx - chestDepth * 0.5, hipY + h * 0.04);
    p.lineTo(cx - chestDepth * 0.3, hipY);
    p.quadraticBezierTo(cx - chestDepth * 0.4, h * 0.26, cx - chestDepth * 0.2, shoulderY);
    p.close();

    // Arm
    final arm = Path();
    arm.moveTo(cx + chestDepth * 0.5, shoulderY);
    arm.lineTo(cx + chestDepth * 0.5 + w * 0.05, shoulderY);
    arm.lineTo(cx + chestDepth * 0.45 + w * 0.05, h * 0.52);
    arm.lineTo(cx + chestDepth * 0.45, h * 0.52);
    arm.close();

    return Path.combine(PathOperation.union, p, arm);
  }

  // ── Muscle Region Paths ────────────────────────────────────

  Path _chestPath(double w, double h, double cx) {
    final p = Path();
    final y = h * 0.19;
    // Left pec
    p.moveTo(cx - w * 0.02, y);
    p.quadraticBezierTo(cx - w * 0.18, y - h * 0.01, cx - w * 0.22, y + h * 0.02);
    p.lineTo(cx - w * 0.2, y + h * 0.09);
    p.lineTo(cx - w * 0.02, y + h * 0.07);
    p.close();
    return p;
  }

  Path _frontShouldersPath(double w, double h, double cx) {
    final p = Path();
    final y = h * 0.14;
    final sw = w * 0.38;
    // Left delt
    p.moveTo(cx - sw - w * 0.01, y);
    p.quadraticBezierTo(cx - sw - w * 0.08, y + h * 0.02, cx - sw - w * 0.06, y + h * 0.08);
    p.lineTo(cx - sw + w * 0.04, y + h * 0.06);
    p.lineTo(cx - sw + w * 0.02, y);
    p.close();
    return p;
  }

  Path _frontBicepsPath(double w, double h, double cx) {
    final p = Path();
    final sw = w * 0.38;
    final top = h * 0.2;
    final bot = h * 0.36;
    // Left bicep
    p.moveTo(cx - sw - w * 0.04, top);
    p.lineTo(cx - sw + w * 0.0, top);
    p.lineTo(cx - sw - w * 0.02, bot);
    p.lineTo(cx - sw - w * 0.08, bot);
    p.close();
    return p;
  }

  Path _corePath(double w, double h, double cx) {
    final p = Path();
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, h * 0.4), width: w * 0.24, height: h * 0.2),
      const Radius.circular(8),
    ));
    return p;
  }

  Path _absPath(double w, double h, double cx) {
    final p = Path();
    // Central abs line
    p.moveTo(cx, h * 0.33);
    p.lineTo(cx, h * 0.52);
    return p;
  }

  Path _frontQuadsPath(double w, double h, double cx) {
    final p = Path();
    final hipW = w * 0.22;
    final top = h * 0.58;
    final bot = h * 0.88;
    // Left quad
    p.moveTo(cx - hipW * 0.5, top);
    p.lineTo(cx - w * 0.03, top);
    p.lineTo(cx - w * 0.04, bot);
    p.lineTo(cx - hipW * 0.75, bot);
    p.close();
    return p;
  }

  Path _sideShouldersPath(double w, double h, double cx) {
    final d = w * 0.16;
    return Path()
      ..moveTo(cx - d * 0.1, h * 0.14)
      ..lineTo(cx + d * 0.6, h * 0.14)
      ..lineTo(cx + d * 0.6, h * 0.21)
      ..lineTo(cx - d * 0.1, h * 0.21)
      ..close();
  }

  Path _sideChestPath(double w, double h, double cx) {
    final d = w * 0.16;
    return Path()
      ..moveTo(cx + d * 0.1, h * 0.2)
      ..quadraticBezierTo(cx + d * 0.9, h * 0.22, cx + d * 0.7, h * 0.3)
      ..lineTo(cx + d * 0.1, h * 0.3)
      ..close();
  }

  Path _sideTricepsPath(double w, double h, double cx) {
    final d = w * 0.16;
    return Path()
      ..moveTo(cx + d * 0.5, h * 0.2)
      ..lineTo(cx + d * 0.5 + w * 0.05, h * 0.2)
      ..lineTo(cx + d * 0.45 + w * 0.05, h * 0.36)
      ..lineTo(cx + d * 0.45, h * 0.36)
      ..close();
  }

  Path _sideCorePath(double w, double h, double cx) {
    final d = w * 0.16;
    return Path()
      ..moveTo(cx - d * 0.05, h * 0.32)
      ..lineTo(cx + d * 0.7, h * 0.32)
      ..lineTo(cx + d * 0.6, h * 0.48)
      ..lineTo(cx - d * 0.03, h * 0.48)
      ..close();
  }

  Path _sideAbsPath(double w, double h, double cx) {
    final d = w * 0.16;
    return Path()
      ..moveTo(cx + d * 0.3, h * 0.32)
      ..lineTo(cx + d * 0.35, h * 0.32)
      ..lineTo(cx + d * 0.3, h * 0.48)
      ..lineTo(cx + d * 0.25, h * 0.48)
      ..close();
  }

  Path _backPath(double w, double h, double cx) {
    final y = h * 0.2;
    return Path()
      ..moveTo(cx - w * 0.18, y)
      ..lineTo(cx + w * 0.18, y)
      ..lineTo(cx + w * 0.18, y + h * 0.18)
      ..lineTo(cx - w * 0.18, y + h * 0.18)
      ..close();
  }

  Path _trapsPath(double w, double h, double cx) {
    final y = h * 0.15;
    return Path()
      ..moveTo(cx - w * 0.12, y)
      ..lineTo(cx + w * 0.12, y)
      ..lineTo(cx + w * 0.18, y + h * 0.06)
      ..lineTo(cx - w * 0.18, y + h * 0.06)
      ..close();
  }

  Path _latsPath(double w, double h, double cx) {
    final y = h * 0.25;
    return Path()
      ..moveTo(cx - w * 0.22, y)
      ..lineTo(cx - w * 0.04, y)
      ..lineTo(cx - w * 0.06, y + h * 0.14)
      ..lineTo(cx - w * 0.24, y + h * 0.12)
      ..close();
  }

  Path _backTricepsPath(double w, double h, double cx) {
    final sw = w * 0.38;
    return Path()
      ..moveTo(cx - sw - w * 0.04, h * 0.2)
      ..lineTo(cx - sw + w * 0.0, h * 0.2)
      ..lineTo(cx - sw - w * 0.02, h * 0.36)
      ..lineTo(cx - sw - w * 0.08, h * 0.36)
      ..close();
  }

  Path _backHamstringsPath(double w, double h, double cx) {
    final hipW = w * 0.22;
    return Path()
      ..moveTo(cx - hipW * 0.5, h * 0.58)
      ..lineTo(cx - w * 0.03, h * 0.58)
      ..lineTo(cx - w * 0.04, h * 0.88)
      ..lineTo(cx - hipW * 0.75, h * 0.88)
      ..close();
  }

  // ── Detail Lines ───────────────────────────────────────────

  void _drawFrontDetails(Canvas canvas, double w, double h, double cx) {
    final linePaint = Paint()
      ..color = _outline.withValues(alpha: 0.4)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Pec separation
    canvas.drawLine(Offset(cx, h * 0.19), Offset(cx, h * 0.27), linePaint);
    // Ab lines
    for (double y = h * 0.36; y < h * 0.52; y += h * 0.04) {
      canvas.drawLine(Offset(cx - w * 0.08, y), Offset(cx + w * 0.08, y), linePaint);
    }
    // Inner pec lines
    canvas.drawLine(Offset(cx - w * 0.02, h * 0.22), Offset(cx - w * 0.16, h * 0.24), linePaint);
    canvas.drawLine(Offset(cx + w * 0.02, h * 0.22), Offset(cx + w * 0.16, h * 0.24), linePaint);
  }

  void _drawBackDetails(Canvas canvas, double w, double h, double cx) {
    final linePaint = Paint()
      ..color = _outline.withValues(alpha: 0.4)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Spine
    canvas.drawLine(Offset(cx, h * 0.16), Offset(cx, h * 0.52), linePaint);
    // Trap lines
    canvas.drawLine(Offset(cx - w * 0.12, h * 0.17), Offset(cx, h * 0.22), linePaint);
    canvas.drawLine(Offset(cx + w * 0.12, h * 0.17), Offset(cx, h * 0.22), linePaint);
    // Lat lines
    canvas.drawLine(Offset(cx - w * 0.18, h * 0.28), Offset(cx - w * 0.06, h * 0.36), linePaint);
    canvas.drawLine(Offset(cx + w * 0.18, h * 0.28), Offset(cx + w * 0.06, h * 0.36), linePaint);
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) {
    return old.activeMuscles != activeMuscles ||
        old.viewIndex != viewIndex ||
        old.accentColor != accentColor;
  }
}
