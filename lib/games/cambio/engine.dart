import 'dart:math';

import '../../shared/card_model.dart';
import 'models.dart';

class CambioResult {
  final bool ok;
  final String? error;
  final CambioState? next;
  const CambioResult.success(this.next)
      : ok = true,
        error = null;
  const CambioResult.failure(this.error)
      : ok = false,
        next = null;
}

/// Cambio engine. Note on visibility: hands live in the synced state, in the
/// clear. Hiding from other players is enforced client-side. For social play
/// this is fine; for cheat-resistant online play you'd need a real server.
class CambioEngine {
  static CambioState newLobby({
    required String gameId,
    required String hostId,
    required String hostName,
    required int seed,
  }) =>
      CambioState(
        gameId: gameId,
        hostId: hostId,
        phase: CambioPhase.lobby,
        players: [CambioPlayer(id: hostId, name: hostName, isHost: true)],
        hands: const {},
        stock: const [],
        discard: const [],
        drawn: null,
        pending: null,
        initialPeekDone: const {},
        currentIdx: 0,
        cambioCallerId: null,
        finalRoundRemaining: 0,
        finalScores: null,
        winnerId: null,
        seed: seed,
        log: const [],
        privateReveals: const [],
      );

  static CambioState addPlayer(CambioState s, CambioPlayer p) {
    if (s.phase != CambioPhase.lobby) return s;
    if (s.players.any((x) => x.id == p.id)) return s;
    return s.copyWith(players: [...s.players, p]);
  }

  static CambioResult startGame(CambioState s) {
    if (s.phase != CambioPhase.lobby) {
      return const CambioResult.failure('Game already started');
    }
    if (s.players.length < 2) {
      return const CambioResult.failure('Need at least 2 players');
    }
    final cards = Decks.standard54()..shuffle(Random(s.seed));
    final hands = <String, List<String>>{};
    var idx = 0;
    for (final p in s.players) {
      hands[p.id] = cards.sublist(idx, idx + 4).map((c) => c.id).toList();
      idx += 4;
    }
    final firstDiscard = cards[idx++].id;
    final stock = cards.sublist(idx).map((c) => c.id).toList();
    return CambioResult.success(s.copyWith(
      phase: CambioPhase.initialPeek,
      hands: hands,
      stock: stock,
      discard: [firstDiscard],
      currentIdx: 0,
      log: [
        ...s.log,
        CambioLogEntry(
            text: 'Dealt 4 to each. Initial peek phase.',
            at: DateTime.now()),
      ],
    ));
  }

  /// Mark a player as having finished their initial peek (positions 2 & 3).
  /// When all players are done, advance to playing.
  static CambioResult finishInitialPeek(CambioState s, String playerId) {
    if (s.phase != CambioPhase.initialPeek) {
      return const CambioResult.failure('Not in initial peek phase');
    }
    final done = {...s.initialPeekDone, playerId};
    final allDone = s.players.every((p) => done.contains(p.id));
    return CambioResult.success(s.copyWith(
      initialPeekDone: done,
      phase: allDone ? CambioPhase.playing : CambioPhase.initialPeek,
      log: allDone
          ? [
              ...s.log,
              CambioLogEntry(
                  text: 'All initial peeks done. ${s.players[0].name} starts.',
                  at: DateTime.now()),
            ]
          : s.log,
    ));
  }

  /// Active player draws from stock.
  static CambioResult drawFromStock(CambioState s, String playerId) {
    if (s.phase != CambioPhase.playing &&
        s.phase != CambioPhase.finalRound) {
      return const CambioResult.failure('Not in play');
    }
    if (s.currentPlayer.id != playerId) {
      return const CambioResult.failure("It's not your turn");
    }
    if (s.drawn != null) {
      return const CambioResult.failure('You already drew');
    }
    if (s.pending != null) {
      return const CambioResult.failure('Resolve the pending power first');
    }
    var stock = List<String>.from(s.stock);
    var discard = List<String>.from(s.discard);
    if (stock.isEmpty) {
      if (discard.length <= 1) {
        return const CambioResult.failure('No cards left to draw');
      }
      final top = discard.removeLast();
      stock = List<String>.from(discard)..shuffle(Random(s.seed + 1));
      discard = [top];
    }
    final cardId = stock.removeLast();
    return CambioResult.success(s.copyWith(
      stock: stock,
      discard: discard,
      drawn: DrawnCard(cardId: cardId, playerId: playerId),
    ));
  }

