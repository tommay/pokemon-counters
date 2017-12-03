module PokemonBase (
  PokemonBase,
  new,
  species,
  types,
  attack,
  defense,
  stamina,
  quickMoves,
  chargeMoves,
  hasEvolutions,
) where

import           Type (Type)
import           Move (Move)

import           Data.Text (Text)

data PokemonBase = PokemonBase {
  species      :: String,
  types        :: [Type],
  attack       :: Int,
  defense      :: Int,
  stamina      :: Int,
  evolutions   :: [Text],
  quickMoves   :: [Move],
  chargeMoves  :: [Move],
  parent       :: Maybe Text
}

instance Show PokemonBase where
  show = species

new = PokemonBase

hasEvolutions :: PokemonBase -> Bool
hasEvolutions this = (not . null) $ PokemonBase.evolutions this
