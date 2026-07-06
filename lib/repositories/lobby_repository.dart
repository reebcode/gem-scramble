import '../core/api_client.dart';
import '../core/result.dart';
import '../models/lobby.dart';

/// Data access for the lobby list.
class LobbyRepository {
  LobbyRepository(this._api);

  final ApiClient _api;

  Future<Result<List<Lobby>>> fetchLobbies() async {
    final result = await _api.getJson('lobbies');
    return switch (result) {
      Success(:final value) => _parse(value),
      Failure(:final message) => Failure(message),
    };
  }

  Result<List<Lobby>> _parse(Map<String, dynamic> json) {
    try {
      final list = (json['lobbies'] as List? ?? const [])
          .map((j) => Lobby.fromJson(j as Map<String, dynamic>))
          .toList();
      return Success(list);
    } catch (e) {
      return Failure('Unexpected lobbies response: $e');
    }
  }
}
