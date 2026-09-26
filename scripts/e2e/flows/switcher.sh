# ⌘K opens the quick switcher over every pane; typing narrows it, Return opens the match, Esc closes.
e2e_launch
e2e_expect_text "Synthetic refactor"
e2e_key k command
e2e_expect_text "Synthetic A › api"
e2e_expect_text "fabrikater-test › scratch"
e2e_shot switcher
e2e_key escape
e2e_expect_gone "fabrikater-test › scratch"
e2e_key k command
e2e_expect_text "Synthetic A › api"
e2e_key codex
e2e_expect_text "Synthetic A › web"
e2e_expect_gone "fabrikater-test › scratch"
e2e_shot switcher-search
e2e_key return
e2e_expect_text "Conversations from Codex cannot be shown yet."
e2e_shot switcher-chosen
