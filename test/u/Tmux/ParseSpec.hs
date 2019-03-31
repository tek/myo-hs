{-# OPTIONS_GHC -F -pgmF htfpp #-}

module Tmux.ParseSpec(
  htf_thisModulesTests,
) where

import Chiasma.Data.Ident (Ident(Str))
import Chiasma.Test.Tmux (sleep)
import Control.Monad.IO.Class (liftIO)
import qualified Data.ByteString.Char8 as ByteString (lines)
import Data.ByteString.Internal (packChars)
import Data.Text (Text)
import qualified Data.Text as T (unpack)
import Ribosome.Test.Tmux (tmuxGuiSpecDef)
import Test.Framework

import Myo.Command.Add (myoAddSystemCommand)
import Myo.Command.Data.AddSystemCommandOptions (AddSystemCommandOptions(AddSystemCommandOptions))
import Myo.Command.Data.Command (CommandLanguage(CommandLanguage))
import qualified Myo.Command.Data.CommandLog as CommandLog (_current)
import Myo.Command.Data.ParseOptions (ParseOptions(ParseOptions))
import Myo.Command.Log (commandLog, commandLogs)
import Myo.Command.Parse (addHandler, myoParse)
import Myo.Command.Run (myoRun)
import Myo.Data.Env (MyoN)
import Myo.Init (initialize'')
import Myo.Output.Data.OutputError (OutputError)
import Myo.Output.Data.OutputEvent (OutputEvent)
import Myo.Output.Data.OutputHandler (OutputHandler(OutputHandler))
import Myo.Output.Data.OutputParser (OutputParser(OutputParser))
import Myo.Output.Data.ParsedOutput (ParsedOutput)
import Myo.Tmux.Runner (addTmuxRunner)

line1 :: String
line1 = "line 1"

line2 :: String
line2 = "line 2"

lang :: CommandLanguage
lang = CommandLanguage "echo"

parseEcho :: Text -> Either OutputError ParsedOutput
parseEcho = undefined

parseSpec :: MyoN ()
parseSpec = do
  let
    ident = Str "cmd"
    cmds = ["echo '" <> line1 <> "'", "echo '" <> line2 <> "'"]
    opts = AddSystemCommandOptions ident cmds (Just (Str "tmux")) (Just (Str "make")) (Just lang)
  initialize''
  addHandler lang (OutputHandler (OutputParser parseEcho))
  addTmuxRunner
  myoAddSystemCommand opts
  myoRun ident
  sleep 2
  mayLog <- commandLog ident
  log' <- ByteString.lines . CommandLog._current <$> gassertJust mayLog
  gassertBool $ packChars line2 `elem` log'
  myoParse $ ParseOptions Nothing Nothing Nothing

test_parse :: IO ()
test_parse =
  tmuxGuiSpecDef parseSpec