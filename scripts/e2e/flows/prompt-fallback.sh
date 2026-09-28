# A blocked pane whose prompt fabrikater cannot read gets a card that says so, offers no answer, and switches to the
# terminal.
e2e_launch
e2e_key k command
e2e_key codex
e2e_expect_text "Synthetic A › web"
e2e_key return
e2e_expect_text "Waiting for Input"
e2e_expect_text "The agent is waiting for input that fabrikater can't read."
e2e_shot prompt-fallback
# The small button shows its name only through its help tag in the accessibility tree.
e2e_click "Answer the prompt in the pane's terminal"
e2e_expect_gone "No Conversation"
e2e_shot prompt-fallback-terminal
