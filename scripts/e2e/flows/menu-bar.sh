# The menu bar item lists the Needs You panes: choosing the blocked Codex pane brings the main window forward on it,
# reopening the window when it was closed, and Settings' "Show Needs You in the menu bar" takes the item out.
e2e_launch
e2e_expect_label "codex, Codex, Needs input"
e2e_expect_status_item 1
e2e_expect_status_menu_item "codex · Needs input"
e2e_expect_status_menu_item "arch: 1 pane needs you"
e2e_key w command
e2e_expect_windows 0
E2E_SHOT=menu-bar e2e_status_menu "codex · Needs input"
e2e_expect_windows 1
e2e_expect_label "Codex, Needs input"
e2e_shot menu-bar-chosen
e2e_key "," command
e2e_expect_windows 2
e2e_click "Show Needs You in the menu bar"
e2e_expect_status_item 0
e2e_shot menu-bar-settings
