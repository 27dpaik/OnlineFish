import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/engine.dart';
import '../models/card_model.dart';
import '../models/game_models.dart';
import '../services/game_service.dart';
import '../services/local_game_service.dart';

/// UI-facing controller. Wraps a [GameService] (local or Firestore) and the
/// pure [LiteratureEngine] together so the screens only deal in intents:
/// `sit`, `startGame`, `ask`, `declare`.
class GameController extends ChangeNotifier {
  GameController(this._service) {
    _sub = _service.watch().listen((s) {
      _state = s;
      _lastError = null;
      notifyListeners();
    });
  }

  final GameService _service;
  StreamSubscription<GameState?>? _sub;
  GameState? _state;
  String? _lastError;

  /// The seat the active local user is viewing as. In multi-player-per-seat
  /// configurations the controller exposes the same hand to every paired
  /// player.
  String? _viewingSeatId;

  GameState? get state => _state;
  String? get lastError => _lastError;
  String get myPlayerId => _service.myPlayerId;
  bool get isLocalMode => _service is LocalGameService;

  String? get mySeatId {
    final s = _state;
    if (s == null) return null;
    if (_viewingSeatId != null) return _viewingSeatId;
    for (final seat in s.seats) {
      if (seat.playerIds.contains(myPlayerId)) return seat.id;
    }
    return null;
  }

  /// In hot-seat mode a single device toggles between seats.
  void setViewingSeat(String? seatId) {
    _viewingSeatId = seatId;
    notifyListeners();
  }

  Future<String> createGame({required String hostName}) =>
      _service.createGame(hostName: hostName);

  Future<String> joinGame({required String code, required String name}) =>
      _service.joinGame(gameCode: code, name: name);

  Future<String> addLocalPlayer(String name) {
    final svc = _service;
    if (svc is! LocalGameService) {
      throw StateError('addLocalPlayer is only valid in local mode');
    }
    return svc.addLocalPlayer(name);
  }

  Future<void> sit({required String playerId, required String seatId}) async {
    final s = _state;
    if (s == null) return;
    final res = LiteratureEngine.sitPlayer(s, playerId, seatId);
    if (!res.ok) {
      _lastError = res.error;
      notifyListeners();
      return;
    }
    await _service.push(res.next!);
  }

  Future<void> startGame() async {
    final s = _state;
    if (s == null) return;
    final res = LiteratureEngine.startGame(s);
    if (!res.ok) {
      _lastError = res.error;
      notifyListeners();
      return;
    }
    await _service.push(res.next!);
  }

  Future<void> ask({
    required String askerSeatId,
    required String targetSeatId,
    required PlayingCard card,
  }) async {
    final s = _state;
    if (s == null) return;
    final res = LiteratureEngine.ask(
      s: s,
      askerSeatId: askerSeatId,
      targetSeatId: targetSeatId,
      card: card,
    );
    if (!res.ok) {
      _lastError = res.error;
      notifyListeners();
      return;
    }
    await _service.push(res.next!);
  }

  Future<void> declare({
    required String declarerSeatId,
    required String halfSuiteId,
    required Map<String, String> assignment,
  }) async {
    final s = _state;
    if (s == null) return;
    final res = LiteratureEngine.declare(
      s: s,
      declarerSeatId: declarerSeatId,
      halfSuiteId: halfSuiteId,
      assignment: assignment,
    );
    if (!res.ok) {
      _lastError = res.error;
      notifyListeners();
      return;
    }
    await _service.push(res.next!);
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _service.dispose();
    super.dispose();
  }
}
