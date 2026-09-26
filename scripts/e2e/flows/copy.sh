# Copy Conversation as Markdown (⌘⇧C) puts the selected pane's conversation on the pasteboard.
printf '' | pbcopy
e2e_launch
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "I'll look at the helper first."
e2e_key c command shift
e2e_wait "the conversation on the pasteboard" sh -c 'pbpaste | grep -q "^### Assistant$"'
pbpaste >"${E2E_OUT}/copy.md"
grep -qx "Rename the helper and run the tests" "${E2E_OUT}/copy.md"
e2e_shot copy
