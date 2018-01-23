module Main where

import qualified Appraisal
import qualified Calc
import qualified Epic
import qualified IVs
import           IVs (IVs)
import qualified GameMaster
import           GameMaster (GameMaster)
import qualified MyPokemon
import           MyPokemon (MyPokemon)

import qualified Options.Applicative as O
import           Options.Applicative ((<**>))
import           Control.Monad (join)
import qualified Data.Maybe as Maybe
import           Data.Semigroup ((<>))

import qualified Data.ByteString as B
import qualified Data.Yaml as Y
import qualified Data.Yaml.Builder as Builder
import qualified System.IO as I

data Options = Options {
  new       :: Bool,
  filename  :: String
}

getOptions :: IO Options
getOptions =
  let opts = Options <$> optNew <*> optFilename
      optNew = O.switch
        (  O.long "new"
        <> O.short 'n'
        <> O.help "Assume pokemon without ivs are newly caught or hatched")
      optFilename = O.argument O.str (O.metavar "FILENAME")
      options = O.info (opts <**> O.helper)
        (  O.fullDesc
        <> O.progDesc "Calculate IVs for pokemon.")
      prefs = O.prefs O.showHelpOnEmpty
  in O.customExecParser prefs options

main = Epic.catch (
  do
    options <- getOptions

    gameMaster <- join $ GameMaster.load "GAME_MASTER.yaml"

    myPokemon <- join $ MyPokemon.load $ filename options

    let new' = new options
    myNewPokemon <- mapM (updateIVs gameMaster new') myPokemon
    B.putStr $ Builder.toByteString myNewPokemon
  )
  $ I.hPutStrLn I.stderr

updateIVs :: (Epic.MonadCatch m) => GameMaster -> Bool -> MyPokemon -> m MyPokemon
updateIVs gameMaster new myPokemon = Epic.catch (
  do
    ivs <- computeIVs gameMaster new myPokemon
    return $ MyPokemon.setIVs myPokemon ivs
  )
  $ \ex -> Epic.fail $
      "Problem with " ++ MyPokemon.name myPokemon ++ ": " ++ ex

computeIVs :: (Epic.MonadCatch m) => GameMaster -> Bool -> MyPokemon -> m [IVs]
computeIVs gameMaster new myPokemon = do
  pokemonBase <- GameMaster.getPokemonBase gameMaster $ MyPokemon.species myPokemon
  possibleLevels <- GameMaster.getLevelsForStardust gameMaster
    $ MyPokemon.stardust myPokemon
  possibleIvs <- do
    appraisal <- Appraisal.new $ MyPokemon.appraisal myPokemon
    return $ Appraisal.possibleIvs appraisal
  possibleIVs <- do
    let allIVs = [IVs.new level attack defense stamina |
          level <- possibleLevels,
          (attack, defense, stamina) <- possibleIvs]
        isWholeLevel s =
          let level = IVs.level s
          in fromIntegral (floor level) == level
        allIVs' = if new && (Maybe.isNothing $ MyPokemon.ivs myPokemon)
          then filter isWholeLevel allIVs
          else allIVs
        ivsMatchMyPokemon ivs =
          MyPokemon.hp myPokemon ==
            Calc.hp gameMaster pokemonBase ivs &&
          MyPokemon.cp myPokemon ==
            Calc.cp gameMaster pokemonBase ivs
        ivsThatMatchMyPokemon = filter ivsMatchMyPokemon allIVs'
    case ivsThatMatchMyPokemon of
      [] -> Epic.fail "No possible ivs"
      matchingIVs -> return $ do
        case MyPokemon.ivs myPokemon of
          Nothing -> matchingIVs
          Just currentIVs ->
            filter (\matching ->
              any (\current ->
                let ivs = sequence [IVs.attack, IVs.defense, IVs.stamina]
                in ivs matching == ivs current)
              currentIVs)
            matchingIVs
  case possibleIVs of
    [] -> Epic.fail "No possible remaining ivs"
    _ -> return possibleIVs
