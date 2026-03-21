import 'package:classic_suite/games/hearts/hearts_ai.dart';
import 'package:classic_suite/games/hearts/hearts_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first trick must start with two of clubs', () {
    final state = HeartsGameState.debug(
      hands: [
        [
          const HeartsCard(HeartsSuit.clubs, 2),
          const HeartsCard(HeartsSuit.hearts, 14),
        ],
        [const HeartsCard(HeartsSuit.clubs, 5)],
        [const HeartsCard(HeartsSuit.clubs, 8)],
        [const HeartsCard(HeartsSuit.clubs, 9)],
      ],
      currentPlayer: 0,
      trickLeader: 0,
      phase: HeartsPhase.playing,
    );

    final legal = state.legalPlaysFor(0);
    expect(legal, hasLength(1));
    expect(legal.single.key, const HeartsCard(HeartsSuit.clubs, 2).key);
  });

  test(
    'hearts cannot be led before they are broken when other suits exist',
    () {
      final state = HeartsGameState.debug(
        hands: [
          [
            const HeartsCard(HeartsSuit.hearts, 10),
            const HeartsCard(HeartsSuit.clubs, 9),
          ],
          [const HeartsCard(HeartsSuit.clubs, 4)],
          [const HeartsCard(HeartsSuit.clubs, 7)],
          [const HeartsCard(HeartsSuit.clubs, 8)],
        ],
        currentPlayer: 0,
        trickLeader: 0,
        phase: HeartsPhase.playing,
        heartsBroken: false,
        completedTricks: const [HeartsTrick(plays: [], winner: 0, points: 0)],
      );

      final legal = state.legalPlaysFor(0);
      expect(legal.map((card) => card.key), [
        const HeartsCard(HeartsSuit.clubs, 9).key,
      ]);
    },
  );

  test('shoot the moon applies 26 points to everyone else', () {
    final state = HeartsGameState.debug(
      hands: const [
        [],
        [],
        [],
        [HeartsCard(HeartsSuit.clubs, 4)],
      ],
      handPoints: const [26, 0, 0, 0],
      matchScores: const [10, 20, 30, 40],
      currentPlayer: 3,
      trickLeader: 0,
      currentTrick: const [
        HeartsTrickPlay(player: 0, card: HeartsCard(HeartsSuit.clubs, 13)),
        HeartsTrickPlay(player: 1, card: HeartsCard(HeartsSuit.clubs, 2)),
        HeartsTrickPlay(player: 2, card: HeartsCard(HeartsSuit.clubs, 3)),
      ],
      completedTricks: const [HeartsTrick(plays: [], winner: 0, points: 0)],
      phase: HeartsPhase.playing,
    ).autoPlayCurrentPlayer();

    expect(state.lastRoundMoonShooter, 0);
    expect(state.lastRoundAppliedScores, [0, 26, 26, 26]);
  });

  test('defensive ai passes queen of spades away', () {
    final state = HeartsGameState.debug(
      hands: [
        const [],
        const [
          HeartsCard(HeartsSuit.spades, 12),
          HeartsCard(HeartsSuit.spades, 14),
          HeartsCard(HeartsSuit.hearts, 13),
          HeartsCard(HeartsSuit.clubs, 2),
          HeartsCard(HeartsSuit.clubs, 3),
          HeartsCard(HeartsSuit.diamonds, 4),
        ],
        const [],
        const [],
      ],
      phase: HeartsPhase.passing,
      passDirection: HeartsPassDirection.left,
    );

    final chosen = HeartsAi.choosePassCards(
      state,
      1,
    ).map((card) => card.key).toSet();
    expect(
      chosen.contains(const HeartsCard(HeartsSuit.spades, 12).key),
      isTrue,
    );
  });

  test('defensive ai dumps queen of spades when void', () {
    final state = HeartsGameState.debug(
      hands: [
        const [],
        const [
          HeartsCard(HeartsSuit.spades, 12),
          HeartsCard(HeartsSuit.hearts, 13),
          HeartsCard(HeartsSuit.diamonds, 2),
        ],
        const [],
        const [],
      ],
      currentPlayer: 1,
      trickLeader: 0,
      currentTrick: const [
        HeartsTrickPlay(player: 0, card: HeartsCard(HeartsSuit.clubs, 9)),
      ],
      completedTricks: const [HeartsTrick(plays: [], winner: 0, points: 0)],
      phase: HeartsPhase.playing,
    );

    expect(
      HeartsAi.chooseCard(state, 1).key,
      const HeartsCard(HeartsSuit.spades, 12).key,
    );
  });

  test('confirmHumanPass recalculates leader when 2♣ moves', () {
    // Player 0 (human) starts with the 2♣ and passes it away (pass left).
    // After the pass, player 1 should receive it and become the leader.
    final state = HeartsGameState.debug(
      hands: [
        const [
          HeartsCard(HeartsSuit.clubs, 2),
          HeartsCard(HeartsSuit.clubs, 3),
          HeartsCard(HeartsSuit.clubs, 4),
          HeartsCard(HeartsSuit.clubs, 5),
          HeartsCard(HeartsSuit.hearts, 6),
          HeartsCard(HeartsSuit.hearts, 7),
          HeartsCard(HeartsSuit.hearts, 8),
          HeartsCard(HeartsSuit.hearts, 9),
          HeartsCard(HeartsSuit.diamonds, 10),
          HeartsCard(HeartsSuit.diamonds, 11),
          HeartsCard(HeartsSuit.diamonds, 12),
          HeartsCard(HeartsSuit.diamonds, 13),
          HeartsCard(HeartsSuit.diamonds, 14),
        ],
        const [
          HeartsCard(HeartsSuit.spades, 3),
          HeartsCard(HeartsSuit.spades, 4),
          HeartsCard(HeartsSuit.spades, 5),
          HeartsCard(HeartsSuit.spades, 6),
          HeartsCard(HeartsSuit.spades, 7),
          HeartsCard(HeartsSuit.spades, 8),
          HeartsCard(HeartsSuit.spades, 9),
          HeartsCard(HeartsSuit.spades, 10),
          HeartsCard(HeartsSuit.spades, 11),
          HeartsCard(HeartsSuit.spades, 12),
          HeartsCard(HeartsSuit.spades, 13),
          HeartsCard(HeartsSuit.spades, 14),
          HeartsCard(HeartsSuit.clubs, 14),
        ],
        const [
          HeartsCard(HeartsSuit.clubs, 6),
          HeartsCard(HeartsSuit.clubs, 7),
          HeartsCard(HeartsSuit.clubs, 8),
          HeartsCard(HeartsSuit.clubs, 9),
          HeartsCard(HeartsSuit.clubs, 10),
          HeartsCard(HeartsSuit.clubs, 11),
          HeartsCard(HeartsSuit.clubs, 12),
          HeartsCard(HeartsSuit.clubs, 13),
          HeartsCard(HeartsSuit.diamonds, 2),
          HeartsCard(HeartsSuit.diamonds, 3),
          HeartsCard(HeartsSuit.diamonds, 4),
          HeartsCard(HeartsSuit.diamonds, 5),
          HeartsCard(HeartsSuit.diamonds, 6),
        ],
        const [
          HeartsCard(HeartsSuit.hearts, 2),
          HeartsCard(HeartsSuit.hearts, 3),
          HeartsCard(HeartsSuit.hearts, 4),
          HeartsCard(HeartsSuit.hearts, 5),
          HeartsCard(HeartsSuit.hearts, 10),
          HeartsCard(HeartsSuit.hearts, 11),
          HeartsCard(HeartsSuit.hearts, 12),
          HeartsCard(HeartsSuit.hearts, 13),
          HeartsCard(HeartsSuit.hearts, 14),
          HeartsCard(HeartsSuit.diamonds, 7),
          HeartsCard(HeartsSuit.diamonds, 8),
          HeartsCard(HeartsSuit.diamonds, 9),
          HeartsCard(HeartsSuit.spades, 2),
        ],
      ],
      currentPlayer: 0,
      trickLeader: 0,
      phase: HeartsPhase.passing,
      passDirection: HeartsPassDirection.left,
    );

    // Human selects the 2♣ plus two other clubs to pass left (to player 1).
    var next = state.togglePassSelection(
      const HeartsCard(HeartsSuit.clubs, 2).key,
    );
    next = next.togglePassSelection(const HeartsCard(HeartsSuit.clubs, 3).key);
    next = next.togglePassSelection(const HeartsCard(HeartsSuit.clubs, 4).key);
    expect(next.selectedPassCards.length, 3);

    final afterPass = next.confirmHumanPass();

    // The 2♣ now lives in player 1's hand (passed left from player 0).
    expect(afterPass.isPlaying, isTrue);
    expect(
      afterPass.hands[1].any(
        (card) => card.suit == HeartsSuit.clubs && card.rank == 2,
      ),
      isTrue,
    );
    // Leader must be player 1 (who now holds the 2♣).
    expect(afterPass.currentPlayer, 1);
    expect(afterPass.trickLeader, 1);
  });
}
