enum DvColor { white, black }

extension DvColorX on DvColor {
  String get short => name[0].toUpperCase();
}

/// A single block. `value` is null for jokers. `revealed` flips to true when
/// the block has been correctly guessed (or revealed by a wrong guess on
/// your own drawn block).
class DvBlock {
  final DvColor color;
  final int? value; // 0..11, or null for joker
  final bool revealed;

  const DvBlock({
    required this.color,
    required this.value,
    this.revealed = false,
  });

  bool get isJoker => value == null;

  String get id =>
      '${color.short}${value == null ? "JK" : value.toString()}';

  /// Used for tie-breaking when two blocks share the same value: black
  /// goes left (smaller sort key).
  int get colorOrder => color == DvColor.black ? 0 : 1;

  DvBlock copyWith({bool? revealed}) =>
      DvBlock(color: color, value: value, revealed: revealed ?? this.revealed);

  Map<String, dynamic> toJson() => {
        'color': color.name,
        'value': value,
        'revealed': revealed,
      };

  static DvBlock fromJson(Map<String, dynamic> j) => DvBlock(
        color: DvColor.values.byName(j['color'] as String),
        value: j['value'] as int?,
        revealed: (j['revealed'] as bool?) ?? false,
      );
}

class DvPlayer {
  final String id;
  final String name;
  final bool isHost;
  const DvPlayer(
      {required this.id, required this.name, this.isHost = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'isHost': isHost};

  static DvPlayer fromJson(Map<String, dynamic> j) => DvPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        isHost: (j['isHost'] as bool?) ?? false,
      );
}

class DvLogEntry {
  final String text;
  final DateTime at;
  const DvLogEntry({required this.text, required this.at});
  Map<String, dynamic> toJson() =>
      {'text': text, 'at': at.toIso8601String()};
  static DvLogEntry fromJson(Map<String, dynamic> j) => DvLogEntry(
        text: j['text'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

enum DvPhase { lobby, playing, finished }

/// A block currently held by a player but not yet placed in their hand.
/// (Drawn from stock; if it's a joker the engine waits for the player to
/// pick a position before sliding it in.)
class DvDrawn {
  final String playerId;
  final DvBlock block;
  const DvDrawn({required this.playerId, required this.block});
  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'block': block.toJson(),
      };
  static DvDrawn fromJson(Map<String, dynamic> j) => DvDrawn(
        playerId: j['playerId'] as String,
        block: DvBlock.fromJson(Map<String, dynamic>.from(j['block'] as Map)),
      );
}

class DvState {
  final String gameId;
  final String hostId;
  final DvPhase phase;
  final List<DvPlayer> players;
  final Map<String, List<DvBlock>> hands; // sorted, owner-private
  final List<DvBlock> stock;
  final DvDrawn? drawn;
  final int currentIdx;
  final bool awaitingChoiceAfterCorrect; // can guess again or stop
  final String? winnerId;
  final int seed;
  final List<DvLogEntry> log;

  const DvState({
    required this.gameId,
    required this.hostId,
    required this.phase,
    required this.players,
    required this.hands,
    required this.stock,
    required this.drawn,
    required this.currentIdx,
    required this.awaitingChoiceAfterCorrect,
    required this.winnerId,
    required this.seed,
    required this.log,
  });

  DvState copyWith({
    DvPhase? phase,
    List<DvPlayer>? players,
    Map<String, List<DvBlock>>? hands,
    List<DvBlock>? stock,
    DvDrawn? drawn,
    bool clearDrawn = false,
    int? currentIdx,
    bool? awaitingChoiceAfterCorrect,
    String? winnerId,
    List<DvLogEntry>? log,
  }) =>
      DvState(
        gameId: gameId,
        hostId: hostId,
        phase: phase ?? this.phase,
        players: players ?? this.players,
        hands: hands ?? this.hands,
        stock: stock ?? this.stock,
        drawn: clearDrawn ? null : (drawn ?? this.drawn),
        currentIdx: currentIdx ?? this.currentIdx,
        awaitingChoiceAfterCorrect: awaitingChoiceAfterCorrect ??
            this.awaitingChoiceAfterCorrect,
        winnerId: winnerId ?? this.winnerId,
        seed: seed,
        log: log ?? this.log,
      );

  DvPlayer get currentPlayer => players[currentIdx];

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'hostId': hostId,
        'phase': phase.name,
        'players': players.map((p) => p.toJson()).toList(),
        'hands': hands.map((k, v) =>
            MapEntry(k, v.map((b) => b.toJson()).toList())),
        'stock': stock.map((b) => b.toJson()).toList(),
        'drawn': drawn?.toJson(),
        'currentIdx': currentIdx,
        'awaitingChoiceAfterCorrect': awaitingChoiceAfterCorrect,
        'winnerId': winnerId,
        'seed': seed,
        'log': log.map((e) => e.toJson()).toList(),
      };

  static DvState fromJson(Map<String, dynamic> j) => DvState(
        gameId: j['gameId'] as String,
        hostId: j['hostId'] as String,
        phase: DvPhase.values.byName(j['phase'] as String),
        players: (j['players'] as List)
            .map((e) =>
                DvPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hands: (j['hands'] as Map).map((k, v) => MapEntry(
              k as String,
              (v as List)
                  .map((e) =>
                      DvBlock.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList(),
            )),
        stock: ((j['stock'] as List?) ?? const [])
            .map((e) => DvBlock.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        drawn: j['drawn'] == null
            ? null
            : DvDrawn.fromJson(Map<String, dynamic>.from(j['drawn'] as Map)),
        currentIdx: j['currentIdx'] as int,
        awaitingChoiceAfterCorrect:
            (j['awaitingChoiceAfterCorrect'] as bool?) ?? false,
        winnerId: j['winnerId'] as String?,
        seed: (j['seed'] as int?) ?? 0,
        log: ((j['log'] as List?) ?? const [])
            .map((e) =>
                DvLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
