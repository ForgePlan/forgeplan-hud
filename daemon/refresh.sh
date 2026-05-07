#!/usr/bin/env bash
# forgeplan-hud daemon :: enrich the cache with R_eff/health.
# Invoked detached by lib/40-forgeplan.sh. Never runs on hot path.
#
# Args: $1 = forgeplan root (dir containing .forgeplan/)
#       $2 = active artifact id (may be empty)
#
# Writes: $HUD_DIR/cache/forgeplan.json (atomic via mktemp+mv)
# Touches: $HUD_DIR/cache/stamp at the end

HUD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$HUD_DIR/lib/00-config.sh"
mkdir -p "$HUD_DIR/cache"

ROOT=${1:-}
ACTIVE=${2:-}
FPL_BIN=${HUD_FPL_BIN:-forgeplan}

# Bail silently if no project root or fpl missing — hot path will use last-known data.
[[ -z "$ROOT" || ! -d "$ROOT/.forgeplan" ]] && exit 0
command -v "$FPL_BIN" >/dev/null 2>&1 || exit 0

cd "$ROOT" || exit 0

# Build the artifact entry (may be null if no active or fpl errors).
ARTIFACT_JSON='{}'
if [[ -n "$ACTIVE" ]]; then
    # `forgeplan get --json` is fast (~80ms) and gives r_eff, title, kind, status,
    # depth, _next_action. Always do this.
    get_raw=$("$FPL_BIN" get "$ACTIVE" --json 2>/dev/null) || get_raw=""

    # `forgeplan score --json` is slow (~2s) but gives the authoritative evidence
    # list and FGR grade. Only attempt for kinds that are scored.
    score_raw=""
    kind=""
    if [[ -n "$get_raw" ]]; then
        kind=$(printf '%s' "$get_raw" | jq -r '.kind // ""' 2>/dev/null)
        case "$kind" in
            prd|rfc|adr|spec)
                score_raw=$("$FPL_BIN" score "$ACTIVE" --json 2>/dev/null) || score_raw=""
                ;;
        esac
    fi

    if [[ -n "$get_raw" ]]; then
        ARTIFACT_JSON=$(jq -n \
            --argjson g "$get_raw" \
            --argjson s "${score_raw:-null}" \
            --arg id "$ACTIVE" '
            { ($id): {
                r_eff:          ($s.fgr.overall // $g.r_eff // null),
                grade:          ($s.fgr.grade // null),
                title:          $g.title,
                kind:           $g.kind,
                status:         $g.status,
                depth:          $g.depth,
                evidence_count: ($s.evidence // [] | length),
                next_action:    ($g._next_action // null)
            }}
        ' 2>/dev/null) || ARTIFACT_JSON='{}'
    fi
fi

# Project-wide health: counts + verdict + top next_action for the idle dashboard.
HEALTH_JSON='{}'
health_raw=$("$FPL_BIN" health --json 2>/dev/null) || health_raw=""
if [[ -n "$health_raw" ]]; then
    HEALTH_JSON=$(printf '%s' "$health_raw" | jq '{
        verdict:          (.verdict // ""),
        orphans:          (if (.orphans | type) == "array"          then .orphans          | length else (.orphans // 0)          end),
        stale:            (.stale_count // 0),
        phase_mismatches: (if (.phase_mismatches | type) == "array" then .phase_mismatches | length else (.phase_mismatches // 0) end),
        at_risk:          (if (.at_risk | type) == "array"          then .at_risk          | length else (.at_risk // 0)          end),
        active_stubs:     (if (.active_stubs | type) == "array"     then .active_stubs     | length else (.active_stubs // 0)     end),
        blind_spots:      (if (.blind_spots | type) == "array"      then .blind_spots      | length else (.blind_spots // 0)      end),
        drafts:           ([.by_status[]? | select(.status == "draft") | .count] | first // 0),
        actives:          ([.by_status[]? | select(.status == "active") | .count] | first // 0),
        next_action:      (.next_actions[0] // "")
    }' 2>/dev/null) || HEALTH_JSON='{}'
fi

# Compose final cache file.
TMP=$(mktemp "$HUD_DIR/cache/forgeplan.json.XXXX")
jq -n --argjson a "$ARTIFACT_JSON" --argjson h "$HEALTH_JSON" '{
    artifacts: $a,
    health:    $h,
    updated:   now | floor
}' > "$TMP" 2>/dev/null && mv "$TMP" "$HUD_DIR/cache/forgeplan.json" || rm -f "$TMP"

touch "$HUD_DIR/cache/stamp"
