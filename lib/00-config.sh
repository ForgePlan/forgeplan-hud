#!/usr/bin/env bash
# forgeplan-hud :: thresholds, language, layout switches
# Source-only. No execution side effects.

# Brand orange #ff5a1f (matches ForgePlanWeb --accent)
HUD_BRAND_256=208

# Threshold pairs for context bar: (warn_pct, alert_pct, critical_pct, hard_pct).
# Two profiles picked at runtime based on context_window_size.
#
# Calibration note (v0.4): the 1M profile was originally shifted left at 30%
# under the lost-in-middle hypothesis. Field experience showed that Opus 4.7
# at 1M doesn't visibly degrade until ~50%, so the 1M curve was pushed back
# closer to the 200k profile — only the upper bands stay slightly tighter.
HUD_CTX_200K_WARN=50
HUD_CTX_200K_ALERT=70
HUD_CTX_200K_CRIT=85
HUD_CTX_200K_HARD=95

HUD_CTX_1M_WARN=50
HUD_CTX_1M_ALERT=65
HUD_CTX_1M_CRIT=80
HUD_CTX_1M_HARD=92

# Rate-limit thresholds (5h and 7d windows from CC stdin, 0-100)
HUD_RATE_WARN=80

# Hint strings now live in lib/05-i18n.sh as bilingual EN/RU pairs.
# Threshold zone → i18n key:
#   WARN  → ctx_warn
#   ALERT → ctx_alert
#   CRIT  → ctx_crit
#   HARD  → ctx_hard

# Bar width (filled + empty cells). 10 cells = 10% per cell, easy to read.
HUD_BAR_WIDTH=10

# Cost emphasis thresholds (USD)
HUD_COST_NOTICE=1.0
HUD_COST_HEAVY=5.0

# Cache freshness window for forgeplan-zone data (seconds)
HUD_CACHE_TTL=30

# Forgeplan binary name — `fpl` is alias, `forgeplan` is real
HUD_FPL_BIN="${HUD_FPL_BIN:-forgeplan}"
