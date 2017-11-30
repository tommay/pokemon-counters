module Defender (
  Defender,
  pokemon,
  hp,
  move,
  damageWindow,
  Defender.init,
  tick,
  takeDamage,
  useEnergy,
  makeMove,
) where

import qualified Pokemon
import           Pokemon (Pokemon)
import qualified Move
import           Move (Move)

import qualified System.Random as Random

import qualified Debug as D

data Defender = Defender {
  pokemon :: Pokemon,
  hp :: Int,
  energy :: Int,
  cooldown :: Int,        -- time until the next move.
  moves :: [(Move, Int)], -- next move(s) to do.
  move :: Move,           -- move in progess.
  damageWindow :: Int,
  rnd :: Random.StdGen
} deriving (Show)

init :: Random.StdGen -> Pokemon -> Defender
init rnd pokemon =
  let quick = Pokemon.quick pokemon
  in Defender {
       pokemon = pokemon,
       hp = Pokemon.hp pokemon * 2,
       energy = 0,
       cooldown = 1600,
       -- The first two moves are always quick and the interval is fixed.
       -- https://thesilphroad.com/tips-and-news/defender-attacks-twice-immediately
       -- XXX What if the damage window for the first move is never reached?
       -- Is it also fixed?
       moves = [(quick, 1000),
                (quick, Move.durationMs quick + 2000)],
       move = quick,  -- Not used.
       damageWindow = -1,
       rnd = rnd
       }

quick :: Defender -> Move
quick this =
  Pokemon.quick $ Defender.pokemon this

charge :: Defender -> Move
charge this =
  Pokemon.charge $ Defender.pokemon this

tick :: Defender -> Defender
tick this =
  this {
    cooldown = Defender.cooldown this - 10,
    damageWindow = Defender.damageWindow this - 10
    }

makeMove :: Defender -> Defender
makeMove this =
  if Defender.cooldown this == 0
    then makeMove' this
    else this

makeMove' :: Defender -> Defender
makeMove' this =
  let -- Get the next move and any move(s) after that.
      (move', cooldown'):moves' = Defender.moves this
      -- If it's a quick move, its energy is available immediately
      -- for the decision about the next move.  Charge move energy
      -- is subtracted at damageWindowStart.
      energy' = if Move.isQuick move'
        then minimum [100, Defender.energy this + Move.energy move']
        else Defender.energy this
      -- Figure out our next move.
      quick = Defender.quick this
      charge = Defender.charge this
      (random, rnd') = Random.random $ Defender.rnd this
      moves'' = case moves' of
        [] ->
          -- Both quick moves and charge moves get an additional 1.5-2.5
          -- seconds added to their duration.  Just use the average, 2.
          if energy' >= negate (Move.energy charge) && (random :: Float) < 0.5
            then [(charge, Move.durationMs charge + 2000)]
            else [(quick, Move.durationMs quick + 2000)]
        val -> val
      -- Set countdown until damage is done to the opponent and it gets
      -- its energy boost and our charge move energy is subtracted.
      damageWindow' = Move.damageWindow move'
  in this {
       energy = energy',
       cooldown = cooldown',
       moves = moves'',
       move = move',
       damageWindow = damageWindow',
       rnd = rnd'
       }

takeDamage :: Pokemon -> Move -> Defender -> Defender
takeDamage pokemon move this =
  let damageDone = damage move pokemon (Defender.pokemon this)
  in this {
       hp = Defender.hp this - damageDone,
       energy = minimum [100,
         Defender.energy this + (damageDone + 1) `div` 2]
       }

useEnergy :: Defender -> Defender
useEnergy this =
  let move = Defender.move this
  in if Move.isCharge move
       then this {
         energy = Defender.energy this + Move.energy move
         }
       else this

damage :: Move -> Pokemon -> Pokemon -> Int
damage move attacker defender =
  let power = Move.power move
      stab = Move.stabFor move $ Pokemon.types attacker
      effectiveness = Move.effectivenessAgainst move $ Pokemon.types defender
      attack = Pokemon.attack attacker
      defense = Pokemon.defense defender
  in floor $ power * stab * effectiveness * attack / defense / 2 + 1