# A log longer than the first read starts clipped; Load Earlier Messages reads further back, to its first prompt.
# The top of the conversation is scrolled out of view, so the pasteboard (Copy Conversation) shows what was loaded.
printf '' | pbcopy
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-backfill.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "The latest reply in a long session."
e2e_expect_menu_item Pane "Load Earlier Messages" enabled
e2e_key c command shift
e2e_wait "the clipped conversation on the pasteboard" sh -c 'pbpaste | grep -q "The latest reply in a long session."'
if pbpaste | grep -q "The first prompt in a long session"; then false; fi
e2e_menu Pane "Load Earlier Messages"
e2e_expect_menu_item Pane "Load Earlier Messages" disabled
e2e_key c command shift
e2e_wait "the first prompt on the pasteboard" sh -c 'pbpaste | grep -q "The first prompt in a long session"'
e2e_shot backfill
