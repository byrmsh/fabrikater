# A long conversation (claude-scale.synthetic.jsonl, 1.5 MB) in a herd of 64 panes opens at its latest reply, finds a
# message far up, and still shows a line appended to the log. Prints how long each took (docs/performance.md).
_scale_now() { perl -MTime::HiRes=time -e 'printf "%.1f", time'; }
_scale_took() { echo "scale: $1 after $(perl -e "printf '%.1f', $(_scale_now) - $2") s"; }

e2e_launch snapshot-scale.synthetic.json=snapshot.synthetic.json events.synthetic.jsonl claude-scale.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Scale pane 1, Claude, Idle"
started=$(_scale_now)
e2e_key down command
e2e_expect_text "Step 450 is configurable now and its suite passes."
_scale_took "the conversation showed" "${started}"
e2e_shot scale
e2e_key f command
e2e_expect_focused_field "Find in Conversation"
started=$(_scale_now)
e2e_key "Turn 400:"
e2e_expect_text "1 of 1"
_scale_took "find scrolled to its match" "${started}"
e2e_shot scale-find
e2e_key escape
started=$(_scale_now)
e2e_append_fixture claude-scale-more.synthetic.jsonl claude.synthetic.jsonl
e2e_expect_text "The long session still follows live."
_scale_took "the appended line showed" "${started}"
e2e_shot scale-follow