  /// Swap the drawn card with one of the player's face-down positions; the
  /// previously face-down card goes to the discard pile. No power is
  /// triggered for the swapped-out card.
  static CambioResult swapDrawn({
    required CambioState s,
    required String playerId,
    required int position,
  }) {
    if (s.drawn == null || s.drawn!.playerId != playerId) {
      return const CambioResult.failure('No drawn card');
    }
    if (position < 0 || position > 3) {
      return const CambioResult.failure('Bad position');
    }
    final hand = List<String>.from(s.hands[playerId]!);
    final swappedOut = hand[position];
    hand[position] = s.drawn!.cardId;
    final newDiscard = [...s.discard, swappedOut];
    final name = s.players.firstWhere((p) => p.id == playerId).name;
    return _afterTurn(s.copyWith(
      hands: {...s.hands, playerId: hand},
      discard: newDiscard,
      clearDrawn: true,
      log: [
        ...s.log,
        CambioLogEntry(
            text: '$name swapped slot ${position + 1} → discarded ${_label(PlayingCard.fromId(swappedOut))}',
            at: DateTime.now()),
      ],
    ));
  }

  /// Discard the drawn card (and possibly trigger its power).
  static CambioResult discardDrawn({
    required CambioState s,
    required String playerId,
  }) {
    if (s.drawn == null || s.drawn!.playerId != playerId) {
      return const CambioResult.failure('No drawn card');
    }
    final card = PlayingCard.fromId(s.drawn!.cardId);
    final newDiscard = [...s.discard, s.drawn!.cardId];
    final name = s.players.firstWhere((p) => p.id == playerId).name;
    final base = s.copyWith(
      discard: newDiscard,
      clearDrawn: true,
      log: [
        ...s.log,
        CambioLogEntry(
            text: '$name discarded ${_label(card)}',
            at: DateTime.now()),
      ],
    );
    final power = _powerFor(card);
    if (power == null) {
      return _afterTurn(base);
    }
    return CambioResult.success(base.copyWith(
      pending: PendingPower(type: power, activePlayerId: playerId),
    ));
  }

  /// Resolve a peek-own (7/8) by revealing the chosen position to the player.
  static CambioResult peekOwn({
    required CambioState s,
    required String playerId,
    required int position,
  }) {
    if (s.pending?.type != PendingPowerType.peekOwn ||
        s.pending?.activePlayerId != playerId) {
      return const CambioResult.failure('No pending peek-own');
    }
    if (position < 0 || position > 3) {
      return const CambioResult.failure('Bad position');
    }
    final cardId = s.hands[playerId]![position];
    return CambioResult.success(s.copyWith(
      privateReveals: [
        ...s.privateReveals,
        PrivateReveal(
          viewerId: playerId,
          cardId: cardId,
          ofPlayerId: playerId,
          position: position,
        ),
      ],
    ));
  }

  /// Resolve a peek-other (9/10).
  static CambioResult peekOther({
    required CambioState s,
    required String playerId,
    required String targetPlayerId,
    required int position,
  }) {
    if (s.pending?.type != PendingPowerType.peekOther ||
        s.pending?.activePlayerId != playerId) {
      return const CambioResult.failure('No pending peek-other');
    }
    if (targetPlayerId == playerId) {
      return const CambioResult.failure('Pick another player');
    }
    if (position < 0 || position > 3) {
      return const CambioResult.failure('Bad position');
    }
    final cardId = s.hands[targetPlayerId]![position];
    return CambioResult.success(s.copyWith(
      privateReveals: [
        ...s.privateReveals,
        PrivateReveal(
          viewerId: playerId,
          cardId: cardId,
          ofPlayerId: targetPlayerId,
          position: position,
        ),
      ],
    ));
  }

  /// Acknowledge a peek and end the pending power. Removes the private
  /// reveals belonging to this player and clears `pending`.
  static CambioResult acknowledgePeek(CambioState s, String playerId) {
    if (s.pending?.activePlayerId != playerId) {
      return const CambioResult.failure('Not your peek');
    }
    return _afterTurn(s.copyWith(
      privateReveals:
          s.privateReveals.where((r) => r.viewerId != playerId).toList(),
      clearPending: true,
    ));
  }

