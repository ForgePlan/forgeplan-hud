#!/usr/bin/env bash
# forgeplan-hud :: ANSI 256 palette (mirrors ForgePlanWeb tokens)
# All functions are pure: take text, return text wrapped in escape codes.

ESC=$'\033'
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"

# Palette (256-color codes)
HUD_FG=231         # #f5f5f5 — primary text, IDs
HUD_DIM=243        # #737373 — secondary metadata
HUD_INACTIVE=237   # #525252 — empty bar cells, deprecated
HUD_BRAND=208      # #ff5a1f — Forgeplan accent orange
HUD_GOOD=46        # #22c55e — R_eff ≥0.6, low context
HUD_WARN=214       # #f59e0b — middle zone
HUD_BAD=196        # #ef4444 — critical zone

fg256() { printf "${ESC}[38;5;%sm%s${RESET}" "$1" "$2"; }
bold()  { printf "${BOLD}%s${RESET}" "$1"; }
dim()   { printf "${ESC}[2;38;5;${HUD_DIM}m%s${RESET}" "$1"; }

color_brand() { fg256 "$HUD_BRAND" "$1"; }
color_good()  { fg256 "$HUD_GOOD"  "$1"; }
color_warn()  { fg256 "$HUD_WARN"  "$1"; }
color_bad()   { fg256 "$HUD_BAD"   "$1"; }
color_fg()    { fg256 "$HUD_FG"    "$1"; }
color_inact() { fg256 "$HUD_INACTIVE" "$1"; }
