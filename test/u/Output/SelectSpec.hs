{-# OPTIONS_GHC -F -pgmF htfpp #-}

module Output.SelectSpec(
  htf_thisModulesTests,
) where

import qualified Chiasma.Data.Ident as Ident (Ident(Str))
import Data.Vector (Vector)
import qualified Data.Vector as Vector (fromList)
import Ribosome.Api.Window (currentCursor)
import Ribosome.Plugin.Mapping (executeMapping)
import Ribosome.Test.Ui (windowCountIs)
import Ribosome.Test.Unit (fixture)
import System.FilePath ((</>))
import Test.Framework

import Config (outputAutoJump, outputSelectFirst, svar)
import Myo.Command.Data.CommandState (CommandState)
import qualified Myo.Command.Data.CommandState as CommandState (parseResult)
import Myo.Command.Output (renderParseResult)
import Myo.Data.Env (Myo)
import Myo.Init (initialize'')
import Myo.Output.Data.Location (Location(Location))
import Myo.Output.Data.OutputEvent (OutputEvent(OutputEvent))
import Myo.Output.Data.ParseReport (ParseReport(ParseReport))
import Myo.Output.Data.ParseResult (ParseResult(ParseResult))
import Myo.Output.Data.ParsedOutput (ParsedOutput(ParsedOutput))
import Myo.Output.Data.ReportLine (ReportLine)
import Myo.Output.Lang.Haskell.Report (HaskellMessage(FoundReq1, NoMethod), formatReportLine)
import Myo.Output.Lang.Haskell.Syntax (haskellSyntax)
import Myo.Plugin (mappingOutputSelect)
import Unit (tmuxSpec)

events :: FilePath -> Vector OutputEvent
events file =
  Vector.fromList [OutputEvent (Just (Location file 9 (Just 2))) 0, OutputEvent Nothing 1]

loc :: FilePath -> Location
loc file =
  Location file 10 Nothing

reportLines :: FilePath -> Vector ReportLine
reportLines file =
  formatReportLine 0 (loc file) (FoundReq1 "TypeA" "TypeB") <> formatReportLine 0 (loc file) (NoMethod "fmap")

parsedOutput :: FilePath -> ParsedOutput
parsedOutput file =
  ParsedOutput haskellSyntax (const $ ParseReport (events file) (reportLines file))

outputSelectSpec :: Myo ()
outputSelectSpec = do
  file <- fixture $ "output" </> "select" </> "File.hs"
  let po = [parsedOutput file]
  initialize''
  setL @CommandState CommandState.parseResult (Just (ParseResult (Ident.Str "test") po))
  renderParseResult (Ident.Str "test") po
  windowCountIs 2
  executeMapping mappingOutputSelect
  (line, col) <- currentCursor
  gassertEqual (9, 2) (line, col)

test_outputSelect :: IO ()
test_outputSelect =
  tmuxSpec (svar outputSelectFirst True . svar outputAutoJump False) outputSelectSpec
