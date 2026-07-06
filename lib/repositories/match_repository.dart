import '../core/api_client.dart';
import '../core/result.dart';
import '../models/match.dart';

/// Data access for matches: joining, word save/submit/validate, and results.
class MatchRepository {
  MatchRepository(this._api);

  final ApiClient _api;

  Future<Result<Match>> joinLobby(String lobbyId, {String? playerName}) async {
    final result = await _api.postJson('matches/join', body: {
      'lobbyType': lobbyId,
      if (playerName != null && playerName.isNotEmpty)
        'playerName': playerName,
    });
    return _parseMatch(result);
  }

  Future<Result<Match>> getMatch(String matchId) async {
    final result = await _api.getJson('matches/$matchId');
    return _parseMatch(result);
  }

  Future<Result<List<Match>>> getMyMatches() async {
    final result = await _api.getJson('matches');
    return switch (result) {
      Success(:final value) => _parseMatchList(value),
      Failure(:final message) => Failure(message),
    };
  }

  Future<Result<Map<String, dynamic>>> getMatchDetails(String matchId) =>
      _api.getJson('matches/$matchId/details');

  Future<Result<void>> saveWords(String matchId, List<String> words) async {
    final result = await _api
        .postJson('matches/$matchId/save-words', body: {'words': words});
    return result.map((_) {});
  }

  /// Submits words for final scoring. Returns the server-computed score.
  Future<Result<int>> submitWords(String matchId, List<String> words) async {
    final result =
        await _api.postJson('matches/$matchId/words', body: {'words': words});
    return switch (result) {
      Success(:final value) => Success((value['myScore'] as num?)?.toInt() ?? 0),
      Failure(:final message) => Failure(message),
    };
  }

  Future<Result<bool>> validateWord(String matchId, String word) async {
    final result =
        await _api.postJson('matches/$matchId/validate', body: {'word': word});
    return switch (result) {
      Success(:final value) => Success(value['valid'] == true),
      Failure(:final message) => Failure(message),
    };
  }

  Future<Result<void>> leaveMatch() async {
    final result = await _api.postJson('matches/leave');
    return result.map((_) {});
  }

  Result<Match> _parseMatch(Result<Map<String, dynamic>> result) {
    return switch (result) {
      Success(:final value) => _tryParse(value),
      Failure(:final message) => Failure(message),
    };
  }

  Result<Match> _tryParse(Map<String, dynamic> json) {
    try {
      // A 409 "already in a match" response carries the active match.
      final payload =
          (json['currentMatch'] as Map<String, dynamic>?) ?? json;
      return Success(Match.fromJson(payload));
    } catch (e) {
      return Failure('Unexpected match response: $e');
    }
  }

  Result<List<Match>> _parseMatchList(Map<String, dynamic> json) {
    try {
      final list = (json['matches'] as List? ?? const [])
          .map((j) => Match.fromJson(j as Map<String, dynamic>))
          .toList();
      return Success(list);
    } catch (e) {
      return Failure('Unexpected matches response: $e');
    }
  }
}