  /// Blind switch (J/Q): pick own position, then opponent + their position.
  static CambioResult blindSwitchPickMine({
    required CambioState s,
    required String playerId,
    required int myPosition,
  }) {
    if (s.pending?.type != PendingPowerType.blindSwitchPickMine ||
        s.pending?.activePlayerId != playerId) {
      return const CambioResult.failure('No pending blind switch');
    }
    return CambioResult.success(s.copyWith(
      pending: s.pending!.copyWith(
        type: PendingPowerType.blindSwitchPickOther,
        myPickedPosition: '$myPosition',
      ),
    ));
  }

  static CambioResult blindSwitchPickOther({
    required CambioState s,
    required String playerId,
    required String otherPlayerId,
    required int otherPosition,
  }) {
    if (s.pending?.type != PendingPowerType.blindSwitchPickOther ||
        s.pending?.activePlayerId != playerId) {
      return const CambioResult.failure('No pending blind switch');
    }
    if (otherPlayerId == playerId) {
      return const CambioResult.failure('Pick another player');
    }
    final myPos = int.parse(s.pending!.myPickedPosition!);
    final myHand = List<String>.from(s.hands[playerId]!);
    final otherHand = List<String>.from(s.hands[otherPlayerId]!);
    final tmp = myHand[myPos];
    myHand[myPos] = otherHand[otherPosition];
    otherHand[otherPosition] = tmp;
    final me = s.players.firstWhere((p) => p.id == playerId).name;
    final them = s.players.firstWhere((p) => p.id == otherPlayerId).name;
    return _afterTurn(s.copyWith(
      hands: {
        ...s.hands,
        playerId: myHand,
        otherPlayerId: otherHand,
      },
      clearPending: true,
      log: [
        ...s.log,
        CambioLogEntry(
            text:
                '$me blind-switched slot ${myPos + 1} ⇄ $them slot ${otherPosition + 1}',
            at: DateTime.now()),
      ],
    ));
  }

  /// Black King step 1: look at any card.
  static CambioResult kingLook({
    required CambioState s,
    required String playerId,
    required String targetPlayerId,
    required int position,
  }) {
    if (s.pending?.type != PendingPowerType.kingLook ||
        s.pending?.activePlayerId != playerId) {
      return const CambioResult.failure('No pending king look');
    }
    final cardId = s.hands[targetPlayerId]![position];
    return CambioResult.success(s.copyWith(
      pending: s.pending!.copyWith(
        type: PendingPowerType.kingSwitchPickMine,
        viewedPlayerId: targetPlayerId,
        viewedPosition: position,
      ),
      privateReveals: [
        ...s.privateReveals,
        PrivateReveal(
          viewerId: playerId,
          cardId: cardId,
          ofPlayerId: targetPlayerId,
          position: position,
        ),
      ],
    ));
  }

  /// Black King step 2: pick own position (the one to give away).
  static CambioResult kingSwitchPickMine({
    required CambioState s,
    required String playerId,
    required int myPosition,
  }) {
    if (s.pending?.type != PendingPowerType.kingSwitchPickMine ||
        s.pending?.activePlayerId != playerId) {
      return const CambioResult.failure('No pending king switch step 2');
    }
    return CambioResult.success(s.copyWith(
      pending: s.pending!.copyWith(
        type: PendingPowerType.kingSwitchPickOther,
        myPickedPosition: '$myPosition',
      ),
    ));
  }

  /// Black King step 3: pick the opponent card to receive.
  static CambioResult kingSwitchPickOther({
    required CambioState s,
    required String playerId,
    required String otherPlayerId,
    required int otherPosition,
  }) {
    if (s.pending?.type != PendingPowerType.kingSwitchPickOther ||
        s.pending?.activePlayerId != playerId) {
      return const CambioResult.failure('No pending king switch step 3');
    }
    final myPos = int.parse(s.pending!.myPickedPosition!);
    final myHand = List<String>.from(s.hands[playerId]!);
    final otherHand = List<String>.from(s.hands[otherPlayerId]!);
    final tmp = myHand[myPos];
    myHand[myPos] = otherHand[otherPosition];
    otherHand[otherPosition] = tmp;
    final me = s.players.firstWhere((p) => p.id == playerId).name;
    final them = s.players.firstWhere((p) => p.id == otherPlayerId).name;
    return _afterTurn(s.copyWith(
      hands: {
        ...s.hands,
        playerId: myHand,
        otherPlayerId: otherHand,
      },
      privateReveals:
          s.privateReveals.where((r) => r.viewerId != playerId).toList(),
      clearPending: true,
      log: [
        ...s.log,
        CambioLogEntry(
            text:
                '$me used Black King: switched slot ${myPos + 1} with $them slot ${otherPosition + 1}',
            at: DateTime.now()),
      ],
    ));
  }

