{-# LANGUAGE DeriveAnyClass #-}

module Myo.Command.Data.AddSystemCommandOptions where

import Chiasma.Data.Ident (Ident)
import GHC.Generics (Generic)
import Ribosome.Msgpack.Decode (MsgpackDecode(..))

import Myo.Command.Data.Command (CommandLanguage)
import Myo.Orphans ()

data AddSystemCommandOptions =
  AddSystemCommandOptions {
    ident :: Ident,
    lines :: [String],
    runner :: Maybe Ident,
    target :: Maybe Ident,
    lang :: Maybe CommandLanguage
  }
  deriving (Generic, MsgpackDecode)
