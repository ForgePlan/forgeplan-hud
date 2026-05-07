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

# Map context percentage to (color, hint) pair.
# Owner decision: WARN already nudges the user to start drafting a handoff
# prompt for the next session — no "silent yellow" zone. Rationale: by the
# time CRIT lands, drafting handoff under pressure produces a worse summary
# than drafting it calmly at 50-60%.
#
# Output: "<color_code> <hint_string>" (hint may be empty).
ctx_zone() {
    local pct=$1
    local window_size=$2
    read -r warn alert crit hard <<< "$(ctx_profile "$window_size")"

    if   [[ $pct -ge $hard  ]]; then echo "$HUD_BAD ctx_hard"
    elif [[ $pct -ge $crit  ]]; then echo "$HUD_BAD ctx_crit"
    elif [[ $pct -ge $alert ]]; then echo "$HUD_BRAND ctx_alert"
    elif [[ $pct -ge $warn  ]]; then echo "$HUD_WARN ctx_warn"
    else                             echo "$HUD_GOOD "
    fi
}

# Compose the full context segment: bar + percent + optional hint.
ctx_render() {
    local pct=$1
    local window_size=$2

    read -r color hint_key <<< "$(ctx_zone "$pct" "$window_size")"

    local bar
    bar=$(ctx_bar "$pct" "$color")

    local pct_str
    pct_str=$(fg256 "$color" "${pct}%")

    if [[ -n "$hint_key" ]]; then
        local hint_text
        hint_text=$(i18n_pair "$hint_key")
        printf '%s %s %s' "$bar" "$pct_str" "$(fg256 "$color" "$hint_text")"
    else
        printf '%s %s' "$bar" "$pct_str"
    fi
}
