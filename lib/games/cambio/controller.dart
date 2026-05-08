import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../shared/sync/game_sync.dart';
import '../../shared/sync/local_sync.dart';
import 'engine.dart';
import 'models.dart';

class CambioController extends ChangeNotifier {
  CambioController(this._sync) {
    _sub = _sync.watch().listen((s) {
      _state = s;
      _lastError = null;
      notifyListeners();
    });
  }

  final GameSync<CambioState> _sync;
  StreamSubscription<CambioState?>? _sub;
  CambioState? _state;
  String? _lastError;
  String? _viewingPlayerId;

  CambioState? get state => _state;
  String? get lastError => _lastError;
  String get myPlayerId => _sync.myPlayerId;
  bool get isLocalMode => _sync is LocalSync<CambioState>;

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
      _sync.createGame(initial: (code) => CambioEngine.newLobby(
            gameId: code,
            hostId: _sync.myPlayerId,
            hostName: hostName,
            seed: Random().nextInt(1 << 31),
          ));

  Future<String> joinGame({required String code, required String name}) =>
      _sync.joinGame(
        code: code,
        merge: (cur, myId) => CambioEngine.addPlayer(
          cur,
          CambioPlayer(id: myId, name: name),
        ),
      );

  Future<String> addLocalPlayer(String name) async {
    final s = _state;
    if (s == null) throw StateError('No game');
    final id = 'p_${DateTime.now().microsecondsSinceEpoch}';
    final next =
        CambioEngine.addPlayer(s, CambioPlayer(id: id, name: name));
    await _sync.push(next);
    return id;
  }

  Future<void> startGame() => _apply((s) => CambioEngine.startGame(s));

  Future<void> finishInitialPeek(String playerId) =>
      _apply((s) => CambioEngine.finishInitialPeek(s, playerId));

  Future<void> drawFromStock(String playerId) =>
      _apply((s) => CambioEngine.drawFromStock(s, playerId));

  Future<void> swapDrawn({required String playerId, required int position}) =>
      _apply((s) =>
          CambioEngine.swapDrawn(s: s, playerId: playerId, position: position));

  Future<void> discardDrawn({required String playerId}) =>
      _apply((s) => CambioEngine.discardDrawn(s: s, playerId: playerId));

  Future<void> peekOwn(
          {required String playerId, required int position}) =>
      _apply((s) =>
          CambioEngine.peekOwn(s: s, playerId: playerId, position: position));

  Future<void> peekOther({
    required String playerId,
    required String targetPlayerId,
    required int position,
  }) =>
      _apply((s) => CambioEngine.peekOther(
            s: s,
            playerId: playerId,
            targetPlayerId: targetPlayerId,
            position: position,
          ));

  Future<void> acknowledgePeek(String playerId) =>
      _apply((s) => CambioEngine.acknowledgePeek(s, playerId));

  Future<void> blindSwitchMine({
    required String playerId,
    required int myPosition,
  }) =>
      _apply((s) => CambioEngine.blindSwitchPickMine(
            s: s,
            playerId: playerId,
            myPosition: myPosition,
          ));

  Future<void> blindSwitchOther({
    required String playerId,
    required String otherPlayerId,
    required int otherPosition,
  }) =>
      _apply((s) => CambioEngine.blindSwitchPickOther(
            s: s,
            playerId: playerId,
            otherPlayerId: otherPlayerId,
            otherPosition: otherPosition,
          ));

  Future<void> kingLook({
    required String playerId,
    required String targetPlayerId,
    required int position,
  }) =>
      _apply((s) => CambioEngine.kingLook(
            s: s,
            playerId: playerId,
            targetPlayerId: targetPlayerId,
            position: position,
          ));

  Future<void> kingSwitchMine({
    required String playerId,
    required int myPosition,
  }) =>
      _apply((s) => CambioEngine.kingSwitchPickMine(
            s: s,
            playerId: playerId,
            myPosition: myPosition,
          ));

  Future<void> kingSwitchOther({
    required String playerId,
    required String otherPlayerId,
    required int otherPosition,
  }) =>
      _apply((s) => CambioEngine.kingSwitchPickOther(
            s: s,
            playerId: playerId,
            otherPlayerId: otherPlayerId,
            otherPosition: otherPosition,
          ));

  /// Stick uses tryPush so only the first sticker wins online.
  Future<void> stick({
    required String stickerId,
    required String ownerPlayerId,
    required int position,
  }) async {
    String? err;
    final committed = await _sync.tryPush((cur) {
      final res = CambioEngine.stick(
        s: cur,
        stickerId: stickerId,
        ownerPlayerId: ownerPlayerId,
        position: position,
      );
      if (!res.ok) {
        err = res.error;
        return cur;
      }
      return res.next!;
    });
    if (err != null) {
      _lastError = err;
      notifyListeners();
    }
    if (!committed) {
      _lastError = 'Someone else stuck first';
      notifyListeners();
    }
  }

  Future<void> callCambio(String playerId) =>
      _apply((s) => CambioEngine.callCambio(s, playerId));

  Future<void> _apply(CambioResult Function(CambioState) op) async {
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
