import 'dart:math';
import 'package:flutter/material.dart';

/// A glowing flame-shaped indicator with pulsing animation.
/// Used for streaks, level badges, and achievement icons.
class FlameGlow extends StatefulWidget {
  final Color color;
  final double size;
  final Widget child;
  final bool animate;

  const FlameGlow({
    super.key,
    required this.color,
    this.size = 40,
    required this.child,
    this.animate = true,
  });

  @override
  State<FlameGlow> createState() => _FlameGlowState();
}

class _FlameGlowState extends State<FlameGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: _glowAnimation.value * 0.6,
                ),
                blurRadius: widget.size * 0.4,
                spreadRadius: widget.size * 0.1,
              ),
              BoxShadow(
                color: widget.color.withValues(
                  alpha: _glowAnimation.value * 0.3,
                ),
                blurRadius: widget.size * 0.8,
                spreadRadius: widget.size * 0.2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Floating ember/spark particles that rise upward.
/// Use as a decorative overlay on dark mode cards or buttons.
class EmberParticles extends StatefulWidget {
  final Color color;
  final int particleCount;
  final double width;
  final double height;

  const EmberParticles({
    super.key,
    this.color = const Color(0xFFF97316),
    this.particleCount = 12,
    this.width = 200,
    this.height = 100,
  });

  @override
  State<EmberParticles> createState() => _EmberParticlesState();
}

class _EmberParticlesState extends State<EmberParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(widget.particleCount, (_) => _createParticle());
    _controller = AnimationController(
      duration: const Duration(milliseconds: 60),
      vsync: this,
    )..addListener(_tick);
    _controller.repeat();
  }

  _Particle _createParticle() {
    return _Particle(
      x: _random.nextDouble() * widget.width,
      y: widget.height + _random.nextDouble() * 20,
      speed: 0.3 + _random.nextDouble() * 0.8,
      size: 1.5 + _random.nextDouble() * 2.5,
      opacity: 0.4 + _random.nextDouble() * 0.6,
      drift: (_random.nextDouble() - 0.5) * 0.5,
    );
  }

  void _tick() {
    setState(() {
      for (var p in _particles) {
        p.y -= p.speed;
        p.x += p.drift;
        p.opacity -= 0.003;
        if (p.y < -10 || p.opacity <= 0) {
          final np = _createParticle();
          p.x = np.x;
          p.y = np.y;
          p.speed = np.speed;
          p.size = np.size;
          p.opacity = np.opacity;
          p.drift = np.drift;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: _EmberPainter(
          particles: _particles,
          color: widget.color,
        ),
      ),
    );
  }
}

class _Particle {
  double x, y, speed, size, opacity, drift;
  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.drift,
  });
}

class _EmberPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;

  _EmberPainter({required this.particles, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = color.withValues(alpha: p.opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// A button with animated flame shimmer and ember particles.
/// The signature CTA button for ASCEND's dark themes.
class FlameButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final Color? secondaryColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const FlameButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color = const Color(0xFF7C3AED),
    this.secondaryColor,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  });

  @override
  State<FlameButton> createState() => _FlameButtonState();
}

class _FlameButtonState extends State<FlameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sec = widget.secondaryColor ??
        widget.color.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                colors: [
                  widget.color,
                  sec,
                  widget.color,
                  sec,
                ],
                stops: [
                  (_shimmerAnimation.value - 0.5).clamp(0.0, 1.0),
                  (_shimmerAnimation.value).clamp(0.0, 1.0),
                  (_shimmerAnimation.value + 0.5).clamp(0.0, 1.0),
                  (_shimmerAnimation.value + 1.0).clamp(0.0, 1.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                onTap: widget.onPressed,
                child: Padding(
                  padding: widget.padding,
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    child: Center(child: widget.child),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pulsing glow ring around profile pictures or badges.
/// Pulses between subtle and bright glow in the mode's accent color.
class GlowRing extends StatefulWidget {
  final Color color;
  final double strokeWidth;
  final double glowRadius;
  final Widget child;

  const GlowRing({
    super.key,
    required this.color,
    this.strokeWidth = 3,
    this.glowRadius = 8,
    required this.child,
  });

  @override
  State<GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<GlowRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = 0.3 + (_controller.value * 0.5);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glow),
                blurRadius: widget.glowRadius + (_controller.value * 6),
                spreadRadius: _controller.value * 3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
