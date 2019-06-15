{-# OPTIONS_GHC -F -pgmF htfpp #-}

module Output.ParseHaskellSpec(
  htf_thisModulesTests,
) where

import Control.Monad.Trans.Except (runExceptT)
import Data.Text (Text)
import qualified Data.Text as Text (unlines)
import Data.Vector (Vector)
import qualified Data.Vector as Vector (fromList)
import Ribosome.Test.Unit (fixtureContent)
import Test.Framework

import Myo.Command.Parse (parseWith)
import Myo.Output.Data.OutputError (OutputError)
import qualified Myo.Output.Data.ParseReport as ParseReport (_lines)
import Myo.Output.Data.ParsedOutput (ParsedOutput(ParsedOutput))
import qualified Myo.Output.Data.ReportLine as ReportLine (_text)
import Myo.Output.Lang.Haskell.Parser hiding (parseHaskell)

haskellOutput :: Text
haskellOutput =
  Text.unlines [
    "leading crap",
    "/path/to/Module/File.hs:13:5: error:",
    "    • Couldn't match type ‘TypeA’ with ‘TypeB’",
    "      Expected type: TypeB",
    "        Actual type: TypeA",
    "    • In the expression: f a b",
    "      In an equation for ‘Module.foo’:",
    "          foo = f a b",
    "   |",
    "13 |   f a b",
    "   |   ^^^^",
    "",
    "/path/to/Module/File.hs:19:7: error: [-fhygiene]",
    "    Not in scope: type constructor or class ‘Something’",
    "   |",
    "19 | makeSomething :: Text -> [Something]",
    "   |                             ^^^^^^^^^",
    "",
    "/path/to/Module/File.hs:2:77: warning: [-Wmissing-methods]",
    "    • No explicit implementation for",
    "        ‘meth’",
    "    • In the instance declaration for ‘Closs Int’",
    "   |",
    "31 | instance Closs Int where",
    "   |          ^^^^^^^^^",
    "",
    "/path/to/File.hs:5:5: error:",
    "    • Couldn't match expected type ‘StateT",
    "                                      (ReaderT",
    "                                         (GHC.Conc.Sync.TVar Data))",
    "                                      a0’",
    "                  with actual type ‘t0 Data1",
    "                                    -> StateT (ReaderT e0) ()’",
    "    • Probable cause: ‘mapM_’ is applied to too few arguments",
    "      In a stmt of a 'do' block: mapM_ end",
    "      In the expression:",
    "        do a <- start",
    "           mapM_ end",
    "      In an equation for ‘execute’:",
    "          execute",
    "            = do a <- start",
    "                 mapM_ end",
    "  |",
    "5 |   mapM_ end",
    "  |   ^^^^^^^^^",
    "",
    "    /path/to/File.hs:17:1: error: [-Wunused-imports, -Werror=unused-imports]",
    "        The import of ‘ComposeSt, captureT, control, defaultLiftBaseWith,",
    "                       defaultRestoreM, embed, embed_’",
    "        from module ‘Control.Monad.Trans.Control’ is redundant",
    "       |",
    "    17 | import Control.Monad.Trans.Control (ComposeSt, MonadBaseControl(..), defaultRestoreM)",
    "       | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^",
    "",
    "    /path/to/File.hs:24:1: error: [-Wunused-imports, -Werror=unused-imports]",
    "        The import of ‘Data.Either.Combinators’ is redundant",
    "          except perhaps to import instances from ‘Data.Either.Combinators’",
    "        To import instances alone, use: import Data.Either.Combinators()",
    "       |",
    "    24 | import Data.Either.Combinators (swapEither)",
    "       | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^",
    "",
    "    /path/to/File.hs:36:1: error:",
    "        Parse error: module header, import declaration",
    "        or top-level declaration expected.",
    "       |",
    "    36 | xyzabcd",
    "       | ^^^^^^^",
    "",
    "    /path/to/File.hs:36:1: error:",
    "        • No instance for (MonadIO (t m)) arising from a use of ‘func’",
    "          Possible fix:",
    "            add (MonadIO (t m)) to the context of",
    "              the type signature for:",
    "                func :: forall a (m :: * -> *). a -> m ()",
    "        • In the expression: func",
    "          In an equation for ‘func’: func = liftIO",
    "       |",
    "    70 |   func",
    "       |   ^^^^",
    "",
    "    /path/to/File.hs:36:1: error:",
    "      Variable not in scope: var",
    "        :: IO a0",
    "       |",
    "    77 |   var",
    "       |   ^^^",
    "    /path/to/File.hs:36:1: error:",
    "        The qualified import of ‘Name’",
    "        from module ‘Module’ is redundant",
    "       |",
    "    14 | import qualified Module as M (",
    "       | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^...",
    "",
    "    /path/to/File.hs:36:1: error:",
    "    A do-notation statement discarded a result of type",
    "      ‘m ()’",
    "    Suppress this warning by saying",
    "      ‘_ <- expr’",
    "",
    "    /path/to/File.hs:36:1: error:",
    "    Module ‘Mod.Ule’ does not export ‘NoSuchName’",
    "    File name does not match module name:",
    "    Saw: ‘Wrong.Module’",
    "    Expected: ‘Correct.Module’",
    "",
    "    /path/to/File.hs:36:1: error:",
    "    Could not find module ‘Non.Existing.Module’",
    "    Use -v to see a list of the files searched for.",
    "    /path/to/File.hs:36:1: error:",
    "      • Could not deduce (Class t m)",
    "        arising from a use of ‘constraintedFun’",
    "      from the context: (MonadIO m, MonadTrans t)",
    "    /path/to/File.hs:36:1: error:",
    "    • Couldn't match type ‘Path.Internal.Path Path.Abs Path.Dir’",
    "                     with ‘[Char]’",
    "      Expected type: ProjectConfig -> [FilePath]",
    "        Actual type: ProjectConfig",
    "                     -> [Path.Internal.Path Path.Abs Path.Dir]",
    "    • Could not deduce (MonadThrow m)",
    "        arising from a use of ‘projectFromNameIn’",
    "      from the context: MonadIO m",
    ""
    ]

target :: Vector Text
target = Vector.fromList [
  "/path/to/Module/File.hs \57505 13",
  "type mismatch",
  "TypeA",
  "TypeB",
  "",
  "/path/to/Module/File.hs \57505 19",
  "type not in scope",
  "Something",
  "",
  "/path/to/Module/File.hs \57505 2",
  "method not implemented: meth",
  "",
  "/path/to/File.hs \57505 5",
  "type mismatch",
  "t0 Data1 -> StateT (ReaderT e0) ()",
  "StateT (ReaderT (GHC.Conc.Sync.TVar Data)) a0",
  "",
  "/path/to/File.hs \57505 17",
  "redundant name imports",
  "ComposeSt, captureT, control, defaultLiftBaseWith, defaultRestoreM, embed, embed_",
  "Control.Monad.Trans.Control",
  "",
  "/path/to/File.hs \57505 24",
  "redundant module import",
  "Data.Either.Combinators",
  "",
  "/path/to/File.hs \57505 36",
  "syntax error",
  "",
  "/path/to/File.hs \57505 36",
  "!instance: func",
  "MonadIO (t m)",
  "",
  "/path/to/File.hs \57505 36",
  "variable not in scope",
  "var :: IO a0",
  "",
  "/path/to/File.hs \57505 36",
  "redundant name imports",
  "Name",
  "Module",
  "",
  "/path/to/File.hs \57505 36",
  "do-notation result discarded",
  "m ()",
  "",
  "/path/to/File.hs \57505 36",
  "invalid import name",
  "NoSuchName",
  "Mod.Ule",
  ""
  ]

parseHaskell :: IO (Either OutputError ParsedOutput)
parseHaskell =
  runExceptT $ parseWith haskellOutputParser haskellOutput

test_parseHaskellErrors :: IO ()
test_parseHaskellErrors = do
  outputE <- parseHaskell
  ParsedOutput _ cons <- assertRight outputE
  let
    report = cons 0
    lines' = ReportLine._text <$> ParseReport._lines report
  assertEqual target lines'

parseHaskellGarbage :: IO (Either OutputError ParsedOutput)
parseHaskellGarbage = do
  output <- fixtureContent "output/parse/haskell-garbage"
  runExceptT $ parseWith haskellOutputParser (toText output)

garbageTarget :: Vector Text
garbageTarget =
  Vector.fromList [
    "/path/to/File.hs \57505 1",
    "variable not in scope",
    "var :: IO a0",
    ""
    ]

test_parseGarbage :: IO ()
test_parseGarbage = do
  outputE <- parseHaskellGarbage
  ParsedOutput _ cons <- assertRight outputE
  let
    report = cons 0
    lines' = ReportLine._text <$> ParseReport._lines report
  assertEqual garbageTarget lines'
