import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../animations/confetti.dart';

typedef CurrentWordChanged = void Function(String word);
typedef WordCompleted = void Function(String word, int score, Rect tileRect);

class ScrambleGame extends FlameGame with PanDetector {
  ScrambleGame({
    required this.board,
    required this.onCurrentWordChanged,
    required this.onWordCompleted,
  });

  final List<List<String>> board;
  final CurrentWordChanged onCurrentWordChanged;
  final WordCompleted onWordCompleted;

  final ConfettiManager confettiManager = ConfettiManager();

  late final int gridSize;
  final double outerPadding = 8;
  final double tileSpacing = 4;
  final double tileScale = 0.9;
  final double hitboxScale = 0.72;
  Rect _boardRect = Rect.zero;
  double _tileSize = 0;

  final List<math.Point<int>> _selection = <math.Point<int>>[];

  final TextPaint _letterPaint = TextPaint(
    style: const TextStyle(
      fontSize: 28,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  );

  @override
  Future<void> onLoad() async {
    gridSize = board.length;
    add(confettiManager);
  }

  @override
  void onPanStart(DragStartInfo info) {
    // Use widget-local coordinates (relative to GameWidget) for hit testing
    final wp = info.eventPosition.widget;
    final cell = _cellAtPosition(Offset(wp.x, wp.y));
    if (cell != null) {
      _selection
        ..clear()
        ..add(cell);
      onCurrentWordChanged(_currentWord);
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    // Use widget-local coordinates (relative to GameWidget)
    final wp = info.eventPosition.widget;
    final cell = _cellAtPosition(Offset(wp.x, wp.y));
    if (cell == null) return;
    if (_selection.isEmpty) {
      _selection.add(cell);
      onCurrentWordChanged(_currentWord);
      return;
    }

    var last = _selection.last;
    if (cell == last) return;

    if (_selection.length >= 2 && cell == _selection[_selection.length - 2]) {
      _selection.removeLast();
      onCurrentWordChanged(_currentWord);
      return;
    }

    int dx = cell.x - last.x;
    int dy = cell.y - last.y;
    int stepX = dx == 0 ? 0 : (dx > 0 ? 1 : -1);
    int stepY = dy == 0 ? 0 : (dy > 0 ? 1 : -1);
    if (stepX != 0 || stepY != 0) {
      // Safety guard against any unexpected infinite loops
      int safety = gridSize * gridSize;
      while (last != cell && safety-- > 0) {
        final nextX = last.x + stepX;
        final nextY = last.y + stepY;
        if (nextX < 0 || nextX >= gridSize || nextY < 0 || nextY >= gridSize) {
          break;
        }
        final next = math.Point<int>(nextX, nextY);
        if (!_selection.contains(next)) {
          _selection.add(next);
        }
        // If no progress is made, break defensively
        if (next == last) break;
        last = next;
      }
      onCurrentWordChanged(_currentWord);
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    final word = _currentWord;
    if (word.length >= 3) {
      final score = _calculateWordScore(word);
      final lastTile = _selection.last;
      final tileRect = _tileRect(lastTile.y, lastTile.x);
      // Defer confetti to UI after server validation
      onWordCompleted(word, score, tileRect);
    }
    Future.microtask(() {
      _selection.clear();
      onCurrentWordChanged('');
    });
  }

  int _calculateWordScore(String word) {
    int score = word.length * 10;
    if (word.length >= 6) score += 50;
    if (word.length >= 8) score += 100;
    return score;
  }

  String get _currentWord {
    final buffer = StringBuffer();
    for (final p in _selection) {
      buffer.write(board[p.y][p.x]);
    }
    return buffer.toString();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _layoutBoard();
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final rect = _tileRect(r, c);
        final inset = rect.width * (1 - tileScale) / 2;
        final drawRect = rect.deflate(inset);
        final isSelected = _selection.contains(math.Point<int>(c, r));
        final fill = Paint()..color = const Color(0xFF2A2A2A);
        final border = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 3 : 1
          ..color = const Color(0xFFFFD700);
        canvas.drawRRect(
          RRect.fromRectAndRadius(drawRect, const Radius.circular(8)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(drawRect, const Radius.circular(8)),
          border,
        );
        final letter = board[r][c].toUpperCase();
        final center = Vector2(
          drawRect.left + drawRect.width / 2,
          drawRect.top + drawRect.height / 2,
        );
        _letterPaint.render(canvas, letter, center, anchor: Anchor.center);
      }
    }

    if (_selection.length >= 2) {
      final pathPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < _selection.length - 1; i++) {
        final a = _tileCenter(_selection[i].y, _selection[i].x);
        final b = _tileCenter(_selection[i + 1].y, _selection[i + 1].x);
        canvas.drawLine(a, b, pathPaint);
      }
    }
  }

  void _layoutBoard() {
    final totalSpacing = (gridSize - 1) * tileSpacing;
    final maxSquare = math.min(
      size.x - outerPadding * 2,
      size.y - outerPadding * 2,
    );
    final inner = maxSquare - totalSpacing;
    _tileSize = inner / gridSize;
    final boardSize = _tileSize * gridSize + totalSpacing;
    final left = (size.x - boardSize) / 2;
    final top = outerPadding;
    _boardRect = Rect.fromLTWH(left, top, boardSize, boardSize);
  }

  Rect _tileRect(int row, int col) {
    final dx = _boardRect.left + col * (_tileSize + tileSpacing);
    final dy = _boardRect.top + row * (_tileSize + tileSpacing);
    return Rect.fromLTWH(dx, dy, _tileSize, _tileSize);
  }

  Offset _tileCenter(int row, int col) {
    final r = _tileRect(row, col);
    final inset = r.width * (1 - tileScale) / 2;
    final d = r.deflate(inset);
    return Offset(d.left + d.width / 2, d.top + d.height / 2);
  }

  math.Point<int>? _cellAtPosition(Offset pos) {
    if (!_boardRect.contains(pos)) return null;
    final localX = pos.dx - _boardRect.left;
    final localY = pos.dy - _boardRect.top;

    // Use direct grid calculation instead of distance-based approach
    final col = (localX / (_tileSize + tileSpacing)).floor();
    final row = (localY / (_tileSize + tileSpacing)).floor();

    // Check bounds
    if (col < 0 || col >= gridSize || row < 0 || row >= gridSize) {
      return null;
    }

    // Check if click is within the tile bounds (accounting for hitbox scale)
    final tileLeft = col * (_tileSize + tileSpacing);
    final tileTop = row * (_tileSize + tileSpacing);
    final tileRight = tileLeft + _tileSize;
    final tileBottom = tileTop + _tileSize;

    final hitboxMargin = _tileSize * (1 - hitboxScale) / 2;
    final hitboxLeft = tileLeft + hitboxMargin;
    final hitboxTop = tileTop + hitboxMargin;
    final hitboxRight = tileRight - hitboxMargin;
    final hitboxBottom = tileBottom - hitboxMargin;

    if (localX >= hitboxLeft &&
        localX <= hitboxRight &&
        localY >= hitboxTop &&
        localY <= hitboxBottom) {
      return math.Point<int>(col, row);
    }

    return null;
  }

  void triggerConfettiExplosion(Offset center) {
    confettiManager.createWordExplosion(Vector2(center.dx, center.dy));
  }

  void triggerVictoryConfetti() {
    confettiManager.createVictoryExplosion(Vector2(size.x / 2, size.y / 2));
  }
}
