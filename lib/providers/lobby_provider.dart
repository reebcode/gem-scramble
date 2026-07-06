import 'package:flutter/foundation.dart';

import '../models/lobby.dart';
import '../repositories/lobby_repository.dart';

/// Presentation state for the lobby list.
class LobbyProvider extends ChangeNotifier {
  LobbyProvider(this._repository);

  final LobbyRepository _repository;

  List<Lobby> _lobbies = const [];
  bool _isLoading = false;
  String? _error;

  List<Lobby> get lobbies => List.unmodifiable(_lobbies);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadLobbies() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.fetchLobbies();
    result.when(
      success: (list) => _lobbies = list,
      failure: (message) => _error = message,
    );
    _isLoading = false;
    notifyListeners();
  }
}
