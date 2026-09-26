# Steps for scripts/e2e/flows/*.sh, sourced by scripts/e2e.sh. Each step fails the flow when it does not hold.
# UI queries go through System Events (the Accessibility API), so the shell running this needs Accessibility and
# Screen Recording access; GitHub's macOS runners grant both.

E2E_APP="${E2E_APP:-build/fabrikater.app}"
E2E_BINARY="${E2E_APP}/Contents/MacOS/fabrikater"
E2E_OUT="${E2E_OUT:-build/e2e}"
E2E_TIMEOUT="${E2E_TIMEOUT:-20}"
E2E_PROCESS="fabrikater"
E2E_FIXTURES="Tests/Fixtures"

e2e_pid=""
e2e_fixture_dir=""

# e2e_launch [fixture...]: starts the app replaying only the named files from Tests/Fixtures, and waits for its window.
# The default is the synthetic herd and conversation. With no files at all (`e2e_launch --none`) every read fails.
e2e_launch() {
    if [ "$#" -eq 0 ]; then
        set -- snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl
    elif [ "$1" = "--none" ]; then
        shift
    fi
    e2e_fixture_dir="$(mktemp -d)"
    local file
    # A loop over "$@" rather than an array: macOS's bash 3.2 treats an empty array as unset under `set -u`.
    for file in "$@"; do
        cp "${E2E_FIXTURES}/${file}" "${e2e_fixture_dir}/"
    done
    # `open` does not pass the environment on, so run the bundled binary directly.
    FABRIKATER_FIXTURES="${e2e_fixture_dir}" "${E2E_BINARY}" >"${E2E_OUT}/${E2E_FLOW:-app}.log" 2>&1 &
    e2e_pid=$!
    e2e_wait "the main window" _e2e_has_window
    osascript -e "tell application \"System Events\" to set frontmost of process \"${E2E_PROCESS}\" to true" >/dev/null
    sleep 1
}

# e2e_finish FLOW STATUS: scripts/e2e.sh calls it when a flow ends. A failed flow leaves FLOW-failure.png and
# FLOW-failure.txt (every element in the window with its text attributes) behind.
e2e_finish() {
    if [ "$2" -ne 0 ] && [ -n "${e2e_pid}" ]; then
        e2e_shot "$1-failure" || true
        e2e_screen_dump >"${E2E_OUT}/$1-failure.txt" || true
    fi
    e2e_quit
}

# e2e_quit: stops the app and removes its fixture copy.
e2e_quit() {
    if [ -n "${e2e_pid}" ]; then
        kill "${e2e_pid}" 2>/dev/null || true
        wait "${e2e_pid}" 2>/dev/null || true
        e2e_pid=""
    fi
    if [ -n "${e2e_fixture_dir}" ]; then
        rm -rf "${e2e_fixture_dir}"
        e2e_fixture_dir=""
    fi
}

# e2e_expect_text TEXT: waits until some element in the main window shows TEXT (name, value or description).
e2e_expect_text() {
    e2e_wait "\"$1\" on screen" _e2e_has_text "$1"
}

# e2e_expect_label TEXT: waits until VoiceOver reads some element as exactly TEXT: its title, value or description, never
# its help tag.
e2e_expect_label() {
    e2e_wait "an element labelled \"$1\"" _e2e_has_label "$1"
}

# e2e_expect_no_text TEXT: fails if TEXT is on screen now.
e2e_expect_no_text() {
    if _e2e_has_text "$1"; then
        echo "e2e: \"$1\" is on screen but should not be" >&2
        return 1
    fi
}

# e2e_expect_gone TEXT: waits until no element in the main window shows TEXT, as after closing a sheet.
e2e_expect_gone() {
    e2e_wait "\"$1\" to leave the screen" _e2e_lacks_text "$1"
}

# e2e_key KEY [modifier...]: presses a key in the app. KEY is a character or down, up, left, right, return, escape;
# modifiers are command, shift, option, control. Example: e2e_key down command
e2e_key() {
    local key="$1"
    shift
    local using=""
    if [ "$#" -gt 0 ]; then
        local mods=()
        local m
        for m in "$@"; do mods+=("${m} down"); done
        using=" using {$(IFS=,; echo "${mods[*]}" | sed 's/,/, /g')}"
    fi
    local press
    case "${key}" in
        down) press="key code 125" ;;
        up) press="key code 126" ;;
        left) press="key code 123" ;;
        right) press="key code 124" ;;
        return) press="key code 36" ;;
        escape) press="key code 53" ;;
        *) press="keystroke \"${key}\"" ;;
    esac
    osascript -e "tell application \"System Events\" to tell process \"${E2E_PROCESS}\"
        set frontmost to true
        ${press}${using}
    end tell" >/dev/null
    sleep 0.5
}

