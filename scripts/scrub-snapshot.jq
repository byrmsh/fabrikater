# Replaces the free text of a `herdr api snapshot` reply with stable placeholders.
# Ids, statuses, numbers and the scratch workspace label `fabrikater-test` are kept; the same input text always
# maps to the same placeholder, so panes and agents that share a cwd or session still match after scrubbing.

def table($values; f): reduce ($values | unique | to_entries[]) as $e ({}; .[$e.value] = ($e.key + 1 | f));
def fake_uuid: "00000000-0000-4000-8000-" + ("000000000000" + tostring)[-12:];

[.. | objects | (.cwd?, .foreground_cwd?) | strings] as $paths
| [.. | objects | (.terminal_title?, .terminal_title_stripped?) | strings] as $titles
| [.. | objects | .agent_session? | objects | .value | strings] as $sessions
| table($paths; "/home/user/project-\(.)") as $path
| table($titles; "Title \(.)") as $title
| table($sessions; fake_uuid) as $session
| walk(
    if type == "object" then
        (if (.cwd | type) == "string" then .cwd = $path[.cwd] else . end)
        | (if (.foreground_cwd | type) == "string" then .foreground_cwd = $path[.foreground_cwd] else . end)
        | (if (.terminal_title | type) == "string" then .terminal_title = $title[.terminal_title] else . end)
        | (if (.terminal_title_stripped | type) == "string"
            then .terminal_title_stripped = $title[.terminal_title_stripped] else . end)
        | (if (.agent_session | type) == "object" and (.agent_session.value | type) == "string"
            then .agent_session.value = $session[.agent_session.value] else . end)
        | (if (.name | type) == "string" and .name != .agent then .name = "Name" else . end)
        | (if (.label | type) != "string" or .label == "fabrikater-test" or has("pane_id") then .
            elif has("tab_id") then .label = "Tab \(.number // .tab_id)"
            elif has("workspace_id") then .label = "Workspace \(.number // .workspace_id)"
            else .label = "Label" end)
    else . end
)
