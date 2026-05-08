import 'dart:async';

import '../models/game_models.dart';

/// Abstraction over "where the game state lives" — local memory for hot-seat
/// play, or Firestore for online play.
abstract class GameService {
  /// Stream of game state. `null` until [createGame] or [joinGame] succeeds,
  /// then non-null for the lifetime of the service.
  Stream<GameState?> watch();

  /// Last-known state synchronously (may be null).
  GameState? get current;

  String get myPlayerId;

  /// Host a new game. Returns the new game code.
  Future<String> createGame({required String hostName, int? seed});

  /// Join an existing game by code with the given display name. Returns
  /// the player's id.
  Future<String> joinGame({required String gameCode, required String name});

  /// Atomically replace the game state. Used by the engine after applying
  /// any move. Implementations are responsible for ordering / conflict
  /// resolution; for this turn-based game last-write-wins is fine since
  /// only one seat acts at a time.
  Future<void> push(GameState state);

  /// Tear down. After dispose [watch] no longer emits.
  Future<void> dispose();
}
