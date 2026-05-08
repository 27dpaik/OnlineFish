import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../shared/card_model.dart';
import '../../shared/sync/game_sync.dart';
import '../../shared/sync/local_sync.dart';
import 'engine.dart';
import 'models.dart';

class OcController extends ChangeNotifier {
  OcController(this._sync) {
    _sub = _sync.watch().listen((s) {
      _state = s;
      _lastError = null;
      notifyListeners();
    });
  }

  final GameSync<OcState> _sync;
  StreamSubscription<OcState?>? _sub;
  OcState? _state;
  String? _lastError;
  String? _viewingPlayerId;

  OcState? get state => _state;
  String? get lastError => _lastError;
  String get myPlayerId => _sync.myPlayerId;
  bool get isLocalMode => _sync is LocalSync<OcState>;

  /// In local hot-seat mode the device toggles between players.
  String? get myActivePlayerId {
    if (_viewingPlayerId != null) return _viewingPlayerId;
    final s = _state;
    if (s == null) return null;
    if (s.players.any((p) => p.id == myPlayerId)) return myPlayerId;
    return s.players.isEmpty ? null : s.players[s.currentIdx].id;
  }

  void setViewingPlayer(String id) {
    _viewingPlayerId = id;
    notifyListeners();
  }

  Future<String> createGame({required String hostName}) =>
      _sync.createGame(initial: (code) => OneCardEngine.newLobby(
            gameId: code,
            hostId: _sync.myPlayerId,
            hostName: hostName,
            seed: Random().nextInt(1 << 31),
          ));

  Future<String> joinGame({required String code, required String name}) =>
      _sync.joinGame(
        code: code,
        merge: (cur, myId) => OneCardEngine.addPlayer(
          cur,
          OcPlayer(id: myId, name: name),
        ),
      );

  Future<String> addLocalPlayer(String name) async {
    final s = _state;
    if (s == null) throw StateError('No game');
    final id = 'p_${DateTime.now().microsecondsSinceEpoch}';
    final next = OneCardEngine.addPlayer(s, OcPlayer(id: id, name: name));
    await _sync.push(next);
    return id;
  }

  Future<void> startGame() async {
    final s = _state;
    if (s == null) return;
    final res = OneCardEngine.startGame(s);
    if (!res.ok) {
      _lastError = res.error;
      notifyListeners();
      return;
    }
    await _sync.push(res.next!);
  }

  Future<void> play({
    required String playerId,
    required PlayingCard card,
    Suit? declaredSuitForSeven,
  }) async {
    final s = _state;
    if (s == null) return;
    final res = OneCardEngine.play(
      s: s,
      playerId: playerId,
      card: card,
      declaredSuitForSeven: declaredSuitForSeven,
    );
    if (!res.ok) {
      _lastError = res.error;
      notifyListeners();
      return;
    }
    await _sync.push(res.next!);
  }

  Future<void> draw({required String playerId}) async {
    final s = _state;
    if (s == null) return;
    final res = OneCardEngine.draw(s: s, playerId: playerId);
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
