# Session Info (⌘I) opens a popover on the toolbar's status item with the session's model, folder, branch and context.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-facts.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "The popover is in place and reads the log's own rows."
e2e_expect_menu_item Pane "Session Info" enabled
e2e_key i command
e2e_expect_text "claude-opus-4-1-20250805"
e2e_expect_text "feature/facts"
e2e_expect_text "84.2k tokens"
e2e_expect_text "/home/user/project"
e2e_shot facts
e2e_key escape
e2e_expect_gone "84.2k tokens"
