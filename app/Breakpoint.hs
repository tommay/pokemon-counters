{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Options.Applicative as O
import           Options.Applicative ((<|>), (<**>))
import           Data.Semigroup ((<>))

import qualified Battle
import qualified BattlerUtil
import           BattlerUtil (Battler)
import qualified Epic
import qualified IVs
import qualified GameMaster
import           GameMaster (GameMaster)
import qualified MakePokemon
import qualified MyPokemon
import           MyPokemon (MyPokemon)
import qualified Pokemon
import           Pokemon (Pokemon)
import qualified PokeUtil
import           Type (Type)
import qualified Util
import qualified Weather
import           Weather (Weather (..))

import           Control.Applicative (optional, some)
import           Control.Monad (join, forM, forM_)
import qualified Data.List as List
import qualified System.IO as I
import qualified Text.Printf as Printf

defaultIVs = IVs.new 20 11 11 11

data Options = Options {
  maybeWeather :: Maybe Weather,
  maybeFilename :: Maybe String,
  attacker :: Battler,
  defender :: Battler
}

getOptions :: IO Options
getOptions =
  let opts = Options <$> optWeather
        <*> optFilename <*> optAttacker <*> optDefender
      optWeather = O.optional Weather.optWeather
      optFilename = O.optional $ O.strOption
        (  O.long "file"
        <> O.short 'f'
        <> O.metavar "FILE"
        <> O.help "File to read my_pokemon from to get the attacker")
      optAttacker = O.argument
        (BattlerUtil.parseBattler defaultIVs) (O.metavar "ATTACKER[:LEVEL]")
      optDefender = O.argument
        (BattlerUtil.parseBattler defaultIVs) (O.metavar "DEFENDER[:LEVEL]")
      options = O.info (opts <**> O.helper)
        (  O.fullDesc
        <> O.progDesc "Battle some pokemon.")
      prefs = O.prefs O.showHelpOnEmpty
  in O.customExecParser prefs options

main =
  Epic.catch (
    do
      options <- getOptions

      gameMaster <- join $ GameMaster.load "GAME_MASTER.yaml"

      let weatherBonus = case maybeWeather options of
            Just weather -> GameMaster.getWeatherBonus gameMaster weather
            Nothing -> const 1

      attackerVariants <- case maybeFilename options of
        Just filename -> do
          myPokemon <- join $ MyPokemon.load $ Just filename
          let name = BattlerUtil.species $ attacker options
          case filter (Util.matchesAbbrevInsensitive name . MyPokemon.name)
              myPokemon of
            [myPokemon] -> MakePokemon.makePokemon gameMaster myPokemon
            [] -> Epic.fail $ "Can't find pokemon named " ++ name
            _ -> Epic.fail $ "Multiple pokemon named " ++ name
        Nothing ->
          BattlerUtil.makeBattlerVariants gameMaster $ attacker options

      defenderVariants <-
        BattlerUtil.makeBattlerVariants gameMaster $ defender options

      defender <- case defenderVariants of
        [defender] -> return defender
        [] -> Epic.fail $ "No possible variants for defender"
        _ -> Epic.fail $ "Multiple variants for defender"

      forM_ attackerVariants $ \ attacker -> do
        indent <- case attackerVariants of
          [_] -> return ""
          _ -> do
            putStrLn $ showPokemon attacker
            return "  "
        let breakPoints = getBreakPoints
              gameMaster weatherBonus attacker defender
        forM_ breakPoints $ \ (level, damage) ->
          putStrLn $ Printf.printf "%s%-4s %d"
            (indent :: String) (levelToString level) damage
    )
    $ I.hPutStrLn I.stderr

getBreakPoints ::
  GameMaster -> (Type -> Float) -> Pokemon -> Pokemon -> [(Float, Int)]
getBreakPoints gameMaster weatherBonus attacker defender =
  let levels = GameMaster.allLevels gameMaster
      levelAndDamageList = map (\ level ->
        let attacker' = PokeUtil.setLevel gameMaster level attacker
            damage = Battle.getDamage weatherBonus
              attacker' (Pokemon.quick attacker') defender
        in (level, damage)) levels
      filtered = filter (\ (level, _) -> level >= Pokemon.level attacker)
        levelAndDamageList
  in List.nubBy (\ (_, d1) (_, d2) -> d1 == d2) filtered

showPokemon :: Pokemon -> String
showPokemon pokemon =
  let ivs = Pokemon.ivs pokemon
  in Printf.printf "%s:%s/%d/%d/%d"
       (Pokemon.pname pokemon)
       (levelToString $ IVs.level ivs)
       (IVs.attack ivs)
       (IVs.defense ivs)
       (IVs.stamina ivs)

levelToString :: Float -> String
levelToString level =
  if fromIntegral (floor level) == level
    then show $ floor level
    else Printf.printf "%.1f" level
