# Show Session Info (⌘I) opens the Session Info panel on the right with the session's model, folder, branch and context,
# and pressing it again closes the panel.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-facts.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "The popover is in place and reads the log's own rows."
e2e_expect_menu_item View "Show Session Info" enabled
e2e_key i command
e2e_expect_text "claude-opus-4-1-20250805"
e2e_expect_text "feature/facts"
e2e_expect_text "84.2k tokens"
e2e_expect_text "/home/user/project"
e2e_shot facts
e2e_key i command
e2e_expect_gone "84.2k tokens"
