# Codex, omp and OpenCode panes show their conversations from their own logs; a shell pane opens in the terminal.
e2e_launch snapshot-agents.synthetic.json=snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl \
    codex.synthetic.jsonl pi.synthetic.jsonl opencode.synthetic.jsonl terminal-w1-pA.synthetic.txt
e2e_expect_text "Synthetic refactor"
e2e_key k command
e2e_expect_text "Synthetic A › api"
e2e_key dates
e2e_expect_text "Synthetic A › web"
e2e_key return
e2e_expect_text "I'll find where dates are parsed first."
e2e_expect_text "ISO week dates like"
e2e_expect_no_text "Conversations from"
e2e_expect_menu_item View "Show Terminal" enabled
e2e_shot agents-codex
e2e_key k command
e2e_expect_text "Synthetic A › api"
e2e_key retries
e2e_key return
e2e_expect_text "Let me read the retry loop."
e2e_expect_text "The loop never counts attempts."
e2e_shot agents-omp
e2e_key k command
e2e_expect_text "Synthetic A › api"
e2e_key rename
e2e_key return
e2e_expect_text "I'll find every use of the flag."
e2e_expect_text "lint is clean now."
e2e_shot agents-opencode
e2e_key k command
e2e_expect_text "Synthetic A › api"
e2e_key zsh
e2e_key return
e2e_expect_gone "Reading the terminal…"
e2e_expect_no_text "Terminal Unavailable"
e2e_expect_no_text "This pane runs a shell"
e2e_expect_menu_item View "Show Terminal" disabled
e2e_shot agents-shell
