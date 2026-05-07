#!/usr/bin/env bash
# forgeplan-hud :: cost, rate_limits, session duration

# Format USD cost — dim under HUD_COST_NOTICE, brand at notice, bad above heavy.
cost_render() {
    local usd=$1
    if [[ -z "$usd" || "$usd" == "null" ]]; then
        return
    fi
    local color
    if awk "BEGIN { exit !($usd >= $HUD_COST_HEAVY) }"; then
        color=$HUD_BAD
    elif awk "BEGIN { exit !($usd >= $HUD_COST_NOTICE) }"; then
        color=$HUD_BRAND
    else
        color=$HUD_DIM
    fi
    fg256 "$color" "$(printf '$%.2f' "$usd")"
}

# Format rate limits: "5h 23%·7d 41%". Adds ⚠ marker if any window ≥ HUD_RATE_WARN.
rate_render() {
    local h5=$1
    local d7=$2
    [[ -z "$h5" || "$h5" == "null" ]] && h5=0
    [[ -z "$d7" || "$d7" == "null" ]] && d7=0

    h5=$(printf '%.0f' "$h5")
    d7=$(printf '%.0f' "$d7")

    local h5_seg d7_seg
    if [[ $h5 -ge $HUD_RATE_WARN ]]; then
        h5_seg=$(color_bad "5h ${h5}%⚠")
    else
        h5_seg=$(dim "5h ${h5}%")
    fi
    if [[ $d7 -ge $HUD_RATE_WARN ]]; then
        d7_seg=$(color_bad "7d ${d7}%⚠")
    else
        d7_seg=$(dim "7d ${d7}%")
    fi
    printf '%s%s%s' "$h5_seg" "$(dim '·')" "$d7_seg"
}

# Format duration: 12m, 1h 03m, 2h 17m
duration_render() {
    local ms=$1
    [[ -z "$ms" || "$ms" == "null" ]] && return
    local total_sec=$(( ms / 1000 ))
    local h=$(( total_sec / 3600 ))
    local m=$(( (total_sec % 3600) / 60 ))
    local out
    if [[ $h -gt 0 ]]; then
        out=$(printf '%dh %02dm' "$h" "$m")
    else
        out=$(printf '%dm' "$m")
    fi
    dim "⏱ $out"
}

# Format model + window-size badge: "⬢ Opus 1M" or "⬢ Sonnet 200k".
# Optional ⌥ prefix when running inside a git worktree.
# Optional [agent: name] suffix when CC was launched with --agent.
model_render() {
    local name=$1
    local window_size=$2
    local worktree=${3:-}
    local agent=${4:-}

    local size_label
    if [[ $window_size -ge 500000 ]]; then
        size_label="1M"
    else
        size_label="200k"
    fi

    local prefix=""
    [[ -n "$worktree" ]] && prefix="$(color_brand '⌥') "

    local suffix=""
    [[ -n "$agent" ]] && suffix=" $(dim "[agent: $agent]")"

    printf '%s%s %s%s' "$prefix" "$(color_brand '⬢')" "$(bold "$name $size_label")" "$suffix"
}
