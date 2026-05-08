import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../shared/card_model.dart';
import '../../shared/sync/game_sync.dart';
import '../../shared/sync/local_sync.dart';
import 'engine.dart';
import 'models.dart';

class LitController extends ChangeNotifier {
  LitController(this._sync) {
    _sub = _sync.watch().listen((s) {
      _state = s;
      _lastError = null;
      notifyListeners();
    });
  }

  final GameSync<LitGameState> _sync;
  StreamSubscription<LitGameState?>? _sub;
  LitGameState? _state;
  String? _lastError;
  String? _viewingSeatId;

  LitGameState? get state => _state;
  String? get lastError => _lastError;
  String get myPlayerId => _sync.myPlayerId;
  bool get isLocalMode => _sync is LocalSync<LitGameState>;

  String? get mySeatId {
    final s = _state;
    if (s == null) return null;
    if (_viewingSeatId != null) return _viewingSeatId;
    for (final seat in s.seats) {
      if (seat.playerIds.contains(myPlayerId)) return seat.id;
    }
    return null;
  }

  void setViewingSeat(String? seatId) {
    _viewingSeatId = seatId;
    notifyListeners();
  }

  Future<String> createGame({required String hostName}) =>
      _sync.createGame(initial: (code) => LiteratureEngine.newLobby(
            gameId: code,
            hostId: _sync.myPlayerId,
            hostName: hostName,
            seed: Random().nextInt(1 << 31),
          ));

  Future<String> joinGame({required String code, required String name}) =>
      _sync.joinGame(
        code: code,
        merge: (cur, myId) => LiteratureEngine.addPlayer(
          cur,
          LitPlayer(id: myId, name: name),
        ),
      );

  Future<String> addLocalPlayer(String name) async {
    final s = _state;
    if (s == null) throw StateError('No game');
    final id = 'p_${DateTime.now().microsecondsSinceEpoch}';
    final next = LiteratureEngine.addPlayer(
      s,
      LitPlayer(id: id, name: name),
    );
    await _sync.push(next);
    return id;
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
    await _sync.push(res.next!);
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
    await _sync.push(res.next!);
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
    await _sync.push(res.next!);
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
