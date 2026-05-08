#!/usr/bin/env bash
# forgeplan-hud :: installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ForgePlan/forgeplan-hud/main/install.sh | bash
#
# Or after `git clone`:
#   ./install.sh
#
# Effects:
#   - Copies the project to ~/.claude/forgeplan-hud/
#   - Patches ~/.claude/settings.json to register the statusLine command
#   - chmod +x the shell entry points
#   - Bails if jq is missing (the HUD requires it)

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/ForgePlan/forgeplan-hud/main"
TARGET="$HOME/.claude/forgeplan-hud"
SETTINGS="$HOME/.claude/settings.json"

say()  { printf '\033[38;5;208m▸\033[0m %s\n' "$1"; }
die()  { printf '\033[38;5;196m✕ %s\033[0m\n' "$1" >&2; exit 1; }
warn() { printf '\033[38;5;214m⚠ %s\033[0m\n' "$1" >&2; }

# ─── prereqs ─────────────────────────────────────────────────────────
command -v jq   >/dev/null 2>&1 || die "jq is required. Install with: brew install jq  (or apt install jq)"
command -v bash >/dev/null 2>&1 || die "bash is required."

# ─── source files (local clone OR download from GitHub) ──────────────
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [[ -f "$SRC_DIR/statusline.sh" && -d "$SRC_DIR/lib" ]]; then
    say "Installing from local checkout: $SRC_DIR"
    mkdir -p "$TARGET/lib" "$TARGET/daemon" "$TARGET/cache"
    cp "$SRC_DIR/statusline.sh"     "$TARGET/"
    cp "$SRC_DIR/lib/"*.sh          "$TARGET/lib/"
    cp "$SRC_DIR/daemon/refresh.sh" "$TARGET/daemon/"
else
    say "Downloading from GitHub..."
    mkdir -p "$TARGET/lib" "$TARGET/daemon" "$TARGET/cache"
    curl -fsSL "$REPO_RAW/statusline.sh"     -o "$TARGET/statusline.sh"
    for f in 00-config 10-colors 20-context 30-cost 40-forgeplan 99-render; do
        curl -fsSL "$REPO_RAW/lib/${f}.sh"   -o "$TARGET/lib/${f}.sh"
    done
    curl -fsSL "$REPO_RAW/daemon/refresh.sh" -o "$TARGET/daemon/refresh.sh"
fi

chmod +x "$TARGET/statusline.sh" "$TARGET/daemon/refresh.sh"
say "Files installed at $TARGET"

# ─── patch settings.json ─────────────────────────────────────────────
mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

# Detect existing statusLine and preserve it as backup if it differs.
existing=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null || echo "")
if [[ -n "$existing" && "$existing" != *"forgeplan-hud"* ]]; then
    warn "settings.json already has statusLine: $existing"
    warn "Backing up to ~/.claude/settings.json.bak — restore manually if you change your mind."
    cp "$SETTINGS" "${SETTINGS}.bak"
fi

tmp=$(mktemp)
jq --arg cmd "$TARGET/statusline.sh" --arg invalidate "$TARGET/daemon/invalidate.sh" --arg pat "forgeplan-hud" '
    .statusLine = {
        type: "command",
        command: $cmd,
        padding: 0,
        refreshInterval: 10
    } |
    # Live refresh: invalidate cache after any forgeplan/fpl Bash call.
    # Idempotent — strip any prior forgeplan-hud invalidate hooks first, then add fresh.
    .hooks //= {} |
    .hooks.PostToolUse = (
        ((.hooks.PostToolUse // []) | map(
            .hooks |= ((. // []) | map(select((.command // "") | contains($pat) | not)))
        ) | map(select((.hooks // []) | length > 0)))
        + [{matcher: "Bash", hooks: [{type: "command", command: $invalidate}]}]
    )
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
say "settings.json patched (statusLine + PostToolUse:forgeplan invalidate hook)"

# ─── verify ──────────────────────────────────────────────────────────
if [[ -x "$TARGET/statusline.sh" ]]; then
    say "Smoke test..."
    smoke=$(printf '{"model":{"display_name":"Opus"},"context_window":{"context_window_size":1000000,"used_percentage":12}}' \
        | "$TARGET/statusline.sh" 2>&1) || die "smoke test failed: $smoke"
    printf '  → %s\n' "$(printf '%s' "$smoke" | sed 's/\x1b\[[0-9;]*m//g' | tail -1)"
fi

cat <<EOF

\033[38;5;208m✓\033[0m forgeplan-hud installed.

Restart any Claude Code sessions to pick up the new statusline.
The bar shows up at the bottom and refreshes every 10s plus on every assistant message.

To uninstall, remove $TARGET and clear .statusLine from $SETTINGS.

EOF
