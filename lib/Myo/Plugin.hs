{-# LANGUAGE TemplateHaskell #-}

module Myo.Plugin where

import Control.Monad ((<=<))
import qualified Data.Map as Map (fromList)
import Data.MessagePack (Object)
import Myo.Output.Data.OutputError (OutputError)
import Neovim (Neovim, NeovimPlugin, Plugin(..), wrapPlugin)
import Ribosome.Control.Monad.Ribo (ConcNvimS, MonadRibo, NvimE, RiboE)
import Ribosome.Control.Ribosome (Ribosome)
import Ribosome.Data.SettingError (SettingError)
import Ribosome.Error.Report (reportError)
import Ribosome.Msgpack.Error (DecodeError)
import Ribosome.Plugin (RpcDef, autocmd, cmd, riboPlugin, rpcHandler, rpcHandlerDef, sync)
import Ribosome.Plugin.Mapping (MappingHandler, mappingHandler)

import Myo.Command.Add (myoAddShellCommand, myoAddSystemCommand)
import Myo.Command.Data.CommandState (CommandState)
import Myo.Command.Output (myoNext, myoPrev, outputQuit, outputSelect)
import Myo.Command.Parse (myoParse, myoParseLatest)
import Myo.Command.Run (myoRun)
import Myo.Command.Update (updateCommands)
import Myo.Data.Env (Env, MyoE)
import Myo.Data.Error (Error)
import Myo.Diag (myoDiag)
import Myo.Init (initialize, myoPoll)
import Myo.Quit (myoQuit)
import Myo.Ui.Data.UiState (UiState)
import Myo.Ui.Toggle (myoToggleLayout, myoTogglePane)
import Myo.Ui.Update (updateUi)

handleError :: Error -> MyoE Error (ConcNvimS Env) ()
handleError =
  reportError "myo"

rpcHandlers :: [[RpcDef (RiboE Env Error (ConcNvimS Env))]]
rpcHandlers =
  [
    $(rpcHandler (cmd []) 'myoDiag),
    $(rpcHandler sync 'myoPoll),
    $(rpcHandlerDef 'myoAddSystemCommand),
    $(rpcHandlerDef 'myoAddShellCommand),
    $(rpcHandlerDef 'myoTogglePane),
    $(rpcHandlerDef 'myoToggleLayout),
    $(rpcHandler (cmd []) 'myoRun),
    $(rpcHandlerDef 'myoParse),
    $(rpcHandler (cmd []) 'myoParseLatest),
    $(rpcHandlerDef 'myoPrev),
    $(rpcHandlerDef 'myoNext),
    $(rpcHandler (autocmd "VimLeavePre" . sync) 'myoQuit)
    ]

mappingOutputQuit ::
  MonadRibo m =>
  NvimE e m =>
  MappingHandler m
mappingOutputQuit =
  mappingHandler "output-quit" outputQuit

mappingOutputSelect ::
  MonadDeepState s CommandState m =>
  MonadDeepError e DecodeError m =>
  MonadDeepError e OutputError m =>
  MonadRibo m =>
  NvimE e m =>
  MappingHandler m
mappingOutputSelect =
  mappingHandler "output-select" outputSelect

mappings ::
  MonadDeepState s CommandState m =>
  MonadDeepError e DecodeError m =>
  MonadDeepError e OutputError m =>
  MonadRibo m =>
  NvimE e m =>
  [MappingHandler m]
mappings =
  [mappingOutputQuit, mappingOutputSelect]

variables ::
  MonadIO m =>
  MonadRibo m =>
  NvimE e m =>
  MonadDeepError e DecodeError m =>
  MonadDeepError e SettingError m =>
  MonadDeepError e DecodeError m =>
  MonadDeepState s CommandState m =>
  MonadDeepState s UiState m =>
  Map Text (Object -> m ())
variables =
  Map.fromList [("myo_commands", updateCommands), ("myo_ui", updateUi)]

plugin' :: Ribosome Env -> Plugin (Ribosome Env)
plugin' env =
  riboPlugin "myo" env rpcHandlers mappings handleError variables

plugin :: FilePath -> Neovim e NeovimPlugin
plugin =
  wrapPlugin . plugin' <=< initialize
