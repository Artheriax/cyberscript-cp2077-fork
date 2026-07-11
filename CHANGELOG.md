# Changelog — Cyberscript CP2077 Fork

All notable changes to this fork are documented here. Dates are in
`Europe/Amsterdam` timezone. Bug IDs (`B-XX`) reference
`research/bugs.md` in this repository.

## [5.1.6] — 2026-07-11

Second iteration of the bug-fix pass. Includes all fixes from fork.1
plus additional fixes discovered during in-game testing with
Companions of Night City, Gangs of Night City, and Cyberscript Studio.

### New fixes in fork.2

- **B-21** (`modpack.lua`, `core.lua`, `see.lua`): Suppress "Record already
  exists" log spam from `TweakDB:CloneRecord` / `TweakDB:CreateRecord`.
  All 5 call sites now check `TweakDB:GetRecord(name) == nil` first and
  are wrapped in `pcall`. Records are only created on first run; subsequent
  runs skip silently.

- **B-22** (`core.lua`): Fixed "Function 'IsA' context must be 'IScriptable'"
  crash in the `GameUI.Listen` callback. The phone-controller check is now
  wrapped in `pcall` so a stale controller reference during menu state
  transitions can never crash the listener.

- **B-23** (`see.lua`, `scripting.lua`): Comprehensive nil-guard pass for
  entity and group lookups. This was the biggest class of runtime errors
  during testing — mods reference entities/groups that don't exist (not
  yet spawned, already despawned, or invalid tags), and Cyberscript crashed
  the entire action list instead of skipping the bad reference.
  - Added global `safeFindEntityByID(obj)` helper that wraps
    `Game.FindEntityByID(obj.id)` in pcall and returns nil on any failure.
    Replaced **all 136 occurrences** of `Game.FindEntityByID(obj.id)` in
    `see.lua` with this helper.
  - Fixed `getTrueEntityFromManager()` to return a stub `{id=nil, tag=tag}`
    instead of crashing on `enti.tag` when the entity doesn't exist.
  - Fixed `getGroupfromManager()` to safely return nil if GroupManager
    or the group doesn't exist.
  - Replaced all 79 `group.entities` reads with
    `(group and group.entities or {})` so a nil group yields an empty
    table instead of crashing.
  - Replaced all 40 `#group.entities` length checks with
    `#(group and group.entities or {})` for the same reason.
  - Replaced both `error()` calls in `spawn_npc` with `logme()` so a bad
    character/position or missing group logs a warning and skips the
    single spawn, instead of aborting the entire action list.

### Carried over from fork.1

All 18 fixes from fork.1 are included:
- B-01 (GameTime error), B-02 (stuck menus), B-03/B-18 (refresh throttle),
  B-04/B-11 (vehicle spawn guards), B-05 (NoCombat cleanup), B-06/B-20
  (legacy F-key files moved), B-07 (garage validation), B-08 (unfreeze_player),
  B-09 (invisibility sync), B-10 (action aliases), B-12 (vehicle traffic params),
  B-13 (api diagnostic logging), B-14 (interaction aliases), B-15 (gang-info
  opt-in), B-19 (fork docs).

### Critical fix discovered during testing

- **db.sqlite3 must ship with the mod** — fork.1 mistakenly excluded
  `db.sqlite3` from the zip, causing `no such table: Characters` to crash
  `setupCore()` before `initCore()` could run. This made the entire settings
  UI disappear and cascaded into per-frame `EntityManager is nil` errors.
  fork.2 includes `db.sqlite3` (1.05 MB, 3,977 character records) and adds
  an `ensureDBReady()` guard in `db.lua` so a missing/corrupt database
  degrades gracefully instead of crashing the init chain.

- **Init-chain race conditions** — added nil guards to `refreshModVariable`
  and the vehicle-tracking block in `mainThread` so they skip silently if
  `cyberscript.EntityManager` or `arrayDistricts` aren't initialized yet,
  instead of throwing per-frame errors.

- **`nativeSettings` nil-guard** in `buildnativesetting()` — if
  `nativeSettings` isn't loaded yet (because `initCore()` hasn't run),
  the function returns gracefully instead of crashing the refresh loop.

- **`GameSession.Observe('Death')` pcall** — wrapped in pcall so it can
  never abort the init chain if the CET version doesn't support it.

- **Diagnostic logging** — added force-logged `[Cyberscript Init]` lines
  throughout the init chain so future init failures are easy to trace.

### Compatibility

Still zero breaking API changes. All fixes are defensive (pcall wrappers,
nil guards, log-and-skip instead of error-and-abort). Existing downstream
mods continue to work without modification.

---

## [5.1.5] — 2026-07-11

First bug-fix pass on top of upstream Cyberscript Core v5.1.4. Addresses
20 issues sourced from the upstream GitHub repo (`cyberscript77/release`)
and the NexusMods bugs/posts tabs (mod ID 6475).

### Critical fixes

- **B-01** (`scripting.lua`): Fixed per-tick CET error
  `Function 'Days' parameter 1 must be GameTime.` that fired every
  refresh tick and filled the log. Applied PR #19 by GoogleRa
  (attributed to Zoliquen & Gilgamesh). The buggy code referenced a
  local `gameTime` variable that was not in scope; now uses the
  already-populated `currentTime` table.

- **B-02** (`interactionUI.lua`): Fixed "cannot navigate menus in
  Cyberscript-dependent mods" (GH #20, #16; NexusMods 11-comment thread).
  Wrapped `ui.OnAction` in `pcall`; on exception, force-resets
  `hubShown` and `input` state so a thrown callback can never freeze
  the hub.

### High-severity fixes

