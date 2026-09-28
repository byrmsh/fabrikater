# A blocked pane whose prompt fabrikater cannot read gets a card that says so and offers no answer.
e2e_launch
e2e_key k command
e2e_key codex
e2e_expect_text "Synthetic A › web"
e2e_key return
e2e_expect_text "Waiting for Input"
e2e_expect_text "The agent is waiting for input that fabrikater can't read."
e2e_shot prompt-fallback
