import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class CoinFly extends PositionComponent {
  final Vector2 targetPosition;
  final int value;
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  CoinFly({
    required Vector2 startPosition,
    required this.targetPosition,
    required this.value,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
  }) : super(position: startPosition);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createCoin();
    _animateFlight();
  }

  void _createCoin() {
    // Create coin body
    final coinBody = CircleComponent(
      radius: 15,
      paint: Paint()..color = color,
    );
    add(coinBody);

    // Add coin shine effect
    final shine = CircleComponent(
      radius: 8,
      position: Vector2(-5, -5),
      paint: Paint()..color = Colors.white.withAlpha((255 * 0.6).round()),
    );
    add(shine);

    // Add value text
    final valueText = TextComponent(
      text: value.toString(),
      position: Vector2(15, 15),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(valueText);
  }

  void _animateFlight() {
    // Calculate flight path with arc
    final endPos = targetPosition.clone();

    // Add movement along arc
    final moveEffect = MoveToEffect(
      endPos,
      CurvedEffectController(
          duration.inMilliseconds / 1000.0, Curves.easeInOut),
    );

    add(moveEffect);

    // Add rotation effect
    final rotationEffect = RotateEffect.by(
      math.pi * 4, // 2 full rotations
      EffectController(duration: duration.inMilliseconds / 1000.0),
    );

    add(rotationEffect);

    // Add scale effect
    final scaleEffect = ScaleEffect.by(
      Vector2.all(0.5),
      CurvedEffectController(duration.inMilliseconds / 1000.0, Curves.easeIn),
    );

    add(scaleEffect);

    // Add fade out effect - remove to avoid OpacityProvider requirement
    // final fadeEffect = OpacityEffect.fadeOut(
    //   CurvedEffectController(
    //       (duration.inMilliseconds * 0.3).round() / 1000.0, Curves.easeOut),
    // );
    // add(fadeEffect);

    // Call completion callback
    Future.delayed(duration, () {
      if (isMounted) {
        removeFromParent();
        onComplete?.call();
      }
    });
  }
}

class CoinFlyManager extends Component {
  final List<CoinFly> _activeCoins = [];

  void createCoinFly({
    required Vector2 startPosition,
    required Vector2 targetPosition,
    required int value,
    Color color = const Color(0xFFFFD700),
    Duration duration = const Duration(milliseconds: 800),
    VoidCallback? onComplete,
  }) {
    final coin = CoinFly(
      startPosition: startPosition,
      targetPosition: targetPosition,
      value: value,
      color: color,
      duration: duration,
      onComplete: onComplete,
    );

    _activeCoins.add(coin);
    add(coin);

    // Clean up completed coins
    Future.delayed(duration, () {
      _activeCoins.remove(coin);
    });
  }

  void createMultipleCoins({
    required Vector2 startPosition,
    required Vector2 targetPosition,
    required int totalValue,
    int coinCount = 5,
    Color color = const Color(0xFFFFD700),
    Duration duration = const Duration(milliseconds: 800),
    VoidCallback? onComplete,
  }) {
    final valuePerCoin = totalValue ~/ coinCount;
    final remainingValue = totalValue % coinCount;

    for (int i = 0; i < coinCount; i++) {
      final coinValue = valuePerCoin + (i < remainingValue ? 1 : 0);
      final offset = Vector2(
        (math.Random().nextDouble() - 0.5) * 100,
        (math.Random().nextDouble() - 0.5) * 100,
      );

      final coinStartPos = startPosition + offset;
      final coinTargetPos = targetPosition +
          Vector2(
            (math.Random().nextDouble() - 0.5) * 20,
            (math.Random().nextDouble() - 0.5) * 20,
          );

      final delay = Duration(milliseconds: i * 100);

      Future.delayed(delay, () {
        createCoinFly(
          startPosition: coinStartPos,
          targetPosition: coinTargetPos,
          value: coinValue,
          color: color,
          duration: duration,
          onComplete: i == coinCount - 1 ? onComplete : null,
        );
      });
    }
  }

  void clearAllCoins() {
    for (final coin in _activeCoins) {
      coin.removeFromParent();
    }
    _activeCoins.clear();
  }

  int get activeCoinCount => _activeCoins.length;
}

class ScoreFly extends PositionComponent {
  final int score;
  final Color color;
  final Duration duration;

  ScoreFly({
    required Vector2 position,
    required this.score,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 1000),
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createScoreDisplay();
    _animateScore();
  }

  void _createScoreDisplay() {
    // Create score background
    final background = RectangleComponent(
      size: Vector2(80, 40),
      paint: Paint()..color = color.withAlpha((255 * 0.9).round()),
    );
    add(background);

    // Add score text
    final scoreText = TextComponent(
      text: '+$score',
      position: Vector2(40, 20),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(scoreText);
  }

  void _animateScore() {
    // Add floating animation
    final floatEffect = MoveEffect.by(
      Vector2(0, -80),
      CurvedEffectController(duration.inMilliseconds / 1000.0, Curves.easeOut),
    );

    add(floatEffect);

    // Add scale effect
    final scaleEffect = ScaleEffect.by(
      Vector2.all(1.2),
      CurvedEffectController(
          (duration.inMilliseconds / 2) / 1000.0, Curves.easeOut),
    );

    add(scaleEffect);

    // Add fade out effect - remove to avoid OpacityProvider requirement
    // final fadeEffect = OpacityEffect.fadeOut(
    //   CurvedEffectController(
    //       (duration.inMilliseconds * 0.7).round() / 1000.0, Curves.easeOut),
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

class WordScoreFly extends PositionComponent {
  final String word;
  final int score;
  final Color color;
  final Duration duration;

  WordScoreFly({
    required Vector2 position,
    required this.word,
    required this.score,
    this.color = const Color(0xFFFFD700),
    this.duration = const Duration(milliseconds: 1200),
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createWordScoreDisplay();
    _animateWordScore();
  }

  void _createWordScoreDisplay() {
    // Create background
    final background = RectangleComponent(
      size: Vector2(120, 60),
      paint: Paint()..color = color.withAlpha((255 * 0.9).round()),
    );
    add(background);

    // Add word text
    final wordText = TextComponent(
      text: word.toUpperCase(),
      position: Vector2(60, 20),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(wordText);

    // Add score text
    final scoreText = TextComponent(
      text: '+$score',
      position: Vector2(60, 40),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(scoreText);
  }

  void _animateWordScore() {
    // Add floating animation
    final floatEffect = MoveEffect.by(
      Vector2(0, -100),
      CurvedEffectController(duration.inMilliseconds / 1000.0, Curves.easeOut),
    );

    add(floatEffect);

    // Add rotation effect
    final rotationEffect = RotateEffect.by(
      math.pi * 0.1,
      CurvedEffectController(
          duration.inMilliseconds / 1000.0, Curves.easeInOut),
    );

    add(rotationEffect);

    // Add scale effect
    final scaleEffect = ScaleEffect.by(
      Vector2.all(1.3),
      CurvedEffectController(
          (duration.inMilliseconds / 2) / 1000.0, Curves.easeOut),
    );

    add(scaleEffect);

    // Add fade out effect - remove to avoid OpacityProvider requirement
    // final fadeEffect = OpacityEffect.fadeOut(
    //   CurvedEffectController(
    //       (duration.inMilliseconds * 0.6).round() / 1000.0, Curves.easeOut),
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
