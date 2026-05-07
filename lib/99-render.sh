#!/usr/bin/env bash
# forgeplan-hud :: final two-line composition

# Two-line render entry. Top line is ForgePlan (skipped when no project),
# bottom line is always the Claude session metrics.
render_all() {
    local fp_root
    fp_root=$(fp_find_root "$HUD_CWD")
    if [[ -n "$fp_root" ]]; then
        fp_render_line "$fp_root"
    fi
    render_claude_line
}

# Build line 2 (Claude session metrics).
# Args via env vars set by statusline.sh after jq parse:
#   HUD_MODEL_NAME, HUD_WINDOW_SIZE, HUD_CTX_PCT,
#   HUD_COST_USD, HUD_RATE_5H, HUD_RATE_7D, HUD_DURATION_MS
render_claude_line() {
    local model_seg ctx_seg cost_seg rate_seg dur_seg
    model_seg=$(model_render "$HUD_MODEL_NAME" "$HUD_WINDOW_SIZE" "$HUD_WORKTREE" "$HUD_AGENT")
    ctx_seg=$(ctx_render "$HUD_CTX_PCT" "$HUD_WINDOW_SIZE")
    cost_seg=$(cost_render "$HUD_COST_USD")
    rate_seg=$(rate_render "$HUD_RATE_5H" "$HUD_RATE_7D")
    dur_seg=$(duration_render "$HUD_DURATION_MS")

    local sep
    sep=$(dim '  ')

    local out="$model_seg$sep$ctx_seg"
    [[ -n "$cost_seg" ]] && out+="$sep$cost_seg"
    [[ -n "$rate_seg" ]] && out+="$sep$rate_seg"
    [[ -n "$dur_seg"  ]] && out+="$sep$dur_seg"
    printf '%s\n' "$out"
}
