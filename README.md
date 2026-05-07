# forgeplan-hud

A two-line **heads-up display** for the [Claude Code](https://docs.anthropic.com/claude-code) CLI, deeply wired into the [ForgePlan](https://github.com/ForgePlan/forgeplan) ecosystem.

```
🔨 ADR-012 ▸ "Slug-canonical identity with di…"  routing/standard  R 0.76 ●●●●●●●●○○  EVID×2  ⚠ 3 orphans
⌥ ⬢ Opus 1M [agent: security-reviewer]  ▮▮▮▮▮▮▮▮▯▯ 78% /compact NOW  $6.40  5h 84%⚠·7d 67%  ⏱ 2h 00m
```

Pure `bash` + `jq`. No daemons, no Node, no network calls in the hot path. ~60 ms per render.

---

## Why

Claude Code's default statusbar is empty. You don't see:
- How close you are to filling the context window (and **when** to start drafting a handoff prompt for the next session)
- How much the current session has cost so far
- Whether you've burnt through your 5-hour or 7-day rate limits
- What ForgePlan artifact you are currently shaping/coding/auditing
- Whether the artifact has enough evidence to activate

`forgeplan-hud` surfaces all of this without leaving your terminal.

---

## Install

Requires `jq` and `bash` (already on every macOS/Linux). For the ForgePlan zone you also need [`forgeplan`](https://github.com/ForgePlan/forgeplan) on `PATH`.

```bash
curl -fsSL https://raw.githubusercontent.com/ForgePlan/forgeplan-hud/main/install.sh | bash
```

The installer:
- Copies the project to `~/.claude/forgeplan-hud/`
- Patches `~/.claude/settings.json` to wire the statusline
- Backs up any existing `.statusLine` setting to `settings.json.bak`

Then **restart any open Claude Code sessions** (the statusline is read at session start).

To remove:

```bash
~/.claude/forgeplan-hud/uninstall.sh
```

---

## What you see

### Line 1 — ForgePlan zone

Only rendered when the current cwd is inside a `.forgeplan/` workspace.

| Segment | Source | Notes |
|---|---|---|
| `🔨 ADR-012` | `.forgeplan/session.yaml: active_artifact` | brand-orange marker + bold ID |
| `▸ "title…"` | daemon cache (`forgeplan get --json`) | truncated to 32 chars |
| `routing/standard` | session.yaml: phase + route_depth | dim |
| `R 0.76 ●●●●●●●●○○` | daemon cache (`forgeplan score --json`) | green ≥0.6, brand 0.3-0.6, red <0.3 |
| `EVID×2` | daemon cache | hidden when 0 |
| `⚠ 3 orphans` | daemon cache (`forgeplan health --json`) | hidden when 0 |
| `⌛` | cache stamp mtime | shown when stale (>3× TTL) |

When the workspace is **idle** (no active artifact), the line collapses to a CTA:

```
🔨 idle  ▸ forgeplan validate ADR-012
```

The CTA text comes from `forgeplan`'s own `_next_action` field, so it always points at the actual next step.

### Line 2 — Claude session zone

Always rendered.

| Segment | Source | Notes |
|---|---|---|
| `⌥` | `workspace.git_worktree` | only when in a worktree |
| `⬢ Opus 1M` | `model.display_name` + `context_window.context_window_size` | size badge: `200k` or `1M` |
| `[agent: name]` | `agent.name` | only when launched with `--agent` |
| `▮▮▯▯▯▯▯▯▯▯ 23%` | `context_window.used_percentage` | colored by U-curve (see below) |
| `prep handoff` | computed | hint, lang configurable |
| `$0.42` | `cost.total_cost_usd` | dim < $1, brand < $5, red ≥ $5 |
| `5h 23%·7d 41%` | `rate_limits.{five_hour,seven_day}.used_percentage` | red + ⚠ when ≥80% |
| `⏱ 12m` | `cost.total_duration_ms` | wall-clock since session start |

---

## The U-curve

LLMs suffer "lost in the middle": as the context window fills, the **center** of the conversation loses fidelity faster than the start or end. This isn't a hard wall — it's a gradient. The HUD color-codes context fill so you have time to **prepare a session handoff** before quality degrades.

| Zone | 200k thresholds | 1M thresholds | Color | Hint |
|---|:---:|:---:|---|---|
| **Good** | < 50% | < 30% | green | (silent) |
| **Warn** | 50-70% | 30-50% | yellow | `prep handoff` |
| **Alert** | 70-85% | 50-70% | brand orange | `mid fades` |
| **Crit** | 85-95% | 70-85% | red | `/compact NOW` |
| **Hard** | ≥ 95% | ≥ 85% | red | `NEW SESSION` |

The 1M profile is more aggressive because the lost-in-middle effect kicks in earlier — useful tokens at 60% of a 1M window already span 600k characters.

You can tweak thresholds in `lib/00-config.sh`.

---

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

Hot path never blocks on `forgeplan` calls. The slow ones (`score` ~2s, `health` ~360ms) live in the detached daemon and update the cache between ticks. If the daemon is missing or `forgeplan` isn't on PATH, the HUD silently falls back to last-known cache, or just to session.yaml.

---

## Configuration

All knobs are in `~/.claude/forgeplan-hud/lib/00-config.sh`:

```bash
# Threshold pairs for context bar
HUD_CTX_200K_WARN=50    HUD_CTX_1M_WARN=30
HUD_CTX_200K_ALERT=70   HUD_CTX_1M_ALERT=50
HUD_CTX_200K_CRIT=85    HUD_CTX_1M_CRIT=70
HUD_CTX_200K_HARD=95    HUD_CTX_1M_HARD=85

# Rate-limit threshold (5h and 7d)
HUD_RATE_WARN=80

# Hints — replace with your language of choice
HUD_HINT_PREP="prep handoff"
HUD_HINT_FADE="mid fades"
HUD_HINT_COMPACT="/compact NOW"
HUD_HINT_ROTATE="NEW SESSION"

# Bar width and cost emphasis
HUD_BAR_WIDTH=10
HUD_COST_NOTICE=1.0
HUD_COST_HEAVY=5.0

# Cache freshness for forgeplan-zone
HUD_CACHE_TTL=30
```

---

## Edge cases

- **No `.forgeplan/` in cwd** → only the Claude line is rendered.
- **`forgeplan` not on PATH** → daemon exits silently; line 1 falls back to session.yaml-only data.
- **`jq` not installed** → graceful one-liner: `⬢ Claude (install jq for full HUD)`.
- **Cache stale (>3× TTL)** → trailing `⌛` marker.
- **No active artifact** → idle CTA with cached `_next_action`.
- **Worktree session** → `⌥` prefix on model.
- **Subagent session (`--agent`)** → `[agent: name]` suffix on model.

---

## Development

Project layout:

```
.
├── statusline.sh          ← entry point
├── lib/
│   ├── 00-config.sh       ← thresholds, hints, switches
│   ├── 10-colors.sh       ← ANSI 256 palette (mirrors ForgePlanWeb)
│   ├── 20-context.sh      ← U-curve renderer
│   ├── 30-cost.sh         ← cost / rate / duration / model
│   ├── 40-forgeplan.sh    ← session.yaml + cache reader
│   └── 99-render.sh       ← two-line composition
├── daemon/
│   └── refresh.sh         ← detached forgeplan-fetcher
├── cache/                 ← runtime, gitignored
├── test/
│   ├── fixture-*.json     ← synthetic stdin
│   └── run.sh             ← runs all fixtures, prints rendered output
├── install.sh
└── uninstall.sh
```

Run the test suite:

```bash
./test/run.sh
```

Hot-path budget: under 100 ms per render. CC's event-debounce is 300 ms, so anything below that won't visibly lag.

---

## License

MIT — see [LICENSE](LICENSE)

Part of the ForgePlan ecosystem alongside [forgeplan](https://github.com/ForgePlan/forgeplan), [forgeplan-web](https://github.com/ForgePlan/forgeplan-web), and [marketplace](https://github.com/ForgePlan/marketplace).
