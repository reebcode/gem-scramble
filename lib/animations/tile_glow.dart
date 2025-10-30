import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class TileGlow extends PositionComponent {
  final double intensity;
  final Color color;
  final Duration duration;

  TileGlow({
    required Vector2 position,
    required Vector2 size,
    this.intensity = 1.0,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 500),
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createGlowEffect();
  }

  void _createGlowEffect() {
    // Create multiple glow layers for depth
    for (int i = 0; i < 3; i++) {
      final glowLayer = RectangleComponent(
        size: size,
        paint: Paint()
          ..color =
              color.withAlpha((255 * 0.3 * intensity * (3 - i) / 3).round())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + i * 2),
      );

      add(glowLayer);

      // Animate the glow
      final glowEffect = ColorEffect(
        color.withAlpha(0),
        EffectController(
          duration: duration.inMilliseconds / 1000.0,
          infinite: true,
          alternate: true,
        ),
      );

      glowLayer.add(glowEffect);
    }

    // Add pulsing effect
    final pulseEffect = ScaleEffect.by(
      Vector2.all(1.2),
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
        alternate: true,
      ),
    );

    add(pulseEffect);

    // Remove after animation completes
    Future.delayed(duration * 2, () {
      if (isMounted) {
        removeFromParent();
      }
    });
  }
}

class TileGlowManager extends Component {
  final List<TileGlow> _activeGlows = [];

  void createGlow({
    required Vector2 position,
    required Vector2 size,
    double intensity = 1.0,
    Color color = const Color(0xFFFFD700),
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final glow = TileGlow(
      position: position,
      size: size,
      intensity: intensity,
      color: color,
      duration: duration,
    );

    _activeGlows.add(glow);
    add(glow);

    // Clean up completed glows
    Future.delayed(duration * 2, () {
      _activeGlows.remove(glow);
    });
  }

  void clearAllGlows() {
    for (final glow in _activeGlows) {
      glow.removeFromParent();
    }
    _activeGlows.clear();
  }

  int get activeGlowCount => _activeGlows.length;
}

class WordGlow extends PositionComponent {
  final String word;
  final Color color;
  final Duration duration;

  WordGlow({
    required Vector2 position,
    required this.word,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 1000),
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createWordGlow();
  }

  void _createWordGlow() {
    // Create text component
    final textComponent = TextComponent(
      text: word.toUpperCase(),
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: color.withAlpha((255 * 0.8).round()),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );

    add(textComponent);

    // Add glow effect
    final glowEffect = ColorEffect(
      color.withAlpha(0),
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
        alternate: true,
      ),
    );

    textComponent.add(glowEffect);

    // Add scale animation
    final scaleEffect = ScaleEffect.by(
      Vector2.all(1.3),
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
        alternate: true,
      ),
    );

    add(scaleEffect);

    // Add rotation effect
    final rotationEffect = RotateEffect.by(
      math.pi * 0.1,
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
        alternate: true,
      ),
    );

    add(rotationEffect);

    // Remove after animation
    Future.delayed(duration * 2, () {
      if (isMounted) {
        removeFromParent();
      }
    });
  }
}

class ScoreGlow extends PositionComponent {
  final int score;
  final Color color;
  final Duration duration;

  ScoreGlow({
    required Vector2 position,
    required this.score,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 800),
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createScoreGlow();
  }

  void _createScoreGlow() {
    // Create score text
    final scoreText = TextComponent(
      text: '+$score',
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: color.withAlpha((255 * 0.8).round()),
              blurRadius: 15,
            ),
          ],
        ),
      ),
    );

    add(scoreText);

    // Add floating animation
    final floatEffect = MoveEffect.by(
      Vector2(0, -50),
      CurvedEffectController(duration.inMilliseconds / 1000.0, Curves.easeOut),
    );

    add(floatEffect);

    // Add fade out effect - remove OpacityEffect to avoid OpacityProvider requirement
    // final fadeEffect = OpacityEffect.fadeOut(
    //   CurvedEffectController(duration.inMilliseconds / 1000.0, Curves.easeOut),
    // );
    // add(fadeEffect);

    // Add scale effect
    final scaleEffect = ScaleEffect.by(
      Vector2.all(1.5),
      CurvedEffectController(duration.inMilliseconds / 1000.0, Curves.easeOut),
    );

    add(scaleEffect);

    // Remove after animation
    Future.delayed(duration, () {
      if (isMounted) {
        removeFromParent();
      }
    });
  }
}

class ComboGlow extends PositionComponent {
  final int comboCount;
  final Color color;
  final Duration duration;

  ComboGlow({
    required Vector2 position,
    required this.comboCount,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 1200),
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createComboGlow();
  }

  void _createComboGlow() {
    // Create combo text
    final comboText = TextComponent(
      text: '${comboCount}x COMBO!',
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: color.withAlpha((255 * 0.8).round()),
              blurRadius: 12,
            ),
          ],
        ),
      ),
    );

    add(comboText);

    // Add pulsing effect
    final pulseEffect = ScaleEffect.by(
      Vector2.all(1.4),
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
        alternate: true,
      ),
    );

    add(pulseEffect);

    // Add color cycling effect
    final colorEffect = ColorEffect(
      Colors.red,
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
        alternate: true,
      ),
    );

    comboText.add(colorEffect);

    // Add rotation effect
    final rotationEffect = RotateEffect.by(
      math.pi * 0.2,
      EffectController(
        duration: duration.inMilliseconds / 1000.0,
        infinite: true,
        alternate: true,
      ),
    );

    add(rotationEffect);

    // Remove after animation
    Future.delayed(duration * 3, () {
      if (isMounted) {
        removeFromParent();
      }
    });
  }
}
