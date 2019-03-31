module Myo.Command.Output where

import Control.Monad.DeepState (MonadDeepState, getsL, setL)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Foldable (traverse_)
import Data.Functor (void)
import qualified Data.Text as Text (unpack)
import Data.Traversable (mapAccumL)
import Ribosome.Api.Syntax (executeSyntax, executeWindowSyntax)
import Ribosome.Control.Monad.Ribo (NvimE)
import Ribosome.Data.Scratch (scratchWindow)
import Ribosome.Data.Syntax (Syntax)
import Ribosome.Scratch (showInScratchOrCreateDef)

import Myo.Command.Data.CommandState (CommandState)
import qualified Myo.Command.Data.CommandState as CommandState (parseReports, reportScratch)
import Myo.Output.Data.ParseReport (ParseReport(ParseReport))
import Myo.Output.Data.ParsedOutput (ParsedOutput(ParsedOutput))
import qualified Myo.Output.Data.ParsedOutput as ParsedOutput (ParsedOutput(_syntax))
import Myo.Output.Data.ReportLine (ReportLine(ReportLine, _text))

renderReport ::
  MonadIO m =>
  NvimE e m =>
  MonadDeepState s CommandState m =>
  ParseReport ->
  [Syntax] ->
  m ()
renderReport (ParseReport _ lines') syntax = do
  oldScratch <- getsL @CommandState CommandState.reportScratch
  scratch <- showInScratchOrCreateDef oldScratch (render <$> lines')
  setL @CommandState CommandState.reportScratch (Just scratch)
  traverse_ (executeWindowSyntax (scratchWindow scratch)) syntax
  -- traverse_ executeSyntax syntax
  where
    render (ReportLine _ text) =
      Text.unpack text

renderParseResult ::
  MonadIO m =>
  NvimE e m =>
  MonadDeepState s CommandState m =>
  [ParsedOutput] ->
  m ()
renderParseResult output = do
  setL @CommandState CommandState.parseReports (Just report)
  renderReport report syntax
  where
    report = mconcat reports
    syntax = ParsedOutput._syntax <$> output
    (_, reports) = mapAccumL format 0 output
    format offset (ParsedOutput _ cons) =
      (offset + length events, report)
      where
        report@(ParseReport events _) = cons offset