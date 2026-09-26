# Hide Pane drops the selected pane's row, Show Hidden Panes (⌘⇧.) brings it back marked, turning off Show Shell Panes
# drops the shell pane, and hiding survives a relaunch.
e2e_launch
e2e_expect_label "zsh, Shell, Unknown"
e2e_key down command
e2e_menu Pane "Hide Pane"
e2e_expect_gone "Synthetic refactor, Claude, Working"
e2e_menu View "Show Shell Panes"
e2e_expect_gone "zsh, Shell, Unknown"
e2e_expect_label "codex, Codex, Needs input"
e2e_shot hiding
e2e_quit
E2E_KEEP_NOTES=1 e2e_launch
e2e_expect_label "codex, Codex, Needs input"
e2e_expect_no_text "zsh, Shell, Unknown"
e2e_menu View "Show Hidden Panes"
e2e_expect_label "Synthetic refactor, Claude, Working, Hidden"
e2e_shot hiding-shown
