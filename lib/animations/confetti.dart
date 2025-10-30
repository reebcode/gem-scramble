import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class Confetti extends PositionComponent {
  final Color color;
  final Vector2 velocity;
  final Duration duration;
  final double rotationSpeed;
  double _opacity = 1.0;

  Confetti({
    required Vector2 position,
    required this.color,
    required this.velocity,
    this.duration = const Duration(milliseconds: 2000),
    this.rotationSpeed = 2.0,
  }) : super(position: position);

  double get opacity => _opacity;
  set opacity(double value) {
    _opacity = value.clamp(0.0, 1.0);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createConfettiPiece();
    _animateConfetti();
  }

  void _createConfettiPiece() {
    // Create confetti shape (random rectangle)
    final width = 4 + math.Random().nextDouble() * 8;
    final height = 8 + math.Random().nextDouble() * 12;

    final confettiPiece = RectangleComponent(
      size: Vector2(width, height),
      paint: Paint()..color = color.withAlpha((255 * _opacity).round()),
    );

    add(confettiPiece);
  }

  void _animateConfetti() {
    // Add movement effect
    final moveEffect = MoveEffect.by(
      velocity,
      CurvedEffectController(duration.inMilliseconds / 1000.0, Curves.easeOut),
    );

    add(moveEffect);

    // Add rotation effect
    final rotationEffect = RotateEffect.by(
      math.pi * rotationSpeed,
      EffectController(duration: duration.inMilliseconds / 1000.0),
    );

    add(rotationEffect);

    // Add gravity effect (simulate falling)
    final gravityEffect = MoveEffect.by(
      Vector2(0, 200),
      CurvedEffectController(duration.inMilliseconds / 1000.0, Curves.easeIn),
    );

    add(gravityEffect);

    // Add fade out effect
    final fadeEffect = _CustomOpacityEffect.fadeOut(
      CurvedEffectController(
          (duration.inMilliseconds * 0.8).round() / 1000.0, Curves.easeOut),
    );

    add(fadeEffect);

    // Remove after animation
    Future.delayed(duration, () {
      if (isMounted) {
        removeFromParent();
      }
    });
  }
}

class ConfettiExplosion extends PositionComponent {
  final Vector2 centerPosition;
  final int particleCount;
  final List<Color> colors;
  final Duration duration;

  ConfettiExplosion({
    required this.centerPosition,
    this.particleCount = 50,
    this.colors = const [
      Color(0xFFFFD700),
      Color(0xFFFF6B6B),
      Color(0xFF4ECDC4),
      Color(0xFF45B7D1),
      Color(0xFF96CEB4),
      Color(0xFFFECA57),
    ],
    this.duration = const Duration(milliseconds: 2000),
  }) : super(position: centerPosition);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createConfettiExplosion();
  }

  void _createConfettiExplosion() {
    final random = math.Random();

    for (int i = 0; i < particleCount; i++) {
      final color = colors[random.nextInt(colors.length)];
      final angle = (random.nextDouble() * 2 * math.pi);
      final speed = 100 + random.nextDouble() * 200;

      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 100, // Add upward bias
      );

      final confetti = Confetti(
        position: Vector2.zero(),
        color: color,
        velocity: velocity,
        duration: duration,
        rotationSpeed: 1 + random.nextDouble() * 3,
      );

      add(confetti);
    }
  }
}

class ConfettiManager extends Component {
  final List<ConfettiExplosion> _activeExplosions = [];

  void createExplosion({
    required Vector2 position,
    int particleCount = 50,
    List<Color>? colors,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    final explosion = ConfettiExplosion(
      centerPosition: position,
      particleCount: particleCount,
      colors: colors ??
          const [
            Color(0xFFFFD700),
            Color(0xFFFF6B6B),
            Color(0xFF4ECDC4),
            Color(0xFF45B7D1),
            Color(0xFF96CEB4),
            Color(0xFFFECA57),
          ],
      duration: duration,
    );

    _activeExplosions.add(explosion);
    add(explosion);

    // Clean up completed explosions
    Future.delayed(duration, () {
      _activeExplosions.remove(explosion);
    });
  }

  void createVictoryExplosion(Vector2 position) {
    createExplosion(
      position: position,
      particleCount: 100,
      colors: const [
        Color(0xFFFFD700), // Gold
        Color(0xFFFFA500), // Orange
        Color(0xFFFF6B6B), // Red
        Color(0xFF4ECDC4), // Teal
        Color(0xFF45B7D1), // Blue
        Color(0xFF96CEB4), // Green
        Color(0xFFFECA57), // Yellow
        Color(0xFFFF9FF3), // Pink
      ],
      duration: const Duration(milliseconds: 3000),
    );
  }

  void createWordExplosion(Vector2 position) {
    createExplosion(
      position: position,
      particleCount: 30,
      colors: const [
        Color(0xFFFFD700),
        Color(0xFFFFA500),
        Color(0xFFFF6B6B),
      ],
      duration: const Duration(milliseconds: 1500),
    );
  }

  void createScoreExplosion(Vector2 position) {
    createExplosion(
      position: position,
      particleCount: 20,
      colors: const [
        Color(0xFFFFD700),
        Color(0xFFFFA500),
      ],
      duration: const Duration(milliseconds: 1000),
    );
  }

  void clearAllExplosions() {
    for (final explosion in _activeExplosions) {
      explosion.removeFromParent();
    }
    _activeExplosions.clear();
  }

  int get activeExplosionCount => _activeExplosions.length;
}

class Fireworks extends PositionComponent {
  final Color color;
  final Duration duration;

