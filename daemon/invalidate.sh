#!/usr/bin/env bash
# forgeplan-hud :: PostToolUse cache invalidator
#
# Wired in ~/.claude/settings.json as a PostToolUse:Bash hook. Claude Code pipes
# the tool invocation as JSON on stdin. If the user (or the assistant) just ran
# a `forgeplan` (or `fpl`) command, we invalidate the HUD cache stamp — the next
# statusline tick will fork the daemon and refresh within ~200-500 ms instead
# of waiting for the 30 s timer.
#
# Cheap path:
#   - never blocks (no fork unless we match)
#   - exits 0 on any error so a malformed payload never breaks CC
#
# Hook output protocol:
#   - exit 0, no stdout → silently approve the tool's outcome
#   - we do NOT write to stdout; that would inject text into CC

HUD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Read the JSON payload. Limit to first 64 KB so a runaway tool_output doesn't
# OOM us via head -c.
input=$(head -c 65536)

# Extract the bash command that just ran. jq is required by the HUD overall;
# if missing, exit silently — we don't want hook errors to block tools.
command -v jq >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
[[ -z "$cmd" ]] && exit 0

# Match `forgeplan` or `fpl` as standalone words. We deliberately do NOT match
# substrings like "forgeplan-hud" or "myfpl" — only the actual CLI invocation.
case "$cmd" in
    "forgeplan"|*" forgeplan"|*" forgeplan "*|"forgeplan "*)
        rm -f "$HUD_DIR/cache/stamp"
        ;;
    "fpl"|*" fpl"|*" fpl "*|"fpl "*)
        rm -f "$HUD_DIR/cache/stamp"
        ;;
esac

exit 0