# e2e_focus_field PLACEHOLDER: clicks into the text field whose placeholder contains PLACEHOLDER.
e2e_focus_field() {
    e2e_wait "a field with placeholder \"$1\"" _e2e_focus_field "$1"
}

_e2e_focus_field() {
    [ "$(osascript 2>>"${E2E_OUT}/${E2E_FLOW:-app}.osascript.log" <<APPLESCRIPT
tell application "System Events"
    tell window 1 of process "${E2E_PROCESS}"
        repeat with uiItem in (entire contents as list)
            try
                if (value of attribute "AXPlaceholderValue" of uiItem) contains "$1" then
                    set value of attribute "AXFocused" of uiItem to true
                    return "focused"
                end if
            end try
        end repeat
    end tell
end tell
return "missing"
APPLESCRIPT
)" = "focused" ]
}

# e2e_shot NAME: saves the main window as build/e2e/NAME.png (the whole screen if the window cannot be found).
e2e_shot() {
    local path="${E2E_OUT}/$1.png"
    local bounds
    if bounds="$(osascript -e "tell application \"System Events\" to tell window 1 of process \"${E2E_PROCESS}\"
        set {x, y} to position
        set {w, h} to size
        return (x as text) & \",\" & (y as text) & \",\" & (w as text) & \",\" & (h as text)
    end tell" 2>/dev/null)"; then
        screencapture -x -o -R "${bounds}" "${path}"
    else
        screencapture -x "${path}"
    fi
    echo "screenshot: ${path}"
}

# e2e_wait WHAT COMMAND [ARG...]: retries COMMAND every half second until it succeeds or E2E_TIMEOUT runs out.
e2e_wait() {
    local what="$1"
    shift
    local deadline=$((SECONDS + E2E_TIMEOUT))
    until "$@"; do
        if [ -n "${e2e_pid}" ] && ! kill -0 "${e2e_pid}" 2>/dev/null; then
            echo "e2e: the app exited while waiting for ${what}; its log:" >&2
            cat "${E2E_OUT}/${E2E_FLOW:-app}.log" >&2
            return 1
        fi
        if [ "${SECONDS}" -ge "${deadline}" ]; then
            echo "e2e: timed out after ${E2E_TIMEOUT}s waiting for ${what}" >&2
            return 1
        fi
        sleep 0.5
    done
}

_e2e_has_window() {
    [ "$(osascript -e "tell application \"System Events\" to count windows of process \"${E2E_PROCESS}\"" 2>/dev/null)" \
        -gt 0 ] 2>/dev/null
}

# e2e_screen_text [ATTRIBUTE...]: prints every title, value, description and help tag in the main window's accessibility
# tree, one per line; or only the named attributes, such as AXTitle AXValue.
e2e_screen_text() {
    local attributes='"AXTitle", "AXValue", "AXDescription", "AXHelp"'
    if [ "$#" -gt 0 ]; then
        attributes="$(printf '"%s", ' "$@")"
        attributes="${attributes%, }"
    fi
    osascript 2>>"${E2E_OUT}/${E2E_FLOW:-app}.osascript.log" <<APPLESCRIPT
set found to {}
tell application "System Events"
    tell window 1 of process "${E2E_PROCESS}"
        repeat with uiItem in (entire contents as list)
            repeat with axName in {${attributes}}
                try
                    set text_ to value of attribute (contents of axName) of uiItem
                    if text_ is not missing value and text_ is not "" then set end of found to (text_ as text)
                end try
            end repeat
        end repeat
    end tell
end tell
set AppleScript's text item delimiters to linefeed
return found as text
APPLESCRIPT
}

# e2e_screen_dump: prints each element in the main window with its role and every text attribute it has. Slow; for
# working out what a check should look for.
e2e_screen_dump() {
    osascript 2>>"${E2E_OUT}/${E2E_FLOW:-app}.osascript.log" <<APPLESCRIPT
set found to {}
tell application "System Events"
    tell window 1 of process "${E2E_PROCESS}"
        repeat with uiItem in (entire contents as list)
            set line_ to ""
            try
                set line_ to (role of uiItem) as text
            end try
            try
                repeat with anAttribute in (attributes of uiItem)
                    try
                        set value_ to value of anAttribute
                        if class of value_ is text then
                            if value_ is not "" then set line_ to line_ & " " & (name of anAttribute) & "=" & value_
                        else if value_ is not missing value then
                            set line_ to line_ & " " & (name of anAttribute) & "(" & ((class of value_) as text) & ")"
                        end if
                    end try
                end repeat
            end try
            set end of found to line_
        end repeat
    end tell
end tell
set AppleScript's text item delimiters to linefeed
return found as text
APPLESCRIPT
}

_e2e_has_text() {
    e2e_screen_text | grep -qF -- "$1"
}

_e2e_lacks_text() {
    ! _e2e_has_text "$1"
}

_e2e_has_label() {
    e2e_screen_text AXTitle AXValue AXDescription | grep -qxF -- "$1"
}
