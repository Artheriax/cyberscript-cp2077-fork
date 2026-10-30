# CyberScript extension API

Other CET mods can listen to CyberScript, add their own datapack actions and triggers, and read loaded datapack content. Everything is on `cyberscript.api`.

## Getting the API

```lua
local cs = GetMod("cyberscript")
if cs and cs.api and cs.api.apiVersion and cs.api.apiVersion >= 1 then
    -- safe to use the calls below
end
```

Check `apiVersion` so your mod still loads on CyberScript builds without this API.

## Events

```lua
local id = cs.api.on("variable", function(e)
    -- e.tag, e.key, e.old, e.new
end)
cs.api.off(id)
```

| Event | Fires | Data |
| --- | --- | --- |
| `action` | After any datapack action runs | `name`, `tag`, `source`, `executortag`, `success`, `error`, `custom` |
| `variable` | After a CyberScript variable changes value (scores, gang and faction values) | `tag`, `key`, `old`, `new` |

A listener that errors is logged and skipped; it never breaks CyberScript or other listeners.

## Custom actions and triggers

Names must contain `:` so they can never clash with built-in names.

```lua
cs.api.registerAction("netrunner:breach_node", function(action, ctx)
    -- action = the action's JSON fields, ctx = { tag, parent, index, source, executortag }
    -- return false to stop the rest of the action list
end, "MyMod")

cs.api.registerTrigger("netrunner:node_breached", function(trigger)
    return true -- or false
end, "MyMod")
```

Datapacks then use them like built-ins:

```json
{ "name": "netrunner:breach_node", "node": "maelstrom_totentanz_01" }
```

Custom triggers support the usual `expected` field. A custom action that errors goes through CyberScript's normal error path, so its `fail_action` still runs.

## Datapack content (read only)

```lua
cs.api.getContentTypes()            -- { "corpo", "faction", "webpage", ... }
cs.api.listContent("webpage")       -- { { tag = "...", datapack = "..." }, ... }
cs.api.getContent("webpage", tag)   -- { tag, data, datapack, scripttype } or nil
```

`getContent` returns a copy, so changing it doesn't change CyberScript's loaded content.
