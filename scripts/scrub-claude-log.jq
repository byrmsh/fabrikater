# Replaces the free text of a Claude session log with placeholders, keeping its shape. Run with `jq -s -c` over the
# whole log (one JSON row per line) so the same id maps to the same placeholder in every row.
#
# Kept: row and content types, roles, tool names, statuses, timestamps, model, version, numbers and booleans, and
# which keys each object has. Ids become stable fakes of the same shape, paths `/home/user/project/file-N.ext`, and
# every other string "Text N" (see `placeholder`).

def pad12: ("000000000000" + tostring)[-12:];

def kept_keys: ["type", "role", "status", "stop_reason", "stop_sequence", "subtype", "level", "model", "version",
    "permissionMode", "userType", "timestamp", "media_type", "operation", "service_tier", "is_error"];
def id_keys: ["uuid", "parentUuid", "logicalParentUuid", "leafUuid", "id", "tool_use_id", "sessionId",
    "continuedInSessionId", "requestId", "promptId", "agentId", "messageId", "sourceToolAssistantUUID"];
def path_keys: ["cwd", "file_path", "filePath", "path", "notebook_path"];

def fake_id($value; $n):
    if $value | test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"; "i")
    then "00000000-0000-4000-8000-" + ($n | pad12)
    elif $value | test("^[a-z]+_") then ($value | capture("^(?<p>[a-z]+_)").p) + "\($n)"
    else "id-\($n)" end;

def extension: (capture("(?<e>\\.[A-Za-z0-9]{1,8})$").e) // "";

# The text with every run between tags replaced by "Text N", line for line. Tags such as `<command-name>` stay, and so
# does a line's leading `+`, `-` or space (diff lines), since parsers key on them.
def placeholder($n):
    split("\n")
    | map(
        [scan("</?[a-z][a-z-]*>|[^<]+|<")]
        | to_entries
        | map(
            if .value | test("^</?[a-z][a-z-]*>$") then .value
            elif .value | test("^\\s*$") then .value
            else (if .key == 0 and (.value | test("^[-+ ]")) then .value[0:1] else "" end) + "Text \($n)" end
        )
        | join("")
    )
    | join("\n");

. as $rows
| [$rows | .. | objects | to_entries[] | select(.key as $k | id_keys | index($k)) | .value | strings]
    as $ids
| (reduce ($ids | unique | to_entries[]) as $e ({}; .[$e.value] = fake_id($e.value; $e.key + 1))) as $id
| [$rows | .. | objects | to_entries[] | select(.key as $k | path_keys | index($k)) | .value | strings] as $paths
| (reduce ($paths | unique | to_entries[]) as $e ({};
    .[$e.value] = "/home/user/project/file-\($e.key + 1)\($e.value | extension)")) as $path
| [$rows | .. | strings] as $texts
| (reduce ($texts | unique | to_entries[]) as $e ({}; .[$e.value] = $e.key + 1)) as $text
| $rows[]
| walk(
    if type == "object" then
        . as $o
        | with_entries(
            if (.value | type) != "string" then .
            elif .key as $k | kept_keys | index($k) then .
            elif .key as $k | id_keys | index($k) then .value = $id[.value]
            elif .key as $k | path_keys | index($k) then .value = $path[.value]
            elif .key == "gitBranch" then .value = "branch"
            else .value as $v | .value = ($v | placeholder($text[$v])) end
        )
        # A tool's name is its type, not free text, except for MCP tools, whose names carry server names.
        | if $o.type == "tool_use" and ($o.name | type) == "string"
            then .name = (if $o.name | contains("__") then "mcp__server__tool" else $o.name end)
          else . end
    elif type == "array" then map(if type == "string" then placeholder($text[.]) else . end)
    else . end
)
