import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'game_sync.dart';

class FirestoreSync<T> implements GameSync<T> {
  FirestoreSync({
    required this.collection,
    required this.toJson,
    required this.fromJson,
  });

  static const _uuid = Uuid();
  final String collection;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _ctrl = StreamController<T?>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _gameCode;
  final String _myId = _uuid.v4();
  T? _state;

  @override
  Stream<T?> watch() => _ctrl.stream;

  @override
  T? get current => _state;

  @override
  String get myPlayerId => _myId;

  DocumentReference<Map<String, dynamic>> _doc(String code) =>
      _db.collection(collection).doc(code);

  @override
  Future<String> createGame({required T Function(String code) initial}) async {
    final code = await _allocateCode();
    final state = initial(code);
    await _doc(code).set(toJson(state));
    _gameCode = code;
    _attach();
    return code;
  }

  @override
  Future<String> joinGame({
    required String code,
    required T Function(T current, String myPlayerId) merge,
  }) async {
    final upper = code.toUpperCase();
    final ref = _doc(upper);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Game $upper not found');
      final current = fromJson(snap.data()!);
      final merged = merge(current, _myId);
      tx.set(ref, toJson(merged));
    });
    _gameCode = upper;
    _attach();
    return _myId;
  }

  void _attach() {
    _sub?.cancel();
    _sub = _doc(_gameCode!).snapshots().listen((snap) {
      if (!snap.exists) {
        _state = null;
      } else {
        _state = fromJson(snap.data()!);
      }
      _ctrl.add(_state);
    });
  }

  @override
  Future<void> push(T state) async {
    if (_gameCode == null) throw StateError('Not connected to a game');
    await _doc(_gameCode!).set(toJson(state));
  }

  @override
  Future<bool> tryPush(T Function(T current) update) async {
    if (_gameCode == null) throw StateError('Not connected to a game');
    final ref = _doc(_gameCode!);
    bool committed = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final cur = fromJson(snap.data()!);
      final next = update(cur);
      tx.set(ref, toJson(next));
      committed = true;
    });
    return committed;
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
    return _shortCode(7);
  }

  static String _shortCode([int len = 5]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
