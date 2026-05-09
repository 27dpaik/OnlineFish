import 'dart:math';

import 'models.dart';
import 'word_bank.dart';

class CfResult {
  final bool ok;
  final String? error;
  final CfState? next;
  const CfResult.success(this.next)
      : ok = true,
        error = null;
  const CfResult.failure(this.error)
      : ok = false,
        next = null;
}

/// Castlefall: a team-based word-guessing party game. The engine handles
/// round setup (sampling words, dividing teams), declarations, and reveals.
/// All actual communication happens in person / over voice — the app just
/// tracks who's on what team and what the words are.
class CastlefallEngine {
  static const wordsPerRound = 16;

  static CfState newLobby({
    required String gameId,
    required String hostId,
    required String hostName,
    required int seed,
  }) =>
      CfState(
        gameId: gameId,
        hostId: hostId,
        phase: CfPhase.lobby,
        players: [CfPlayer(id: hostId, name: hostName, isHost: true)],
        round: null,
        declaration: null,
        seed: seed,
      );

  static CfState addPlayer(CfState s, CfPlayer p) {
    if (s.players.any((x) => x.id == p.id)) return s;
    return s.copyWith(players: [...s.players, p]);
  }

  /// Start a new round. Picks 16 words from the chosen category, assigns 2
  /// of them as the team words, and divides players into teams. The seed is
  /// rotated each round so consecutive rounds differ.
  static CfResult startRound(CfState s, String categoryName) {
    if (s.players.length < 4) {
      return const CfResult.failure('Castlefall needs at least 4 players');
    }
    final category = castlefallBank
        .where((c) => c.name == categoryName)
        .firstOrNull;
    if (category == null) {
      return CfResult.failure('Unknown category: $categoryName');
    }
    if (category.words.length < wordsPerRound) {
      return const CfResult.failure(
          'Category has fewer than 16 words — pick another');
    }
    // Rotate the seed so the next round is different.
    final r = Random(s.seed + s.players.length * 7);
    final shuffled = [...category.words]..shuffle(r);
    final wordList = shuffled.take(wordsPerRound).toList();
    final wordA = wordList[r.nextInt(wordList.length)];
    String wordB;
    do {
      wordB = wordList[r.nextInt(wordList.length)];
    } while (wordB == wordA);

    final players = [...s.players]..shuffle(r);
    final aSize = (players.length + (r.nextBool() ? 1 : 0)) ~/ 2;
    final teamA = players.take(aSize).map((p) => p.id).toList();
    final teamB = players.skip(aSize).map((p) => p.id).toList();

    return CfResult.success(s.copyWith(
      phase: CfPhase.playing,
      round: CfRound(
        wordList: wordList,
        wordA: wordA,
        wordB: wordB,
        teamA: teamA,
        teamB: teamB,
        categoryName: category.name,
      ),
      clearDeclaration: true,
      seed: s.seed + 1,
    ));
  }

  /// Method 1 declaration: declarer claims `claimedPlayerIds` are all on
  /// their team. Sets a 60-second deadline. Anyone can later resolve
  /// (or override with a method-2 word guess).
  static CfResult declareTeam({
    required CfState s,
    required String declarerId,
    required List<String> claimedPlayerIds,
  }) {
    if (s.phase != CfPhase.playing) {
      return const CfResult.failure('No round to declare in');
    }
    if (!s.players.any((p) => p.id == declarerId)) {
      return const CfResult.failure('Unknown declarer');
    }
    if (!claimedPlayerIds.contains(declarerId)) {
      return const CfResult.failure('You must include yourself');
    }
    final now = DateTime.now();
    return CfResult.success(s.copyWith(
      phase: CfPhase.declaring,
      declaration: CfDeclaration(
        kind: 'team',
        declarerId: declarerId,
        madeAt: now,
        deadlineAt: now.add(const Duration(seconds: 60)),
        claimedPlayerIds: claimedPlayerIds,
      ),
    ));
  }

  /// Method 2 (immediate): guess the opposing team's word. Overrides any
  /// in-flight method-1 declaration.
  static CfResult guessWord({
    required CfState s,
    required String declarerId,
    required String guessedWord,
  }) {
    if (s.phase != CfPhase.playing && s.phase != CfPhase.declaring) {
      return const CfResult.failure('No round to guess in');
    }
    final round = s.round;
    if (round == null) return const CfResult.failure('No round');
    final theirWord = round.wordFor(declarerId);
    final opponentWord = theirWord == round.wordA ? round.wordB : round.wordA;
    final correct = guessedWord == opponentWord;
    return CfResult.success(s.copyWith(
      phase: CfPhase.revealed,
      declaration: CfDeclaration(
        kind: 'word',
        declarerId: declarerId,
        madeAt: DateTime.now(),
        guessedWord: guessedWord,
        success: correct,
      ),
    ));
  }

  /// Resolve a method-1 declaration. The UI calls this once the 60-second
  /// deadline has passed (any client can do it; idempotent).
  static CfResult resolveTeamDeclaration(CfState s) {
    if (s.phase != CfPhase.declaring || s.declaration == null) {
      return const CfResult.failure('No team declaration to resolve');
    }
    final round = s.round!;
    final dec = s.declaration!;
    final declarer = dec.declarerId;
    final declarerTeam =
        round.teamA.contains(declarer) ? round.teamA : round.teamB;
    // All claimed players must be on the declarer's team. Castlefall says
    // "they are all on your team" — so it's correct iff every claimed
    // player is on declarerTeam (and the declarer included themselves).
    final correct = dec.claimedPlayerIds!
        .every((id) => declarerTeam.contains(id));
    return CfResult.success(s.copyWith(
      phase: CfPhase.revealed,
      declaration: dec.copyWith(success: correct),
    ));
  }

  /// Start a fresh round with the same lobby. Same as startRound but with
  /// a different seed (state.seed has already been incremented).
  static CfResult nextRound(CfState s, String categoryName) {
    if (s.phase != CfPhase.revealed && s.phase != CfPhase.lobby) {
      return const CfResult.failure('Finish the current round first');
    }
    return startRound(
      s.copyWith(phase: CfPhase.lobby, clearRound: true, clearDeclaration: true),
      categoryName,
    );
  }
}
