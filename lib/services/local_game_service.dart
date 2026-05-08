import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../engine/engine.dart';
import '../models/game_models.dart';
import 'game_service.dart';

/// Single-device "pass the phone" mode. No network — useful for testing the
/// game logic and for parties where everyone is in the same room.
class LocalGameService implements GameService {
  static const _uuid = Uuid();
  final _ctrl = StreamController<GameState?>.broadcast();
  GameState? _state;
  final String _myId = _uuid.v4();

  @override
  Stream<GameState?> watch() => _ctrl.stream;

  @override
  GameState? get current => _state;

  @override
  String get myPlayerId => _myId;

  @override
  Future<String> createGame({required String hostName, int? seed}) async {
    final code = _shortCode();
    _state = LiteratureEngine.newLobby(
      gameId: code,
      hostId: _myId,
      hostName: hostName,
      seed: seed ?? Random().nextInt(1 << 31),
    );
    _ctrl.add(_state);
    return code;
  }

  @override
  Future<String> joinGame({required String gameCode, required String name}) async {
    // Local mode is single-device; "joining" just adds another player to the
    // current lobby.
    if (_state == null) {
      throw StateError('No local game in progress');
    }
    final p = Player(id: _uuid.v4(), name: name);
    _state = LiteratureEngine.addPlayer(_state!, p);
    _ctrl.add(_state);
    return p.id;
  }

  /// Add a player by name to the lobby (convenience for the local mode UI).
  Future<String> addLocalPlayer(String name) async {
    final p = Player(id: _uuid.v4(), name: name);
    _state = LiteratureEngine.addPlayer(_state!, p);
    _ctrl.add(_state);
    return p.id;
  }

  @override
  Future<void> push(GameState state) async {
    _state = state;
    _ctrl.add(_state);
  }

  @override
  Future<void> dispose() async {
    await _ctrl.close();
  }

  static String _shortCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
