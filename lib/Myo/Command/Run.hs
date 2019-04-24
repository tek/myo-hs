module Myo.Command.Run where

import Chiasma.Data.Ident (Ident)
import Chiasma.Ui.Data.TreeModError (TreeModError)
import Chiasma.Ui.Lens.Ident (matchIdentL)
import Control.Lens (Lens')
import qualified Control.Lens as Lens (preview)
import Control.Monad (when)
import Control.Monad.Catch (MonadThrow)
import Control.Monad.DeepError (MonadDeepError, hoistEither)
import Control.Monad.DeepState (MonadDeepState, gets)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Trans.Control (MonadBaseControl)
import Data.Maybe (isNothing)
import Ribosome.Control.Monad.Ribo (MonadRibo, prepend)
import Ribosome.Tmux.Run (RunTmux)

import Myo.Command.Command (commandByIdent)
import Myo.Command.Data.Command (Command(..))
import Myo.Command.Data.CommandError (CommandError)
import Myo.Command.Data.CommandState (CommandState)
import qualified Myo.Command.Data.CommandState as CommandState (running)
import Myo.Command.Data.Pid (Pid)
import Myo.Command.Data.RunError (RunError)
import Myo.Command.Data.RunTask (RunTask, RunTaskDetails)
import qualified Myo.Command.Data.RunTask as RunTask (RunTask(..))
import qualified Myo.Command.Data.RunTask as RunTaskDetails (RunTaskDetails(..))
import Myo.Command.Data.RunningCommand (RunningCommand(RunningCommand))
import Myo.Command.History (pushHistory)
import Myo.Command.Log (pushCommandLog)
import Myo.Command.RunTask (runTask)
import Myo.Command.Runner (findRunner)
import Myo.Command.RunningCommand (isCommandRunning)
import Myo.Data.Env (Env, Runner(Runner))
import Myo.Orphans ()
import Myo.Ui.Data.ToggleError (ToggleError)
import Myo.Ui.Render (MyoRender)
import Myo.Ui.Toggle (ensurePaneOpen)

ensurePrerequisites ::
  RunTmux m =>
  MonadRibo m =>
  MyoRender s e m =>
  MonadBaseControl IO m =>
  MonadDeepError e ToggleError m =>
  MonadDeepError e TreeModError m =>
  MonadDeepError e RunError m =>
  MonadDeepError e CommandError m =>
  MonadDeepState s Env m =>
  MonadDeepState s CommandState m =>
  MonadThrow m =>
  RunTaskDetails ->
  m ()
ensurePrerequisites (RunTaskDetails.UiSystem ident) =
  ensurePaneOpen ident
ensurePrerequisites (RunTaskDetails.UiShell shellIdent paneIdent) = do
  running <- isCommandRunning shellIdent
  unless running (myoRun shellIdent)
ensurePrerequisites _ =
  return ()

executeRunner ::
  MonadIO m =>
  MonadDeepError e RunError m =>
  MonadDeepState s Env m =>
  Runner ->
  RunTask ->
  m ()
executeRunner (Runner _ _ run) task = do
  r <- liftIO $ run task
  hoistEither r

runCommand ::
  RunTmux m =>
  MonadRibo m =>
  MyoRender s e m =>
  MonadBaseControl IO m =>
  MonadDeepError e ToggleError m =>
  MonadDeepError e TreeModError m =>
  MonadDeepError e RunError m =>
  MonadDeepError e CommandError m =>
  MonadDeepState s Env m =>
  MonadDeepState s CommandState m =>
  MonadThrow m =>
  Command ->
  m ()
runCommand cmd = do
  task <- runTask cmd
  ensurePrerequisites (RunTask.rtDetails task)
  runner <- findRunner task
  pushCommandLog (cmdIdent cmd)
  executeRunner runner task
  pushHistory cmd

myoRun ::
  RunTmux m =>
  MonadRibo m =>
  MyoRender s e m =>
  MonadBaseControl IO m =>
  MonadDeepError e ToggleError m =>
  MonadDeepError e TreeModError m =>
  MonadDeepError e RunError m =>
  MonadDeepError e CommandError m =>
  MonadDeepState s Env m =>
  MonadDeepState s CommandState m =>
  MonadThrow m =>
  Ident ->
  m ()
myoRun =
  runCommand <=< commandByIdent
