# OnlineFish

Three card games in one Flutter app:

- **Literature** (a.k.a. Fish) — 6+ players, 2 teams of 3, ask & declare
  half-suites.
- **One Card** — Crazy-Eights variant with attack/defense cards and a wild 7.
- **Cambio** — memory-style game; peek, swap, stick, and call cambio.

Two play modes for every game:

- **Local hot-seat** — one device, pass between players. No backend needed,
  works offline.
- **Online** — synced via Firebase Firestore. Each player runs the app and
  joins by 5-letter game code.

## Game rules

### Literature

- Standard 52 + 2 jokers = 54 cards.
- 6 seats: A1, A2, A3 on Team A; B1, B2, B3 on Team B. 9 cards each.
- 7+ humans? Two players can share one seat ("playing as one") — both see
  the same hand and both can play.
- 9 half-suites: 4 Lower (2–7), 4 Upper (9–A), 1 Eights & Jokers.
- Ask an opponent for a card. You must hold ≥1 card in that card's
  half-suite, and you must not already hold the card.
- Declare: state who on your team holds each of a half-suite's 6 cards.
  Right → your team wins it. Wrong → the other team wins it.
- After all 9 are claimed, more wins.

### One Card

- 7 cards each (2-player game) or 5 each (3+).
- Top card flipped to start the discard. Match by suit or rank, or play
  a wild.
- Action cards:
  - **K** — take another turn.
  - **Q** — reverse direction (acts like a J in 2-player).
  - **J** — skip the next player.
- Attack / defense:
  - **2** = attack 2.
  - **A** = attack 3.
  - **Black Joker** = attack 7 (wild).
  - **Colored Joker** = attack 10 (only on a red top).
  - **3** = shield (any suit; cancels a pending attack).
  - **7** = wild; declare the next active suit.
- Empty hand = win.

### Cambio

- 4 cards each in a 2×2 grid, face-down.
- One initial peek of your bottom 2 (positions 3 & 4) — memorize them.
- On your turn: draw from stock, then **swap** with one of your face-down
  cards (and discard the swapped-out card) **or** discard the drawn card.
- Discarding a card with a power triggers it:
  - **7 / 8** — peek one of your own cards.
  - **9 / 10** — peek any opponent's card.
  - **J / Q** — blind-switch one of yours with one of an opponent's.
  - **Black K** — look at any card, then switch one of yours with any
    opponent's.
  - **Red K** — no power. Worth −1 point.
  - Number cards & Aces — no power.
- Sticking: any player at any time can tap a card matching the top of
  the discard pile. Correct → that card is removed. Wrong → penalty
  card. (Online: the first sticker wins the race; later attempts get
  "Someone else stuck first".)
- Call **Cambio** at the start of your turn (instead of drawing). Every
  other player gets one more turn, then everyone scores.
- Scoring:
  - Joker = 0
  - Ace = 1
  - 2…10 = face value
  - J / Q / Black K = 10
  - Red K = −1
- Lowest total wins. Ties broken in favor of the non-caller; if multiple
  non-callers tie, the lowest single card wins.

## Project layout

```
lib/
  main.dart
  home_screen.dart           # game picker + entry forms
  shared/
    card_model.dart          # PlayingCard, Suit, Rank, Decks
    card_widget.dart
    sync/
      game_sync.dart         # generic GameSync<T> abstraction
      local_sync.dart        # in-memory sync for hot-seat
      firestore_sync.dart    # Firestore-backed sync
  games/
    literature/
      models.dart  engine.dart  controller.dart  half_suite.dart
      screens/{lit_lobby,lit_game,lit_declare}_screen.dart
    one_card/
      models.dart  engine.dart  controller.dart
      screens/{oc_lobby,oc_game}_screen.dart
    cambio/
      models.dart  engine.dart  controller.dart
      screens/{cambio_lobby,cambio_game}_screen.dart
test/
  engine_test.dart            # Literature engine
  one_card_test.dart          # One Card engine
  cambio_test.dart            # Cambio engine
  widget_test.dart            # Smoke test for the home screen
```

The **engines are pure** — no Flutter, no I/O. Each is a set of static
functions over a JSON-serializable state class. UI and network sit on top.
Sync is a thin generic layer over Firestore (or in-memory for local mode).

## Running locally

```bash
flutter pub get
flutter run             # iOS / Android / desktop / web
flutter test            # 21 engine + widget tests
```

Local hot-seat works for any of the three games out of the box — pick a
game, then *Local hot-seat game*.

## Sharing a game by link

When you host an online game, the lobby has a **Copy invite link** button.
The link looks like `https://your-domain.com/?game=cambio&code=AB7K3`.
When a friend opens it, the app:

1. Lands them on the right game's entry screen
2. Pre-fills the game code
3. Shows an "invited to game AB7K3" banner

They just type their name and tap **Join online game**.

Invite links require the app to be deployed to a URL — see the Firebase
Hosting steps below. Native (iOS/Android) builds can still join by typing
the code manually; the link itself is web-only.

## Deploying to web (so friends can use a link)

```bash
flutter build web
firebase init hosting   # pick "build/web" as the public directory
firebase deploy
```

Your app will live at something like `https://<project>.web.app`. That's
the URL the invite-link button uses.

## Setting up online play (Firebase)

The online mode pushes the game state to Firestore. To enable it:

1. **Create a Firebase project** at https://console.firebase.google.com.
2. **Enable Firestore** (Build → Firestore Database → Create in production
   mode is fine).
3. Install the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
4. Link this app to your Firebase project:
   ```bash
   flutterfire configure
   ```
   Pick your project and target platforms. This generates
   `lib/firebase_options.dart` and the platform configs.
5. Update `lib/main.dart` to use the generated options:
   ```dart
   import 'firebase_options.dart';
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```
6. Loosen Firestore rules (these are permissive — fine for friends-only
   play; tighten before shipping):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{collection}/{code} {
         allow read, write: if true;
       }
     }
   }
   ```

Without these steps the app still launches; the online buttons show a
notice and local mode works.

## Online architecture & known limitations

- Each game uses its own Firestore collection: `lit_games`, `oc_games`,
  `cambio_games`. One document per game, keyed by 5-letter code.
- Most moves push the full state with last-write-wins — fine for
  turn-based play.
- Cambio's "stick a card" race uses a Firestore transaction so only the
  first sticker wins; later attempts surface as `Someone else stuck first`.
- **Cambio cheat-resistance**: hands are stored in the clear in the
  Firestore document. Hiding cards from other players is enforced
  client-side. A determined opponent could read the document directly.
  For social play this is fine; for tournament-grade play you'd need a
  server-authoritative engine. House rules ("memorize 2 cards at start",
  "no two-handed play") are honor-system online.
- The engine handles "stock empty" by reshuffling the discard (minus the
  top) back into the stock.

## Status

Working:

- Three full game engines with all rules implemented.
- Local hot-seat for all three.
- Online play via Firestore (after the setup above).
- 21 unit tests across deal/ask/declare for Literature, play/draw for One
  Card, peek/stick/cambio for Cambio.

Not done (deliberately scoped out for v1):

- Card animations / sounds.
- A persistent notes panel for Cambio players to track what they've seen.
- "Give one of your cards" reward for sticking another player's card.
- Auth, rate limiting, hardened Firestore rules.
- A server-authoritative engine for cheat-proof Cambio.
