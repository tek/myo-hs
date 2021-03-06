module Myo.Test.Command.HistoryMenuTest where

import Control.Concurrent.Lifted (fork, killThread)
import Control.Exception.Lifted (bracket)
import Control.Lens ((^?))
import qualified Control.Lens as Lens (element)
import Hedgehog ((===))
import Ribosome.Api.Input (syntheticInput)
import Ribosome.Menu.Action (menuReturn)
import qualified Ribosome.Menu.Data.FilteredMenuItem as FilteredMenuItem (item)
import Ribosome.Menu.Data.Menu (Menu(Menu))
import Ribosome.Menu.Data.MenuConsumerAction (MenuConsumerAction)
import qualified Ribosome.Menu.Data.MenuItem as MenuItem (text)
import qualified Ribosome.Menu.Data.MenuResult as MenuResult (MenuResult(Return))
import Ribosome.Menu.Prompt.Data.Prompt (Prompt)
import Ribosome.Test.Run (UnitTest)
import Ribosome.Test.Tmux (tmuxTestDef)

import Myo.Command.Data.Command (Command(Command))
import qualified Myo.Command.Data.CommandInterpreter as CommandInterpreter (CommandInterpreter(System))
import Myo.Command.Data.CommandState (CommandState)
import qualified Myo.Command.Data.CommandState as CommandState (history)
import Myo.Command.Data.HistoryEntry (HistoryEntry(HistoryEntry))
import Myo.Command.HistoryMenu (historyMenu)
import Myo.Test.Unit (MyoTest)

nativeChars :: [Text]
nativeChars =
  ["i", "l", "i", "n", "e", "<esc>", "k", "<cr>"]

history :: [HistoryEntry]
history =
  [entry "c1", entry "c2", entry "c3", entry "c4", entry "c4", entry "c4", entry "c4", entry "c4"]
  where
    entry n =
      HistoryEntry (Command (CommandInterpreter.System Nothing) n def def def def False False False)

exec ::
  MonadIO m =>
  Menu Ident ->
  Prompt ->
  m (MenuConsumerAction m (Maybe Text), Menu Ident)
exec m@(Menu _ items selected _ _ _) _ =
  menuReturn item m
  where
    item =
      items ^? Lens.element selected . FilteredMenuItem.item . MenuItem.text

historyMenuTest :: MyoTest ()
historyMenuTest = do
  setL @CommandState CommandState.history history
  entry <- bracket (fork input) killThread (const (historyMenu exec))
  MenuResult.Return (Just "[c2] <no command line>") === entry
  where
    input =
      syntheticInput (Just 0.1) nativeChars

test_historyMenu :: UnitTest
test_historyMenu =
  tmuxTestDef historyMenuTest
