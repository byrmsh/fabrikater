# Steps for scripts/e2e/flows/*.sh, sourced by scripts/e2e.sh. Each step fails the flow when it does not hold.
# Keys, menus and windows go through System Events; reading and pressing elements goes through build/e2e-ax
# (scripts/e2e/ax.swift), which walks the window in one process. The shell running this needs Accessibility and Screen
# Recording access; GitHub's macOS runners grant both.

E2E_APP="${E2E_APP:-build/fabrikater.app}"
E2E_BINARY="${E2E_APP}/Contents/MacOS/fabrikater"
E2E_OUT="${E2E_OUT:-build/e2e}"
E2E_TIMEOUT="${E2E_TIMEOUT:-20}"
E2E_PROCESS="fabrikater"
E2E_FIXTURES="Tests/Fixtures"
E2E_AX="${E2E_AX:-build/e2e-ax}"

e2e_pid=""
e2e_fixture_dir=""
e2e_restore_light=""

# e2e_launch [fixture...]: starts the app replaying only the named files from Tests/Fixtures, and waits for its window.
# The default is the synthetic herd and conversation. With no files at all (`e2e_launch --none`) every read fails.
# SOURCE=NAME replays a fixture under another name, such as claude-long.synthetic.jsonl=claude.synthetic.jsonl.
# Pane notes (names, pins) start empty unless E2E_KEEP_NOTES=1, which relaunches with the last run's notes.
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
        cp "${E2E_FIXTURES}/${file%%=*}" "${e2e_fixture_dir}/${file#*=}"
    done
    # Fixture runs keep pane notes in their own defaults domain; clearing it keeps one flow's renames out of the next.
    if [ -z "${E2E_KEEP_NOTES:-}" ]; then
        defaults delete sh.bayram.fabrikater.fixtures >/dev/null 2>&1 || true
    fi
    # E2E_DARK=1 turns the system to dark mode for this launch; e2e_quit turns it back.
    if [ -n "${E2E_DARK:-}" ] && [ "$(_e2e_dark_mode)" = "false" ]; then
        _e2e_dark_mode true
        e2e_restore_light=1
    fi
    # `open` does not pass the environment on, so run the bundled binary directly. Ignoring saved window state keeps
    # one flow's hidden sidebar or text size out of the next.
    FABRIKATER_FIXTURES="${e2e_fixture_dir}" "${E2E_BINARY}" -ApplePersistenceIgnoreState YES >"${E2E_OUT}/${E2E_FLOW:-app}.log" 2>&1 &
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

# e2e_swap_fixture FROM TO: replaces the running app's fixture TO with Tests/Fixtures/FROM, as if the host changed. The
# app reads it at its next snapshot poll (every 20 s), so wait with a longer E2E_TIMEOUT.
e2e_swap_fixture() {
    cp "${E2E_FIXTURES}/$1" "${e2e_fixture_dir}/.swap"
    mv "${e2e_fixture_dir}/.swap" "${e2e_fixture_dir}/$2"
}

# e2e_append_fixture FROM TO: appends Tests/Fixtures/FROM to the running app's fixture TO, as an agent writing to its
# session log does. A followed log shows the new lines within a second.
e2e_append_fixture() {
    cat "${E2E_FIXTURES}/$1" >>"${e2e_fixture_dir}/$2"
}

# e2e_quit: stops the app and removes its fixture copy.
# _e2e_dark_mode [true|false]: prints whether the system is in dark mode, or sets it.
_e2e_dark_mode() {
    if [ "$#" -eq 0 ]; then
        osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode'
    else
        osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1" >/dev/null
    fi
}

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
    if [ -n "${e2e_restore_light}" ]; then
        _e2e_dark_mode false
        e2e_restore_light=""
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

# e2e_expect_order FIRST SECOND: waits until elements VoiceOver reads as exactly FIRST and SECOND are both in the
# window, FIRST earlier, as sidebar rows are top to bottom. Each label's last element counts, so a row's copy in
# Needs You or Pinned above the workspaces does not.
e2e_expect_order() {
    e2e_wait "\"$1\" above \"$2\"" _e2e_in_order "$1" "$2"
}

_e2e_in_order() {
    local labels first second
    labels="$(e2e_screen_text AXTitle AXValue AXDescription)"
    first="$(printf '%s\n' "${labels}" | grep -nxF -- "$1" | tail -n1 | cut -d: -f1)"
    second="$(printf '%s\n' "${labels}" | grep -nxF -- "$2" | tail -n1 | cut -d: -f1)"
    [ -n "${first}" ] && [ -n "${second}" ] && [ "${first}" -lt "${second}" ]
}

# e2e_expect_no_text TEXT: fails if TEXT is on screen now.
e2e_expect_no_text() {
    if _e2e_has_text "$1"; then
        echo "e2e: \"$1\" is on screen but should not be" >&2
        return 1
    fi
}

# e2e_expect_no_label TEXT: fails if some element reads as exactly TEXT now, for text that also appears inside longer text.
e2e_expect_no_label() {
    if _e2e_has_label "$1"; then
        echo "e2e: an element reads \"$1\" but should not" >&2
        return 1
    fi
}

