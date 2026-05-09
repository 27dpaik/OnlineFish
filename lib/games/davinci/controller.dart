import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../shared/sync/game_sync.dart';
import '../../shared/sync/local_sync.dart';
import 'engine.dart';
import 'models.dart';

class DvController extends ChangeNotifier {
  DvController(this._sync) {
    _sub = _sync.watch().listen((s) {
      _state = s;
      _lastError = null;
      notifyListeners();
    });
  }

  final GameSync<DvState> _sync;
  StreamSubscription<DvState?>? _sub;
  DvState? _state;
  String? _lastError;
  String? _viewingPlayerId;

  DvState? get state => _state;
  String? get lastError => _lastError;
  String get myPlayerId => _sync.myPlayerId;
  bool get isLocalMode => _sync is LocalSync<DvState>;

  String? get myActivePlayerId {
    if (_viewingPlayerId != null) return _viewingPlayerId;
    final s = _state;
    if (s == null) return null;
    if (s.players.any((p) => p.id == myPlayerId)) return myPlayerId;
    return s.players.isEmpty ? null : s.players[0].id;
  }

  void setViewingPlayer(String id) {
    _viewingPlayerId = id;
    notifyListeners();
  }

  Future<String> createGame({required String hostName}) =>
      _sync.createGame(initial: (code) => DaVinciEngine.newLobby(
            gameId: code,
            hostId: _sync.myPlayerId,
            hostName: hostName,
            seed: Random().nextInt(1 << 31),
          ));

  Future<String> joinGame({required String code, required String name}) =>
      _sync.joinGame(
        code: code,
        merge: (cur, myId) =>
            DaVinciEngine.addPlayer(cur, DvPlayer(id: myId, name: name)),
      );

  Future<String> addLocalPlayer(String name) async {
    final s = _state;
    if (s == null) throw StateError('No game');
    final id = 'p_${DateTime.now().microsecondsSinceEpoch}';
    final next = DaVinciEngine.addPlayer(s, DvPlayer(id: id, name: name));
    await _sync.push(next);
    return id;
  }

  Future<void> startGame() => _apply((s) => DaVinciEngine.startGame(s));
  Future<void> drawFromStock(String playerId) =>
      _apply((s) => DaVinciEngine.drawFromStock(s, playerId));
  Future<void> placeDrawn(String playerId) =>
      _apply((s) => DaVinciEngine.placeDrawn(s, playerId));
  Future<void> placeDrawnAt(String playerId, int position) =>
      _apply((s) => DaVinciEngine.placeDrawnAt(s, playerId, position));
  Future<void> guess({
    required String guesserId,
    required String targetId,
    required int position,
    required int? value,
  }) =>
      _apply((s) => DaVinciEngine.guess(
            s: s,
            guesserId: guesserId,
            targetId: targetId,
            position: position,
            value: value,
          ));
  Future<void> stopAfterCorrect(String playerId) =>
      _apply((s) => DaVinciEngine.stopAfterCorrect(s, playerId));

  Future<void> _apply(DvResult Function(DvState) op) async {
    final s = _state;
    if (s == null) return;
    final res = op(s);
    if (!res.ok) {
      _lastError = res.error;
      notifyListeners();
      return;
    }
    await _sync.push(res.next!);
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _sync.dispose();
    super.dispose();
  }
}
