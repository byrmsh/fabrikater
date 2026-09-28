# Lines an agent writes to its session log appear in the open conversation, in the main window and in a pane window.
e2e_launch
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "The helper is renamed and one test still fails."
e2e_expect_no_text "Fix the failing test too"
e2e_append_fixture claude-follow.synthetic.jsonl claude.synthetic.jsonl
e2e_expect_text "Fix the failing test too"
e2e_expect_text "The failing test expected the old name; it passes now."
e2e_shot follow
e2e_menu Pane "Open in New Window"
e2e_expect_windows 2
e2e_expect_text "The failing test expected the old name; it passes now."
e2e_append_fixture claude-follow-more.synthetic.jsonl claude.synthetic.jsonl
e2e_expect_text "Both tests pass on the renamed helper."
e2e_shot follow-window
