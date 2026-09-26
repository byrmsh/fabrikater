# Open Folder in VS Code waits for a pane with a known folder, then is enabled in the Pane menu. It is not chosen: that
# would start VS Code on the machine running the flow.
e2e_launch
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_expect_menu_item Pane "Open Folder in VS Code" disabled
e2e_key down command
e2e_expect_text "I'll look at the helper first."
e2e_expect_menu_item Pane "Open Folder in VS Code" enabled
e2e_shot vscode
