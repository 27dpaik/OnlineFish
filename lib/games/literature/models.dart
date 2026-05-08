import '../../shared/card_model.dart';

enum TeamId { a, b }

extension TeamIdX on TeamId {
  String get label => this == TeamId.a ? 'Team A' : 'Team B';
  TeamId get opponent => this == TeamId.a ? TeamId.b : TeamId.a;
}

enum LitPhase { lobby, playing, finished }

class LitSeat {
  final String id;
  final TeamId team;
  final int positionInTeam;
  final List<String> playerIds;

  const LitSeat({
    required this.id,
    required this.team,
    required this.positionInTeam,
    required this.playerIds,
  });

  LitSeat copyWith({List<String>? playerIds}) => LitSeat(
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

  static LitSeat fromJson(Map<String, dynamic> j) => LitSeat(
        id: j['id'] as String,
        team: TeamId.values.byName(j['team'] as String),
        positionInTeam: j['positionInTeam'] as int,
        playerIds: List<String>.from(j['playerIds'] as List),
      );
}

class LitPlayer {
  final String id;
  final String name;
  final String? seatId;
  final bool isHost;

  const LitPlayer({
    required this.id,
    required this.name,
    this.seatId,
    this.isHost = false,
  });

  LitPlayer copyWith({String? name, String? seatId, bool? isHost}) => LitPlayer(
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

  static LitPlayer fromJson(Map<String, dynamic> j) => LitPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        seatId: j['seatId'] as String?,
        isHost: (j['isHost'] as bool?) ?? false,
      );
}

class LitLogEntry {
  final String kind;
  final String text;
  final DateTime at;

  const LitLogEntry({required this.kind, required this.text, required this.at});

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'text': text,
        'at': at.toIso8601String(),
      };

  static LitLogEntry fromJson(Map<String, dynamic> j) => LitLogEntry(
        kind: j['kind'] as String,
        text: j['text'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

class LitGameState {
  final String gameId;
  final String hostId;
  final LitPhase phase;
  final List<LitSeat> seats;
  final Map<String, LitPlayer> players;
  final Map<String, List<String>> hands;
  final String? currentSeatId;
  final Map<String, TeamId> claimedHalfSuites;
  final List<LitLogEntry> log;
  final TeamId? winner;
  final int seed;

  const LitGameState({
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

  LitGameState copyWith({
    LitPhase? phase,
    List<LitSeat>? seats,
    Map<String, LitPlayer>? players,
    Map<String, List<String>>? hands,
    String? currentSeatId,
    Map<String, TeamId>? claimedHalfSuites,
    List<LitLogEntry>? log,
    TeamId? winner,
    bool clearWinner = false,
  }) =>
      LitGameState(
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

  LitSeat seatById(String id) => seats.firstWhere((s) => s.id == id);
  LitSeat seatForPlayer(String playerId) =>
      seats.firstWhere((s) => s.playerIds.contains(playerId));

  List<LitSeat> seatsOnTeam(TeamId team) =>
      seats.where((s) => s.team == team).toList();

  int teamScore(TeamId team) =>
      claimedHalfSuites.values.where((t) => t == team).length;

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

  static LitGameState fromJson(Map<String, dynamic> j) => LitGameState(
        gameId: j['gameId'] as String,
        hostId: j['hostId'] as String,
        phase: LitPhase.values.byName(j['phase'] as String),
        seats: (j['seats'] as List)
            .map((e) => LitSeat.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        players: (j['players'] as Map).map((k, v) => MapEntry(k as String,
            LitPlayer.fromJson(Map<String, dynamic>.from(v as Map)))),
        hands: (j['hands'] as Map).map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List))),
        currentSeatId: j['currentSeatId'] as String?,
        claimedHalfSuites: (j['claimedHalfSuites'] as Map).map((k, v) =>
            MapEntry(k as String, TeamId.values.byName(v as String))),
        log: (j['log'] as List)
            .map((e) =>
                LitLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        winner: j['winner'] == null
            ? null
            : TeamId.values.byName(j['winner'] as String),
        seed: (j['seed'] as int?) ?? 0,
      );
}

