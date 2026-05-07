#!/usr/bin/env bash
# forgeplan-hud :: bilingual hint table (EN — RU)
# Implemented as a case dispatch instead of associative arrays — bash 3.2
# (default on macOS) does not support `declare -A`. Adding a hint = adding
# one branch here.

i18n_pair() {
    case "$1" in
        # ── Context bar (U-curve) ────────────────────────────────
        ctx_warn)     echo "prep handoff — готовь передачу" ;;
        ctx_alert)    echo "mid fades — середина бледнеет" ;;
        ctx_crit)     echo "/compact NOW — /compact СЕЙЧАС" ;;
        ctx_hard)     echo "NEW SESSION — НОВАЯ СЕССИЯ" ;;

        # ── Idle hints (one per project-health category) ─────────
        idle_route)   echo 'forgeplan route "<task>" — запусти forgeplan route' ;;
        idle_orphans) echo "Link orphan artifacts — связать сироты" ;;
        idle_stubs)   echo "Fill or supersede stubs — заполни или замени stubs" ;;
        idle_mismatch) echo "Fix phase mismatches — исправь фазы артефактов" ;;
        idle_stale)   echo "Renew stale evidence — обнови протухшие evidence" ;;
        idle_at_risk) echo "Review at-risk artifacts — проверь рисковые артефакты" ;;
        idle_drafts)  echo "Activate ready drafts — активируй готовые drafts" ;;
        idle_blind)   echo "Investigate blind spots — разбери слепые зоны" ;;

        *) echo "?" ;;
    esac
}
