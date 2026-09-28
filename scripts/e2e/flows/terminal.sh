# View › Show Terminal (⌘T) swaps the conversation for the pane's terminal, and back; a shell pane's in dark mode.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl screen-w1-p1.synthetic.txt \
    terminal-w1-pA.synthetic.txt
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "I'll look at the helper first."
e2e_expect_menu_item View "Show Terminal" enabled
e2e_key t command
e2e_expect_gone "I'll look at the helper first."
e2e_expect_gone "Reading the terminal…"
e2e_expect_no_text "Terminal Unavailable"
e2e_shot terminal
e2e_key t command
e2e_expect_text "I'll look at the helper first."
e2e_quit
E2E_DARK=1 e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl \
    terminal-w1-pA.synthetic.txt
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_key down command
e2e_key t command
e2e_expect_gone "Reading the terminal…"
e2e_expect_no_text "Terminal Unavailable"
e2e_shot terminal-shell-dark
