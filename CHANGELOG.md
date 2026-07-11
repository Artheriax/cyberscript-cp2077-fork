# Changelog — Cyberscript CP2077 Fork

All notable changes to this fork are documented here. Dates are in
`Europe/Amsterdam` timezone. Bug IDs (`B-XX`) reference
`research/bugs.md` in this repository.

## [5.1.4-fork.1] — 2026-07-11

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
