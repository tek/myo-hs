module Myo.Command.Data.CommandInterpreter(
  CommandInterpreter(..),
) where

import Myo.Data.Ident (Ident)

data CommandInterpreter =
  System {
    systemTarget :: Maybe Ident
  }
  |
  Shell {
    shellTarget :: Ident
  }
  |
  Vim {
    vimSilent :: Bool,
    vimTarget :: Maybe Ident
  }
  deriving (Eq, Show)
