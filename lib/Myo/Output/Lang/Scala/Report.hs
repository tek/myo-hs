module Myo.Output.Lang.Scala.Report where

import Control.Lens (ifolded, withIndex)
import Control.Monad (join)
import Data.Attoparsec.Text (parseOnly)
import Data.Either.Combinators (mapLeft)
import qualified Data.List as List (unwords)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Text as Text (splitAt)
import Data.Vector (Vector)
import qualified Data.Vector as Vector (fromList, unzip)
import Data.Vector.Lens (toVectorOf)
import Text.Parser.Char (CharParsing, anyChar, char, noneOf, string)
import Text.Parser.Combinators (between, choice, many, sepBy1, skipMany, skipOptional, some, try)
import Text.Parser.Token (TokenParsing, brackets, parens, whiteSpace)

import Myo.Output.Data.Location (Location(Location))
import Myo.Output.Data.OutputError (OutputError)
import qualified Myo.Output.Data.OutputError as OutputError (OutputError(Parse))
import Myo.Output.Data.OutputEvent (EventIndex(EventIndex), OutputEvent(OutputEvent))
import Myo.Output.Data.ParseReport (ParseReport(ParseReport))
import Myo.Output.Data.ParsedOutput (ParsedOutput(ParsedOutput))
import Myo.Output.Data.ReportLine (ReportLine(ReportLine))
import Myo.Output.Data.String (lineNumber)
import Myo.Output.Lang.Scala.Data.ScalaEvent (EventType, ScalaEvent(ScalaEvent))
import qualified Myo.Output.Lang.Scala.Data.ScalaEvent as EventType (EventType(..))
import Myo.Output.Lang.Scala.Syntax (scalaSyntax)

colMarker :: Text
colMarker =
  "†"

foundReqSeparator :: Text
foundReqSeparator =
  "|"

foundMarker :: Text
foundMarker =
  "+"

reqMarker :: Text
reqMarker =
  "-"

separatorMarker :: Text
separatorMarker =
  "<"

data ScalaMessage =
  ScalaMessage {
    smError :: Text,
    smInfo :: [Text],
    smCode :: Text
  }
  deriving (Eq, Show)

qname :: TokenParsing m => m Text
qname =
  toText . List.unwords <$> between (char '‘') (char '’') (sepBy1 (some (noneOf "\n ’")) whiteSpace)

ws :: TokenParsing m => m ()
ws =
  skipOptional whiteSpace

data ScalaOutputEvent =
  ScalaOutputEvent {
    level :: Int,
    index :: Int,
    location :: Location,
    message :: ScalaMessage
    }
  deriving (Eq, Show)

formatLocation :: Location -> Text
formatLocation (Location path line _) =
  unwords [toText path, lineNumber, show (line + 1)]

data FRExpr =
  Plain Text
  |
  Bracketed Text FRExpr
  |
  Parenthesized Text FRExpr
  |
  FR FRExpr FRExpr
  -- |
  -- FRTuple [FRExpr]
  deriving (Eq, Show)

bracketParser ::
  Monad m =>
  CharParsing m =>
  TokenParsing m =>
  m FRExpr
bracketParser =
  choice $ surrounded ++ [try foundreq, Plain <$> plain]
  where
    surrounded = [try bracketed, try parenthesized]
    plain = toText <$> many (noneOf "[]()|")
    bracketed = do
      before <- plain
      sub <- brackets bracketParser
      return $ Bracketed before sub
    parenthesized = do
      before <- plain
      sub <- parens bracketParser
      return $ Parenthesized before sub
    -- tuple =
    --   FRTuple <$> sepBy1 bracketParser (char ',')
    foundreq = do
      found <- part <* (char '|')
      FR found <$> part
      where
        part = choice $ surrounded ++ [Plain <$> plain]

formatInfo :: Text -> Text
formatInfo input =
  fromRight input (format <$> parse)
  where
    format (Plain text) = text
    format (Bracketed pre sub) =
      pre <> "[" <> format sub <> "]"
    format (Parenthesized pre sub) =
      pre <> "(" <> format sub <> ")"
    format (FR found req) =
      foundMarker <> (format found) <> separatorMarker <> "|" <> (format req) <> reqMarker
    parse = parseOnly bracketParser input

indent :: Text -> Text
indent =
  ("  " <>)

formatCode :: Location -> Text -> Text
formatCode (Location _ _ col) code =
  pre <> colMarker <> post
  where
    num = fromMaybe 0 col
    (pre, post) = Text.splitAt num code

formatReportLine :: Int -> Location -> ScalaMessage -> Vector ReportLine
formatReportLine index location (ScalaMessage err info code) = do
  ReportLine (EventIndex index) <$> Vector.fromList lines'
  where
    lines' =
      formatLocation location : err : formattedInfo <> [formattedCode, ""]
    formattedInfo =
      indent . formatInfo <$> info
    formattedCode =
      indent . formatCode location $ code

formatEvent :: Location -> Int -> Int -> ScalaMessage -> (OutputEvent, Vector ReportLine)
formatEvent location level index message =
  (OutputEvent (Just location) level, formatReportLine index location message)

parsedOutputCons :: Vector ScalaOutputEvent -> Int -> ParseReport
parsedOutputCons events offset =
  ParseReport events' (join lines')
  where
    (events', lines') = Vector.unzip (cons <$> events)
    cons ScalaOutputEvent{..} =
      formatEvent location level (index + offset) message

eventLevel :: EventType -> Int
eventLevel EventType.Warning = 1
eventLevel EventType.Error = 0

eventReport :: Int -> ScalaEvent -> Either OutputError ScalaOutputEvent
eventReport index (ScalaEvent loc tpe msg info code) =
  return $ ScalaOutputEvent (eventLevel tpe) index loc (ScalaMessage msg info code)

scalaReport :: Vector ScalaEvent -> Either OutputError ParsedOutput
scalaReport events =
  ParsedOutput scalaSyntax . parsedOutputCons <$> (traverse (uncurry eventReport) . zipWithIndex) events
  where
    zipWithIndex = toVectorOf (ifolded . withIndex)
