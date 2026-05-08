import 'dart:math';

import '../../shared/card_model.dart';
import 'models.dart';

class OcResult {
  final bool ok;
  final String? error;
  final OcState? next;
  const OcResult.success(this.next)
      : ok = true,
        error = null;
  const OcResult.failure(this.error)
      : ok = false,
        next = null;
}

/// One Card — a Crazy-Eights-with-attacks variant. See README for full rules.
class OneCardEngine {
  static OcState newLobby({
    required String gameId,
    required String hostId,
    required String hostName,
    required int seed,
  }) =>
      OcState(
        gameId: gameId,
        hostId: hostId,
        phase: OcPhase.lobby,
        players: [OcPlayer(id: hostId, name: hostName, isHost: true)],
        hands: const {},
        stock: const [],
        discard: const [],
        currentIdx: 0,
        direction: 1,
        pendingAttack: 0,
        declaredSuit: null,
        winnerId: null,
        seed: seed,
        log: const [],
      );

  static OcState addPlayer(OcState s, OcPlayer p) {
    if (s.phase != OcPhase.lobby) return s;
    if (s.players.any((x) => x.id == p.id)) return s;
    return s.copyWith(players: [...s.players, p]);
  }

  static OcResult startGame(OcState s) {
    if (s.phase != OcPhase.lobby) {
      return const OcResult.failure('Game already started');
    }
    if (s.players.length < 2) {
      return const OcResult.failure('Need at least 2 players');
    }
    final cards = Decks.standard54()..shuffle(Random(s.seed));
    final perPlayer = s.players.length == 2 ? 7 : 5;
    final hands = <String, List<String>>{};
    var idx = 0;
    for (final p in s.players) {
      hands[p.id] = cards.sublist(idx, idx + perPlayer).map((c) => c.id).toList();
      idx += perPlayer;
    }
    // First face-up. If it's a joker, bury it and try again until non-joker.
    String firstId = cards[idx++].id;
    while (PlayingCard.fromId(firstId).isJoker && idx < cards.length) {
      cards.add(PlayingCard.fromId(firstId));
      firstId = cards[idx++].id;
    }
    final stock = cards.sublist(idx).map((c) => c.id).toList();
    return OcResult.success(s.copyWith(
      phase: OcPhase.playing,
      hands: hands,
      stock: stock,
      discard: [firstId],
      currentIdx: 0,
      direction: 1,
      pendingAttack: 0,
      log: [
        ...s.log,
        OcLogEntry(
            text: 'Dealt $perPlayer to each. Top: ${_label(PlayingCard.fromId(firstId))}.',
            at: DateTime.now()),
      ],
    ));
  }

  /// Validate that `card` (in `playerId`'s hand) is legal to play given the
  /// current top discard / pending attack.
  static String? validatePlay({
    required OcState s,
    required String playerId,
    required PlayingCard card,
    Suit? declaredSuitForSeven,
  }) {
    if (s.phase != OcPhase.playing) return 'Game is not in progress';
    if (s.currentPlayer.id != playerId) return "It's not your turn";
    if (!s.handFor(playerId).contains(card)) {
      return "You don't have that card";
    }
    final top = s.topDiscard;
    final attackPending = s.pendingAttack > 0;

    // When defending an attack, only attack cards or a 3-shield can be played.
    if (attackPending) {
      if (_isAttack(card)) {
        // Colored joker still gated on red top.
        if (card.isColoredJoker && !top.suit.isRed) {
          return 'Colored joker only plays on a red card';
        }
        return null; // chain
      }
      if (card.rank == Rank.three) return null; // shield
      return 'Attack pending — play another attack, a 3 (shield), or draw';
    }

    // Wilds (always playable when no attack pending).
    if (card.rank == Rank.seven) {
      if (declaredSuitForSeven == null || declaredSuitForSeven == Suit.joker) {
        return 'Pick a suit when you play a 7';
      }
      return null;
    }
    if (card.isBlackJoker) return null; // black joker = wild attack 7
    if (card.isColoredJoker) {
      if (!s.activeSuit.isRed) {
        return 'Colored joker only plays on a red card';
      }
      return null;
    }

    // Non-wild: must match active suit or rank.
    if (card.suit == s.activeSuit) return null;
    if (card.rank == top.rank) return null;
    return 'Card must match suit or rank — try drawing';
  }

