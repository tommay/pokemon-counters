module Breakpoint (
   getBreakpoints,
) where

import qualified Battle
import qualified GameMaster
import           GameMaster (GameMaster)
import qualified Move
import qualified Pokemon
import           Pokemon (Pokemon)
import qualified PokeUtil
import           Type (Type)
import           WeatherBonus (WeatherBonus)

import qualified Data.List as List

getBreakpoints ::
  GameMaster -> WeatherBonus -> Pokemon -> Pokemon -> [(Float, Int, Float)]
getBreakpoints gameMaster weatherBonus attacker defender =
  let levels = GameMaster.allLevels gameMaster
      quick = Pokemon.quick attacker
      levelAndDamageList = map (\ level ->
        let attacker' = PokeUtil.setLevel gameMaster level attacker
            damage = Battle.getDamage weatherBonus attacker' quick defender
            dps = fromIntegral damage / Move.duration quick
        in (level, damage, dps)) levels
      filtered = filter (\ (level, _, _) -> level >= Pokemon.level attacker)
        levelAndDamageList
  in List.nubBy (\ (_, d1, _) (_, d2, _) -> d1 == d2) filtered

