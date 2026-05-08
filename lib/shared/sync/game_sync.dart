import 'dart:async';

/// Generic "where the game state lives" abstraction. T is the per-game
/// state class. Callers pass JSON encode/decode and a player id factory.
abstract class GameSync<T> {
  Stream<T?> watch();
  T? get current;
  String get myPlayerId;

  /// Create a new game with a fresh code. Returns the code.
  Future<String> createGame({required T Function(String code) initial});

  /// Join an existing game by code. `merge` mutates the current state to
  /// include the joining player. Returns the player id.
  Future<String> joinGame({
    required String code,
    required T Function(T current, String myPlayerId) merge,
  });

  /// Atomically replace the game state. Last-write-wins is fine for
  /// turn-based games where one seat acts at a time.
  Future<void> push(T state);

  /// Atomic compare-and-set. Used by Cambio's "stick a card" race so only
  /// the first sticker wins. Returns `true` if the update was applied.
  /// Returning `false` means another player got there first; caller should
  /// re-read state and decide what to do. Implementations may always-write
  /// for simplicity in local mode.
  Future<bool> tryPush(T Function(T current) update);

  Future<void> dispose();
}
