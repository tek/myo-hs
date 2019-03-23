module Myo.Settings where

import Ribosome.Data.Setting (Setting(Setting))

vimTmuxPane :: Setting Int
vimTmuxPane = Setting "vim_tmux_pane" True Nothing

tmuxSocket :: Setting FilePath
tmuxSocket = Setting "tmux_socket" True Nothing

displayResult :: Setting Bool
displayResult =
  Setting "display_result" True (Just True)

detectUi :: Setting Bool
detectUi =
  Setting "detect_ui" True (Just True)
