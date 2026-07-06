import 'package:flutter_test/flutter_test.dart';
import 'package:gem_scramble/models/match.dart';

Map<String, dynamic> _baseJson() => {
      'matchId': 'm1',
      'lobbyId': 'bronze',
      'board': [
        ['A', 'B'],
        ['C', 'D'],
      ],
      'timer': 60,
      'myWords': ['cab'],
      'opponentWords': <String>[],
      'completed': true,
      'myScore': 25,
      'opponentScore': 16,
      'opponentUsername': 'Rival',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'entryFee': 10,
      'prizePool': 20,
      'gameDuration': 60,
    };

void main() {
  group('Match', () {
    test('fromJson parses required and optional fields', () {
      final match = Match.fromJson(_baseJson());
      expect(match.matchId, 'm1');
      expect(match.board.length, 2);
      expect(match.myWords, ['cab']);
      expect(match.playerDeadlineAt, isNull);
      expect(match.startedAt, isNull);
    });

    test('toJson/fromJson round-trips', () {
      final match = Match.fromJson(_baseJson());
      final roundTripped = Match.fromJson(
        match.toJson().map((k, v) => MapEntry(k, v)),
      );
      expect(roundTripped, match);
      expect(roundTripped.myScore, match.myScore);
      expect(roundTripped.prizePool, match.prizePool);
    });

    test('winner/draw/prize helpers', () {
      final win = Match.fromJson(_baseJson());
      expect(win.isWinner, isTrue);
      expect(win.isDraw, isFalse);
      expect(win.myPrize, 20);

      final draw =
          Match.fromJson({..._baseJson(), 'myScore': 16, 'opponentScore': 16});
      expect(draw.isWinner, isFalse);
      expect(draw.isDraw, isTrue);
      expect(draw.myPrize, 0);
    });
  });
}
