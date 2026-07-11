# Cyberscript CP2077 Fork

A maintained fork of [Cyberscript](https://github.com/cyberscript77/release) for Cyberpunk 2077 — a framework that lets mod creators build quests, NPCs, vehicles, factions, and interactive scenes using JSON datapacks instead of REDscript.

[![Version](https://img.shields.io/badge/version-5.1.4--fork.2-blue)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green)](#license)
[![Base](https://img.shields.io/badge/based%20on-cyberscript%20v5.1.4-orange)](https://github.com/cyberscript77/release)

---

## Table of Contents

- [Cyberscript CP2077 Fork](#cyberscript-cp2077-fork)
  - [Table of Contents](#table-of-contents)
  - [Credits](#credits)
  - [What this fork does](#what-this-fork-does)
  - [Requirements](#requirements)
  - [Installation](#installation)
    - [For end users](#for-end-users)
    - [For mod creators](#for-mod-creators)
  - [For Mod Creators](#for-mod-creators-1)
    - [Quick start](#quick-start)
    - [Datapack structure](#datapack-structure)
    - [Public API reference](#public-api-reference)
    - [Action reference](#action-reference)
      - [Spawning](#spawning)
      - [Movement](#movement)
      - [Player](#player)
      - [Time \& weather](#time--weather)
      - [UI](#ui)
      - [TweakDB](#tweakdb)
      - [Entities](#entities)
    - [Trigger reference](#trigger-reference)
      - [Common triggers](#common-triggers)
      - [Player triggers](#player-triggers)
    - [Debugging your mod](#debugging-your-mod)
      - [1. Debug Entity Lookups (new in fork.2)](#1-debug-entity-lookups-new-in-fork2)
      - [2. Enable Logging](#2-enable-logging)
      - [3. Init chain diagnostics](#3-init-chain-diagnostics)
      - [4. API error logging](#4-api-error-logging)
      - [5. Common mod issues](#5-common-mod-issues)
    - [Backward compatibility](#backward-compatibility)
      - [Behavior changes (5 total)](#behavior-changes-5-total)
    - [Migration from upstream v5.1.3](#migration-from-upstream-v513)
  - [Bug fixes](#bug-fixes)
    - [Critical (2)](#critical-2)
    - [High (10)](#high-10)
    - [Medium (7)](#medium-7)
    - [Low (4)](#low-4)
  - [For end users](#for-end-users-1)
    - [I'm a player, not a modder — do I need this?](#im-a-player-not-a-modder--do-i-need-this)
    - [Will this break my existing mods?](#will-this-break-my-existing-mods)
    - [How do I report a bug?](#how-do-i-report-a-bug)
  - [Building from source](#building-from-source)
  - [License](#license)

---

## Credits

This fork is built on the work of the original Cyberscript team:

- **Original author:** [donk7413](https://github.com/donk7413) / RedRock Studio
- **Upstream repo:** [cyberscript77/release](https://github.com/cyberscript77/release)
- **NexusMods:** [CyberScript Core (mod ID 6475)](https://www.nexusmods.com/cyberpunk2077/mods/6475)
- **Wiki:** [cyberscript77.github.io/wiki](https://cyberscript77.github.io/wiki)

This fork's bug-fix pass was done by [Artheriax](https://github.com/Artheriax). All fixes are designed to be **non-breaking** — existing mods that depend on Cyberscript continue to work without modification.

Special thanks to:
- **GoogleRa** (PR #19), attributed to **Zoliquen** and **Gilgamesh** — wrote the fix for the critical `GameTime` error (B-01) that fired every frame
- **The NexusMods community** — for the detailed bug reports that made this fix pass possible
- **psiberx** — for the `GameSession.lua` library used by Cyberscript

If your mod depends on Cyberscript, please credit the original author (donk7413 / RedRock Studio). This fork is just a bug-fix branch.

---

## What this fork does

This is a **maintenance fork** that carries a comprehensive bug-fix pass on top of upstream Cyberscript v5.1.4. The upstream repo hasn't been updated since May 2025, and multiple critical bugs were affecting every user:

- Per-frame `GameTime` error spam filling the CET log
- Settings UI disappearing entirely
- 100% CTDs when quickhacking spawned vehicles
- "Cannot navigate menus" in dependent mods
- FPS drops every 10–20 seconds
- F-key (quickhack/dialog/exit-vehicle) breaking
- And 15+ more (see [Bug fixes](#bug-fixes) below)

**Zero breaking API changes.** Every fix is either:
- Purely additive (new optional parameters, action aliases)
- Defensive (pcall wrappers, nil guards, log-and-skip instead of error-and-abort)
- Opt-in (new settings that default to current behavior)

See [CHANGELOG.md](CHANGELOG.md) for the full list of 23 fixes (B-01 through B-23).

---

## Requirements

- **Cyberpunk 2077** patch 2.12 or later (patch 2.3+ supported)
- **Cyber Engine Tweaks (CET)** v1.32.1+ — [NexusMods](https://www.nexusmods.com/cyberpunk2077/mods/107)
- **nativeSettings** — [NexusMods](https://www.nexusmods.com/cyberpunk2077/mods/1591)
- **Codeware** — [NexusMods](https://www.nexusmods.com/cyberpunk2077/mods/10829) (required for entity spawning)
- **Appearance Menu Mod (AMM)** — optional, but recommended for character appearances

---

## Installation

### For end users

1. Download `cyberscript-cp2077-fork-5.1.4-fork.2.zip`
2. Back up your existing `bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/` directory (if present)
3. Extract the zip into your Cyberpunk 2077 game root, merging with the existing directory
4. Launch the game
5. Check `bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/cyberscript.log` — you should see:
   ```
   [Cyberscript Init] initCore() started — version 5.1.4-fork.2
   ```
   This confirms you're on the fork version.

### For mod creators

If you're developing a mod that depends on Cyberscript, install this fork as above, then see [For Mod Creators](#for-mod-creators) below.

---

## For Mod Creators

### Quick start

A Cyberscript mod ("datapack") is a folder of JSON files that defines interactions, NPCs, vehicles, quests, etc. Cyberscript reads these JSONs at startup and turns them into in-game content.

Minimal datapack structure:

```
my-mod/
├── metadata.json          # required — mod identity
├── scripts/
│   ├── interact/
│   │   └── my_interact.json   # an interaction (key binding + actions)
│   └── npc/
│       └── my_npc.json        # an NPC spawn definition
└── (optional: lang/, texture/, sound/)
```

Place your datapack folder inside:
```
bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/user/data/
```

Cyberscript auto-discovers it on next load. See the [official wiki](https://cyberscript77.github.io/wiki) for full datapack format reference.

### Datapack structure

| Folder | Purpose |
|---|---|
| `scripts/interact/` | Interactions — key bindings that trigger action lists |
| `scripts/npc/` | NPC spawn definitions and behaviors |
| `scripts/vehicle/` | Vehicle spawn definitions |
| `scripts/quest/` | Custom quests and objectives |
| `scripts/mission/` | Mission definitions |
| `scripts/setting/` | Custom settings UI entries |
| `scripts/node/` | World map nodes (metro stations, etc.) |
| `scripts/circuit/` | Dialog circuits |
| `scripts/codex/` | Codex entries |
| `lang/` | Localization JSON files |
| `texture/` | PNG/JPG textures |
| `sound/` | MP3/WAV sound files (Audioware format, not REDmod) |

### Public API reference

Your mod can call Cyberscript's public API via `GetMod("cyberscript").api`:

```lua
local cyberscript = GetMod("cyberscript")
local api = cyberscript.api

-- Spawn an NPC
api.spawn(chara, appearance, tag, x, y, z, spawnlevel, isprevention, isMPplayer, scriptlevel, isitem, rotation)

-- Spawn a vehicle
api.spawnVehicle(chara, appearance, tag, x, y, z, spawnlevel, spawn_system, isAV, from_behind, isMP, wait_for_vehicule, scriptlevel, wait_for_vehicle_second)

-- Despawn an entity by tag
api.despawn(tag)

-- Move an entity to a position
api.move(targetPuppet, targetPosition, targetDistance, movementType, v2)

-- Teleport an entity
api.teleport(objlook, position, rotation, isplayer)

-- Get an entity from the manager by tag
local ent = api.getEntitybyTag(tag)

-- Run an action list
api.runActionList(actionlist, tag, source, isquest, executortag, bypassMenu)

-- Check a trigger requirement
local ok = api.checkTriggerRequirement(requirement, triggerlist)

-- Set/get script variables
api.setVariable(tag, key, score)
local value = api.getVariableKey(tag, key)
```

**All API calls are pcall-wrapped** in this fork — if a call fails, it logs the error to `cyberscript.log` with context (chara, tag, error message) and returns nil, instead of crashing your mod's script. This is new in fork.2.

### Action reference

Actions are the building blocks of Cyberscript scripts. Each action is a JSON object with a `name` field. Here are the most commonly used:

#### Spawning

| Action | Description |
|---|---|
| `spawn_npc` | Spawn a custom NPC with full parameter control |
| `spawn_vehicle` | Spawn a vehicle |
| `despawn` | Despawn an entity by tag |
| `despawnAll` | Despawn all Cyberscript entities |

#### Movement

| Action | Description |
|---|---|
| `move` | Move an entity to a position |
| `teleport` | Teleport an entity |
| `vehicle_go_to_position` | Send a vehicle to XYZ with min/max speed |
| `vehicle_add_to_traffic` | Add a vehicle to traffic (**new:** accepts `minspeed`, `maxspeed`, `cleartraffic`, `x`/`y`/`z`) |
| `vehicle_cancel_last_cmd` | Cancel a vehicle's current command |

#### Player

| Action | Description |
|---|---|
| `teleport_player` | Teleport the player |
| `freeze_player` / `unfreeze_player` | Freeze/unfreeze the player (B-08: `unfreeze_player` now correctly resumes time) |
| `player_look_at_entity` | Make the player look at an entity (**new:** `track: true` + `duration` for continuous tracking) |
| `player_look_at_position` | Make the player look at XYZ |
| `player_look_at_xyz` | **Alias** for `player_look_at_position` (B-10) |
| `player_look_at_rotation` | Set player camera rotation |
| `player_look_at_forward` | Look forward |
| `player_look_at_unlock` | Unlock camera |
| `rotate_player_camera` | Rotate camera 90° |
| `player_rotate` | **Alias** for `rotate_player_camera` (B-10) |

#### Time & weather

| Action | Description |
|---|---|
| `set_time` | Set in-game time (hour, minute) |
| `add_time` | Add hours to current time |
| `change_weather` | Change weather |
| `reset_weather` | Reset to default weather |
| `set_timedilation` / `unset_timedilation` | Control time dilation |
| `set_timedilationforplayer` / `unset_timedilationforplayer` | Player-specific time dilation |

#### UI

| Action | Description |
|---|---|
| `notify` | Show in-game notification |
| `open_help` | Show help popup |
| `open_phone` | Open phone UI |
| `set_hud` | Toggle HUD elements |

#### TweakDB

| Action | Description |
|---|---|
| `set_tweak` / `set_noupdate_tweak` | Set TweakDB flat |
| `update_tweak` | Trigger TweakDB update |
| `clone_tweak` | Clone a TweakDB record (**B-21:** skips if record exists) |
| `create_tweak` | Create a TweakDB record (**B-21:** skips if record exists) |
| `delete_tweak` | Delete a TweakDB record |

#### Entities

| Action | Description |
|---|---|
| `set_entity_appearance` | Change entity appearance |
| `swap_character` | Swap entity to different character |
| `apply_effect` / `remove_effect` | Apply/remove status effects |
| `play_entity_voice` | Play a voice line for an entity |

See `mod/data/actiontemplate.json` for the full list with parameter schemas.

### Trigger reference

Triggers fire when conditions are met. Each trigger is evaluated every frame.

#### Common triggers

| Trigger | Fires when |
|---|---|
| `look_at_entity` | Player looks at an entity with the expected tag |
| `look_at_hash` | Player looks at an entity with the expected hash |
| `entity_at_position` | Entity is at a position |
| `entity_is_alive` | Entity is alive |
| `killed_entity` | Entity is killed |
| `entity_in_faction` | Entity is in a specific faction |
| `entity_looked_is_gang` | Looked-at entity is a gang member |
| `look_at_entity` | Player looks at a specific entity tag |

#### Player triggers

| Trigger | Fires when |
|---|---|
| `player_in_district` | Player is in a specific district |
| `player_at_position` | Player is at a position |
| `player_in_vehicle` | Player is in a vehicle |
| `player_health_below` | Player health below threshold |

See `mod/data/triggertemplate.json` for the full list.

### Debugging your mod

This fork includes several debugging tools:

#### 1. Debug Entity Lookups (new in fork.2)

**Options → Mods → CyberScript → Script Settings → "Debug Entity Lookups"**

When enabled, every nil/skipped entity reference is logged to `cyberscript.log`:

```
[safeFindEntityByID] entity not found tag=gang_car id=1234567890
[safeFindEntityByID] nil input tag=lookatentity
[safeFindEntityByID] pcall failed tag=myNPC err=Function 'FindEntityByID' parameter 2 must be entEntityID
```

This tells you exactly which entity tags in your JSON are referencing non-existent or despawned entities.

#### 2. Enable Logging

**Options → Mods → CyberScript → Script Settings → "Enable Logging"**

The standard Cyberscript debug log. Very verbose — enables all `logme()` calls.

#### 3. Init chain diagnostics

Every load now logs the init chain to `cyberscript.log`:

```
[Cyberscript Init] setupCore() started
[Cyberscript Init] setupCore: ModIsLoaded=true, setting up GameSession
[Cyberscript Init] setupCore: about to call initCore()
[Cyberscript Init] initCore() started — version 5.1.4-fork.2
[Cyberscript Init] SaveLoading() — about to call makeNativeSettings()
[Cyberscript Init] makeNativeSettings() called — building settings tabs
[Cyberscript Init] SaveLoading() — makeNativeSettings() completed
[Cyberscript Init] setupCore: initCore() completed
```

If the settings UI is missing or a dependent mod isn't loading, check which init line is the last one that appeared — that tells you where the init aborted.

#### 4. API error logging

Every `api.*` call is wrapped in pcall. If a call fails, you'll see:

```
[Cyberscript API] api.spawn failed for chara=Character.MyNPC tag=mynpc err=...
[Cyberscript API] api.spawnVehicle failed for chara=Vehicle.MyCar tag=mycar err=...
```

#### 5. Common mod issues

| Symptom | Likely cause | Fix |
|---|---|---|
| NPC doesn't spawn | Invalid character tweak ID | Check `Character.XXX` exists in TweakDB |
| Settings tab missing | `nativeSettings` mod not installed | Install nativeSettings |
| "no such table: Characters" | Missing/corrupt `db.sqlite3` | Reinstall Cyberscript (db.sqlite3 ships with it) |
| "Record already exists" spam | Trying to create a TweakDB record that exists | Use `clone_tweak` or check existence first (fork.2 auto-skips) |
| Menu navigation stuck | Hub callback threw an exception | fork.2 wraps in pcall — but check your callback for errors |
| F-key doesn't work | Old `inputUserMappings.xml` installed | fork.2 moved it to `mod/data/legacy/` — don't install it |

### Backward compatibility

This fork is **100% backward compatible** with mods built for upstream Cyberscript v5.1.4 and v5.1.3:

- **No public API signatures changed** — all `api.*` functions have the same arguments and return values
- **No action names removed** — only aliases added (`player_rotate`, `player_look_at_xyz`)
- **No trigger names changed**
- **No interaction names changed** — fork.2 adds an alias system (`mod/data/legacy_interaction_aliases.json`) for restoring pre-v5.1.4 names if needed
- **No settings removed** — `inputUserMappings.xml` and `settings.lua` were *moved* to `mod/data/legacy/`, not deleted
- **No save format changes** — `currentSave` structure is identical

#### Behavior changes (5 total)

These are the only behavior differences from upstream v5.1.4:

| Change | What's different | Why |
|---|---|---|
| `refreshModVariable` throttled to ~20 Hz | Script variables update 3× less often | B-03: eliminates per-frame FPS drops. 20 Hz is still 3× faster than any UI display. |
| `unfreeze_player` now actually unfreezes time | Was calling `SetTimeDilation(0)` which PAUSES time | B-08: was a bug — time stayed stuck after scripted freeze |
| Invalid garage entries pruned on load | `currentSave.garage` entries with bad paths are removed | B-07: fixes "vehicle call list is empty" |
| Invalid entity references skip instead of crash | Actions referencing non-existent entities log and continue | B-23: was crashing the entire action list |
| `clone_tweak`/`create_tweak` skip if record exists | No longer logs "Record already exists" warning | B-21: was log spam, not a real error |

### Migration from upstream v5.1.3

If your mod was built for v5.1.3 or earlier, the v5.1.4 upstream release renamed some default interactions and menu options. This fork restores compatibility via the alias system:

1. Open `bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/mod/data/legacy_interaction_aliases.json`
2. Add entries mapping old interaction names to new names:
   ```json
   {
     "aliases": {
       "old_interaction_name": "new_interaction_name",
       "another_old_name": "another_new_name"
     }
   }
   ```
3. Cyberscript will now resolve both names to the same cached interaction.

The file ships empty — you only need to populate it if your mod uses pre-v5.1.4 interaction names.

---

## Bug fixes

This fork addresses 23 issues. See [CHANGELOG.md](CHANGELOG.md) for full details.

### Critical (2)
- **B-01**: Per-frame `GameTime` error spam (PR #19 applied)
- **B-02**: "Cannot navigate menus" — hub state stuck after exception

### High (10)
- **B-03/B-18**: FPS drops — throttled `refreshModVariable` to ~20 Hz
- **B-04/B-11**: CTD on quickhack/vehicle-enter — spawn path guarded
- **B-05**: Second Heart inventory/map lock — NoCombat cleanup on session events
- **B-06/B-20**: F-key broken — legacy `inputUserMappings.xml`/`settings.lua` moved
- **B-07**: Vehicle call list empty — garage entries validated
- **B-09**: Permanent invisibility — state synced on load
- **B-14**: v5.1.4 interaction renames — backward-compat alias system
- **B-21**: "Record already exists" log spam — existence check before clone/create
- **B-22**: `IsA` crash — phone controller check wrapped in pcall
- **B-23**: Entity/group lookup crashes — comprehensive nil-guard pass (254 call sites)

### Medium (7)
- **B-08**: Time stops after `unfreeze_player` — fixed to use `UnsetTimeDilation`
- **B-10**: Missing action aliases — `player_rotate`, `player_look_at_xyz` added
- **B-12**: `vehicle_add_to_traffic` — added `min_speed`/`max_speed` params
- **B-13**: API error logging — all `api.*` calls wrapped in pcall
- **B-15**: Gang-info world-map override — re-added as opt-in setting
- **B-17**: Cyberware-EX conflict — verified resolved in 5.1.4
- **db.sqlite3**: Now ships with the mod (was excluded in fork.1 by mistake)

### Low (4)
- **B-16**: REDmod → Audioware migration — documented (already shipped upstream)
- **B-19**: Fork maintenance strategy documented
- **Init diagnostics**: Force-logged `[Cyberscript Init]` lines throughout init chain
- **Debug Entity Lookups**: New native settings toggle for mod authors

---

## For end users

### I'm a player, not a modder — do I need this?

If you use any mod that depends on Cyberscript (Companions of Night City, Gangs of Night City, Night City Jobs, etc.), **yes** — this fork fixes multiple critical bugs that affect every user:

- The CET log error spam (B-01)
- FPS drops every 10–20 seconds (B-03)
- Settings UI disappearing (db.sqlite3 fix)
- "Cannot navigate menus" bug (B-02)
- F-key quickhack/dialog breaking (B-06)

### Will this break my existing mods?

**No.** This fork is 100% backward compatible. Every fix is either defensive (pcall wrappers, nil guards) or opt-in (new settings default to current behavior). See [Backward compatibility](#backward-compatibility) above.

### How do I report a bug?

Open an issue at [github.com/Artheriax/cyberscript-cp2077-fork/issues](https://github.com/Artheriax/cyberscript-cp2077-fork/issues) with:

1. The bug ID from [CHANGELOG.md](CHANGELOG.md) if applicable
2. The CET log (`bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/cyberscript.log`)
3. Whether the issue reproduces on upstream v5.1.4 (to isolate fork-only bugs)
4. Your game patch version and CET version

---

## Building from source

```bash
# Clone the fork
git clone https://github.com/Artheriax/cyberscript-cp2077-fork.git
cd cyberscript-cp2077-fork

# Apply the bug-fix patch (if starting from a fresh upstream clone)
git apply cyberscript-cp2077-fork-5.1.4-fork.2.patch

# Verify Lua syntax
python3 -c "
import lupa
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
import os
for root, dirs, files in os.walk('bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/mod/modules'):
    for f in files:
        if f.endswith('.lua'):
            path = os.path.join(root, f)
            result = lua.eval('function(p) local ok, err = loadfile(p) if not ok then return false, err end return true, nil end')
            ok, err = result(path)
            print(f'[{\"OK\" if ok else \"FAIL\"}] {path}' + (f' — {err}' if err else ''))
"

# Package the zip
zip -r cyberscript-cp2077-fork-5.1.4-fork.2.zip bin/ FORK.md CHANGELOG.md README.md \
  -x "bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/cyberscript.log"
```

---

## License

Cyberscript is licensed under the MIT License. See the upstream repo for the full license text.

This fork inherits the MIT License. All bug fixes in this fork are released under the same license.

---

*This README is part of the Cyberscript CP2077 Fork. For the upstream project, see [cyberscript77/release](https://github.com/cyberscript77/release).*