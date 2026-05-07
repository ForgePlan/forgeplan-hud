#!/usr/bin/env bash
# forgeplan-hud :: Claude Code statusline with Forgeplan integration
#
# Wired into ~/.claude/settings.json as:
#   { "statusLine": { "type": "command",
#                     "command": "~/.claude/forgeplan-hud/statusline.sh",
#                     "refreshInterval": 10 } }
#
# Hot path: read stdin → parse with jq → render two lines. Target <30ms.

set -o pipefail   # don't -e: many optional fields may fail to parse
                  # don't -u: empty vars are intentional fall-through

HUD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load lib/ in lexical order: 00-config → 10-colors → 20-context → 30-cost → 99-render
for f in "$HUD_DIR"/lib/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
done

# Read full stdin from Claude Code
input=$(cat)

# Graceful fallback: without jq we can still render a minimal one-liner.
if ! command -v jq >/dev/null 2>&1; then
    # Strip likely model name with grep — works without jq.
    model=$(printf '%s' "$input" | grep -o '"display_name":[^,}]*' | head -1 | sed 's/.*"display_name":[[:space:]]*"\([^"]*\)".*/\1/')
    printf '⬢ %s  (install jq for full HUD)\n' "${model:-Claude}"
    exit 0
fi

# Parse all needed fields in a single jq invocation (one fork instead of many).
# Use ASCII Unit Separator (\x1f) — tab is whitespace IFS in bash, so consecutive
# tabs collapse to one delimiter and empty fields would silently disappear
# (e.g. an empty agent.name would shift exceeds_200k_tokens into HUD_AGENT).
IFS=$'\x1f' read -r HUD_MODEL_NAME HUD_WINDOW_SIZE HUD_CTX_PCT \
        HUD_COST_USD HUD_RATE_5H HUD_RATE_7D HUD_DURATION_MS \
        HUD_CWD HUD_PROJECT_DIR HUD_WORKTREE HUD_AGENT \
        HUD_EXCEEDS_200K HUD_SESSION_NAME < <(
    printf '%s' "$input" | jq -r '
        [
          .model.display_name // "Claude",
          .context_window.context_window_size // 200000,
          (.context_window.used_percentage // 0 | floor),
          .cost.total_cost_usd // 0,
          .rate_limits.five_hour.used_percentage // 0,
          .rate_limits.seven_day.used_percentage // 0,
          .cost.total_duration_ms // 0,
          .cwd // "",
          .workspace.project_dir // "",
          .workspace.git_worktree // .worktree.name // "",
          .agent.name // "",
          (.exceeds_200k_tokens // false | tostring),
          .session_name // ""
        ] | map(tostring) | join("")
    '
)

export HUD_MODEL_NAME HUD_WINDOW_SIZE HUD_CTX_PCT
export HUD_COST_USD HUD_RATE_5H HUD_RATE_7D HUD_DURATION_MS
export HUD_CWD HUD_PROJECT_DIR HUD_WORKTREE HUD_AGENT
export HUD_EXCEEDS_200K HUD_SESSION_NAME

render_all
