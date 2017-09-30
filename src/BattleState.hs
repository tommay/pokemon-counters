module BattleState (
  calcDps
) where

import qualified Move
import qualified Pokemon
import           Pokemon (Pokemon)

import qualified Debug.Trace as T

data BattleState = BattleState {
  time   :: Float,
  damage :: Integer,
  energy :: Float,
  extraQuickMoves :: Integer
} deriving (Show)

-- Note that both the "floor" and the "+ 1" make damage somewhat
-- nonlinear wrt pokemon level.

calcDps :: Pokemon -> Pokemon -> Bool -> Float
calcDps attacker defender useCharge =
  let quickMove = Pokemon.quick attacker
      chargeMove = Pokemon.charge attacker
      moveDamage move =
        let power = Move.power move
            stab = Move.stabFor move $ Pokemon.types attacker
            effectiveness = Move.effectivenessAgainst move $ Pokemon.types defender
            attack' = Pokemon.attack attacker
            defense' = Pokemon.defense defender
        in floor $ power * stab * effectiveness * attack' / defense' / 2 + 1
      step state =
        let (move, extraTime, extraQuickMoves) =
              case useCharge &&
                   BattleState.energy state >= -(Move.energy chargeMove) of
                True ->
                  case BattleState.extraQuickMoves state of
                    0 -> (chargeMove, 0.5, 0)
                    extra -> (quickMove, 0, extra - 1)
                False -> (quickMove, 0, 1)
        in BattleState {
            time = BattleState.time state + Move.duration move + extraTime,
            damage = BattleState.damage state + moveDamage move,
            energy = minimum [BattleState.energy state + Move.energy move, 100],
            extraQuickMoves = extraQuickMoves
         }
      initialState = BattleState {
        time = 0,
        damage = 0,
        energy = 0,
        extraQuickMoves = 0
      }
      timeLimit = 120
      stepUntilTimeLimitReached state =
        case BattleState.time state >= timeLimit of
          True -> state
          False -> stepUntilTimeLimitReached $ step state
      finalState = stepUntilTimeLimitReached initialState
  in fromIntegral (BattleState.damage finalState) / BattleState.time finalState

spew a b = T.traceShow (a, b) b