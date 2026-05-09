import 'dart:math';

import 'models.dart';

class DvResult {
  final bool ok;
  final String? error;
  final DvState? next;
  const DvResult.success(this.next)
      : ok = true,
        error = null;
  const DvResult.failure(this.error)
      : ok = false,
        next = null;
}

/// Da Vinci Code engine. 26 blocks (white & black, 0..11 + joker each).
/// Each player keeps a sorted hand. On your turn: draw, place (joker
/// position chosen), guess one of any opponent's blocks. Right → opponent
/// reveals, you can guess again or stop. Wrong → your drawn block is
/// revealed, turn ends. Last player with hidden blocks wins.
class DaVinciEngine {
  static List<DvBlock> standardSet() {
    final out = <DvBlock>[];
    for (final c in DvColor.values) {
      for (var v = 0; v <= 11; v++) {
        out.add(DvBlock(color: c, value: v));
      }
      out.add(DvBlock(color: c, value: null)); // joker
    }
    assert(out.length == 26);
    return out;
  }

  static DvState newLobby({
    required String gameId,
    required String hostId,
    required String hostName,
    required int seed,
  }) =>
      DvState(
        gameId: gameId,
        hostId: hostId,
        phase: DvPhase.lobby,
        players: [DvPlayer(id: hostId, name: hostName, isHost: true)],
        hands: const {},
        stock: const [],
        drawn: null,
        currentIdx: 0,
        awaitingChoiceAfterCorrect: false,
        winnerId: null,
        seed: seed,
        log: const [],
      );

  static DvState addPlayer(DvState s, DvPlayer p) {
    if (s.phase != DvPhase.lobby) return s;
    if (s.players.any((x) => x.id == p.id)) return s;
    return s.copyWith(players: [...s.players, p]);
  }

  static DvResult startGame(DvState s) {
    if (s.phase != DvPhase.lobby) {
      return const DvResult.failure('Game already started');
    }
    if (s.players.length < 2 || s.players.length > 4) {
      return const DvResult.failure('Da Vinci Code is for 2-4 players');
    }
    final perPlayer = s.players.length <= 3 ? 4 : 3;
    final all = standardSet()..shuffle(Random(s.seed));
    // Reroll any starting joker per the official rule (no jokers in starting
    // hand) — repeatedly take from front, swap any joker into the back of
    // the stock.
    final hands = <String, List<DvBlock>>{};
    var idx = 0;
    for (final p in s.players) {
      final taken = <DvBlock>[];
      while (taken.length < perPlayer) {
        if (idx >= all.length) break;
        final b = all[idx++];
        if (b.isJoker) {
          // Stash joker at end and continue.
          all.add(b);
          continue;
        }
        taken.add(b);
      }
      taken.sort(_sortKey);
      hands[p.id] = taken;
    }
    final stock = all.sublist(idx);
    return DvResult.success(s.copyWith(
      phase: DvPhase.playing,
      hands: hands,
      stock: stock,
      currentIdx: 0,
      log: [
        ...s.log,
        DvLogEntry(
            text: 'Dealt $perPlayer blocks each (${stock.length} in stock).',
            at: DateTime.now()),
      ],
    ));
  }

  /// Sort comparator: ascending by value; ties → black first; jokers don't
  /// auto-sort (the player chooses where to place a joker, so jokers are
  /// inserted at a chosen position and skipped by this comparator).
  static int _sortKey(DvBlock a, DvBlock b) {
    final av = a.value ?? -1;
    final bv = b.value ?? -1;
    if (av != bv) return av.compareTo(bv);
    return a.colorOrder.compareTo(b.colorOrder);
  }

