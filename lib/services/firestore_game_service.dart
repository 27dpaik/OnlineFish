import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../engine/engine.dart';
import '../models/game_models.dart';
import 'game_service.dart';

/// Online sync via Firestore. Each game lives at `games/{code}` as a single
/// document containing the full serialized [GameState]. Because Literature
/// is turn-based this last-write-wins approach is fine.
class FirestoreGameService implements GameService {
  static const _uuid = Uuid();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _ctrl = StreamController<GameState?>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _gameCode;
  final String _myId = _uuid.v4();
  GameState? _state;

  @override
  Stream<GameState?> watch() => _ctrl.stream;

  @override
  GameState? get current => _state;

  @override
  String get myPlayerId => _myId;

  DocumentReference<Map<String, dynamic>> _doc(String code) =>
      _db.collection('games').doc(code);

  @override
  Future<String> createGame({required String hostName, int? seed}) async {
    final code = await _allocateCode();
    final initial = LiteratureEngine.newLobby(
      gameId: code,
      hostId: _myId,
      hostName: hostName,
      seed: seed ?? Random().nextInt(1 << 31),
    );
    await _doc(code).set(initial.toJson());
    _gameCode = code;
    _attach();
    return code;
  }

  @override
  Future<String> joinGame({required String gameCode, required String name}) async {
    final code = gameCode.toUpperCase();
    final snap = await _doc(code).get();
    if (!snap.exists) {
      throw StateError('Game $code not found');
    }
    final state = GameState.fromJson(snap.data()!);
    if (state.phase != GamePhase.lobby) {
      throw StateError('Game $code already started');
    }
    final player = Player(id: _myId, name: name);
    final next = LiteratureEngine.addPlayer(state, player);
    await _doc(code).set(next.toJson());
    _gameCode = code;
    _attach();
    return _myId;
  }

  void _attach() {
    _sub?.cancel();
    _sub = _doc(_gameCode!).snapshots().listen((snap) {
      if (!snap.exists) {
        _state = null;
      } else {
        _state = GameState.fromJson(snap.data()!);
      }
      _ctrl.add(_state);
    });
  }

  @override
  Future<void> push(GameState state) async {
    if (_gameCode == null) throw StateError('Not connected to a game');
    await _doc(_gameCode!).set(state.toJson());
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _ctrl.close();
  }

  Future<String> _allocateCode() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _shortCode();
      final snap = await _doc(code).get();
      if (!snap.exists) return code;
    }
    // Fallback: 7-char code, vanishingly small collision chance.
    return _shortCode(7);
  }

  static String _shortCode([int len = 5]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
