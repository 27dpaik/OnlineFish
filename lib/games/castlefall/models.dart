enum CfPhase {
  lobby,
  playing, // a round is in progress
  declaring, // method-1 declaration in progress (60s window)
  revealed, // round ended, words/teams shown
}

class CfPlayer {
  final String id;
  final String name;
  final bool isHost;
  const CfPlayer(
      {required this.id, required this.name, this.isHost = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'isHost': isHost};

  static CfPlayer fromJson(Map<String, dynamic> j) => CfPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        isHost: (j['isHost'] as bool?) ?? false,
      );
}

class CfDeclaration {
  /// 'team'  → method 1 (claim N players are on your team)
  /// 'word'  → method 2 (guess opposing team's word; immediate)
  final String kind;
  final String declarerId;
  final List<String>? claimedPlayerIds; // method 1
  final String? guessedWord; // method 2
  final DateTime madeAt;
  final DateTime? deadlineAt; // method 1 only
  final bool? success;

  const CfDeclaration({
    required this.kind,
    required this.declarerId,
    required this.madeAt,
    this.claimedPlayerIds,
    this.guessedWord,
    this.deadlineAt,
    this.success,
  });

  CfDeclaration copyWith({bool? success}) => CfDeclaration(
        kind: kind,
        declarerId: declarerId,
        madeAt: madeAt,
        claimedPlayerIds: claimedPlayerIds,
        guessedWord: guessedWord,
        deadlineAt: deadlineAt,
        success: success ?? this.success,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'declarerId': declarerId,
        'madeAt': madeAt.toIso8601String(),
        if (claimedPlayerIds != null) 'claimedPlayerIds': claimedPlayerIds,
        if (guessedWord != null) 'guessedWord': guessedWord,
        if (deadlineAt != null) 'deadlineAt': deadlineAt!.toIso8601String(),
        if (success != null) 'success': success,
      };

  static CfDeclaration fromJson(Map<String, dynamic> j) => CfDeclaration(
        kind: j['kind'] as String,
        declarerId: j['declarerId'] as String,
        madeAt: DateTime.parse(j['madeAt'] as String),
        claimedPlayerIds: (j['claimedPlayerIds'] as List?)
            ?.map((e) => e as String)
            .toList(),
        guessedWord: j['guessedWord'] as String?,
        deadlineAt: j['deadlineAt'] == null
            ? null
            : DateTime.parse(j['deadlineAt'] as String),
        success: j['success'] as bool?,
      );
}

class CfRound {
  final List<String> wordList; // 16 words shown to all players
  final String wordA;
  final String wordB;
  final List<String> teamA; // player ids
  final List<String> teamB;
  final String categoryName;

  const CfRound({
    required this.wordList,
    required this.wordA,
    required this.wordB,
    required this.teamA,
    required this.teamB,
    required this.categoryName,
  });

  String wordFor(String playerId) =>
      teamA.contains(playerId) ? wordA : wordB;

  bool sameTeam(String a, String b) =>
      (teamA.contains(a) && teamA.contains(b)) ||
      (teamB.contains(a) && teamB.contains(b));

  Map<String, dynamic> toJson() => {
        'wordList': wordList,
        'wordA': wordA,
        'wordB': wordB,
        'teamA': teamA,
        'teamB': teamB,
        'categoryName': categoryName,
      };

  static CfRound fromJson(Map<String, dynamic> j) => CfRound(
        wordList: List<String>.from(j['wordList'] as List),
        wordA: j['wordA'] as String,
        wordB: j['wordB'] as String,
        teamA: List<String>.from(j['teamA'] as List),
        teamB: List<String>.from(j['teamB'] as List),
        categoryName: j['categoryName'] as String,
      );
}

class CfState {
  final String gameId;
  final String hostId;
  final CfPhase phase;
  final List<CfPlayer> players;
  final CfRound? round;
  final CfDeclaration? declaration;
  final int seed;

  const CfState({
    required this.gameId,
    required this.hostId,
    required this.phase,
    required this.players,
    required this.round,
    required this.declaration,
    required this.seed,
  });

  CfState copyWith({
    CfPhase? phase,
    List<CfPlayer>? players,
    CfRound? round,
    bool clearRound = false,
    CfDeclaration? declaration,
    bool clearDeclaration = false,
    int? seed,
  }) =>
      CfState(
        gameId: gameId,
        hostId: hostId,
        phase: phase ?? this.phase,
        players: players ?? this.players,
        round: clearRound ? null : (round ?? this.round),
        declaration:
            clearDeclaration ? null : (declaration ?? this.declaration),
        seed: seed ?? this.seed,
      );

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'hostId': hostId,
        'phase': phase.name,
        'players': players.map((p) => p.toJson()).toList(),
        if (round != null) 'round': round!.toJson(),
        if (declaration != null) 'declaration': declaration!.toJson(),
        'seed': seed,
      };

  static CfState fromJson(Map<String, dynamic> j) => CfState(
        gameId: j['gameId'] as String,
        hostId: j['hostId'] as String,
        phase: CfPhase.values.byName(j['phase'] as String),
        players: (j['players'] as List)
            .map((e) =>
                CfPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        round: j['round'] == null
            ? null
            : CfRound.fromJson(Map<String, dynamic>.from(j['round'] as Map)),
        declaration: j['declaration'] == null
            ? null
            : CfDeclaration.fromJson(
                Map<String, dynamic>.from(j['declaration'] as Map)),
        seed: (j['seed'] as int?) ?? 0,
      );
}
