# A pane window has the main window's panels, and the menu bar acts on it while it is in front: Show Changes (⌥⌘0)
# opens its own changes inspector and Session Info (⌘I) its own facts popover.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-changes.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "The uploader retries now. One more setting to change."
e2e_menu Pane "Open in New Window"
e2e_expect_windows 2
e2e_expect_gone "Synthetic refactor, Claude, Working"
e2e_expect_text "The uploader retries now. One more setting to change."
e2e_expect_menu_item Pane "Rename…" disabled
e2e_key 0 command option
e2e_expect_text "2 files"
e2e_expect_label "Uploader.swift"
e2e_shot window-changes
e2e_click "Show Changes"
e2e_expect_gone "2 files"
e2e_quit
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-facts.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "The popover is in place and reads the log's own rows."
e2e_menu Pane "Open in New Window"
e2e_expect_windows 2
e2e_expect_gone "Synthetic refactor, Claude, Working"
e2e_expect_menu_item Pane "Session Info" enabled
e2e_key i command
e2e_expect_text "claude-opus-4-1-20250805"
e2e_expect_text "84.2k tokens"
e2e_shot window-facts
e2e_key escape
e2e_expect_gone "84.2k tokens"
