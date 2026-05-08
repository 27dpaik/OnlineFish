import '../../shared/card_model.dart';

enum CambioPhase {
  lobby,
  initialPeek, // each player gets one chance to peek bottom 2
  playing,
  finalRound, // someone called Cambio; one more turn each then score
  finished,
}

enum PendingPowerType {
  peekOwn, // 7 or 8
  peekOther, // 9 or 10
  blindSwitchPickMine, // J/Q step 1
  blindSwitchPickOther, // J/Q step 2
  kingLook, // Black K step 1
  kingSwitchPickMine, // Black K step 2
  kingSwitchPickOther, // Black K step 3
}

class CambioPlayer {
  final String id;
  final String name;
  final bool isHost;

  const CambioPlayer({
    required this.id,
    required this.name,
    this.isHost = false,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'isHost': isHost};

  static CambioPlayer fromJson(Map<String, dynamic> j) => CambioPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        isHost: (j['isHost'] as bool?) ?? false,
      );
}

class PendingPower {
  final PendingPowerType type;
  final String activePlayerId;
  // For multi-step powers (King; blind switch):
  final String? viewedPlayerId;
  final int? viewedPosition;
  final String? myPickedPosition; // for blind switch step 2

  const PendingPower({
    required this.type,
    required this.activePlayerId,
    this.viewedPlayerId,
    this.viewedPosition,
    this.myPickedPosition,
  });

  PendingPower copyWith({
    PendingPowerType? type,
    String? viewedPlayerId,
    int? viewedPosition,
    String? myPickedPosition,
    bool clearViewed = false,
    bool clearMyPicked = false,
  }) =>
      PendingPower(
        type: type ?? this.type,
        activePlayerId: activePlayerId,
        viewedPlayerId: clearViewed ? null : (viewedPlayerId ?? this.viewedPlayerId),
        viewedPosition: clearViewed ? null : (viewedPosition ?? this.viewedPosition),
        myPickedPosition:
            clearMyPicked ? null : (myPickedPosition ?? this.myPickedPosition),
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'activePlayerId': activePlayerId,
        'viewedPlayerId': viewedPlayerId,
        'viewedPosition': viewedPosition,
        'myPickedPosition': myPickedPosition,
      };

  static PendingPower fromJson(Map<String, dynamic> j) => PendingPower(
        type: PendingPowerType.values.byName(j['type'] as String),
        activePlayerId: j['activePlayerId'] as String,
        viewedPlayerId: j['viewedPlayerId'] as String?,
        viewedPosition: j['viewedPosition'] as int?,
        myPickedPosition: j['myPickedPosition'] as String?,
      );
}

/// A card the active player drew but hasn't yet committed to swap or discard.
class DrawnCard {
  final String cardId;
  final String playerId;
  const DrawnCard({required this.cardId, required this.playerId});
  Map<String, dynamic> toJson() => {'cardId': cardId, 'playerId': playerId};
  static DrawnCard fromJson(Map<String, dynamic> j) => DrawnCard(
        cardId: j['cardId'] as String,
        playerId: j['playerId'] as String,
      );
}

/// A peek that should be visible to a single client. Used so the engine can
/// briefly reveal a card to the player who's looking at it. Cleared when the
/// active player ends the peek.
class PrivateReveal {
  final String viewerId;
  final String cardId;
  final String ofPlayerId;
  final int position;
  const PrivateReveal({
    required this.viewerId,
    required this.cardId,
    required this.ofPlayerId,
    required this.position,
  });
  Map<String, dynamic> toJson() => {
        'viewerId': viewerId,
        'cardId': cardId,
        'ofPlayerId': ofPlayerId,
        'position': position,
      };
  static PrivateReveal fromJson(Map<String, dynamic> j) => PrivateReveal(
        viewerId: j['viewerId'] as String,
        cardId: j['cardId'] as String,
        ofPlayerId: j['ofPlayerId'] as String,
        position: j['position'] as int,
      );
}

