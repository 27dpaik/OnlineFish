import 'dart:math';

import '../../shared/card_model.dart';
import 'half_suite.dart';
import 'models.dart';

class MoveResult {
  final bool ok;
  final String? error;
  final LitGameState? next;
  const MoveResult.success(this.next)
      : ok = true,
        error = null;
  const MoveResult.failure(this.error)
      : ok = false,
        next = null;
}

class LiteratureEngine {
  static const seatOrder = ['A1', 'A2', 'A3', 'B1', 'B2', 'B3'];

  static List<LitSeat> emptySeats() => const [
        LitSeat(id: 'A1', team: TeamId.a, positionInTeam: 1, playerIds: []),
        LitSeat(id: 'A2', team: TeamId.a, positionInTeam: 2, playerIds: []),
        LitSeat(id: 'A3', team: TeamId.a, positionInTeam: 3, playerIds: []),
        LitSeat(id: 'B1', team: TeamId.b, positionInTeam: 1, playerIds: []),
        LitSeat(id: 'B2', team: TeamId.b, positionInTeam: 2, playerIds: []),
        LitSeat(id: 'B3', team: TeamId.b, positionInTeam: 3, playerIds: []),
      ];

  static LitGameState newLobby({
    required String gameId,
    required String hostId,
    required String hostName,
    required int seed,
  }) {
    final host = LitPlayer(id: hostId, name: hostName, isHost: true);
    return LitGameState(
      gameId: gameId,
      hostId: hostId,
      phase: LitPhase.lobby,
      seats: emptySeats(),
      players: {hostId: host},
      hands: const {},
      currentSeatId: null,
      claimedHalfSuites: const {},
      log: const [],
      winner: null,
      seed: seed,
    );
  }

  static LitGameState addPlayer(LitGameState s, LitPlayer p) {
    if (s.phase != LitPhase.lobby) return s;
    return s.copyWith(players: {...s.players, p.id: p});
  }

  static MoveResult sitPlayer(LitGameState s, String playerId, String seatId) {
    if (s.phase != LitPhase.lobby) {
      return const MoveResult.failure('Cannot change seats once the game has started');
    }
    if (!s.players.containsKey(playerId)) {
      return const MoveResult.failure('Unknown player');
    }
    var seats = s.seats.map((seat) {
      if (seat.playerIds.contains(playerId)) {
        return seat.copyWith(
          playerIds: seat.playerIds.where((id) => id != playerId).toList(),
        );
      }
      return seat;
    }).toList();
    seats = seats.map((seat) {
      if (seat.id == seatId) {
        return seat.copyWith(playerIds: [...seat.playerIds, playerId]);
      }
      return seat;
    }).toList();
    final players = {
      ...s.players,
      playerId: s.players[playerId]!.copyWith(seatId: seatId),
    };
    return MoveResult.success(s.copyWith(seats: seats, players: players));
  }

  static MoveResult startGame(LitGameState s, {String? startingSeatId}) {
    if (s.phase != LitPhase.lobby) {
      return const MoveResult.failure('Game already started');
    }
    for (final seat in s.seats) {
      if (seat.playerIds.isEmpty) {
        return MoveResult.failure('Seat ${seat.id} has no player');
      }
    }
    final hands = _dealToSeats(seatOrder, s.seed);
    final start = startingSeatId ?? 'A1';
    return MoveResult.success(s.copyWith(
      phase: LitPhase.playing,
      hands: hands,
      currentSeatId: start,
      log: [
        ...s.log,
        LitLogEntry(
          kind: 'info',
          text: 'Game started. ${s.seatLabel(start)} plays first.',
          at: DateTime.now(),
        ),
      ],
    ));
  }

  static Map<String, List<String>> _dealToSeats(List<String> order, int seed) {
    final cards = Decks.standard54();
    cards.shuffle(Random(seed));
    final hands = <String, List<String>>{};
    for (var i = 0; i < 6; i++) {
      hands[order[i]] =
          cards.sublist(i * 9, (i + 1) * 9).map((c) => c.id).toList()..sort();
    }
    return hands;
  }

  static MoveResult ask({
    required LitGameState s,
    required String askerSeatId,
    required String targetSeatId,
    required PlayingCard card,
  }) {
    if (s.phase != LitPhase.playing) {
      return const MoveResult.failure('Game is not in progress');
    }
    if (s.currentSeatId != askerSeatId) {
      return const MoveResult.failure("It's not your team's turn");
    }
    final asker = s.seatById(askerSeatId);
    final target = s.seatById(targetSeatId);
    if (asker.team == target.team) {
      return const MoveResult.failure('You can only ask the other team');
    }
    final askerHand = s.handFor(askerSeatId);
    if (askerHand.isEmpty) {
      return const MoveResult.failure('Empty hand cannot ask');
    }
    if (askerHand.contains(card)) {
      return const MoveResult.failure('You already have that card');
    }
    final hs = HalfSuites.forCard(card);
    final hasInHalfSuite = askerHand.any(hs.contains);
    if (!hasInHalfSuite) {
      return MoveResult.failure(
          'You must hold a card in ${hs.name} to ask for that');
    }
    final targetHand = s.handFor(targetSeatId);
    if (targetHand.isEmpty) {
      return const MoveResult.failure('Target seat has no cards');
    }
    final success = targetHand.contains(card);
    final newHands = Map<String, List<String>>.from(s.hands);
    if (success) {
      newHands[targetSeatId] =
          List<String>.from(newHands[targetSeatId]!)..remove(card.id);
      newHands[askerSeatId] = (List<String>.from(newHands[askerSeatId]!)
        ..add(card.id))
        ..sort();
    }
    final askerName = _seatLabel(s, askerSeatId);
    final targetName = _seatLabel(s, targetSeatId);
    final logText = success
        ? '$askerName asked $targetName for ${_cardLabel(card)} → got it.'
        : '$askerName asked $targetName for ${_cardLabel(card)} → no, turn passes.';
    String? nextSeat = success ? askerSeatId : targetSeatId;
    if (newHands[nextSeat]?.isEmpty ?? false) {
      nextSeat = _findNextSeatWithCards(s, fromSeat: nextSeat);
    }
    return MoveResult.success(s.copyWith(
      hands: newHands,
      currentSeatId: nextSeat,
      log: [
        ...s.log,
        LitLogEntry(
          kind: 'ask',
          text: logText,
          at: DateTime.now(),
          askerSeatId: askerSeatId,
          targetSeatId: targetSeatId,
          cardId: card.id,
          success: success,
        ),
      ],
    ));
  }

