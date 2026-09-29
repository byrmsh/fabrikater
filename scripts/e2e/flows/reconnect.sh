# The host comes back: with no snapshot the sidebar says Offline, and once the snapshot can be read the herd fills in
# on the retry backoff, with no relaunch. When the host goes away again, the herd stays and the footer says it is stale.
e2e_launch --none events.synthetic.jsonl
e2e_expect_label "Offline"
e2e_swap_fixture snapshot.synthetic.json snapshot.synthetic.json
E2E_TIMEOUT=45 e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_expect_text "Connected"
e2e_shot reconnect
rm "${e2e_fixture_dir}/snapshot.synthetic.json"
E2E_TIMEOUT=45 e2e_expect_text "Offline, showing the last known state"
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_shot reconnect-stale