# e2e_expect_gone TEXT: waits until no element in the main window shows TEXT, as after closing a sheet.
e2e_expect_gone() {
    e2e_wait "\"$1\" to leave the screen" _e2e_lacks_text "$1"
}

# e2e_expect_focus TEXT: waits until the focused element holds TEXT, as a text field does once it takes focus.
e2e_expect_focus() {
    e2e_wait "a focused field holding \"$1\"" _e2e_focus_is "$1"
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

# e2e_menu MENU ITEM: chooses ITEM from the menu bar's MENU, for commands without a shortcut. Example: e2e_menu Pane "Hide Pane"
e2e_menu() {
    osascript -e "tell application \"System Events\" to tell process \"${E2E_PROCESS}\"
        set frontmost to true
        click menu item \"$2\" of menu 1 of menu bar item \"$1\" of menu bar 1
    end tell" >/dev/null
    sleep 0.5
}

# e2e_submenu MENU SUBMENU ITEM: chooses ITEM from SUBMENU in the menu bar's MENU. Example: e2e_submenu View "Sort Panes By" "Recent Activity"
e2e_submenu() {
    osascript -e "tell application \"System Events\" to tell process \"${E2E_PROCESS}\"
        set frontmost to true
        click menu item \"$3\" of menu 1 of menu item \"$2\" of menu 1 of menu bar item \"$1\" of menu bar 1
    end tell" >/dev/null
    sleep 0.5
}

# e2e_expect_menu_item MENU ITEM enabled|disabled: waits until the menu bar's MENU holds ITEM in that state.
e2e_expect_menu_item() {
    e2e_wait "\"$2\" $3 in the $1 menu" _e2e_menu_item_is "$@"
}

_e2e_menu_item_is() {
    local want="true"
    [ "$3" = "enabled" ] || want="false"
    [ "$(osascript -e "tell application \"System Events\" to tell process \"${E2E_PROCESS}\"
        return enabled of menu item \"$2\" of menu 1 of menu bar item \"$1\" of menu bar 1
    end tell" 2>>"${E2E_OUT}/${E2E_FLOW:-app}.osascript.log")" = "${want}" ]
}

# e2e_focus_field PLACEHOLDER: clicks into the text field whose placeholder contains PLACEHOLDER.
e2e_focus_field() {
    e2e_wait "a field with placeholder \"$1\"" _e2e_focus_field "$1"
}

_e2e_focus_field() {
    _e2e_ax focus "$1"
}

# e2e_click TITLE: presses the first element whose title, description or help tag is TITLE (a link button has only
# its help tag).
e2e_click() {
    e2e_wait "a button titled \"$1\"" _e2e_click "$1"
    sleep 0.5
}

_e2e_click() {
    _e2e_ax press "$1"
}

# e2e_disclose TEXT: expands the first disclosure triangle whose label holds a text reading exactly TEXT, as clicking it
# does. A DisclosureGroup outside a List exposes its label's texts as the triangle's children.
e2e_disclose() {
    e2e_wait "a disclosure triangle labelled \"$1\"" _e2e_disclose "$1"
    sleep 0.5
}

_e2e_disclose() {
    _e2e_ax disclose "$1"
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

# e2e_wait WHAT COMMAND [ARG...]: retries COMMAND every quarter second until it succeeds or E2E_TIMEOUT runs out.
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
        sleep 0.25
    done
}

# e2e_expect_windows COUNT: waits until the app has COUNT windows open, as after opening a pane in a new window. The
# newest window is then the front one, which every other step reads.
e2e_expect_windows() {
    e2e_wait "$1 windows" _e2e_window_count_is "$1"
}

_e2e_window_count_is() {
    [ "$(osascript -e "tell application \"System Events\" to count windows of process \"${E2E_PROCESS}\"" 2>/dev/null)" \
        = "$1" ]
}

_e2e_has_window() {
    [ "$(osascript -e "tell application \"System Events\" to count windows of process \"${E2E_PROCESS}\"" 2>/dev/null)" \
        -gt 0 ] 2>/dev/null
}

# e2e_screen_text [ATTRIBUTE...]: prints every title, value, description and help tag in the main window's accessibility
# tree, one per line; or only the named attributes, such as AXTitle AXValue.
e2e_screen_text() {
    _e2e_ax text "$@"
}

# e2e_screen_dump: prints each element in the main window with its role and every text attribute it has, for
# working out what a check should look for.
e2e_screen_dump() {
    _e2e_ax dump
}

# The checks read the whole text before searching it: under pipefail, grep -q quitting early could fail the pipe.
_e2e_has_text() {
    local screen
    screen="$(e2e_screen_text)"
    grep -qF -- "$1" <<<"${screen}"
}

_e2e_focus_is() {
    [ "$(_e2e_ax focused-value)" = "$1" ]
}

_e2e_lacks_text() {
    ! _e2e_has_text "$1"
}

_e2e_has_label() {
    local screen
    screen="$(e2e_screen_text AXTitle AXValue AXDescription)"
    grep -qxF -- "$1" <<<"${screen}"
}

# _e2e_ax COMMAND [ARGUMENT...]: runs the accessibility helper against the app (commands in scripts/e2e/ax.swift).
_e2e_ax() {
    "${E2E_AX}" "${e2e_pid}" "$@" 2>>"${E2E_OUT}/${E2E_FLOW:-app}.ax.log"
}
