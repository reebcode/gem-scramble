import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/events.dart';

class LetterTile extends PositionComponent with HasGameReference, TapCallbacks {
  final String letter;
  final VoidCallback? onTap;

  bool _isSelected = false;
  bool _isGlowing = false;

  bool get isSelected => _isSelected;

  LetterTile({
    required this.letter,
    required Vector2 position,
    required Vector2 size,
    this.onTap,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _setupTile();
  }

  void _setupTile() {
    // Add background rectangle
    final background = RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF2A2A2A),
    );
    add(background);

    // Add border
    final border = RectangleComponent(
      size: size,
      paint: Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    add(border);

    // Add letter text
    final textComponent = TextComponent(
      text: letter.toUpperCase(),
      position: size / 2,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(textComponent);
  }

  void select() {
    if (_isSelected) return;

    _isSelected = true;
    _startGlowEffect();
    _startScaleEffect();
  }

  void deselect() {
    if (!_isSelected) return;

    _isSelected = false;
    _stopGlowEffect();
    _startScaleEffect(reverse: true);
  }

  void _startGlowEffect() {
    if (_isGlowing) return;

    _isGlowing = true;
    final glowEffect = ColorEffect(
      const Color(0xFFFFD700),
      EffectController(
        duration: 0.5,
        infinite: true,
        alternate: true,
      ),
    );

    children.whereType<RectangleComponent>().first.add(glowEffect);
  }

  void _stopGlowEffect() {
    _isGlowing = false;
    final background = children.whereType<RectangleComponent>().first;
    background.removeWhere((component) => component is ColorEffect);
    background.paint.color = const Color(0xFF2A2A2A);
  }

  void _startScaleEffect({bool reverse = false}) {
    final scaleEffect = ScaleEffect.by(
      Vector2.all(reverse ? 0.9 : 1.1),
      CurvedEffectController(0.15, Curves.easeInOut),
    );

    add(scaleEffect);
  }

  void highlight() {
    final highlightEffect = ColorEffect(
      Colors.green,
      EffectController(
        duration: 0.3,
        infinite: true,
        alternate: true,
      ),
    );

    children.whereType<RectangleComponent>().first.add(highlightEffect);

    // Remove highlight after animation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (isMounted) {
        children
            .whereType<RectangleComponent>()
            .first
            .removeWhere((component) => component is ColorEffect);
        children.whereType<RectangleComponent>().first.paint.color =
            _isSelected ? const Color(0xFFFFD700) : const Color(0xFF2A2A2A);
      }
    });
  }

  void shake() {
    final shakeEffect = MoveEffect.by(
      Vector2(5, 0),
      CurvedEffectController(0.1, Curves.elasticIn),
    );

    add(shakeEffect);

    // Return to original position
    Future.delayed(const Duration(milliseconds: 100), () {
      if (isMounted) {
        add(MoveEffect.by(
          Vector2(-5, 0),
          CurvedEffectController(0.1, Curves.elasticOut),
        ));
      }
    });
  }

  void flyTo(Vector2 targetPosition, VoidCallback? onComplete) {
    final flyEffect = MoveToEffect(
      targetPosition,
      CurvedEffectController(0.5, Curves.easeInOut),
    );

    add(flyEffect);

    if (onComplete != null) {
      Future.delayed(const Duration(milliseconds: 500), onComplete);
    }
  }

  void explode() {
    // Create particle effect
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2) / 8;
      final velocity = Vector2(math.cos(angle), math.sin(angle)) * 100;

      final particle = RectangleComponent(
        size: Vector2.all(4),
        position: size / 2,
        paint: Paint()..color = const Color(0xFFFFD700),
      );

      add(particle);

      final moveEffect = MoveEffect.by(
        velocity,
        CurvedEffectController(0.3, Curves.easeOut),
      );

      // Remove fade effect to avoid OpacityProvider requirement
      // final fadeEffect = OpacityEffect.fadeOut(
      //   CurvedEffectController(0.3, Curves.easeOut),
      // );

      particle.add(moveEffect);
      // particle.add(fadeEffect);

      // Remove particle after animation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (particle.isMounted) {
          particle.removeFromParent();
        }
      });
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    onTap?.call();
  }
}
