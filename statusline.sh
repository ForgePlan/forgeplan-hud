#!/usr/bin/env bash
# forgeplan-hud :: Claude Code statusline with Forgeplan integration
#
# Wired into ~/.claude/settings.json as:
#   { "statusLine": { "type": "command",
#                     "command": "~/.claude/forgeplan-hud/statusline.sh",
#                     "refreshInterval": 10 } }
#
# Hot path: read stdin → parse with jq → render two lines. Target <30ms.

set -euo pipefail

HUD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load lib/ in lexical order: 00-config → 10-colors → 20-context → 30-cost → 99-render
for f in "$HUD_DIR"/lib/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
done

# Read full stdin from Claude Code
input=$(cat)

# Parse all needed fields in a single jq invocation (one fork instead of seven)
read -r HUD_MODEL_NAME HUD_WINDOW_SIZE HUD_CTX_PCT \
        HUD_COST_USD HUD_RATE_5H HUD_RATE_7D HUD_DURATION_MS \
        HUD_CWD HUD_PROJECT_DIR < <(
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
          .workspace.project_dir // ""
        ] | @tsv
    ' | tr '\t' ' '
)

export HUD_MODEL_NAME HUD_WINDOW_SIZE HUD_CTX_PCT
export HUD_COST_USD HUD_RATE_5H HUD_RATE_7D HUD_DURATION_MS
export HUD_CWD HUD_PROJECT_DIR

# Phase 1: render only the Claude line.
# Phase 2 will add render_forgeplan_line above it when .forgeplan/ is detected.
render_claude_line
