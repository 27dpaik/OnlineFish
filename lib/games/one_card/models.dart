import '../../shared/card_model.dart';

enum OcPhase { lobby, playing, finished }

class OcPlayer {
  final String id;
  final String name;
  final bool isHost;

  const OcPlayer(
      {required this.id, required this.name, this.isHost = false});

  OcPlayer copyWith({String? name, bool? isHost}) =>
      OcPlayer(id: id, name: name ?? this.name, isHost: isHost ?? this.isHost);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'isHost': isHost};

  static OcPlayer fromJson(Map<String, dynamic> j) => OcPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        isHost: (j['isHost'] as bool?) ?? false,
      );
}

class OcLogEntry {
  final String text;
  final DateTime at;
  const OcLogEntry({required this.text, required this.at});
  Map<String, dynamic> toJson() =>
      {'text': text, 'at': at.toIso8601String()};
  static OcLogEntry fromJson(Map<String, dynamic> j) => OcLogEntry(
        text: j['text'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

class OcState {
  final String gameId;
  final String hostId;
  final OcPhase phase;
  final List<OcPlayer> players; // turn order
  final Map<String, List<String>> hands;
  final List<String> stock; // draw from end
  final List<String> discard; // top is last
  final int currentIdx;
  final int direction; // 1 or -1
  final int pendingAttack;
  final String? declaredSuit; // active suit if 7 was played, else null
  final String? winnerId;
  final int seed;
  final List<OcLogEntry> log;

  const OcState({
    required this.gameId,
    required this.hostId,
    required this.phase,
    required this.players,
    required this.hands,
    required this.stock,
    required this.discard,
    required this.currentIdx,
    required this.direction,
    required this.pendingAttack,
    required this.declaredSuit,
    required this.winnerId,
    required this.seed,
    required this.log,
  });

  OcState copyWith({
    OcPhase? phase,
    List<OcPlayer>? players,
    Map<String, List<String>>? hands,
    List<String>? stock,
    List<String>? discard,
    int? currentIdx,
    int? direction,
    int? pendingAttack,
    String? declaredSuit,
    bool clearDeclaredSuit = false,
    String? winnerId,
    bool clearWinner = false,
    List<OcLogEntry>? log,
  }) =>
      OcState(
        gameId: gameId,
        hostId: hostId,
        phase: phase ?? this.phase,
        players: players ?? this.players,
        hands: hands ?? this.hands,
        stock: stock ?? this.stock,
        discard: discard ?? this.discard,
        currentIdx: currentIdx ?? this.currentIdx,
        direction: direction ?? this.direction,
        pendingAttack: pendingAttack ?? this.pendingAttack,
        declaredSuit:
            clearDeclaredSuit ? null : (declaredSuit ?? this.declaredSuit),
        winnerId: clearWinner ? null : (winnerId ?? this.winnerId),
        seed: seed,
        log: log ?? this.log,
      );

  PlayingCard get topDiscard =>
      PlayingCard.fromId(discard.last);

  Suit get activeSuit {
    if (declaredSuit != null) {
      return Suit.values.byName(declaredSuit!);
    }
    return topDiscard.suit;
  }

  OcPlayer get currentPlayer => players[currentIdx];

  List<PlayingCard> handFor(String playerId) =>
      (hands[playerId] ?? const []).map(PlayingCard.fromId).toList();

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'hostId': hostId,
        'phase': phase.name,
        'players': players.map((p) => p.toJson()).toList(),
        'hands': hands,
        'stock': stock,
        'discard': discard,
        'currentIdx': currentIdx,
        'direction': direction,
        'pendingAttack': pendingAttack,
        'declaredSuit': declaredSuit,
        'winnerId': winnerId,
        'seed': seed,
        'log': log.map((e) => e.toJson()).toList(),
      };

  static OcState fromJson(Map<String, dynamic> j) => OcState(
        gameId: j['gameId'] as String,
        hostId: j['hostId'] as String,
        phase: OcPhase.values.byName(j['phase'] as String),
        players: (j['players'] as List)
            .map((e) => OcPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hands: (j['hands'] as Map).map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List))),
        stock: List<String>.from((j['stock'] as List?) ?? const []),
        discard: List<String>.from((j['discard'] as List?) ?? const []),
        currentIdx: j['currentIdx'] as int,
        direction: j['direction'] as int,
        pendingAttack: (j['pendingAttack'] as int?) ?? 0,
        declaredSuit: j['declaredSuit'] as String?,
        winnerId: j['winnerId'] as String?,
        seed: (j['seed'] as int?) ?? 0,
        log: (j['log'] as List)
            .map((e) =>
                OcLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
