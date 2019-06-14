{-# LANGUAGE QuasiQuotes #-}

module Myo.Command.Parse where

import Chiasma.Data.Ident (Ident)
import qualified Control.Lens as Lens (at, over, view)
import Control.Monad (when)
import Control.Monad.DeepError (hoistMaybe)
import Control.Monad.IO.Class (MonadIO)
import Data.Text (Text)
import Myo.Output.Data.ParseResult (ParseResult(ParseResult))
import Ribosome.Config.Setting (setting, settingMaybe)
import Ribosome.Data.SettingError (SettingError)
import qualified Ribosome.Log as Log
import Ribosome.Msgpack.Error (DecodeError)
import Text.RE.PCRE.Text (RE, SearchReplace, ed, (*=~/))

import Myo.Command.Command (commandByIdent, latestCommand)
import Myo.Command.Data.Command (Command(Command), CommandLanguage(CommandLanguage))
import qualified Myo.Command.Data.Command as Command (ident)
import Myo.Command.Data.CommandError (CommandError)
import Myo.Command.Data.CommandLog (CommandLog)
import qualified Myo.Command.Data.CommandLog as CommandLog (CommandLog(_current))
import Myo.Command.Data.CommandState (CommandState)
import qualified Myo.Command.Data.CommandState as CommandState (outputHandlers, parseResult)
import Myo.Command.Data.ParseOptions (ParseOptions(ParseOptions))
import Myo.Command.History (displayNameByIdent)
import Myo.Command.Log (commandLog, commandLogByName)
import Myo.Command.Output (renderParseResult)
import Myo.Output.Data.OutputError (OutputError)
import qualified Myo.Output.Data.OutputError as OutputError (OutputError(NoLang, NoHandler, NoOutput))
import Myo.Output.Data.OutputHandler (OutputHandler(OutputHandler))
import Myo.Output.Data.OutputParser (OutputParser(OutputParser))
import Myo.Output.Data.ParsedOutput (ParsedOutput)
import qualified Myo.Settings as Settings (displayResult, proteomeMainType)

selectCommand ::
  MonadDeepError e OutputError m =>
  MonadDeepError e CommandError m =>
  MonadDeepState s CommandState m =>
  Maybe Ident ->
  m Command
selectCommand (Just ident) = commandByIdent "selectCommand" ident
selectCommand Nothing = latestCommand

removeTerminalCodesRE :: SearchReplace RE Text
removeTerminalCodesRE =
  [ed|\e\[[0-9;?]*[a-zA-z]///|]

removeLineFeedRE :: SearchReplace RE Text
removeLineFeedRE =
  [ed|\r///|]

sanitizeOutput :: Text -> Text
sanitizeOutput =
  (*=~/ removeTerminalCodesRE) . (*=~/ removeLineFeedRE)

commandOutputResult ::
  MonadDeepError e OutputError m =>
  Text ->
  Maybe CommandLog ->
  m Text
commandOutputResult ident =
  maybe err convert
  where
    convert =
      return . sanitizeOutput . decodeUtf8 . CommandLog._current
    err =
      throwHoist $ OutputError.NoOutput ident

commandOutput ::
  MonadDeepError e OutputError m =>
  MonadDeepError e CommandError m =>
  MonadDeepState s CommandState m =>
  Ident ->
  m Text
commandOutput ident = do
  name <- displayNameByIdent ident
  commandOutputResult name =<< commandLog ident

commandOutputByName ::
  MonadDeepError e OutputError m =>
  MonadDeepError e CommandError m =>
  MonadDeepState s CommandState m =>
  Text ->
  m Text
commandOutputByName name =
  commandOutputResult name =<< commandLogByName name

handlersForLang ::
  (MonadDeepError e OutputError m, MonadDeepState s CommandState m) =>
  CommandLanguage ->
  m [OutputHandler]
handlersForLang lang = do
  result <- getL @CommandState $ CommandState.outputHandlers . Lens.at lang
  hoistMaybe (OutputError.NoHandler lang) result

parseWith :: MonadDeepError s OutputError m => OutputParser -> Text -> m ParsedOutput
parseWith (OutputParser parser) =
  hoistEither . parser

parseWithLang ::
  (MonadDeepError e OutputError m, MonadDeepState s CommandState m) =>
  CommandLanguage ->
  Text ->
  m [ParsedOutput]
parseWithLang lang output = do
  handlers <- handlersForLang lang
  traverse parse handlers
  where
    parse (OutputHandler parser) = parseWith parser output

parseCommandWithLang ::
  MonadRibo m =>
  MonadIO m =>
  MonadDeepError e OutputError m =>
  MonadDeepError e CommandError m =>
  MonadDeepState s CommandState m =>
  CommandLanguage ->
  Ident ->
  m [ParsedOutput]
parseCommandWithLang lang ident = do
  output <- commandOutput ident
  Log.showDebug "parse output:" output
  parseWithLang lang output

projectLanguage ::
  NvimE e m =>
  MonadRibo m =>
  m (Maybe CommandLanguage)
projectLanguage =
  CommandLanguage <$$> settingMaybe Settings.proteomeMainType

parseCommand ::
  NvimE e m =>
  MonadRibo m =>
  MonadDeepError e OutputError m =>
  MonadDeepError e CommandError m =>
  MonadDeepState s CommandState m =>
  Command ->
  m [ParsedOutput]
parseCommand (Command _ ident _ _ (Just lang) _) =
  parseCommandWithLang lang ident
parseCommand (Command _ ident _ _ Nothing _) = do
  lang <- hoistMaybe (OutputError.NoLang ident) =<< projectLanguage
  parseCommandWithLang lang ident

myoParse ::
  MonadDeepError e CommandError m =>
  MonadDeepError e OutputError m =>
  MonadDeepError e DecodeError m =>
  MonadDeepError e SettingError m =>
  MonadDeepState s CommandState m =>
  MonadIO m =>
  MonadRibo m =>
  NvimE e m =>
  ParseOptions ->
  m ()
myoParse (ParseOptions _ ident _) = do
  cmd <- selectCommand ident
  parsedOutput <- parseCommand cmd
  setL @CommandState CommandState.parseResult (Just (ParseResult (Lens.view Command.ident cmd) parsedOutput))
  display <- setting Settings.displayResult
  when display $ renderParseResult (Lens.view Command.ident cmd) parsedOutput

myoParseLatest ::
  MonadDeepError e CommandError m =>
  MonadDeepError e OutputError m =>
  MonadDeepError e DecodeError m =>
  MonadDeepError e SettingError m =>
  MonadDeepState s CommandState m =>
  MonadIO m =>
  MonadRibo m =>
  NvimE e m =>
  m ()
myoParseLatest =
  myoParse (ParseOptions Nothing Nothing Nothing)

addHandler :: MonadDeepState s CommandState m => CommandLanguage -> OutputHandler -> m ()
addHandler lang parser =
  modify @CommandState $ Lens.over (CommandState.outputHandlers . Lens.at lang) update
  where
    update (Just current) = Just (parser : current)
    update Nothing = Just [parser]
