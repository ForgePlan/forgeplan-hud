<div align="center">

# forgeplan-hud

### Two-line heads-up display for Claude Code

A **terminal statusline** wired into the [ForgePlan](https://github.com/ForgePlan/forgeplan) ecosystem.
Pure `bash` + `jq`, ~60 ms render, zero network calls. Surfaces context window, session cost,
rate limits, active artifact, R_eff, evidence count, and project health — at the bottom of every
Claude Code session.

<br>

[![License: MIT](https://img.shields.io/badge/license-MIT-000.svg?style=flat-square)](LICENSE)
[![Bash 3.2+](https://img.shields.io/badge/bash-3.2+-green?style=flat-square)](https://www.gnu.org/software/bash/)
[![ForgePlan](https://img.shields.io/badge/ForgePlan-ecosystem-ff5a1f?style=flat-square)](https://github.com/ForgePlan)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-statusLine-d97706?style=flat-square)](https://docs.anthropic.com/claude-code)

**[Forgeplan](https://github.com/ForgePlan/forgeplan)** ·
**[Web](https://github.com/ForgePlan/forgeplan-web)** ·
**[Marketplace](https://github.com/ForgePlan/marketplace)** ·
**[Releases](https://github.com/ForgePlan/forgeplan-hud/releases)**

<br>

[English](README.md) **·** [Русский](README.ru.md)

<br>

</div>

---

<div align="center">

```
    ┌──────────┐    ┌────────────┐    ┌─────────────┐    ┌───────────────┐
    │  STDIN   │ ─▶ │  jq parse  │ ─▶ │  fp_lookup  │ ─▶ │  render lines │
    └──────────┘    └────────────┘    └─────────────┘    └───────────────┘
     CC pipes        13 fields         session.yaml +     2-line ANSI
     JSON event      in one fork       cache (lazy bg)    to stdout
```

**Local. Bilingual EN — RU. ~60 ms hot path.**

</div>

---

## Why

<table>
<tr>
<td width="50%">

### Before

- Empty status bar at the bottom of Claude Code
- "How much context have I burned?" — no idea
- "Did I just run past my 5-hour limit?" — surprise
- Active forgeplan artifact invisible during work
- Health verdict (orphans, stubs, stale) only via `forgeplan health`
- Session cost only after the bill arrives

</td>
<td width="50%">

### After

- Two-line bar with model · context · cost · rate · duration
- U-curve hint ladder (`prep handoff` → `NEW SESSION`)
- Active artifact with R_eff bar and evidence count
- Idle dashboard: orphans · stubs · drafts with bilingual hint
- Worktree marker `⌥` and agent badge `[agent: name]`
- ANSI 256 palette mirrors ForgePlan brand orange `#ff5a1f`

</td>
</tr>
</table>

## Install

```bash
# One-liner (recommended)
curl -fsSL https://raw.githubusercontent.com/ForgePlan/forgeplan-hud/main/install.sh | bash

# Or after git clone
git clone https://github.com/ForgePlan/forgeplan-hud.git
./forgeplan-hud/install.sh
```

The installer copies the project to `~/.claude/forgeplan-hud/` and patches `~/.claude/settings.json`
to register the statusLine command. Restart any open Claude Code sessions to pick up the bar.

To remove:

```bash
~/.claude/forgeplan-hud/uninstall.sh
```

**Requirements:** `bash` (3.2+, default on macOS), `jq`. `forgeplan` CLI is optional —
the bar gracefully shows only the Claude line when no `.forgeplan/` is in the cwd ancestry.

## 60-Second Demo

**Active ForgePlan artifact, healthy session:**

```
🔨 ADR-012 ▸ "Slug-canonical identity with di…"  routing/standard  R 0.76 ●●●●●●●●○○  EVID×2
⬢ Opus 1M  ▮▮▯▯▯▯▯▯▯▯ 24%  $10.55  5h 31%·7d 41%  ⏱ 1h 03m
```

**Idle workspace with project rotting:**

```
🔨 idle ⚠ 2 orphans · 3 stubs · 32 drafts  ▸ Link orphan artifacts — связать сироты
⬢ Opus 1M  ▮▯▯▯▯▯▯▯▯▯ 12%  $0.04  5h 8%·7d 41%  ⏱ 3m
```

**Context bar in critical zone, rate limit alert, heavy cost:**

```
⬢ Opus 1M  ▮▮▮▮▮▮▮▮▯▯ 78% /compact NOW — /compact СЕЙЧАС  $6.40  5h 84%⚠·7d 67%  ⏱ 2h 00m
```

**Worktree session with subagent:**

```
⌥ ⬢ Opus 1M [agent: security-reviewer]  ▮▮▯▯▯▯▯▯▯▯ 18%  $0.12  5h 12%·7d 30%  ⏱ 6m
```

## What it shows

### Line 1 — ForgePlan zone (when `.forgeplan/` is in scope)

| Segment | Source | Notes |
|---|---|---|
| `🔨 ADR-012` | `session.yaml: active_artifact` | brand-orange marker + bold ID |
| `▸ "title…"` | daemon cache (`forgeplan get --json`) | truncated to 32 chars |
| `routing/standard` | session.yaml: phase + route_depth | dim |
| `R 0.76 ●●●●●●●●○○` | daemon cache (`forgeplan score --json`) | green ≥0.6, brand 0.3-0.6, red <0.3 |
| `EVID×2` | daemon cache | hidden when 0 |
| `⚠ 3 orphans` | daemon cache (`forgeplan health --json`) | hidden when 0 |
| `⌛` | cache stamp mtime | shown when stale (>3× TTL) |

When idle (no active artifact), the line collapses to a hybrid health summary:

```
🔨 idle  ▸ forgeplan route "<task>" — запусти forgeplan route   (healthy)
🔨 idle ⚠ 2 orphans · 3 stubs  ▸ Link orphan artifacts — связать сироты   (needs_attention)
🔨 critical ✕ 8 stale · 12 mismatch  ▸ Renew stale evidence — обнови ...  (critical)
```

### Line 2 — Claude session zone

| Segment | Source | Notes |
|---|---|---|
| `⌥` | `workspace.git_worktree` | only when in a worktree |
| `⬢ Opus 1M` | `model.display_name` + `context_window_size` | size badge: `200k` or `1M` |
| `[agent: name]` | `agent.name` | only when launched with `--agent` |
| `▮▮▯▯▯▯▯▯▯▯ 23%` | `context_window.used_percentage` | colored by U-curve |
| `prep handoff — готовь передачу` | i18n table | bilingual hint, threshold-driven |
| `$0.42` | `cost.total_cost_usd` | dim < $1, brand < $5, red ≥ $5 |
| `5h 23%·7d 41%` | `rate_limits.{five_hour,seven_day}` | red + ⚠ when ≥80% |
| `⏱ 12m` | `cost.total_duration_ms` | wall-clock since session start |

## The U-curve

LLMs suffer "lost in the middle": as the context window fills, the **center** of the
conversation loses fidelity faster than the start or end. The HUD color-codes context
fill so you have time to **prepare a session handoff** before quality degrades.

| Zone | 200k | 1M | Color | Bilingual hint |
|---|:---:|:---:|---|---|
| **Good** | < 50% | < 50% | green | (silent) |
| **Warn** | 50-70% | 50-65% | yellow | `prep handoff — готовь передачу` |
| **Alert** | 70-85% | 65-80% | brand orange | `mid fades — середина бледнеет` |
| **Crit** | 85-95% | 80-92% | red | `/compact NOW — /compact СЕЙЧАС` |
| **Hard** | ≥ 95% | ≥ 92% | red | `NEW SESSION — НОВАЯ СЕССИЯ` |

The 1M profile was originally shifted left (30 / 50 / 70 / 85), then calibrated back
to match 200k after field experience showed Opus 4.7 at 1M doesn't visibly degrade
until ~50%. All thresholds live in `lib/00-config.sh` — adjust to taste.

## How it works

```
                ┌─── stdin (JSON from CC) ──────────────┐
                │                                       │
   every CC ──► statusline.sh ──► reads stdin           │
   event +     │                                        │
   refresh    │ if .forgeplan/ in ancestry:             │
   10 sec     │   reads session.yaml (free)             │
              │   reads cache/forgeplan.json (jq, free) │
              │   if cache > 30s old:                   │
              │     forks daemon/refresh.sh in bg ──────┼──► forgeplan get --json
              │                                         │   forgeplan score --json
              │ renders two lines to stdout             │   forgeplan health --json
              └──── two lines (ANSI) ───────────────────┘   writes cache atomically
```

The hot path never blocks on `forgeplan` calls. Slow ones (`score` ~2 s, `health` ~360 ms)
live in the detached daemon and update the cache between ticks. If `forgeplan` isn't on
PATH, the HUD silently falls back to last-known cache, or to `session.yaml` only.

### Live refresh on `forgeplan` commands

`install.sh` also wires a **PostToolUse:Bash hook** (`daemon/invalidate.sh`) into
`~/.claude/settings.json`. After every Bash tool call that runs `forgeplan` or `fpl`,
the hook deletes the cache stamp — the next statusline tick (≤10 s, usually
the next assistant message) forks the daemon and refreshes within ~200-500 ms.

This turns the HUD into a **tight feedback loop**: run `forgeplan link PRD-001 ...` →
on the next response the bar already reflects the new orphan count. Without the hook
you'd wait for the 30 s cache TTL.

The matcher only fires on standalone `forgeplan` / `fpl` words — `forgeplan-hud` and
`myfpl` are correctly ignored. `uninstall.sh` removes the hook cleanly.

## Configuration

All knobs live in `~/.claude/forgeplan-hud/lib/00-config.sh`:

```bash
# Threshold profiles for the context bar
HUD_CTX_200K_WARN=50    HUD_CTX_1M_WARN=50
HUD_CTX_200K_ALERT=70   HUD_CTX_1M_ALERT=65
HUD_CTX_200K_CRIT=85    HUD_CTX_1M_CRIT=80
HUD_CTX_200K_HARD=95    HUD_CTX_1M_HARD=92

# Rate-limit threshold (5h and 7d)
HUD_RATE_WARN=80

# Cost emphasis
HUD_COST_NOTICE=1.0     # dim → brand
HUD_COST_HEAVY=5.0      # brand → red

# Cache freshness for forgeplan-zone
HUD_CACHE_TTL=30

# Forgeplan binary (alias `fpl` works too)
HUD_FPL_BIN="forgeplan"
```

Bilingual hint strings live in `lib/05-i18n.sh` — extend the `case` dispatch to add new pairs.

## Documentation

| File | What's inside |
|---|---|
| [README.md](README.md) | This page (English) |
| [README.ru.md](README.ru.md) | Russian translation |
| [LICENSE](LICENSE) | MIT |
| [test/run.sh](test/run.sh) | Runs every fixture and prints rendered output |

## Edge cases

- **No `.forgeplan/` in cwd** → only the Claude line is rendered.
- **`forgeplan` not on PATH** → daemon exits silently; line 1 falls back to `session.yaml`-only data.
- **`jq` not installed** → graceful one-liner: `⬢ Claude (install jq for full HUD)`.
- **Cache stale (>3× TTL)** → trailing `⌛` marker.
- **No active artifact** → idle dashboard with health verdict + bilingual category hint.
- **Worktree session** → `⌥` prefix on model.
- **Subagent session (`--agent`)** → `[agent: name]` suffix on model.

## Project layout

```
.
├── statusline.sh          ← entry point
├── lib/
│   ├── 00-config.sh       ← thresholds, cache TTL, cost knobs
│   ├── 05-i18n.sh         ← bilingual hint table (EN — RU)
│   ├── 10-colors.sh       ← ANSI 256 palette (mirrors ForgePlanWeb)
│   ├── 20-context.sh      ← U-curve renderer
│   ├── 30-cost.sh         ← cost / rate / duration / model
│   ├── 40-forgeplan.sh    ← session.yaml + cache reader + idle dashboard
│   └── 99-render.sh       ← two-line composition
├── daemon/
│   └── refresh.sh         ← detached forgeplan-fetcher
├── cache/                 ← runtime, gitignored
├── test/
│   ├── fixture-*.json     ← synthetic stdin
│   └── run.sh             ← snapshot-style runner
├── install.sh
└── uninstall.sh
```

## Dogfood

`forgeplan-hud` is calibrated against itself: the design lives in the
[ForgePlan](https://github.com/ForgePlan/forgeplan) workspace, the visual language is
copied from [`@forgeplan/web`](https://github.com/ForgePlan/forgeplan-web), and every
field decision (the U-curve thresholds, the i18n table, the idle priority order) is
captured as a commit message in this repo. The bar at the bottom of the terminal is
literally watching itself being built.

## Contributing

```bash
# Branch from main
# Work in a small loop: edit lib/ → ./test/run.sh → smoke-eyeball → commit
# bash 3.2 compatibility is non-negotiable (default on macOS) — no `declare -A`
# PR → main, single reviewer, no CI gate yet
```

## License

MIT — see [LICENSE](LICENSE).

Part of the **ForgePlan** ecosystem alongside
[`forgeplan`](https://github.com/ForgePlan/forgeplan),
[`@forgeplan/web`](https://github.com/ForgePlan/forgeplan-web), and the
[marketplace](https://github.com/ForgePlan/marketplace).
