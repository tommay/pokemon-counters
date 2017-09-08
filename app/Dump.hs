import qualified System.Environment
import qualified GameMaster

main = do
  args <- System.Environment.getArgs
  let filename = case args of
        (filename:_) -> filename
        [] -> "GAME_MASTER.yaml"
  result <- GameMaster.load filename
  case result of
    Right gameMaster ->
      print gameMaster
    Left exception ->
      putStrLn $ "oops: " ++ exception