  /// Current player draws the top of the stock. Block goes into `drawn`,
  /// hidden from others. If it's a non-joker the player can simply call
  /// `placeDrawn`; if it's a joker the player picks a position via
  /// `placeDrawnAt`.
  static DvResult drawFromStock(DvState s, String playerId) {
    if (s.phase != DvPhase.playing) {
      return const DvResult.failure('Game not in progress');
    }
    if (s.currentPlayer.id != playerId) {
      return const DvResult.failure("Not your turn");
    }
    if (s.drawn != null) {
      return const DvResult.failure('You already drew');
    }
    if (s.awaitingChoiceAfterCorrect) {
      return const DvResult.failure('Stop or guess — already drew earlier');
    }
    if (s.stock.isEmpty) {
      // Nothing to draw — skip phase, must just guess. We allow guess
      // without drawing only when stock is empty.
      return const DvResult.failure('Stock is empty — call passTurn or guess');
    }
    final stock = List<DvBlock>.from(s.stock);
    final top = stock.removeLast();
    return DvResult.success(s.copyWith(
      stock: stock,
      drawn: DvDrawn(playerId: playerId, block: top),
    ));
  }

  /// Place the drawn (non-joker) block into the player's hand at the
  /// auto-sorted position.
  static DvResult placeDrawn(DvState s, String playerId) {
    if (s.drawn == null || s.drawn!.playerId != playerId) {
      return const DvResult.failure('No drawn block');
    }
    if (s.drawn!.block.isJoker) {
      return const DvResult.failure(
          'Joker drawn — pick a position with placeDrawnAt');
    }
    final block = s.drawn!.block;
    final hand = [...?s.hands[playerId], block]..sort(_sortKey);
    return DvResult.success(s.copyWith(
      hands: {...s.hands, playerId: hand},
      clearDrawn: true,
    ));
  }

  /// Place the drawn block at a specific position. Required for jokers;
  /// allowed for non-jokers but the position is ignored unless it matches
  /// the sorted position. (We still accept it for UI uniformity.)
  static DvResult placeDrawnAt(DvState s, String playerId, int position) {
    if (s.drawn == null || s.drawn!.playerId != playerId) {
      return const DvResult.failure('No drawn block');
    }
    final cur = List<DvBlock>.from(s.hands[playerId] ?? const []);
    if (position < 0 || position > cur.length) {
      return const DvResult.failure('Bad position');
    }
    final block = s.drawn!.block;
    cur.insert(position, block);
    return DvResult.success(s.copyWith(
      hands: {...s.hands, playerId: cur},
      clearDrawn: true,
    ));
  }

