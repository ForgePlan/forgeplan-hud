#!/usr/bin/env bash
# forgeplan-hud :: thresholds, language, layout switches
# Source-only. No execution side effects.

# Brand orange #ff5a1f (matches ForgePlanWeb --accent)
HUD_BRAND_256=208

# Threshold pairs for context bar: (warn_pct, alert_pct, critical_pct).
# Two profiles — picked at runtime based on context_window_size from CC stdin.
# Rationale: 1M-context models suffer "lost in the middle" earlier than 200k,
# so the curve is shifted left.
HUD_CTX_200K_WARN=50
HUD_CTX_200K_ALERT=70
HUD_CTX_200K_CRIT=85
HUD_CTX_200K_HARD=95

HUD_CTX_1M_WARN=30
HUD_CTX_1M_ALERT=50
HUD_CTX_1M_CRIT=70
HUD_CTX_1M_HARD=85

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
