import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ascend_logo_painter.dart';

/// Branded "Solo Leveling" style loading screen shown on app start.
///
/// A pulsing shield crest over rotating magic rings, drifting particles, and
/// an animated "Initializing Hunter System..." progress bar — then hands off
/// to the app via [onComplete].
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────
  late final AnimationController _fadeCtrl; // entry fade (one-shot)
  late final AnimationController _pulseCtrl; // crest pulse (loop)
  late final AnimationController _ringCtrl; // magic circle (loop)
  late final AnimationController _particleCtrl; // particle ticker (loop)
  late final AnimationController _progressCtrl; // progress fill (one-shot)

  late final Animation<double> _fade;

  final List<Particle> _particles = [];
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _initParticles();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
      lowerBound: 0,
      upperBound: 2 * math.pi,
    )..repeat();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
    _particleCtrl.addListener(_advanceParticles);

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Small pause on a full bar, then hand off.
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) widget.onComplete();
        });
      }
    });
    _progressCtrl.forward();
  }

  void _initParticles() {
    for (var i = 0; i < 22; i++) {
      _particles.add(Particle(
        x: _rng.nextDouble(),
        y: 0.1 + _rng.nextDouble(),
        r: 1.0 + _rng.nextDouble() * 1.8,
        opacity: 0.12 + _rng.nextDouble() * 0.4,
        speed: 0.0012 + _rng.nextDouble() * 0.0018,
      ));
    }
  }

  void _advanceParticles() {
    for (final p in _particles) {
      p.y -= p.speed;
      if (p.y < -0.05) {
        p.y = 1.05 + _rng.nextDouble() * 0.1;
        p.x = _rng.nextDouble();
      }
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _particleCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: Stack(
            children: [
              // Rotating magic rings behind the crest.
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (context, _) => CustomPaint(
                    painter: _MagicRingPainter(
                      angle: _ringCtrl.value,
                      accent: accent,
                    ),
                  ),
                ),
              ),

              // Crest + wordmark.
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCrest(accent),
                    const SizedBox(height: 28),
                    const Text(
                      'ASCEND',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'HUNTER FITNESS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),

              // Floating particles (topmost).
              Positioned.fill(
                child: CustomPaint(
                  painter: ParticlePainter(
                    particles: _particles,
                    accent: accent,
                    repaint: _particleCtrl,
                  ),
                ),
              ),

              // Progress bar + caption.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                    child: AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (context, _) => _buildProgress(accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrest(Color accent) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final t = _pulseCtrl.value * 2 * math.pi;
        final scale = 1.0 + 0.035 * math.sin(t);
        final glow = (0.5 + 0.45 * math.sin(t)).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: ShieldCrestPainter(accent: accent, glow: glow),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgress(Color accent) {
    final value = _progressCtrl.value;
    final percent = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: accent.withValues(alpha: 0.15)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Initializing Hunter System...',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }
}

/// Concentric dashed rings that slowly rotate — the "magic circle" behind the
/// crest.
class _MagicRingPainter extends CustomPainter {
  final double angle;
  final Color accent;

  _MagicRingPainter({required this.angle, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final radii = <double>[size.shortestSide * 0.32, size.shortestSide * 0.44];
    for (var ring = 0; ring < radii.length; ring++) {
      final r = radii[ring];
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: ring == 0 ? 0.35 : 0.22);
      // Three arcs per ring, offset by 120°.
      for (var i = 0; i < 3; i++) {
        final start = i * 2 * math.pi / 3;
        final sweep = math.pi / 3.4;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          start,
          sweep,
          false,
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MagicRingPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.accent != accent;
}
