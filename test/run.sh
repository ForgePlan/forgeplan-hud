#!/usr/bin/env bash
# forgeplan-hud :: test runner — runs every fixture and prints rendered output
# without ANSI codes, so you can eyeball-diff against expected.

set -e

HUD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES_DIR="$HUD_DIR/test"

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

print_section() { printf '\n\033[38;5;208m=== %s ===\033[0m\n' "$1"; }

# 1) Various context bar zones (1M model, no .forgeplan/)
print_section "Context bar zones (1M Opus, /tmp cwd)"
for pct in 12 35 55 75 90 97; do
    out=$(jq --argjson p "$pct" '.context_window.used_percentage = $p' \
        "$FIXTURES_DIR/fixture-no-fp.json" \
        | jq '.model.display_name = "Opus" | .context_window.context_window_size = 1000000' \
        | "$HUD_DIR/statusline.sh" | strip_ansi)
    printf '  %3d%% → %s\n' "$pct" "$out"
done

# 2) 200k profile
print_section "Context bar zones (200k Sonnet, /tmp cwd)"
for pct in 30 55 75 88 96; do
    out=$(jq --argjson p "$pct" '.context_window.used_percentage = $p' \
        "$FIXTURES_DIR/fixture-no-fp.json" \
        | "$HUD_DIR/statusline.sh" | strip_ansi)
    printf '  %3d%% → %s\n' "$pct" "$out"
done

# 3) Idle case
print_section "Idle (no active artifact)"
"$HUD_DIR/statusline.sh" < "$FIXTURES_DIR/fixture-idle.json" | strip_ansi

# 4) No .forgeplan
print_section "No .forgeplan/ root"
"$HUD_DIR/statusline.sh" < "$FIXTURES_DIR/fixture-no-fp.json" | strip_ansi

# 5) Rate alert + heavy cost
print_section 'Rate alert + heavy cost ($6.40, 5h 84%)'
"$HUD_DIR/statusline.sh" < "$FIXTURES_DIR/fixture-rate-alert.json" | strip_ansi

# 6) Full ForgePlan + worktree + agent (live-ish: needs real ForgePlan path)
if [[ -d "/Users/explosovebit/Work/ForgePlan/.forgeplan" ]]; then
    print_section "Full ForgePlan + worktree + agent (live data)"
    jq '.cwd = "/Users/explosovebit/Work/ForgePlan" |
        .workspace.current_dir = "/Users/explosovebit/Work/ForgePlan" |
        .workspace.project_dir = "/Users/explosovebit/Work/ForgePlan" |
        .workspace.git_worktree = "feat-payments" |
        .agent.name = "security-reviewer"' \
        "$FIXTURES_DIR/fixture-no-fp.json" \
        | "$HUD_DIR/statusline.sh" | strip_ansi
fi

# 7) Speed
print_section "Speed (10 runs, warm cache)"
/usr/bin/time -p bash -c "
for i in {1..10}; do
    cat '$FIXTURES_DIR/fixture-no-fp.json' | '$HUD_DIR/statusline.sh' > /dev/null
done
" 2>&1 | tail -3

printf '\n\033[38;5;46m✓ done\033[0m\n'