- **B-03 / B-18** (`scripting.lua`): Throttled `refreshModVariable` to
  ~20 Hz (every 3 frames at 60 fps) instead of every frame. Cuts the
  per-tick cost ~3× and eliminates the periodic stutter reported on
  NexusMods. First call after session load always runs.

- **B-04 / B-11** (`npc.lua`): Wrapped `spawnVehicleV2` in `pcall` so
  any failure (missing dynamic-entity component, patch 2.3+ vehicle API
  change, null entity ref) is logged and recovered from instead of
  crashing the game. Mitigates the 100% CTD when quickhacking
  "Emergency Brakes" on a Cyberscript-spawned vehicle (GH #9) and the
  patch 2.3 vehicle-mount crash.

- **B-05** (`core.lua`, `interactionUI.lua`): Added `GameSession.Observe`
  listeners for `Death` and `Load` events that clear the stuck
  `GameplayRestriction.NoCombat` status effect and reset
  `interactionUI.hubShown`. Fixes "Inventory/map/phone stop working
  after Second Heart revive" (NexusMods, Reddit). Also moved the
  NoCombat clear in `ChoiceApply` to fire on every choice apply, not
  only when a callback exists.

- **B-06 / B-20** (`mod/data/legacy/`): Moved `inputUserMappings.xml`
  and `settings.lua` out of `mod/data/` into `mod/data/legacy/` with a
  README. These files were never loaded by Cyberscript Lua code but
  were mistakenly installed by users per old wiki instructions, causing
  the "F-key stops working in quickhack/dialog/exit-vehicle" bug
  (Reddit, CDPR forums).

- **B-07** (`core.lua`): Validated each `currentSave.garage` entry
  before calling `EnablePlayerVehicle`. Nil/empty paths are skipped;
  failing entries are pruned from the garage. Fixes the recurring
  "vehicle call list is empty" bug (GH #2, Reddit, CDPR forums).

- **B-09** (`npc.lua`, `core.lua`): `PlayerToggleInvisible` now calls
  `UpdateVisibility()` after `SetInvisible()` (matching the existing
  `setInvisible` helper). Added a `GameSession.OnLoad` hook that
  force-clears invisibility if the user has disabled the "infinite
  invisibility" option, so the engine's persisted invisibility flag
  cannot outlive the setting. Fixes "permanent invisibility" (GH #15).

- **B-14** (`modpack.lua`, `mod/data/legacy_interaction_aliases.json`):
  Added a backward-compatibility alias system for interactions renamed
  in v5.1.4. The new `legacy_interaction_aliases.json` file maps old
  interaction tags to new ones; Cyberscript registers each old tag as
  an alias pointing at the new tag's cached data. Purely additive —
  restores compatibility with pre-5.1.4 downstream mods.

### Medium-severity fixes

- **B-08** (`see.lua`): Fixed `unfreeze_player` action which called
  `SetTimeDilation("cyberscript", 0)` — but 0 PAUSES time instead of
  unpausing. Now calls `UnsetTimeDilation("cyberscript")` to actually
  restore normal time flow. Fixes "in-game time stops after weather/time
  change" (GH #10).

- **B-10** (`see.lua`): Added action-name aliases `player_rotate` →
  `rotate_player_camera` and `player_look_at_xyz` →
  `player_look_at_position` (the wiki documents the former names but
  the implementation only had the latter). Added optional
  `action.track = true` + `action.duration` for `player_look_at_entity`
  to continuously track a moving entity. Additive; default behavior
  unchanged.

- **B-12** (`see.lua`, `actiontemplate.json`): `vehicle_add_to_traffic`
  now reads optional `min_speed` / `max_speed` / `cleartraffic` /
  position parameters (with defaults matching the old hard-coded
  values) instead of always using `1, 5, true, 0, 0, 0`. Schema
  documented in `actiontemplate.json`.

- **B-13** (`api.lua`): Every `api.*` entry point now wraps its
  internal call in `pcall` and logs failures with context (chara, tag,
  error). Public API signatures unchanged. Helps downstream-mod
  authors debug spawn failures (GH #17).

- **B-15** (`observers/worldmap.lua`): Gated the gang-info / fixer
  world-map override behind an opt-in user setting
  `world_map_gang_info_override` (default `true` to preserve current
  fork behavior). Users / downstream mods who want the "removed" v5.1.4
  behavior can set it to `false`.

### Low-severity / process

- **B-19** (`FORK.md`, `CHANGELOG.md`): Documented the fork's merge
  strategy, version tagging scheme, and compatibility guarantees.

### Not addressed in this pass

- **B-16** (REDmod → Audioware migration, v5.0.0): Already shipped;
  documentation-only follow-up. A runtime warning in `sound.lua` when
  REDmod sound files are detected is a candidate for a future pass.
- **B-17** (Cyberware-EX conflict): Possibly already fixed in 5.1.4;
  verification requires in-game testing which is out of scope for this
  code-only pass.

### Compatibility summary

| Risk to downstream mods | Fixes | Count |
|---|---|---|
| ✅ None | B-01, B-02, B-03, B-05, B-07, B-08, B-09, B-12, B-13, B-14, B-15, B-18, B-20 | 13 |
| ✅ Restores compat | B-14, B-15 | 2 |
| ⚠️ Low (mitigated) | B-04, B-06, B-10 | 3 |
| ℹ️ Already shipped | B-16 | 1 |
| ❓ Needs in-game verify | B-17 | 1 |
| 📝 Process only | B-19 | 1 |

**Bottom line**: 0 breaking changes. All 20 issues addressed or
documented. Existing downstream mods continue to work without
modification.

---

## [5.1.4] — 2025-05-20 (upstream baseline)

Fork baseline. Bit-identical to upstream `cyberscript77/release` at
commit `6054a10`. See upstream NexusMods changelog for v5.1.4 details.
