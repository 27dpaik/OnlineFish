import '../models/card_model.dart';
import '../models/game_models.dart';
import 'deck.dart';

/// Result of validating a proposed move.
class MoveResult {
  final bool ok;
  final String? error;
  final GameState? next;
  const MoveResult.success(this.next)
      : ok = true,
        error = null;
  const MoveResult.failure(this.error)
      : ok = false,
        next = null;
}

/// Pure functions that drive the game forward. The controller calls these and
/// pushes the resulting state to whichever sync layer (local or Firestore) is
/// in use.
class LiteratureEngine {
  static const seatOrder = ['A1', 'A2', 'A3', 'B1', 'B2', 'B3'];

  /// Build the initial 6 seats with no players assigned.
  static List<Seat> emptySeats() => const [
        Seat(id: 'A1', team: TeamId.a, positionInTeam: 1, playerIds: []),
        Seat(id: 'A2', team: TeamId.a, positionInTeam: 2, playerIds: []),
        Seat(id: 'A3', team: TeamId.a, positionInTeam: 3, playerIds: []),
        Seat(id: 'B1', team: TeamId.b, positionInTeam: 1, playerIds: []),
        Seat(id: 'B2', team: TeamId.b, positionInTeam: 2, playerIds: []),
        Seat(id: 'B3', team: TeamId.b, positionInTeam: 3, playerIds: []),
      ];

  static GameState newLobby({
    required String gameId,
    required String hostId,
    required String hostName,
    required int seed,
  }) {
    final host = Player(id: hostId, name: hostName, isHost: true);
    return GameState(
      gameId: gameId,
      hostId: hostId,
      phase: GamePhase.lobby,
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

  /// Add a player to the lobby. They have no seat yet.
  static GameState addPlayer(GameState s, Player p) {
    if (s.phase != GamePhase.lobby) return s;
    return s.copyWith(players: {...s.players, p.id: p});
  }

  /// Sit a player in a specific seat. Multiple players can share one seat.
  static MoveResult sitPlayer(GameState s, String playerId, String seatId) {
    if (s.phase != GamePhase.lobby) {
      return const MoveResult.failure('Cannot change seats once the game has started');
    }
    if (!s.players.containsKey(playerId)) {
      return const MoveResult.failure('Unknown player');
    }
    // Remove from their current seat (if any).
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

  /// All 6 seats must have ≥1 player to start.
  static MoveResult startGame(GameState s, {String? startingSeatId}) {
    if (s.phase != GamePhase.lobby) {
      return const MoveResult.failure('Game already started');
    }
    for (final seat in s.seats) {
      if (seat.playerIds.isEmpty) {
        return MoveResult.failure('Seat ${seat.id} has no player');
      }
    }
    final hands = Deck.dealToSeats(seatOrder: seatOrder, seed: s.seed);
    final start = startingSeatId ?? 'A1';
    return MoveResult.success(s.copyWith(
      phase: GamePhase.playing,
      hands: hands,
      currentSeatId: start,
      log: [
        ...s.log,
        GameLogEntry(
          kind: 'info',
          text: 'Game started. $start plays first.',
          at: DateTime.now(),
        ),
      ],
    ));
  }

  /// `askerSeat` asks `targetSeat` for `card`.
  ///   - asker must hold ≥1 card in the same half-suite as `card`
  ///   - asker must NOT already hold `card`
  ///   - target must be on the opposing team
  ///   - target must have ≥1 card
  static MoveResult ask({
    required GameState s,
    required String askerSeatId,
    required String targetSeatId,
    required PlayingCard card,
  }) {
    if (s.phase != GamePhase.playing) {
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
        GameLogEntry(kind: 'ask', text: logText, at: DateTime.now()),
      ],
    ));
  }

  /// `declarerSeat` claims a half-suite by mapping each card to the seat that
  /// holds it. `assignment` maps cardId → seatId. Every card in the half-suite
  /// must be present, and every assigned seat must be on the declarer's team.
  static MoveResult declare({
    required GameState s,
    required String declarerSeatId,
    required String halfSuiteId,
    required Map<String, String> assignment,
  }) {
    if (s.phase != GamePhase.playing) {
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
    GamePhase newPhase = s.phase;
    TeamId? overallWinner;
    String? nextSeat = s.currentSeatId;
    if (allClaimed) {
      newPhase = GamePhase.finished;
      final aScore = newClaimed.values.where((t) => t == TeamId.a).length;
      overallWinner = aScore > newClaimed.length / 2 ? TeamId.a : TeamId.b;
    } else {
      // After a declaration, the team that just won the half-suite plays next.
      // Find any seat on `winner` with cards; otherwise the other team plays.
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
        GameLogEntry(kind: 'declare', text: logText, at: DateTime.now()),
      ],
    ));
  }

  // -- helpers --

  static String _seatHoldingCard(GameState s, String cardId) {
    for (final entry in s.hands.entries) {
      if (entry.value.contains(cardId)) return entry.key;
    }
    return '';
  }

  static String? _findNextSeatWithCards(GameState s, {required String fromSeat}) {
    final fromTeam = s.seatById(fromSeat).team;
    // Try the seat itself first (e.g., refilled via successful ask).
    if ((s.hands[fromSeat]?.isNotEmpty ?? false)) return fromSeat;
    // Then any teammate.
    for (final seat in s.seatsOnTeam(fromTeam)) {
      if ((s.hands[seat.id]?.isNotEmpty ?? false)) return seat.id;
    }
    // Otherwise the other team.
    for (final seat in s.seatsOnTeam(fromTeam.opponent)) {
      if ((s.hands[seat.id]?.isNotEmpty ?? false)) return seat.id;
    }
    return null;
  }

  static String? _firstSeatOnTeamWithCards(GameState s, TeamId team) {
    for (final seat in s.seatsOnTeam(team)) {
      if ((s.hands[seat.id]?.isNotEmpty ?? false)) return seat.id;
    }
    return null;
  }

  static String _seatLabel(GameState s, String seatId) {
    final seat = s.seatById(seatId);
    final names = seat.playerIds
        .map((id) => s.players[id]?.name ?? '?')
        .join('+');
    return '$seatId ($names)';
  }

  static String _cardLabel(PlayingCard c) {
    if (c.suit == Suit.joker) {
      return c.rank == Rank.jokerBig ? 'Big Joker' : 'Small Joker';
    }
    return '${c.rank.short}${c.suit.symbol}';
  }
}
