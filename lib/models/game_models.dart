import 'card_model.dart';

enum TeamId { a, b }

extension TeamIdX on TeamId {
  String get label => this == TeamId.a ? 'Team A' : 'Team B';
  TeamId get opponent => this == TeamId.a ? TeamId.b : TeamId.a;
}

enum GamePhase { lobby, playing, finished }

/// A seat is a hand of 9 cards on a team. Exactly 6 seats per game (3 per
/// team). One *or more* players can occupy a seat — when more than 6 people
/// want to play, two people share a seat ("playing as one") and both see and
/// control the same hand.
class Seat {
  final String id; // "A1", "A2", "A3", "B1", "B2", "B3"
  final TeamId team;
  final int positionInTeam; // 1..3
  final List<String> playerIds; // 1+ players sharing this seat

  const Seat({
    required this.id,
    required this.team,
    required this.positionInTeam,
    required this.playerIds,
  });

  Seat copyWith({List<String>? playerIds}) => Seat(
        id: id,
        team: team,
        positionInTeam: positionInTeam,
        playerIds: playerIds ?? this.playerIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'team': team.name,
        'positionInTeam': positionInTeam,
        'playerIds': playerIds,
      };

  static Seat fromJson(Map<String, dynamic> j) => Seat(
        id: j['id'] as String,
        team: TeamId.values.byName(j['team'] as String),
        positionInTeam: j['positionInTeam'] as int,
        playerIds: List<String>.from(j['playerIds'] as List),
      );
}

class Player {
  final String id;
  final String name;
  final String? seatId;
  final bool isHost;

  const Player({
    required this.id,
    required this.name,
    this.seatId,
    this.isHost = false,
  });

  Player copyWith({String? name, String? seatId, bool? isHost}) => Player(
        id: id,
        name: name ?? this.name,
        seatId: seatId ?? this.seatId,
        isHost: isHost ?? this.isHost,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seatId': seatId,
        'isHost': isHost,
      };

  static Player fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        name: j['name'] as String,
        seatId: j['seatId'] as String?,
        isHost: (j['isHost'] as bool?) ?? false,
      );
}

/// Permanent record of a turn played.
class GameLogEntry {
  final String kind; // "ask" | "declare" | "info"
  final String text;
  final DateTime at;

  const GameLogEntry({required this.kind, required this.text, required this.at});

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'text': text,
        'at': at.toIso8601String(),
      };

  static GameLogEntry fromJson(Map<String, dynamic> j) => GameLogEntry(
        kind: j['kind'] as String,
        text: j['text'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

class GameState {
  final String gameId;
  final String hostId;
  final GamePhase phase;
  final List<Seat> seats; // length 6
  final Map<String, Player> players;
  final Map<String, List<String>> hands; // seatId -> list of card ids
  final String? currentSeatId;
  final Map<String, TeamId> claimedHalfSuites; // halfSuiteId -> winning team
  final List<GameLogEntry> log;
  final TeamId? winner;
  final int seed; // shuffle seed (for reproducibility/testing)

  const GameState({
    required this.gameId,
    required this.hostId,
    required this.phase,
    required this.seats,
    required this.players,
    required this.hands,
    required this.currentSeatId,
    required this.claimedHalfSuites,
    required this.log,
    required this.winner,
    required this.seed,
  });

  GameState copyWith({
    GamePhase? phase,
    List<Seat>? seats,
    Map<String, Player>? players,
    Map<String, List<String>>? hands,
    String? currentSeatId,
    Map<String, TeamId>? claimedHalfSuites,
    List<GameLogEntry>? log,
    TeamId? winner,
    bool clearWinner = false,
  }) =>
      GameState(
        gameId: gameId,
        hostId: hostId,
        phase: phase ?? this.phase,
        seats: seats ?? this.seats,
        players: players ?? this.players,
        hands: hands ?? this.hands,
        currentSeatId: currentSeatId ?? this.currentSeatId,
        claimedHalfSuites: claimedHalfSuites ?? this.claimedHalfSuites,
        log: log ?? this.log,
        winner: clearWinner ? null : (winner ?? this.winner),
        seed: seed,
      );

  Seat seatById(String id) => seats.firstWhere((s) => s.id == id);
  Seat seatForPlayer(String playerId) =>
      seats.firstWhere((s) => s.playerIds.contains(playerId));

  List<Seat> seatsOnTeam(TeamId team) =>
      seats.where((s) => s.team == team).toList();

  int teamScore(TeamId team) =>
      claimedHalfSuites.values.where((t) => t == team).length;

  /// Hand for a given seat, materialized as PlayingCard objects.
  List<PlayingCard> handFor(String seatId) =>
      (hands[seatId] ?? const []).map(PlayingCard.fromId).toList();

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'hostId': hostId,
        'phase': phase.name,
        'seats': seats.map((s) => s.toJson()).toList(),
        'players': players.map((k, v) => MapEntry(k, v.toJson())),
        'hands': hands,
        'currentSeatId': currentSeatId,
        'claimedHalfSuites':
            claimedHalfSuites.map((k, v) => MapEntry(k, v.name)),
        'log': log.map((e) => e.toJson()).toList(),
        'winner': winner?.name,
        'seed': seed,
      };

  static GameState fromJson(Map<String, dynamic> j) => GameState(
        gameId: j['gameId'] as String,
        hostId: j['hostId'] as String,
        phase: GamePhase.values.byName(j['phase'] as String),
        seats: (j['seats'] as List)
            .map((e) => Seat.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        players: (j['players'] as Map).map((k, v) => MapEntry(
            k as String, Player.fromJson(Map<String, dynamic>.from(v as Map)))),
        hands: (j['hands'] as Map).map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List))),
        currentSeatId: j['currentSeatId'] as String?,
        claimedHalfSuites: (j['claimedHalfSuites'] as Map).map((k, v) =>
            MapEntry(k as String, TeamId.values.byName(v as String))),
        log: (j['log'] as List)
            .map(
                (e) => GameLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        winner: j['winner'] == null
            ? null
            : TeamId.values.byName(j['winner'] as String),
        seed: (j['seed'] as int?) ?? 0,
      );
}
