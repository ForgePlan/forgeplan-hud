<div align="center">

# forgeplan-hud

### Двухстрочный heads-up дисплей для Claude Code

**Терминальный statusline**, встроенный в экосистему [ForgePlan](https://github.com/ForgePlan/forgeplan).
Чистый `bash` + `jq`, рендер ~60 мс, без сетевых вызовов. Показывает контекстное окно, стоимость
сессии, rate-лимиты, активный артефакт, R_eff, количество evidence и здоровье проекта — внизу
каждой Claude Code сессии.

<br>

[![License: MIT](https://img.shields.io/badge/license-MIT-000.svg?style=flat-square)](LICENSE)
[![Bash 3.2+](https://img.shields.io/badge/bash-3.2+-green?style=flat-square)](https://www.gnu.org/software/bash/)
[![ForgePlan](https://img.shields.io/badge/ForgePlan-ecosystem-ff5a1f?style=flat-square)](https://github.com/ForgePlan)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-statusLine-d97706?style=flat-square)](https://docs.anthropic.com/claude-code)

**[Forgeplan](https://github.com/ForgePlan/forgeplan)** ·
**[Web](https://github.com/ForgePlan/forgeplan-web)** ·
**[Marketplace](https://github.com/ForgePlan/marketplace)** ·
**[Релизы](https://github.com/ForgePlan/forgeplan-hud/releases)**

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
     CC пайпит       13 полей в       session.yaml +     2 строки ANSI
     JSON событие    одном fork       cache (lazy bg)    в stdout
```

**Локально. Билингва EN — RU. ~60 мс на hot path.**

</div>

---

## Зачем

<table>
<tr>
<td width="50%">

### Раньше

- Пустая статусная строка внизу Claude Code
- «Сколько контекста я уже сжёг?» — непонятно
- «Я только что выбежал за 5-часовой лимит?» — сюрприз
- Активный forgeplan-артефакт невидим во время работы
- Health-вердикт (orphans, stubs, stale) только через `forgeplan health`
- Стоимость сессии — только когда придёт счёт

</td>
<td width="50%">

### Сейчас

- Двухстрочный бар: модель · контекст · стоимость · лимиты · длительность
- U-кривая лестницы подсказок (`prep handoff` → `NEW SESSION`)
- Активный артефакт с R_eff-баром и счётчиком evidence
- Idle-дашборд: orphans · stubs · drafts с билингвальной подсказкой
- Worktree-маркер `⌥` и agent-бэйдж `[agent: name]`
- ANSI 256 палитра отражает фирменный оранжевый ForgePlan `#ff5a1f`

</td>
</tr>
</table>

## Установка

```bash
# Одной командой (рекомендуется)
curl -fsSL https://raw.githubusercontent.com/ForgePlan/forgeplan-hud/main/install.sh | bash

# Или после git clone
git clone https://github.com/ForgePlan/forgeplan-hud.git
./forgeplan-hud/install.sh
```

Установщик копирует проект в `~/.claude/forgeplan-hud/` и патчит `~/.claude/settings.json`,
регистрируя statusLine-команду. Перезапусти открытые Claude Code сессии — бар появится снизу.

Удаление:

```bash
~/.claude/forgeplan-hud/uninstall.sh
```

**Требования:** `bash` (3.2+, дефолтный на macOS), `jq`. CLI `forgeplan` опционален —
HUD корректно показывает только Claude-строку, если `.forgeplan/` нет в дереве cwd.

## 60-секундное демо

**Активный ForgePlan-артефакт, нормальная сессия:**

```
🔨 ADR-012 ▸ "Slug-canonical identity with di…"  routing/standard  R 0.76 ●●●●●●●●○○  EVID×2
⬢ Opus 1M  ▮▮▯▯▯▯▯▯▯▯ 24%  $10.55  5h 31%·7d 41%  ⏱ 1h 03m
```

**Idle workspace с накопившимися проблемами:**

```
🔨 idle ⚠ 2 orphans · 3 stubs · 32 drafts  ▸ Link orphan artifacts — связать сироты
⬢ Opus 1M  ▮▯▯▯▯▯▯▯▯▯ 12%  $0.04  5h 8%·7d 41%  ⏱ 3m
```

**Контекстный бар в критической зоне, alert по rate-лимитам, тяжёлая стоимость:**

```
⬢ Opus 1M  ▮▮▮▮▮▮▮▮▯▯ 78% /compact NOW — /compact СЕЙЧАС  $6.40  5h 84%⚠·7d 67%  ⏱ 2h 00m
```

**Worktree-сессия с субагентом:**

```
⌥ ⬢ Opus 1M [agent: security-reviewer]  ▮▮▯▯▯▯▯▯▯▯ 18%  $0.12  5h 12%·7d 30%  ⏱ 6m
```

## Что показывает

### Строка 1 — ForgePlan зона (когда `.forgeplan/` в области видимости)

| Сегмент | Источник | Заметки |
|---|---|---|
| `🔨 ADR-012` | `session.yaml: active_artifact` | brand-orange маркер + bold ID |
| `▸ "title…"` | кэш демона (`forgeplan get --json`) | обрезается до 32 символов |
| `routing/standard` | session.yaml: phase + route_depth | dim |
| `R 0.76 ●●●●●●●●○○` | кэш демона (`forgeplan score --json`) | green ≥0.6, brand 0.3-0.6, red <0.3 |
| `EVID×2` | кэш демона | скрыто при 0 |
| `⚠ 3 orphans` | кэш демона (`forgeplan health --json`) | скрыто при 0 |
| `⌛` | mtime stamp-файла кэша | показано когда устарел (>3× TTL) |

В idle (нет активного артефакта) строка сворачивается в hybrid health-summary:

```
🔨 idle  ▸ forgeplan route "<task>" — запусти forgeplan route   (healthy)
🔨 idle ⚠ 2 orphans · 3 stubs  ▸ Link orphan artifacts — связать сироты   (needs_attention)
🔨 critical ✕ 8 stale · 12 mismatch  ▸ Renew stale evidence — обнови ...  (critical)
```

### Строка 2 — Claude session зона

| Сегмент | Источник | Заметки |
|---|---|---|
| `⌥` | `workspace.git_worktree` | только при работе в worktree |
| `⬢ Opus 1M` | `model.display_name` + `context_window_size` | бэйдж размера: `200k` или `1M` |
| `[agent: name]` | `agent.name` | только при запуске с `--agent` |
| `▮▮▯▯▯▯▯▯▯▯ 23%` | `context_window.used_percentage` | цвет по U-кривой |
| `prep handoff — готовь передачу` | i18n-таблица | билингвальная подсказка по порогам |
| `$0.42` | `cost.total_cost_usd` | dim < $1, brand < $5, red ≥ $5 |
| `5h 23%·7d 41%` | `rate_limits.{five_hour,seven_day}` | red + ⚠ при ≥80% |
| `⏱ 12m` | `cost.total_duration_ms` | время с начала сессии |

## U-кривая

LLM страдают от «lost in the middle»: по мере заполнения контекстного окна **середина**
разговора теряет точность быстрее чем начало или конец. HUD цветом кодирует заполнение,
чтобы у тебя было время **подготовить передачу сессии** до деградации качества.

| Зона | 200k | 1M | Цвет | Билингвальная подсказка |
|---|:---:|:---:|---|---|
| **Good** | < 50% | < 50% | green | (тишина) |
| **Warn** | 50-70% | 50-65% | yellow | `prep handoff — готовь передачу` |
| **Alert** | 70-85% | 65-80% | brand orange | `mid fades — середина бледнеет` |
| **Crit** | 85-95% | 80-92% | red | `/compact NOW — /compact СЕЙЧАС` |
| **Hard** | ≥ 95% | ≥ 92% | red | `NEW SESSION — НОВАЯ СЕССИЯ` |

Изначально 1M-профиль был сдвинут влево (30 / 50 / 70 / 85), затем откалиброван назад
к 200k после полевых наблюдений: Opus 4.7 на 1M не деградирует визуально до ~50%.
Все пороги в `lib/00-config.sh` — настраивай под себя.

## Как работает

```
                ┌─── stdin (JSON от CC) ────────────────┐
                │                                       │
   каждое CC ─► statusline.sh ──► читает stdin          │
   событие +   │                                        │
   refresh    │ если .forgeplan/ в дереве cwd:          │
   10 сек     │   читает session.yaml (бесплатно)       │
              │   читает cache/forgeplan.json (jq)      │
              │   если кэш > 30s старый:                │
              │     форкает daemon/refresh.sh в bg ─────┼──► forgeplan get --json
              │                                         │   forgeplan score --json
              │ рендерит две строки в stdout            │   forgeplan health --json
              └──── две строки (ANSI) ──────────────────┘   атомарно пишет кэш
```

Hot path никогда не блокируется на `forgeplan`-вызовах. Медленные (`score` ~2 с,
`health` ~360 мс) живут в отдельном демоне и обновляют кэш между тиками. Если
`forgeplan` нет на PATH, HUD молча fallback на последний кэш или на `session.yaml`.

## Конфигурация

Все настройки в `~/.claude/forgeplan-hud/lib/00-config.sh`:

```bash
# Профили порогов для контекстного бара
HUD_CTX_200K_WARN=50    HUD_CTX_1M_WARN=50
HUD_CTX_200K_ALERT=70   HUD_CTX_1M_ALERT=65
HUD_CTX_200K_CRIT=85    HUD_CTX_1M_CRIT=80
HUD_CTX_200K_HARD=95    HUD_CTX_1M_HARD=92

# Порог rate-лимитов (5h и 7d)
HUD_RATE_WARN=80

# Акценты по стоимости
HUD_COST_NOTICE=1.0     # dim → brand
HUD_COST_HEAVY=5.0      # brand → red

# Свежесть кэша forgeplan-зоны
HUD_CACHE_TTL=30

# Бинарник forgeplan (алиас `fpl` тоже работает)
HUD_FPL_BIN="forgeplan"
```

Билингвальные подсказки в `lib/05-i18n.sh` — добавь свою категорию через `case`-ветку.

## Документация

| Файл | Что внутри |
|---|---|
| [README.md](README.md) | Английская версия |
| [README.ru.md](README.ru.md) | Эта страница |
| [LICENSE](LICENSE) | MIT |
| [test/run.sh](test/run.sh) | Прогоняет все fixtures и печатает результат |

## Edge-кейсы

- **Нет `.forgeplan/` в cwd** → рендерится только Claude-строка.
- **`forgeplan` не на PATH** → демон молча выходит; строка 1 fallback на данные `session.yaml`.
- **`jq` не установлен** → graceful one-liner: `⬢ Claude (install jq for full HUD)`.
- **Кэш устарел (>3× TTL)** → trailing маркер `⌛`.
- **Нет активного артефакта** → idle-дашборд с health-вердиктом + категория с билингвальной подсказкой.
- **Worktree-сессия** → префикс `⌥` на модели.
- **Subagent-сессия (`--agent`)** → суффикс `[agent: name]` на модели.

## Структура проекта

```
.
├── statusline.sh          ← entry point
├── lib/
│   ├── 00-config.sh       ← пороги, TTL кэша, настройки стоимости
│   ├── 05-i18n.sh         ← билингвальная таблица подсказок (EN — RU)
│   ├── 10-colors.sh       ← ANSI 256 палитра (отзеркаливает ForgePlanWeb)
│   ├── 20-context.sh      ← рендер U-кривой
│   ├── 30-cost.sh         ← cost / rate / duration / model
│   ├── 40-forgeplan.sh    ← session.yaml + cache reader + idle-дашборд
│   └── 99-render.sh       ← двухстрочная сборка
├── daemon/
│   └── refresh.sh         ← отдельный forgeplan-fetcher
├── cache/                 ← runtime, gitignored
├── test/
│   ├── fixture-*.json     ← синтетический stdin
│   └── run.sh             ← snapshot-style runner
├── install.sh
└── uninstall.sh
```

## Dogfood

`forgeplan-hud` калибруется на самом себе: дизайн живёт в workspace
[ForgePlan](https://github.com/ForgePlan/forgeplan), визуальный язык скопирован из
[`@forgeplan/web`](https://github.com/ForgePlan/forgeplan-web), а каждое полевое решение
(пороги U-кривой, i18n-таблица, приоритет idle-категорий) зафиксировано как commit-сообщение
в этом репозитории. Бар внизу терминала буквально наблюдает за тем как сам себя строит.

## Contributing

```bash
# Ветка от main
# Маленький цикл: edit lib/ → ./test/run.sh → smoke-eyeball → commit
# bash 3.2 совместимость обязательна (дефолт на macOS) — никаких `declare -A`
# PR → main, single reviewer, CI пока нет
```

## Лицензия

MIT — см. [LICENSE](LICENSE).

Часть экосистемы **ForgePlan** наряду с
[`forgeplan`](https://github.com/ForgePlan/forgeplan),
[`@forgeplan/web`](https://github.com/ForgePlan/forgeplan-web) и
[marketplace](https://github.com/ForgePlan/marketplace).
