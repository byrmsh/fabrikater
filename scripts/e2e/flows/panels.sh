# The panels move: View ▸ Plan Panel ▸ On the Right takes the plan out of the strip above the conversation into the
# right-hand column, Show Session Info (⌘I) joins it below, and Move Up puts it above the plan. The arrangement is still
# there after a relaunch; On the Left moves the plan into a column beside the conversation, and Reset Panels puts
# everything back.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-todos.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "2 of 4 done"
e2e_expect_label "Plan Panel"
e2e_submenu View "Plan Panel" "On the Right"
e2e_expect_text "2 of 4 done"
e2e_key i command
e2e_expect_order "Plan Panel" "Session Info Panel"
e2e_shot panels-right
e2e_submenu View "Session Info Panel" "Move Up"
e2e_expect_order "Session Info Panel" "Plan Panel"
e2e_quit
E2E_KEEP_NOTES=1 e2e_launch snapshot.synthetic.json events.synthetic.jsonl \
    claude-todos.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_order "Session Info Panel" "Plan Panel"
e2e_submenu View "Plan Panel" "On the Left"
e2e_expect_text "Writing the retry tests"
e2e_shot panels-left
e2e_menu View "Reset Panels"
e2e_expect_gone "Session Info Panel"
e2e_expect_text "2 of 4 done"
e2e_shot panels-reset