  static OcResult play({
    required OcState s,
    required String playerId,
    required PlayingCard card,
    Suit? declaredSuitForSeven,
  }) {
    final err = validatePlay(
      s: s,
      playerId: playerId,
      card: card,
      declaredSuitForSeven: declaredSuitForSeven,
    );
    if (err != null) return OcResult.failure(err);

    final hand = List<String>.from(s.hands[playerId]!);
    hand.remove(card.id);
    final newHands = {...s.hands, playerId: hand};
    final newDiscard = [...s.discard, card.id];

    int newAttack = s.pendingAttack;
    int newDir = s.direction;
    String? newDeclaredSuit;
    bool clearDeclaredSuit = true;
    bool extraTurn = false; // King: same player plays again
    bool skipNext = false; // Jack: skip the next player
    var logText = '${s.players.firstWhere((p) => p.id == playerId).name} '
        'played ${_label(card)}';

    final wasDefendingWithShield =
        s.pendingAttack > 0 && card.rank == Rank.three;

    if (wasDefendingWithShield) {
      newAttack = 0;
      logText += ' as a SHIELD — attack blocked';
    } else if (_isAttack(card)) {
      newAttack += _attackValue(card);
      logText += ' (attack +${_attackValue(card)}, total $newAttack)';
    } else if (card.rank == Rank.king) {
      extraTurn = true;
      logText += ' (King — extra turn)';
    } else if (card.rank == Rank.queen) {
      if (s.players.length == 2) {
        skipNext = true;
        logText += ' (Queen — skip in 2-player)';
      } else {
        newDir = -newDir;
        logText += ' (Queen — direction reversed)';
      }
    } else if (card.rank == Rank.jack) {
      skipNext = true;
      logText += ' (Jack — next player skipped)';
    } else if (card.rank == Rank.seven) {
      newDeclaredSuit = declaredSuitForSeven!.name;
      clearDeclaredSuit = false;
      logText += ' → suit is now ${declaredSuitForSeven.symbol}';
    }

    // Win check
    String? winnerId;
    OcPhase nextPhase = s.phase;
    if (hand.isEmpty) {
      winnerId = playerId;
      nextPhase = OcPhase.finished;
      logText += '. Hand empty — wins!';
    }

    int nextIdx = s.currentIdx;
    if (nextPhase == OcPhase.playing) {
      if (extraTurn) {
        // Same player.
      } else {
        nextIdx = _advance(s, newDir);
        if (skipNext) nextIdx = _advance(s.copyWith(currentIdx: nextIdx), newDir);
      }
    }

    return OcResult.success(s.copyWith(
      phase: nextPhase,
      hands: newHands,
      discard: newDiscard,
      currentIdx: nextIdx,
      direction: newDir,
      pendingAttack: newAttack,
      declaredSuit: newDeclaredSuit,
      clearDeclaredSuit: clearDeclaredSuit && newDeclaredSuit == null,
      winnerId: winnerId,
      log: [
        ...s.log,
        OcLogEntry(text: logText, at: DateTime.now()),
      ],
    ));
  }

  /// Draw cards. If pendingAttack > 0, draw that many and absorb the attack;
  /// else draw 1. Either way the turn passes.
  static OcResult draw({required OcState s, required String playerId}) {
    if (s.phase != OcPhase.playing) {
      return const OcResult.failure('Game is not in progress');
    }
    if (s.currentPlayer.id != playerId) {
      return const OcResult.failure("It's not your turn");
    }
    final n = s.pendingAttack > 0 ? s.pendingAttack : 1;
    var stock = List<String>.from(s.stock);
    var discard = List<String>.from(s.discard);
    final taken = <String>[];
    for (var i = 0; i < n; i++) {
      if (stock.isEmpty) {
        // Reshuffle discard (except top) into stock.
        if (discard.length <= 1) break;
        final top = discard.removeLast();
        stock = List<String>.from(discard)..shuffle(Random(s.seed + i));
        discard = [top];
      }
      taken.add(stock.removeLast());
    }
    final newHands = {
      ...s.hands,
      playerId: [...s.hands[playerId]!, ...taken],
    };
    final nextIdx = _advance(s, s.direction);
    final name = s.players.firstWhere((p) => p.id == playerId).name;
    final attackText = s.pendingAttack > 0
        ? ' (absorbed ${s.pendingAttack} from attack)'
        : '';
    return OcResult.success(s.copyWith(
      hands: newHands,
      stock: stock,
      discard: discard,
      currentIdx: nextIdx,
      pendingAttack: 0,
      log: [
        ...s.log,
        OcLogEntry(
            text: '$name drew ${taken.length}$attackText',
            at: DateTime.now()),
      ],
    ));
  }

  // --- helpers ---

  static int _advance(OcState s, int direction) {
    final n = s.players.length;
    return ((s.currentIdx + direction) % n + n) % n;
  }

  static bool _isAttack(PlayingCard c) =>
      c.rank == Rank.two || c.rank == Rank.ace || c.isJoker;

  static int _attackValue(PlayingCard c) {
    if (c.rank == Rank.two) return 2;
    if (c.rank == Rank.ace) return 3;
    if (c.isBlackJoker) return 7;
    if (c.isColoredJoker) return 10;
    return 0;
  }

  static String _label(PlayingCard c) {
    if (c.isJoker) {
      return c.isBlackJoker ? 'Black Joker' : 'Colored Joker';
    }
    return '${c.rank.short}${c.suit.symbol}';
  }
}
