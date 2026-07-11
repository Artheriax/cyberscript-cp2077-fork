# Cyberscript CP2077 Fork — Maintenance Branch

This is the `Artheriax/cyberscript-cp2077-fork` repository, carrying a
focused bug-fix pass on top of upstream Cyberscript Core v5.1.4
(`cyberscript77/release`, commit `6054a10`).

## Relationship to upstream

| | Upstream (`cyberscript77/release`) | This fork (`Artheriax/cyberscript-cp2077-fork`) |
|---|---|---|
| Base commit | `6054a10` (v5.1.4) | `6054a10` (v5.1.4) |
| Bug-fix commits | none (single squashed release) | this patch series |
| Open issues | 7 issues + 1 open PR (#19) | 0 (fixes live here first) |
| NexusMods ID | 6475 | n/a (fork is not published on Nexus) |

The fork was created as a one-time snapshot. This bug-fix pass is the first
delta. All fixes here are designed to be **non-breaking** for downstream
mods that depend on Cyberscript — no public API signatures changed, no
interactions renamed (only additive aliases), no events removed.

## Merge strategy

- **Upstream → fork**: rebase the fork on each new upstream release.
  Conflicts expected in `scripting.lua` (large file, frequent upstream
  edits) and `interactionUI.lua`. The bug-fix markers (`-- B-XX fix`)
  make it easy to find and re-apply patches.
- **Fork → upstream**: every fix here is a candidate for an upstream PR.
  The PR #19 fix (B-01) is already open upstream and should be merged
  first. The other fixes can be cherry-picked as separate PRs.
- **Versioning**: fork releases are tagged as `5.1.7`, `5.1.8`, etc.
  When upstream cuts a new release, the fork rebases and increments
  accordingly.

## How to identify fork patches in source

Every fix is marked with a `B-XX` comment (where `XX` is the bug ID from
`research/bugs.md`) at the site of the change, e.g.:

```lua
-- B-01 fix (PR #19 by GoogleRa, attributed to Zoliquen & Gilgamesh):
-- `gameTime` was the LOCAL variable inside getGameTime() and is NOT in scope here,
-- ...
setVariable("game_time","day",  currentTime.day)
```

To see every patch applied by this pass:

```bash
grep -rn "B-[0-9]\+ fix" bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/mod/
```

## Files touched by this pass

| File | Bugs addressed |
|---|---|
| `mod/modules/scripting.lua` | B-01, B-03, B-18 |
| `mod/modules/interactionUI.lua` | B-02, B-05 (partial) |
| `mod/modules/core.lua` | B-05, B-07, B-09 |
| `mod/modules/npc.lua` | B-04, B-09, B-11 |
| `mod/modules/api.lua` | B-13 |
| `mod/modules/see.lua` | B-08, B-10, B-12 |
| `mod/modules/modpack.lua` | B-14 |
| `mod/modules/observers/worldmap.lua` | B-15 |
| `mod/data/actiontemplate.json` | B-12 (schema docs) |
| `mod/data/legacy_interaction_aliases.json` | B-14 (new file) |
| `mod/data/legacy/inputUserMappings.xml` | B-06, B-20 (moved from `mod/data/`) |
| `mod/data/legacy/settings.lua` | B-06, B-20 (moved from `mod/data/`) |
| `mod/data/legacy/README.md` | B-06, B-20 (new file) |
| `FORK.md` | B-19 (this file) |
| `CHANGELOG.md` | B-19 |

## Compatibility guarantees

Per the user's requirement, **maximum compatibility with existing mods
that depend on Cyberscript** is preserved:

1. **No public API signature changes** — `api.lua` exports the same
   functions with the same argument counts. The B-13 fix wraps each
   call in `pcall` and adds logging, but the signatures are unchanged.
2. **No interaction renames** — B-14 adds an *additive* alias system;
   existing JSON actions using current names keep working. Old names from
   pre-5.1.4 can be re-enabled by editing `legacy_interaction_aliases.json`.
3. **No events removed** — B-15 makes the gang-info world-map override
   opt-in (default `true` to preserve current fork behavior), not removed.
4. **No settings removed** — B-06/B-20 *moves* `inputUserMappings.xml`
   and `settings.lua` to `mod/data/legacy/` but does not delete them.
5. **No per-tick behavior change** — B-03/B-18 throttles
   `refreshModVariable` to ~20 Hz (every 3 frames at 60 fps), which is
   well above any reasonable polling rate for UI/script-variable reads.
6. **No new required parameters** — B-10 and B-12 add *optional*
   parameters with sensible defaults.

## Reporting bugs in this fork

Open an issue at https://github.com/Artheriax/cyberscript-cp2077-fork/issues
with:
- The bug ID from `research/bugs.md` if applicable
- The CET log (`bin/x64/plugins/cyber_engine_tweaks/mods/cyberscript/cyberscript.log`)
- Whether the issue reproduces on upstream v5.1.4 (to isolate fork-only bugs)
