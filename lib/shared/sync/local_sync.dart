import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'game_sync.dart';

class LocalSync<T> implements GameSync<T> {
  static const _uuid = Uuid();
  final _ctrl = StreamController<T?>.broadcast();
  T? _state;
  final String _myId = _uuid.v4();

  @override
  Stream<T?> watch() => _ctrl.stream;

  @override
  T? get current => _state;

  @override
  String get myPlayerId => _myId;

  @override
  Future<String> createGame({required T Function(String code) initial}) async {
    final code = _shortCode();
    _state = initial(code);
    _ctrl.add(_state);
    return code;
  }

  @override
  Future<String> joinGame({
    required String code,
    required T Function(T current, String myPlayerId) merge,
  }) async {
    if (_state == null) throw StateError('No local game in progress');
    _state = merge(_state as T, _myId);
    _ctrl.add(_state);
    return _myId;
  }

  @override
  Future<void> push(T state) async {
    _state = state;
    _ctrl.add(_state);
  }

  @override
  Future<bool> tryPush(T Function(T current) update) async {
    if (_state == null) return false;
    _state = update(_state as T);
    _ctrl.add(_state);
    return true;
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
