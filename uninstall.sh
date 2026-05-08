#!/usr/bin/env bash
# forgeplan-hud :: uninstaller — removes installation and clears statusLine config.

set -euo pipefail

TARGET="$HOME/.claude/forgeplan-hud"
SETTINGS="$HOME/.claude/settings.json"

say()  { printf '\033[38;5;208m▸\033[0m %s\n' "$1"; }
warn() { printf '\033[38;5;214m⚠ %s\033[0m\n' "$1" >&2; }

if [[ -d "$TARGET" ]]; then
    rm -rf "$TARGET"
    say "Removed $TARGET"
else
    warn "Nothing at $TARGET"
fi

if [[ -f "$SETTINGS" ]]; then
    cmd=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null || echo "")
    if [[ "$cmd" == *"forgeplan-hud"* ]]; then
        tmp=$(mktemp)
        jq --arg pat "forgeplan-hud" '
            del(.statusLine) |
            # Strip our PostToolUse invalidate hook + collapse empty matchers
            .hooks.PostToolUse = ((.hooks.PostToolUse // []) | map(
                .hooks |= ((. // []) | map(select((.command // "") | contains($pat) | not)))
            ) | map(select((.hooks // []) | length > 0))) |
            # If PostToolUse list is now empty, remove the key entirely
            if (.hooks.PostToolUse // [] | length) == 0 then del(.hooks.PostToolUse) else . end |
            # If hooks object is now empty, remove it too
            if (.hooks // {} | length) == 0 then del(.hooks) else . end
        ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
        say "Cleared .statusLine and PostToolUse:forgeplan invalidate hook from settings.json"

        if [[ -f "${SETTINGS}.bak" ]]; then
            warn "Backup found at ${SETTINGS}.bak — review and restore manually if needed."
        fi
    else
        warn "statusLine in settings.json is not forgeplan-hud — leaving as-is."
    fi
fi

say "Done."
