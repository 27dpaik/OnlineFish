import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../shared/sync/game_sync.dart';
import '../../shared/sync/local_sync.dart';
import 'engine.dart';
import 'models.dart';

class CfController extends ChangeNotifier {
  CfController(this._sync) {
    _sub = _sync.watch().listen((s) {
      _state = s;
      _lastError = null;
      notifyListeners();
    });
  }

  final GameSync<CfState> _sync;
  StreamSubscription<CfState?>? _sub;
  CfState? _state;
  String? _lastError;
  String? _viewingPlayerId;

  CfState? get state => _state;
  String? get lastError => _lastError;
  String get myPlayerId => _sync.myPlayerId;
  bool get isLocalMode => _sync is LocalSync<CfState>;

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
      _sync.createGame(initial: (code) => CastlefallEngine.newLobby(
            gameId: code,
            hostId: _sync.myPlayerId,
            hostName: hostName,
            seed: Random().nextInt(1 << 31),
          ));

  Future<String> joinGame({required String code, required String name}) =>
      _sync.joinGame(
        code: code,
        merge: (cur, myId) => CastlefallEngine.addPlayer(
            cur, CfPlayer(id: myId, name: name)),
      );

  Future<String> addLocalPlayer(String name) async {
    final s = _state;
    if (s == null) throw StateError('No game');
    final id = 'p_${DateTime.now().microsecondsSinceEpoch}';
    final next =
        CastlefallEngine.addPlayer(s, CfPlayer(id: id, name: name));
    await _sync.push(next);
    return id;
  }

  Future<void> startRound(String category) =>
      _apply((s) => CastlefallEngine.startRound(s, category));

  Future<void> declareTeam({
    required String declarerId,
    required List<String> claimedPlayerIds,
  }) =>
      _apply((s) => CastlefallEngine.declareTeam(
            s: s,
            declarerId: declarerId,
            claimedPlayerIds: claimedPlayerIds,
          ));

  Future<void> guessWord({
    required String declarerId,
    required String guessedWord,
  }) =>
      _apply((s) => CastlefallEngine.guessWord(
            s: s,
            declarerId: declarerId,
            guessedWord: guessedWord,
          ));

  Future<void> resolveTeamDeclaration() =>
      _apply((s) => CastlefallEngine.resolveTeamDeclaration(s));

  Future<void> nextRound(String category) =>
      _apply((s) => CastlefallEngine.nextRound(s, category));

  Future<void> _apply(CfResult Function(CfState) op) async {
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
