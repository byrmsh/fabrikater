# Pane › Past Sessions… (⌘Y) lists the sessions kept beside the selected pane's log, newest first with the live one
# marked Current, and Return opens the highlighted one read-only in a window of its own.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl claude-sessions.synthetic.txt \
    claude-00000000-0000-4000-8000-0000000000a1.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_expect_menu_item Pane "Past Sessions…" disabled
e2e_key down command
e2e_expect_text "I'll look at the helper first."
e2e_key y command
e2e_expect_text "Sessions in project-1"
e2e_expect_text "Add a retry with backoff to the sync client"
e2e_expect_text "Why does the settings screen flicker on launch?"
e2e_expect_text "Current"
e2e_shot past-sessions
e2e_key return
e2e_expect_windows 2
e2e_expect_text "Done. Pushes now retry after 1, 2, 4 and 8 seconds before giving up."
e2e_expect_no_text "Message the agent"
e2e_shot past-session-window
# The menu bar's conversation commands act on the session window in front, and the pane's commands have nothing to act
# on there.
printf '' | pbcopy
e2e_key c command shift
e2e_wait "the past session on the pasteboard" sh -c 'pbpaste | grep -q "Pushes now retry"'
e2e_expect_menu_item Pane "Send" disabled
e2e_expect_menu_item Pane "Reload Conversation" enabled