class CambioLogEntry {
  final String text;
  final DateTime at;
  const CambioLogEntry({required this.text, required this.at});
  Map<String, dynamic> toJson() =>
      {'text': text, 'at': at.toIso8601String()};
  static CambioLogEntry fromJson(Map<String, dynamic> j) => CambioLogEntry(
        text: j['text'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

class CambioState {
  final String gameId;
  final String hostId;
  final CambioPhase phase;
  final List<CambioPlayer> players;
  final Map<String, List<String>> hands; // 4 cards each
  final List<String> stock;
  final List<String> discard;
  final DrawnCard? drawn;
  final PendingPower? pending;
  final Set<String> initialPeekDone;
  final int currentIdx;
  final String? cambioCallerId;
  final int finalRoundRemaining;
  final Map<String, int>? finalScores;
  final String? winnerId;
  final int seed;
  final List<CambioLogEntry> log;
  final List<PrivateReveal> privateReveals;

  const CambioState({
    required this.gameId,
    required this.hostId,
    required this.phase,
    required this.players,
    required this.hands,
    required this.stock,
    required this.discard,
    required this.drawn,
    required this.pending,
    required this.initialPeekDone,
    required this.currentIdx,
    required this.cambioCallerId,
    required this.finalRoundRemaining,
    required this.finalScores,
    required this.winnerId,
    required this.seed,
    required this.log,
    required this.privateReveals,
  });

  CambioState copyWith({
    CambioPhase? phase,
    List<CambioPlayer>? players,
    Map<String, List<String>>? hands,
    List<String>? stock,
    List<String>? discard,
    DrawnCard? drawn,
    bool clearDrawn = false,
    PendingPower? pending,
    bool clearPending = false,
    Set<String>? initialPeekDone,
    int? currentIdx,
    String? cambioCallerId,
    bool clearCambioCallerId = false,
    int? finalRoundRemaining,
    Map<String, int>? finalScores,
    String? winnerId,
    List<CambioLogEntry>? log,
    List<PrivateReveal>? privateReveals,
  }) =>
      CambioState(
        gameId: gameId,
        hostId: hostId,
        phase: phase ?? this.phase,
        players: players ?? this.players,
        hands: hands ?? this.hands,
        stock: stock ?? this.stock,
        discard: discard ?? this.discard,
        drawn: clearDrawn ? null : (drawn ?? this.drawn),
        pending: clearPending ? null : (pending ?? this.pending),
        initialPeekDone: initialPeekDone ?? this.initialPeekDone,
        currentIdx: currentIdx ?? this.currentIdx,
        cambioCallerId:
            clearCambioCallerId ? null : (cambioCallerId ?? this.cambioCallerId),
        finalRoundRemaining: finalRoundRemaining ?? this.finalRoundRemaining,
        finalScores: finalScores ?? this.finalScores,
        winnerId: winnerId ?? this.winnerId,
        seed: seed,
        log: log ?? this.log,
        privateReveals: privateReveals ?? this.privateReveals,
      );

  CambioPlayer get currentPlayer => players[currentIdx];

  PlayingCard? get topDiscard =>
      discard.isEmpty ? null : PlayingCard.fromId(discard.last);

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'hostId': hostId,
        'phase': phase.name,
        'players': players.map((p) => p.toJson()).toList(),
        'hands': hands,
        'stock': stock,
        'discard': discard,
        'drawn': drawn?.toJson(),
        'pending': pending?.toJson(),
        'initialPeekDone': initialPeekDone.toList(),
        'currentIdx': currentIdx,
        'cambioCallerId': cambioCallerId,
        'finalRoundRemaining': finalRoundRemaining,
        'finalScores': finalScores,
        'winnerId': winnerId,
        'seed': seed,
        'log': log.map((e) => e.toJson()).toList(),
        'privateReveals': privateReveals.map((e) => e.toJson()).toList(),
      };

  static CambioState fromJson(Map<String, dynamic> j) => CambioState(
        gameId: j['gameId'] as String,
        hostId: j['hostId'] as String,
        phase: CambioPhase.values.byName(j['phase'] as String),
        players: (j['players'] as List)
            .map((e) =>
                CambioPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hands: (j['hands'] as Map).map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List))),
        stock: List<String>.from((j['stock'] as List?) ?? const []),
        discard: List<String>.from((j['discard'] as List?) ?? const []),
        drawn: j['drawn'] == null
            ? null
            : DrawnCard.fromJson(Map<String, dynamic>.from(j['drawn'] as Map)),
        pending: j['pending'] == null
            ? null
            : PendingPower.fromJson(
                Map<String, dynamic>.from(j['pending'] as Map)),
        initialPeekDone:
            Set<String>.from((j['initialPeekDone'] as List?) ?? const []),
        currentIdx: j['currentIdx'] as int,
        cambioCallerId: j['cambioCallerId'] as String?,
        finalRoundRemaining: (j['finalRoundRemaining'] as int?) ?? 0,
        finalScores: (j['finalScores'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt())),
        winnerId: j['winnerId'] as String?,
        seed: (j['seed'] as int?) ?? 0,
        log: ((j['log'] as List?) ?? const [])
            .map((e) =>
                CambioLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        privateReveals: ((j['privateReveals'] as List?) ?? const [])
            .map((e) =>
                PrivateReveal.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