  static MoveResult declare({
    required LitGameState s,
    required String declarerSeatId,
    required String halfSuiteId,
    required Map<String, String> assignment,
  }) {
    if (s.phase != LitPhase.playing) {
      return const MoveResult.failure('Game is not in progress');
    }
    final declarer = s.seatById(declarerSeatId);
    final hs = HalfSuites.byId(halfSuiteId);
    if (s.claimedHalfSuites.containsKey(halfSuiteId)) {
      return const MoveResult.failure('That half-suite has already been won');
    }
    final teamSeatIds = s.seatsOnTeam(declarer.team).map((e) => e.id).toSet();
    for (final entry in assignment.entries) {
      if (!teamSeatIds.contains(entry.value)) {
        return MoveResult.failure(
            'Assigned seat ${entry.value} is not on your team');
      }
    }
    final cardIds = hs.cards.map((c) => c.id).toSet();
    if (assignment.length != cardIds.length ||
        !assignment.keys.toSet().containsAll(cardIds)) {
      return const MoveResult.failure(
          'You must assign every card in the half-suite');
    }
    bool correct = true;
    for (final entry in assignment.entries) {
      final actualSeat = _seatHoldingCard(s, entry.key);
      if (actualSeat != entry.value) {
        correct = false;
        break;
      }
    }
    final winner = correct ? declarer.team : declarer.team.opponent;
    final newHands = Map<String, List<String>>.from(s.hands);
    for (final cid in cardIds) {
      for (final seatId in newHands.keys) {
        newHands[seatId] = List<String>.from(newHands[seatId]!)..remove(cid);
      }
    }
    final newClaimed = {...s.claimedHalfSuites, halfSuiteId: winner};
    final declarerName = _seatLabel(s, declarerSeatId);
    final logText = correct
        ? '$declarerName declared ${hs.name} → CORRECT. ${winner.label} wins it.'
        : '$declarerName declared ${hs.name} → WRONG. ${winner.label} wins it.';
    final allClaimed = newClaimed.length == HalfSuites.all.length;
    LitPhase newPhase = s.phase;
    TeamId? overallWinner;
    String? nextSeat = s.currentSeatId;
    if (allClaimed) {
      newPhase = LitPhase.finished;
      final aScore = newClaimed.values.where((t) => t == TeamId.a).length;
      overallWinner = aScore > newClaimed.length / 2 ? TeamId.a : TeamId.b;
    } else {
      nextSeat = _firstSeatOnTeamWithCards(s.copyWith(hands: newHands), winner) ??
          _firstSeatOnTeamWithCards(
              s.copyWith(hands: newHands), winner.opponent);
    }
    return MoveResult.success(s.copyWith(
      phase: newPhase,
      hands: newHands,
      claimedHalfSuites: newClaimed,
      currentSeatId: nextSeat,
      winner: overallWinner,
      log: [
        ...s.log,
        LitLogEntry(
          kind: 'declare',
          text: logText,
          at: DateTime.now(),
          askerSeatId: declarerSeatId,
          halfSuiteId: halfSuiteId,
          success: correct,
          winnerTeam: winner.name,
        ),
      ],
    ));
  }

  static String _seatHoldingCard(LitGameState s, String cardId) {
    for (final entry in s.hands.entries) {
      if (entry.value.contains(cardId)) return entry.key;
    }
    return '';
  }

  static String? _findNextSeatWithCards(LitGameState s, {required String fromSeat}) {
    final fromTeam = s.seatById(fromSeat).team;
    if ((s.hands[fromSeat]?.isNotEmpty ?? false)) return fromSeat;
    for (final seat in s.seatsOnTeam(fromTeam)) {
      if ((s.hands[seat.id]?.isNotEmpty ?? false)) return seat.id;
    }
    for (final seat in s.seatsOnTeam(fromTeam.opponent)) {
      if ((s.hands[seat.id]?.isNotEmpty ?? false)) return seat.id;
    }
    return null;
  }

  static String? _firstSeatOnTeamWithCards(LitGameState s, TeamId team) {
    for (final seat in s.seatsOnTeam(team)) {
      if ((s.hands[seat.id]?.isNotEmpty ?? false)) return seat.id;
    }
    return null;
  }

  static String _seatLabel(LitGameState s, String seatId) =>
      s.seatLabel(seatId);

  static String _cardLabel(PlayingCard c) {
    if (c.suit == Suit.joker) {
      return c.rank == Rank.jokerBig ? 'Big Joker' : 'Small Joker';
    }
    return '${c.rank.short}${c.suit.symbol}';
  }
}