  /// Try to stick a matching card. Anyone can attempt at any time during
  /// playing/finalRound. If `targetPlayerId == playerId` it's a self-stick;
  /// per house rules we forbid self-sticking your own discard, but allow
  /// sticking any matching card you hold against any prior discard.
  /// Wrong stick → penalty (one card from stock added to sticker's hand).
  static CambioResult stick({
    required CambioState s,
    required String stickerId,
    required String ownerPlayerId,
    required int position,
  }) {
    if (s.phase != CambioPhase.playing &&
        s.phase != CambioPhase.finalRound) {
      return const CambioResult.failure('Not in play');
    }
    if (s.discard.isEmpty) {
      return const CambioResult.failure('No discard to match');
    }
    final topRank = PlayingCard.fromId(s.discard.last).rank;
    final ownerHand = List<String>.from(s.hands[ownerPlayerId] ?? const []);
    if (position < 0 || position >= ownerHand.length) {
      return const CambioResult.failure('Bad position');
    }
    final stuckCard = PlayingCard.fromId(ownerHand[position]);
    final stickerName = s.players.firstWhere((p) => p.id == stickerId).name;
    final ownerName =
        s.players.firstWhere((p) => p.id == ownerPlayerId).name;
    if (stuckCard.rank == topRank) {
      // Correct stick: remove the card.
      ownerHand.removeAt(position);
      final newDiscard = [...s.discard, stuckCard.id];
      return CambioResult.success(s.copyWith(
        hands: {...s.hands, ownerPlayerId: ownerHand},
        discard: newDiscard,
        log: [
          ...s.log,
          CambioLogEntry(
              text:
                  '$stickerName stuck $ownerName slot ${position + 1} = ${_label(stuckCard)} ✓',
              at: DateTime.now()),
        ],
      ));
    } else {
      // Wrong stick: penalty card from stock to sticker (face-down to them).
      var stock = List<String>.from(s.stock);
      var discard = List<String>.from(s.discard);
      if (stock.isEmpty && discard.length > 1) {
        final top = discard.removeLast();
        stock = List<String>.from(discard)..shuffle(Random(s.seed + 7));
        discard = [top];
      }
      String? penalty;
      if (stock.isNotEmpty) penalty = stock.removeLast();
      final stickerHand = List<String>.from(s.hands[stickerId]!);
      if (penalty != null) stickerHand.add(penalty);
      return CambioResult.success(s.copyWith(
        stock: stock,
        discard: discard,
        hands: {...s.hands, stickerId: stickerHand},
        log: [
          ...s.log,
          CambioLogEntry(
              text:
                  '$stickerName wrongly stuck $ownerName slot ${position + 1}: ${_label(stuckCard)} ≠ ${topRank.short}. Penalty card.',
              at: DateTime.now()),
        ],
      ));
    }
  }

  /// Call Cambio: only on your turn, before drawing or any other action.
  /// Everyone else gets one final turn, then scores are computed.
  static CambioResult callCambio(CambioState s, String playerId) {
    if (s.phase != CambioPhase.playing) {
      return const CambioResult.failure('Cannot call Cambio now');
    }
    if (s.currentPlayer.id != playerId) {
      return const CambioResult.failure("It's not your turn");
    }
    if (s.drawn != null || s.pending != null) {
      return const CambioResult.failure(
          'Cambio must be called before doing anything else this turn');
    }
    final name = s.players.firstWhere((p) => p.id == playerId).name;
    final next = s.copyWith(
      phase: CambioPhase.finalRound,
      cambioCallerId: playerId,
      finalRoundRemaining: s.players.length - 1,
      currentIdx: (s.currentIdx + 1) % s.players.length,
      log: [
        ...s.log,
        CambioLogEntry(
            text: '$name called CAMBIO! Everyone else gets one more turn.',
            at: DateTime.now()),
      ],
    );
    return CambioResult.success(next);
  }

