# ⌘F opens the find bar over the conversation: typing counts the matching messages, Return steps to the next and
# wraps, a query with no match says so, and Esc closes the bar.
e2e_launch
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_key f command
e2e_expect_focused_field "Find in Conversation"
e2e_key "helper"
e2e_expect_text "3 of 3"
e2e_shot find
e2e_key return
e2e_expect_text "1 of 3"
e2e_shot find-next
e2e_key g command
e2e_expect_text "2 of 3"
e2e_key "zebra"
e2e_expect_text "Not Found"
e2e_key escape
e2e_expect_gone "Not Found"
e2e_shot find-closed