  /// Guess an opponent's block at `position` to be `value` (null = joker).
  /// On a correct guess: opponent's block flips revealed; the guesser then
  /// has the choice to guess again or stop (`awaitingChoiceAfterCorrect`).
  /// On a wrong guess: the guesser's drawn block is revealed and added to
  /// their hand at the sorted position; turn passes.
  static DvResult guess({
    required DvState s,
    required String guesserId,
    required String targetId,
    required int position,
    required int? value,
  }) {
    if (s.phase != DvPhase.playing) {
      return const DvResult.failure('Game not in progress');
    }
    if (s.currentPlayer.id != guesserId) {
      return const DvResult.failure('Not your turn');
    }
    if (s.drawn == null && !s.awaitingChoiceAfterCorrect) {
      return const DvResult.failure('Draw a block first');
    }
    if (targetId == guesserId) {
      return const DvResult.failure("Can't guess your own block");
    }
    final targetHand = s.hands[targetId];
    if (targetHand == null ||
        position < 0 ||
        position >= targetHand.length) {
      return const DvResult.failure('Bad position');
    }
    final block = targetHand[position];
    if (block.revealed) {
      return const DvResult.failure('Already revealed');
    }
    final guesserName =
        s.players.firstWhere((p) => p.id == guesserId).name;
    final targetName =
        s.players.firstWhere((p) => p.id == targetId).name;
    final guessLabel = value == null ? 'joker' : '$value';

    final correct = block.value == value;
    if (correct) {
      final newTargetHand = [...targetHand];
      newTargetHand[position] = block.copyWith(revealed: true);
      final newHands = {...s.hands, targetId: newTargetHand};
      // Win check: any player with all blocks revealed is out.
      final remaining = s.players.where((p) {
        final hand = newHands[p.id] ?? const [];
        return hand.any((b) => !b.revealed);
      }).toList();
      String? winnerId;
      DvPhase nextPhase = s.phase;
      if (remaining.length == 1) {
        winnerId = remaining.first.id;
        nextPhase = DvPhase.finished;
      }
      return DvResult.success(s.copyWith(
        hands: newHands,
        phase: nextPhase,
        winnerId: winnerId,
        awaitingChoiceAfterCorrect: nextPhase == DvPhase.playing,
        log: [
          ...s.log,
          DvLogEntry(
              text:
                  '$guesserName guessed $targetName slot ${position + 1} = $guessLabel ✓',
              at: DateTime.now()),
        ],
      ));
    }
    // Wrong: reveal the guesser's drawn block (if any) and add to hand.
    final newHands = {...s.hands};
    if (s.drawn != null) {
      final revealed = s.drawn!.block.copyWith(revealed: true);
      final hand = [...?newHands[guesserId], revealed];
      hand.sort(_sortKey);
      newHands[guesserId] = hand;
    }
    // Win check after possible reveal.
    final remaining = s.players.where((p) {
      final hand = newHands[p.id] ?? const [];
      return hand.any((b) => !b.revealed);
    }).toList();
    String? winnerId;
    DvPhase nextPhase = s.phase;
    if (remaining.length == 1) {
      winnerId = remaining.first.id;
      nextPhase = DvPhase.finished;
    }
    int nextIdx = s.currentIdx;
    if (nextPhase == DvPhase.playing) {
      nextIdx = _nextActive(s, newHands);
    }
    return DvResult.success(s.copyWith(
      hands: newHands,
      phase: nextPhase,
      winnerId: winnerId,
      currentIdx: nextIdx,
      clearDrawn: true,
      awaitingChoiceAfterCorrect: false,
      log: [
        ...s.log,
        DvLogEntry(
            text:
                '$guesserName guessed $targetName slot ${position + 1} = $guessLabel ✗ (drew block revealed)',
            at: DateTime.now()),
      ],
    ));
  }

  /// After a correct guess the guesser may choose to stop. Their drawn
  /// block (if any) stays hidden — slid into hand at the sorted position.
  static DvResult stopAfterCorrect(DvState s, String playerId) {
    if (s.currentPlayer.id != playerId) {
      return const DvResult.failure('Not your turn');
    }
    if (!s.awaitingChoiceAfterCorrect) {
      return const DvResult.failure('No correct guess to stop on');
    }
    final newHands = {...s.hands};
    if (s.drawn != null) {
      final block = s.drawn!.block;
      // For jokers we use placeDrawnAt; if reaching here with a joker
      // still in `drawn`, slot it at the leftmost position by default.
      if (block.isJoker) {
        final hand = [block, ...?newHands[playerId]];
        newHands[playerId] = hand;
      } else {
        final hand = [...?newHands[playerId], block]..sort(_sortKey);
        newHands[playerId] = hand;
      }
    }
    return DvResult.success(s.copyWith(
      hands: newHands,
      clearDrawn: true,
      awaitingChoiceAfterCorrect: false,
      currentIdx: _nextActive(s, newHands),
    ));
  }

  static int _nextActive(DvState s, Map<String, List<DvBlock>> hands) {
    final n = s.players.length;
    var idx = (s.currentIdx + 1) % n;
    for (var i = 0; i < n; i++) {
      final p = s.players[idx];
      final hand = hands[p.id] ?? const [];
      if (hand.any((b) => !b.revealed)) return idx;
      idx = (idx + 1) % n;
    }
    return s.currentIdx;
  }
}