  /// Compute final scores and finish.
  static CambioResult _finish(CambioState s) {
    final scores = <String, int>{};
    for (final p in s.players) {
      var sum = 0;
      for (final cid in s.hands[p.id] ?? const []) {
        sum += _scoreOf(PlayingCard.fromId(cid));
      }
      scores[p.id] = sum;
    }
    // Lowest wins. Tiebreakers: non-caller wins; among non-callers, lowest
    // single card wins.
    final low = scores.values.reduce(min);
    final lowest = scores.entries.where((e) => e.value == low).toList();
    String winnerId;
    if (lowest.length == 1) {
      winnerId = lowest.first.key;
    } else {
      final nonCallers = lowest.where((e) => e.key != s.cambioCallerId).toList();
      if (nonCallers.length == 1) {
        winnerId = nonCallers.first.key;
      } else if (nonCallers.isNotEmpty) {
        // Compare smallest single card.
        nonCallers.sort((a, b) {
          final aMin = _smallestCard(s.hands[a.key]!);
          final bMin = _smallestCard(s.hands[b.key]!);
          return aMin.compareTo(bMin);
        });
        winnerId = nonCallers.first.key;
      } else {
        // Only the caller has the low — the caller wins by default.
        winnerId = lowest.first.key;
      }
    }
    return CambioResult.success(s.copyWith(
      phase: CambioPhase.finished,
      finalScores: scores,
      winnerId: winnerId,
      log: [
        ...s.log,
        CambioLogEntry(
            text: 'Scores: ${scores.entries.map((e) => "${s.players.firstWhere((p) => p.id == e.key).name}=${e.value}").join(", ")}. Winner: ${s.players.firstWhere((p) => p.id == winnerId).name}.',
            at: DateTime.now()),
      ],
    ));
  }

  /// Advance the turn after a normal action concludes. If we're in the final
  /// round and have used up all remaining turns, finish the game.
  static CambioResult _afterTurn(CambioState s) {
    if (s.phase == CambioPhase.finalRound) {
      final remaining = s.finalRoundRemaining - 1;
      if (remaining <= 0) {
        return _finish(s.copyWith(finalRoundRemaining: 0));
      }
      return CambioResult.success(s.copyWith(
        currentIdx: (s.currentIdx + 1) % s.players.length,
        finalRoundRemaining: remaining,
      ));
    }
    return CambioResult.success(s.copyWith(
      currentIdx: (s.currentIdx + 1) % s.players.length,
    ));
  }

  // --- helpers ---

  static PendingPowerType? _powerFor(PlayingCard c) {
    switch (c.rank) {
      case Rank.seven:
      case Rank.eight:
        return PendingPowerType.peekOwn;
      case Rank.nine:
      case Rank.ten:
        return PendingPowerType.peekOther;
      case Rank.jack:
      case Rank.queen:
        return PendingPowerType.blindSwitchPickMine;
      case Rank.king:
        if (c.suit.isBlack) return PendingPowerType.kingLook;
        return null; // red king has no power
      default:
        return null;
    }
  }

  static int _scoreOf(PlayingCard c) {
    if (c.isJoker) return 0;
    if (c.rank == Rank.king && c.suit.isRed) return -1;
    if (c.rank == Rank.king) return 10; // black king
    if (c.rank == Rank.queen || c.rank == Rank.jack) return 10;
    if (c.rank == Rank.ace) return 1;
    // numeric
    return switch (c.rank) {
      Rank.two => 2,
      Rank.three => 3,
      Rank.four => 4,
      Rank.five => 5,
      Rank.six => 6,
      Rank.seven => 7,
      Rank.eight => 8,
      Rank.nine => 9,
      Rank.ten => 10,
      _ => 0,
    };
  }

  static int _smallestCard(List<String> hand) {
    if (hand.isEmpty) return 100;
    return hand.map((id) => _scoreOf(PlayingCard.fromId(id))).reduce(min);
  }

  static String _label(PlayingCard c) {
    if (c.isJoker) return c.isBlackJoker ? 'Black Joker' : 'Colored Joker';
    return '${c.rank.short}${c.suit.symbol}';
  }
}
