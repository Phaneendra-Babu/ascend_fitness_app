/// Painters for the Ascend brand mark — the shield crest used on the splash
/// screen and the stylized "A" used for the app icon.
///
/// Both are drawn purely in code (no image assets) so they stay crisp at any
/// size and can react to the theme's accent color.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Ascend shield crest: an ornate pointed shield with a sword through it,
/// radial energy lines, and a glowing halo. The [glow] value (0–1) drives the
/// halo intensity so the splash can pulse it.
class ShieldCrestPainter extends CustomPainter {
  final Color accent;
  final double glow;

  const ShieldCrestPainter({required this.accent, this.glow = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // ── Halo ─────────────────────────────────────────────────────
    final haloRadius = size.shortestSide * 0.75;
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.35 * glow),
            accent.withValues(alpha: 0.12 * glow),
            accent.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    // ── Energy lines (radial strokes around the shield) ──────────
    final inner = Offset(w / 2, h * 0.46);
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.45 * glow)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * (3.14159 * 2 / 12) + 0.3;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        inner + dir * size.shortestSide * 0.42,
        inner + dir * size.shortestSide * 0.56,
        linePaint,
      );
    }

    // ── Shield outline ────────────────────────────────────────────
    final shieldPath = _shieldPath(size);
    canvas.drawPath(
      shieldPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );
    // Inner plate (subtle fill)
    canvas.drawPath(
      shieldPath,
      Paint()..color = accent.withValues(alpha: 0.06),
    );

    // ── Sword through the shield ──────────────────────────────────
    _paintSword(canvas, size, accent, glow);

    // ── Glow on the shield rim ────────────────────────────────────
    canvas.drawPath(
      shieldPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: 0.25 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  /// The shield silhouette: flat top, slightly flared shoulders, tapered sides
  /// meeting at a point at the bottom.
  Path _shieldPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    // Top edge (left → right), with small corner notches.
    path.moveTo(w * 0.22, h * 0.24);
    path.lineTo(w * 0.78, h * 0.24);
    path.lineTo(w * 0.86, h * 0.30);
    // Right side curving down to the bottom point.
    path.cubicTo(w * 0.88, h * 0.46, w * 0.78, h * 0.66, w * 0.62, h * 0.80);
    path.cubicTo(w * 0.55, h * 0.88, w * 0.45, h * 0.88, w * 0.38, h * 0.80);
    path.cubicTo(w * 0.22, h * 0.66, w * 0.12, h * 0.46, w * 0.14, h * 0.30);
    path.lineTo(w * 0.22, h * 0.24);
    path.close();
    return path;
  }

  void _paintSword(Canvas canvas, Size size, Color accent, double glow) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Blade (vertical, above the crossguard).
    final bladeTop = h * 0.10;
    final crossY = h * 0.52;
    final blade = Path()
      ..moveTo(cx - w * 0.045, bladeTop)
      ..lineTo(cx + w * 0.045, bladeTop)
      ..lineTo(cx + w * 0.016, crossY)
      ..lineTo(cx - w * 0.016, crossY)
      ..close();
    canvas.drawPath(
      blade,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85 + 0.15 * glow),
    );
    canvas.drawPath(
      blade,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.9),
    );

    // Crossguard.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - w * 0.16, crossY - h * 0.012, cx + w * 0.16, crossY + h * 0.012),
        Radius.circular(h * 0.012),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

    // Blade tip glow.
    canvas.drawCircle(
      Offset(cx, bladeTop),
      w * 0.05,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.5 * glow),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, bladeTop), radius: w * 0.2)),
    );
  }

  @override
  bool shouldRepaint(covariant ShieldCrestPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.glow != glow;
}

/// The app-icon mark: a bold, stylized "A" — wide triangular form with a
/// horizontal crossbar — rendered white/silver on a dark navy field with a
/// soft blue edge glow. Used to generate the Android launcher icons.
class AscendLogoPainter extends CustomPainter {
  final Color accent;
  final Color fieldColor;
  final Color letterColor;

  const AscendLogoPainter({
    this.accent = const Color(0xFF38BDF8),
    this.fieldColor = const Color(0xFF0F172A),
    this.letterColor = const Color(0xFFE2E8F0),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // ── Dark navy rounded field ───────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.18)),
      Paint()..color = fieldColor,
    );

    // ── Blue radial glow behind the "A" ───────────────────────────
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: size.shortestSide * 0.42)),
    );

    // ── Stylized "A" ──────────────────────────────────────────────
    // Draw slightly dark-edged strokes first (outline) then the silver fill.
    final aPath = _letterAPath(size);

    // Soft accent under-glow.
    canvas.drawPath(
      aPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.05
        ..color = accent.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Main letter.
    canvas.drawPath(aPath, Paint()..color = letterColor);

    // Metallic edge hint.
    canvas.drawPath(
      aPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  /// Bold triangular "A" with a horizontal crossbar, centered with padding.
  Path _letterAPath(Size size) {
    final pad = size.shortestSide * 0.18;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final left = pad;
    final top = pad;
    final cx = size.width / 2;

    final path = Path();
    // Apex.
    path.moveTo(cx, top);
    // Right leg (down-out).
    path.lineTo(left + w, top + h);
    // Right foot.
    path.lineTo(cx + w * 0.30, top + h);
    // Crossbar bottom-right.
    path.lineTo(cx + w * 0.13, top + h * 0.62);
    // Crossbar bottom-left.
    path.lineTo(cx - w * 0.13, top + h * 0.62);
    // Left foot.
    path.lineTo(cx - w * 0.30, top + h);
    // Left leg (up-in).
    path.lineTo(left, top + h);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant AscendLogoPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.fieldColor != fieldColor ||
      oldDelegate.letterColor != letterColor;
}

/// Small convenience: a full-screen particle layer for the splash. The
/// particles drift upward and are recycled by the splash's ticker. Pass the
/// ticker as [repaint] so mutating the particle list triggers redraws.
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color accent;

  ParticlePainter({
    required this.particles,
    required this.accent,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.r,
        Paint()..color = accent.withValues(alpha: p.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) =>
      oldDelegate.particles != particles;
}

/// One floating particle's state. Coordinates are normalized (0–1) so the
/// layer is resolution-independent. Fields are mutable — the splash animates
/// them in place and drives repaints via the painter's `repaint` listenable.
class Particle {
  double x;
  double y;
  double r;
  double opacity;
  double speed; // normalized upward speed per tick

  Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.opacity,
    required this.speed,
  });
}
