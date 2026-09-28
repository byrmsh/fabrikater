# View › Sort Panes By › Recent Activity moves a pane that changed to the top of its workspace, and Herdr Order puts it
# back.
e2e_launch
e2e_submenu View "Sort Panes By" "Recent Activity"
e2e_expect_order "Synthetic refactor, Claude, Working" "codex, Codex, Needs input"
e2e_swap_fixture snapshot-codex.synthetic.json snapshot.synthetic.json
E2E_TIMEOUT=45 e2e_expect_order "codex, Codex, Needs input" "Synthetic refactor, Claude, Working"
e2e_shot sorting
e2e_submenu View "Sort Panes By" "Herdr Order"
e2e_expect_order "Synthetic refactor, Claude, Working" "codex, Codex, Needs input"
e2e_shot sorting-herdr
