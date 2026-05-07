#!/usr/bin/env bash
# forgeplan-hud :: context window bar with U-curve attention thresholds
# Pure functions — operate on (pct, window_size) → ANSI string

# Render filled/empty bar of HUD_BAR_WIDTH cells.
# pct: integer 0-100. cells_filled = round(pct/100 * width).
ctx_bar() {
    local pct=$1
    local color_filled=$2
    local width=$HUD_BAR_WIDTH
    local filled=$(( (pct * width + 50) / 100 ))
    [[ $filled -gt $width ]] && filled=$width
    [[ $filled -lt 0 ]] && filled=0

    local empty=$((width - filled))
    local out=""
    [[ $filled -gt 0 ]] && out+=$(fg256 "$color_filled" "$(printf '▮%.0s' $(seq 1 $filled))")
    [[ $empty  -gt 0 ]] && out+=$(color_inact "$(printf '▯%.0s' $(seq 1 $empty))")
    printf '%s' "$out"
}

# Choose threshold profile based on context window size.
# 200_000 → conservative profile; 1_000_000 → aggressive (lost-in-middle hits earlier).
ctx_profile() {
    local window_size=$1
    if [[ $window_size -ge 500000 ]]; then
        echo "$HUD_CTX_1M_WARN $HUD_CTX_1M_ALERT $HUD_CTX_1M_CRIT $HUD_CTX_1M_HARD"
    else
        echo "$HUD_CTX_200K_WARN $HUD_CTX_200K_ALERT $HUD_CTX_200K_CRIT $HUD_CTX_200K_HARD"
    fi
}

# ─────────────────────────────────────────────────────────────────────
#  TODO(user): implement ctx_zone()
# ─────────────────────────────────────────────────────────────────────
# This is the heart of the U-curve logic and the most "authorial" decision
# in this whole project — please write it yourself (5-10 lines).
#
# Inputs:
#   $1 = pct (integer 0-100)
#   $2 = window_size (e.g. 200000 or 1000000)
#
# Output (single line, space-separated):
#   <color_code> <hint_string>
#
# where:
#   color_code  ∈ { $HUD_GOOD, $HUD_WARN, $HUD_BRAND, $HUD_BAD }
#   hint_string ∈ { "", $HUD_HINT_WARN, $HUD_HINT_ALERT, $HUD_HINT_CRIT }
#
# Use ctx_profile to get thresholds:
#   read -r warn alert crit hard <<< "$(ctx_profile "$window_size")"
#
# Recommended mapping:
#   pct < warn   → GOOD,  no hint
#   pct < alert  → WARN,  no hint        (early caution, not yet loud)
#   pct < crit   → BRAND, "$HUD_HINT_WARN"   (you said brand orange = "tense but ok")
#   pct < hard   → BAD,   "$HUD_HINT_ALERT"  (critical — must act)
#   pct ≥ hard   → BAD,   "$HUD_HINT_CRIT"   (must rotate session NOW)
#
# Open question only you can answer: do you want pct < alert to show ANY hint?
# Some folks want zero noise until things actually hurt; others like a soft heads-up.
#
ctx_zone() {
    local pct=$1
    local window_size=$2
    # YOUR CODE HERE
    # Default fallback to keep the script working — replace this:
    echo "$HUD_GOOD "
}

# Compose the full context segment: bar + percent + optional hint.
ctx_render() {
    local pct=$1
    local window_size=$2

    read -r color hint <<< "$(ctx_zone "$pct" "$window_size")"

    local bar
    bar=$(ctx_bar "$pct" "$color")

    local pct_str
    pct_str=$(fg256 "$color" "${pct}%")

    if [[ -n "$hint" ]]; then
        printf '%s %s %s' "$bar" "$pct_str" "$(fg256 "$color" "$hint")"
    else
        printf '%s %s' "$bar" "$pct_str"
    fi
}