  Fireworks({
    required Vector2 position,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 1500),
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createFireworks();
  }

  void _createFireworks() {
    // Create multiple bursts
    for (int burst = 0; burst < 3; burst++) {
      Future.delayed(Duration(milliseconds: burst * 200), () {
        _createBurst(burst);
      });
    }
  }

  void _createBurst(int burstIndex) {
    final random = math.Random();
    final particleCount = 20 + random.nextInt(20);

    for (int i = 0; i < particleCount; i++) {
      final angle = (random.nextDouble() * 2 * math.pi);
      final speed = 50 + random.nextDouble() * 150;

      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );

      final particle = _OpacityCircleComponent(
        radius: 2 + random.nextDouble() * 4,
        paint: Paint()..color = color,
      );

      add(particle);

      // Add movement effect
      final moveEffect = MoveEffect.by(
        velocity,
        CurvedEffectController(
            (800 + random.nextInt(400)) / 1000.0, Curves.easeOut),
      );

      particle.add(moveEffect);

      // Add fade out effect - skip for now to avoid complexity
      // final fadeEffect = OpacityEffect.fadeOut(
      //   CurvedEffectController(
      //       (600 + random.nextInt(300)) / 1000.0, Curves.easeOut),
      // );

      // particle.add(fadeEffect);

      // Remove particle after animation
      Future.delayed(Duration(milliseconds: 1000 + random.nextInt(500)), () {
        if (particle.isMounted) {
          particle.removeFromParent();
        }
      });
    }
  }
}

class Sparkle extends PositionComponent {
  final Color color;
  final Duration duration;

  Sparkle({
    required Vector2 position,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 1000),
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createSparkle();
  }

  void _createSparkle() {
    // Create sparkle shape (star-like)
    final sparkle = StarComponent(
      radius: 8,
      starPaint: Paint()..color = color,
    );

    add(sparkle);

    // Add pulsing effect
    final pulseEffect = ScaleEffect.by(
      Vector2.all(1.5),
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
        alternate: true,
      ),
    );

    add(pulseEffect);

    // Add rotation effect
    final rotationEffect = RotateEffect.by(
      math.pi * 2,
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
      ),
    );

    add(rotationEffect);

    // Add fade out effect - skip for now to avoid complexity
    // final fadeEffect = OpacityEffect.fadeOut(
    //   CurvedEffectController(
    //       (duration.inMilliseconds * 0.8).round() / 1000.0, Curves.easeOut),
    // );

    // add(fadeEffect);

    // Remove after animation
    Future.delayed(duration, () {
      if (isMounted) {
        removeFromParent();
      }
    });
  }
}

class StarComponent extends PositionComponent {
  final double radius;
  final Paint starPaint;

  StarComponent({required this.radius, required this.starPaint});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = size / 2;
    final outerRadius = radius;
    final innerRadius = radius * 0.4;

    final path = Path();

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final outerX = center.x + math.cos(angle) * outerRadius;
      final outerY = center.y + math.sin(angle) * outerRadius;
      final innerX = center.x + math.cos(angle + math.pi / 5) * innerRadius;
      final innerY = center.y + math.sin(angle + math.pi / 5) * innerRadius;

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }

    path.close();
    canvas.drawPath(path, starPaint);
  }
}

class _OpacityCircleComponent extends CircleComponent {
  _OpacityCircleComponent({
    required double radius,
    required Paint paint,
  }) : super(radius: radius, paint: paint);
}

class _CustomOpacityEffect extends Effect {
  final double _startOpacity;
  final double _endOpacity;

  _CustomOpacityEffect._({
    required double startOpacity,
    required double endOpacity,
    required EffectController controller,
  })  : _startOpacity = startOpacity,
        _endOpacity = endOpacity,
        super(controller);

  factory _CustomOpacityEffect.fadeOut(EffectController controller) {
    return _CustomOpacityEffect._(
      startOpacity: 1.0,
      endOpacity: 0.0,
      controller: controller,
    );
  }

  @override
  void apply(double progress) {
    if (parent is Confetti) {
      final confetti = parent as Confetti;
      confetti.opacity =
          _startOpacity + (_endOpacity - _startOpacity) * progress;
    }
  }
}
