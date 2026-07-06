import 'package:flutter_test/flutter_test.dart';
import 'package:gem_scramble/core/api_client.dart';
import 'package:gem_scramble/core/result.dart';
import 'package:gem_scramble/models/match.dart';
import 'package:gem_scramble/providers/game_session_provider.dart';
import 'package:gem_scramble/repositories/match_repository.dart';

Match _match({List<String> myWords = const []}) => Match(
      matchId: 'm1',
      lobbyId: 'bronze',
      board: const [
        ['A', 'B'],
        ['C', 'D'],
      ],
      timer: 60,
      myWords: myWords,
      opponentWords: const [],
      completed: false,
      myScore: 0,
      opponentScore: 0,
      opponentUsername: 'Rival',
      createdAt: DateTime.utc(2026),
      entryFee: 10,
      prizePool: 20,
      gameDuration: 60,
    );

class FakeMatchRepository extends MatchRepository {
  FakeMatchRepository() : super(ApiClient());

  Result<Match> joinResult = Success(_match());
  Result<Match> getMatchResult = Success(_match());
  Result<bool> validateResult = const Success(true);
  Result<int> submitResult = const Success(25);
  final List<List<String>> savedWords = [];

  @override
  Future<Result<Match>> joinLobby(String lobbyId, {String? playerName}) async =>
      joinResult;

  @override
  Future<Result<Match>> getMatch(String matchId) async => getMatchResult;

  @override
  Future<Result<bool>> validateWord(String matchId, String word) async =>
      validateResult;

  @override
  Future<Result<void>> saveWords(String matchId, List<String> words) async {
    savedWords.add(List.of(words));
    return const Success(null);
  }

  @override
  Future<Result<int>> submitWords(String matchId, List<String> words) async =>
      submitResult;
}

void main() {
  group('GameSessionProvider', () {
    late FakeMatchRepository repo;
    late GameSessionProvider session;

    setUp(() {
      repo = FakeMatchRepository();
      session = GameSessionProvider(repo);
    });

    tearDown(() {
      session.dispose();
    });

    test('joinLobby seeds session state from the match', () async {
      repo.joinResult = Success(_match(myWords: ['cab', 'bad']));

      final result = await session.joinLobby('bronze');

      expect(result.isSuccess, isTrue);
      expect(session.match, isNotNull);
      expect(session.foundWords, ['cab', 'bad']);
      // length^2 scoring: 9 + 9
      expect(session.clientScore, 18);
      expect(session.hasSubmitted, isFalse);
      expect(session.timeRemaining, 60);
    });

    test('joinLobby failure leaves session empty', () async {
      repo.joinResult = const Failure('Insufficient balance');

      final result = await session.joinLobby('bronze');

      expect(result.errorOrNull, 'Insufficient balance');
      expect(session.match, isNull);
    });

    test('tryAddWord accepts valid words and auto-saves', () async {
      await session.joinLobby('bronze');

      final outcome = await session.tryAddWord('CAB');

      expect(outcome, AddWordOutcome.accepted);
      expect(session.foundWords, contains('cab'));
      expect(session.clientScore, 9);
      // Allow the fire-and-forget auto-save to complete.
      await Future<void>.delayed(Duration.zero);
      expect(repo.savedWords, isNotEmpty);
      expect(repo.savedWords.last, contains('cab'));
    });

    test('tryAddWord rejects duplicates without a server round-trip',
        () async {
      await session.joinLobby('bronze');
      await session.tryAddWord('cab');

      final outcome = await session.tryAddWord('CAB');

      expect(outcome, AddWordOutcome.duplicate);
      expect(session.foundWords.length, 1);
    });

    test('tryAddWord reports invalid words', () async {
      await session.joinLobby('bronze');
      repo.validateResult = const Success(false);

      final outcome = await session.tryAddWord('zzz');

      expect(outcome, AddWordOutcome.rejected);
      expect(session.foundWords, isEmpty);
      expect(session.clientScore, 0);
    });

    test('submitWords marks the session submitted and blocks re-submission',
        () async {
      await session.joinLobby('bronze');
      await session.tryAddWord('cab');

      final result = await session.submitWords();

      expect(result.valueOrNull, 25);
      expect(session.hasSubmitted, isTrue);

      final again = await session.submitWords();
      expect(again.errorOrNull, 'Already submitted');
    });

    test('reset clears all session state', () async {
      await session.joinLobby('bronze');
      await session.tryAddWord('cab');

      session.reset();

      expect(session.match, isNull);
      expect(session.foundWords, isEmpty);
      expect(session.clientScore, 0);
      expect(session.timeRemaining, 0);
    });
  });
}
