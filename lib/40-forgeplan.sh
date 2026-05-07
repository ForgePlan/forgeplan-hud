#!/usr/bin/env bash
# forgeplan-hud :: ForgePlan-zone reader
# Strategy:
#   - Hot path reads ONLY .forgeplan/session.yaml (free) + cache/forgeplan.json (jq).
#   - When cache is stale, fork the daemon in background and use last-known data.
#   - All heavy work (`forgeplan get/health --json`) lives in daemon/refresh.sh.

# Walk up from $1 up to 10 levels, return path that contains .forgeplan/ or empty.
fp_find_root() {
    local dir="$1"
    [[ -z "$dir" ]] && return
    local i=0
    while [[ -n "$dir" && "$dir" != "/" && $i -lt 10 ]]; do
        if [[ -d "$dir/.forgeplan" ]]; then
            printf '%s' "$dir"
            return
        fi
        dir=$(dirname "$dir")
        i=$((i + 1))
    done
}

# Parse one top-level key from a YAML file with grep+awk. No yq needed.
# Strips surrounding quotes and "null" sentinel.
fp_yaml_key() {
    local file=$1 key=$2
    local raw
    raw=$(grep -m1 "^${key}:" "$file" 2>/dev/null | cut -d: -f2- | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/^"(.*)"$/\1/')
    [[ "$raw" == "null" || -z "$raw" ]] && return
    printf '%s' "$raw"
}

# Read session state into env vars: FP_PHASE, FP_ACTIVE, FP_DEPTH
fp_session_read() {
    local root=$1
    local f="$root/.forgeplan/session.yaml"
    [[ ! -f "$f" ]] && return
    FP_PHASE=$(fp_yaml_key   "$f" "phase")
    FP_ACTIVE=$(fp_yaml_key  "$f" "active_artifact")
    FP_DEPTH=$(fp_yaml_key   "$f" "route_depth")
}

# Read enriched cache (artifact + project-wide health snapshot).
# Sets FP_REFF, FP_TITLE, FP_KIND, FP_STATUS, FP_EVID_COUNT, FP_NEXT_ACTION
# and full health bag: FP_VERDICT, FP_ORPHANS, FP_STALE, FP_MISMATCHES,
# FP_AT_RISK, FP_ACTIVE_STUBS, FP_BLIND_SPOTS, FP_DRAFTS, FP_ACTIVES,
# FP_HEALTH_NEXT_ACTION.
fp_cache_read() {
    local cache="$HUD_DIR/cache/forgeplan.json"
    [[ ! -f "$cache" ]] && return

    # Use ASCII Unit Separator to preserve empty fields (titles can have spaces).
    local data
    data=$(jq -r --arg id "$FP_ACTIVE" '
        . as $root |
        ($root.artifacts[$id] // {}) as $a |
        ($root.health             // {}) as $h |
        [
          ($a.r_eff           // ""),
          ($a.title           // ""),
          ($a.kind            // ""),
          ($a.status          // ""),
          ($a.evidence_count  // 0  | tostring),
          ($a.next_action     // ""),
          ($h.verdict         // ""),
          ($h.orphans         // 0  | tostring),
          ($h.stale           // 0  | tostring),
          ($h.phase_mismatches // 0 | tostring),
          ($h.at_risk         // 0  | tostring),
          ($h.active_stubs    // 0  | tostring),
          ($h.blind_spots     // 0  | tostring),
          ($h.drafts          // 0  | tostring),
          ($h.actives         // 0  | tostring),
          ($h.next_action     // "")
        ] | join("")
    ' "$cache" 2>/dev/null) || return

    IFS=$'\x1f' read -r \
        FP_REFF FP_TITLE FP_KIND FP_STATUS FP_EVID_COUNT FP_NEXT_ACTION \
        FP_VERDICT FP_ORPHANS FP_STALE FP_MISMATCHES \
        FP_AT_RISK FP_ACTIVE_STUBS FP_BLIND_SPOTS \
        FP_DRAFTS FP_ACTIVES FP_HEALTH_NEXT_ACTION \
        <<< "$data"
}

# Cache freshness: seconds since last refresh (mtime of stamp).
# Returns 99999 (forever stale) if stamp missing.
fp_cache_age() {
    local stamp="$HUD_DIR/cache/stamp"
    if [[ ! -f "$stamp" ]]; then
        echo 99999
        return
    fi
    local now mtime
    now=$(date +%s)
    mtime=$(stat -f %m "$stamp" 2>/dev/null || stat -c %Y "$stamp" 2>/dev/null || echo 0)
    echo $((now - mtime))
}

# If cache is older than HUD_CACHE_TTL, fork daemon in background and
# return immediately. Daemon writes new cache; next statusline tick reads it.
fp_maybe_refresh() {
    local root=$1
    local age
    age=$(fp_cache_age)
    [[ $age -lt $HUD_CACHE_TTL ]] && return

    # Avoid stampede: touch stamp first so concurrent statusline ticks don't
    # all spawn the daemon. Daemon will overwrite stamp at completion.
    mkdir -p "$HUD_DIR/cache"
    touch "$HUD_DIR/cache/stamp"

    # Detached fork — never blocks hot path.
    ( "$HUD_DIR/daemon/refresh.sh" "$root" "$FP_ACTIVE" >/dev/null 2>&1 & ) &
    disown 2>/dev/null || true
}

# R_eff bar: 10 cells, color by ForgePlanWeb thresholds (≥0.6 good, ≥0.3 brand, else bad).
fp_reff_render() {
    local reff=$1
    [[ -z "$reff" ]] && return

    local color
    if   awk "BEGIN { exit !($reff >= 0.6) }"; then color=$HUD_GOOD
    elif awk "BEGIN { exit !($reff >= 0.3) }"; then color=$HUD_BRAND
    else                                            color=$HUD_BAD
    fi

    # Visual dots — ●●●●●○○○○○ pattern, 10 cells.
    local filled
    filled=$(awk -v r="$reff" 'BEGIN { printf "%d", (r * 10) + 0.5 }')
    [[ $filled -gt 10 ]] && filled=10
    [[ $filled -lt 0  ]] && filled=0
    local empty=$((10 - filled))

    local dots=""
    [[ $filled -gt 0 ]] && dots+=$(fg256 "$color" "$(printf '●%.0s' $(seq 1 $filled))")
    [[ $empty  -gt 0 ]] && dots+=$(color_inact "$(printf '○%.0s' $(seq 1 $empty))")

    printf '%s %s %s' "$(dim 'R')" "$(fg256 "$color" "$(printf '%.2f' "$reff")")" "$dots"
}

# Idle render: hybrid layout.
# - healthy             → "🔨 idle  ▸ <next_action or default>"
# - needs_attention/    → "🔨 idle ⚠ <counts>  ▸ <next_action>"
# - critical            → "🔨 critical ✕ <counts>  ▸ <next_action>"
fp_render_idle() {
    local marker
    marker=$(color_brand '🔨')

    local verdict_seg="" counts="" sep
    sep=$(dim ' · ')

    # Verdict marker → glyph + label color.
    # forgeplan returns: healthy | needs_attention | unhealthy | critical | "".
    case "$FP_VERDICT" in
        critical)
            verdict_seg=" $(color_bad "critical ✕")"
            ;;
        unhealthy)
            verdict_seg=" $(color_bad "⚠")"
            ;;
        needs_attention)
            verdict_seg=" $(color_warn "⚠")"
            ;;
        *)
            # healthy or empty — no marker, will keep CTA short
            ;;
    esac

    # Counts only when there is something to fix. Order = priority of attention.
    local parts=()
    [[ "${FP_STALE:-0}"        -gt 0 ]]  && parts+=("$(color_bad   "${FP_STALE} stale")")
    [[ "${FP_MISMATCHES:-0}"   -gt 0 ]]  && parts+=("$(color_warn  "${FP_MISMATCHES} mismatch")")
    [[ "${FP_ORPHANS:-0}"      -gt 0 ]]  && parts+=("$(color_warn  "${FP_ORPHANS} orphans")")
    [[ "${FP_ACTIVE_STUBS:-0}" -gt 0 ]]  && parts+=("$(color_warn  "${FP_ACTIVE_STUBS} stubs")")
    [[ "${FP_AT_RISK:-0}"      -gt 0 ]]  && parts+=("$(color_warn  "${FP_AT_RISK} at-risk")")
    # Drafts only when accumulation is worth flagging (≥10) — small drafts are normal flow.
    [[ "${FP_DRAFTS:-0}"       -ge 10 ]] && parts+=("$(dim         "${FP_DRAFTS} drafts")")

    if [[ ${#parts[@]} -gt 0 ]]; then
        counts=" ${parts[0]}"
        local i
        for ((i = 1; i < ${#parts[@]}; i++)); do
            counts+="$sep${parts[$i]}"
        done
    fi

    # Hint: prefer cached health.next_action[0]; fallback to static route CTA.
    local hint_text='forgeplan route "<task>"'
    if [[ -n "$FP_HEALTH_NEXT_ACTION" ]]; then
        hint_text=$(fp_truncate "$FP_HEALTH_NEXT_ACTION" 60)
    fi
    local hint
    hint=$(dim "▸ $hint_text")

    # Compose:  🔨 idle[ <verdict>][ <counts>]  ▸ <hint>
    local idle_label
    idle_label=$(dim 'idle')
    if [[ -n "$verdict_seg" || -n "$counts" ]]; then
        printf '%s %s%s%s  %s\n' "$marker" "$idle_label" "$verdict_seg" "$counts" "$hint"
    else
        printf '%s %s  %s\n' "$marker" "$idle_label" "$hint"
    fi
}

# Truncate string to N chars with ellipsis. Pure bash, no awk.
fp_truncate() {
    local s=$1 n=$2
    if [[ ${#s} -gt $n ]]; then
        printf '%s…' "${s:0:$((n - 1))}"
    else
        printf '%s' "$s"
    fi
}

# Compose line 1. Returns nothing if no .forgeplan/ root.
fp_render_line() {
    local root=$1
    [[ -z "$root" ]] && return

    fp_session_read "$root"
    fp_cache_read
    fp_maybe_refresh "$root"

    local sep
    sep=$(dim '  ')
    local marker
    marker=$(color_brand '🔨')

    # Idle case — no active artifact or phase says idle.
    # Layout: hybrid. Healthy → short CTA. needs_attention/critical → expand
    # with counts of what is rotting in the project (stale/mismatch/orphans/drafts).
    if [[ -z "$FP_ACTIVE" || "$FP_PHASE" == "idle" ]]; then
        fp_render_idle
        return
    fi

    # Active artifact branch
    local id_seg phase_seg
    id_seg=$(bold "$FP_ACTIVE")
    phase_seg=$(dim "${FP_PHASE:-?}/${FP_DEPTH:-?}")

    local out="$marker $id_seg"

    # Title from cache (may be empty if cache cold)
    if [[ -n "$FP_TITLE" ]]; then
        local trunc
        trunc=$(fp_truncate "$FP_TITLE" 32)
        out+=" $(dim "▸ \"$trunc\"")"
    fi

    out+="$sep$phase_seg"

    # R_eff (only if PRD/RFC/ADR/EVID — cache writes empty for kinds without scoring)
    if [[ -n "$FP_REFF" ]]; then
        out+="$sep$(fp_reff_render "$FP_REFF")"
    fi

    # Evidence count (only if >0)
    if [[ -n "$FP_EVID_COUNT" && "$FP_EVID_COUNT" != "0" ]]; then
        out+="$sep$(dim "EVID×$FP_EVID_COUNT")"
    fi

    # Orphans alert (project-wide health signal)
    if [[ -n "$FP_ORPHANS" && "$FP_ORPHANS" != "0" ]]; then
        out+="$sep$(color_bad "⚠ $FP_ORPHANS orphans")"
    fi

    # Stale-cache marker
    local age
    age=$(fp_cache_age)
    if [[ $age -gt $((HUD_CACHE_TTL * 3)) ]]; then
        out+=" $(dim '⌛')"
    fi

    printf '%s\n' "$out"
}
