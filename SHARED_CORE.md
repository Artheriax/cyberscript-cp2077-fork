# CyberScript shared core

The parts of Night City that several mods share, kept in CyberScript so they all agree: what one mod does, the others see. Real Netrunning runs on it, and so will the property, corporation and corporate-career mods.

It's saved with each CyberScript save (`currentSave.core`), so every save has its own world, and nothing in it moves while the game is paused.

## For CET mods

`core.version` is 2 when everything below is there (time, districts, places, routines, incidents, jobs, and people's bodies and money); 1 had only organisations, the market, news, heat, standing, money and people.

```lua
local cs = GetMod("cyberscript")
local core = cs and cs.api and (cs.api.apiVersion or 0) >= 2 and cs.api.core
```

| Part | What it does |
| --- | --- |
| `core.orgs` | Corporations, gangs and other organisations, and world regions. `get(id)`, `all(kind)`, `register({ id, name, kind, region, ... })` to add your own (or add fields to an existing one), `region(id)`. Register yours again on every load. |
| `core.market` | The stock exchange. `get(ticker)`, `forOrg(org)`, `price`, `change`, `history`, `held`, `buy(ticker, qty)`, `sell(ticker, qty or "all")`, `portfolio()`, `shock(ticker, pct, why)`, `addTip(ticker, pct, steps, headline)`, `listCompany({ ticker, name, org, price, vol, rivals })`, `delist(ticker)`. Prices step every 30 seconds of play. 25 companies are listed: every corporation, both media companies, NCPD and NetWatch. |
| `core.news` | One news feed. `add(text, { source, org })`, `list(n)`, `texts(n)`. Keeps the latest 60 stories. |
| `core.heat` | Attention V is drawing, 0 to 100, per channel (`"netwatch"`, `"ncpd"`, anything). `get`, `add`, `set`, `all`, `setDecay(channel, perMinute)`. |
| `core.standing` | How each organisation feels about V, -100 to 100. `get`, `change`, `set`, `all`, `describe(value)`. Shared with CyberScript's `Affinity` (key `faction_<org>`), so a Gangs of Night City choice and a Real Netrunning hack move the same number. |
| `core.money` | V's eddies: `get()`, `give(n)`, `take(n)` (false if V can't afford it). |
| `core.people` | Who lives in Night City. `populate(place, { count, lifestyle, job, jobs, org, home, district })` makes a place's people from the save's seed (same save, same people); `register(def)` adds hand-made characters (again on every load); `promote({ key, ... })` turns someone another mod half-knows into a full person (same key, same person). `get(id)`, `byKey(key)`, `find({ field = value })`, `all()`, `update(id, fields, why)`, `remember(id, kind, text, by)`, `history(id)`, `opinion(id)`, `changeOpinion(id, amount, why)`, `relations(id)`, `relate(a, b, kind)`, `affiliations(id)`, `isAffiliated(id, org)`, `affiliate(id, org, role, { secret }, why)`, `leave(id, org, why)`, `members(org)`, `attitude(id)`. People can belong to gangs, corporations and other organisations (openly or in secret), or to nobody. `money(id)`, `pay(id, amount, why)`, `owns(id)`. `bind(id, entity)` links a person to the NPC a mod spawned for them: the core watches it, so a death marks them dead (and reports an incident), being knocked down marks them hurt, and despawning ends the link (`unbind`, `personFor(entity)`, `entityFor(id)`). Only changes are saved. |
| `core.time` | The game's clock, the same for every mod: `now()` `{ seconds, day, hour, minute, weekday, weekdayName, night }`, `hour()`, `day()`, `weekday()`, `isNight()`, `between(from, to, hour?)` (wraps past midnight). Sleeping and skipping time count. |
| `core.districts` | The seven districts (`watson`, `westbrook`, `citycenter`, `heywood`, `santodomingo`, `pacifica`, `badlands`) with their outlines: `get`, `all`, `byTag`, `at(pos)`. Street control: `influence(id, org)`, `control(id)`, `leader(id)`, `push(id, org, amount, why)`, `set`. Kept in CyberScript's own gang district scores, so Gangs of Night City and the core see the same turf. |
| `core.places` | Locations: `register(def)` (again every load) or `add(def)` (saved), `get`, `find(query)`, `near(pos, radius, query)`, `update`, `setOwner(id, owner, why)`, `remove`, `isOpen(id, hour)`, `ownedBy(owner)`. A place: `{ id, name, kind, district, pos, owner, org, open = { from, to }, tags }`. |
| `core.routines` | Where people are at each hour: `get(id)` (a mod's, or one made from their way of life), `set(id, routine)`, `clear`, `whereIs(id, hour?, weekday?)`, `at(placeId, hour?)`, `default(person)`. A routine: `{ { from, to, activity, place = placeId or "home" or "work", days }, ... }`. |
| `core.incidents` | What happens, where, to whom and by whom: `report({ kind, text, place, district, pos, by, severity, news, people = { [id] = role } })`, `get`, `recent(n)`, `find(query)`. Everyone involved remembers it, killed and hurt people are marked, V's victims and their families think less of V (people V saves more), and an organisation behind it gains street influence. |
| `core.jobs` | Who works where: `hire(id, { org, place, job, wage }, why)`, `fire(id, why)`, `employees(orgOrPlace)`, `closePlace(placeId, why)`, `payday()`. At every in-game midnight the known people are paid and pay their living costs; anyone who runs out is marked `broke`. |

### Events

`core.on(name, fn)` returns an id for `core.off(id)`. The same events reach `cs.api.on("core.<name>", fn)`.

- `news` `{ text, source, org, time }`
- `heat` `{ channel, value, change, why }`
- `standing` `{ org, value, change, why }`
- `market.shock` `{ ticker, pct, why }`, `market.trade` `{ side, ticker, qty, price, tipped }`, `market.step` `{ clock }`, `market.listed`, `market.delisted`
- `org.registered` `{ id }`
- `people.populated` `{ place, ids }`, `people.added` `{ id, source, key }`, `people.changed` `{ id, changed, why }`, `people.event` `{ id, kind, text, by }`, `people.opinion` `{ id, value, change, why }`, `people.relation` `{ a, b, kind, why }`, `people.affiliation` `{ id, org, role, secret, joined, why }`, `people.money` `{ id, value, change, why }`, `people.bound` / `people.unbound` `{ id }`
- `time.hour` `{ day, hour }`, `time.day` `{ day, weekday }`
- `districts.influence` `{ district, org, value, change, why }`, `districts.leader` `{ district, org, old, why }`
- `places.added` `{ id }`, `places.changed` `{ id, changed, why }`, `places.owner` `{ id, owner, old, why }`, `places.removed` `{ id, why }`
- `routines.changed` `{ id, why }`
- `incidents.reported` (the whole incident)
- `jobs.hired` `{ id, org, place, job, wage, why }`, `jobs.fired` `{ id, org, place, job, why }`, `jobs.payday` `{ day, paid, broke }`

## For datapacks

Actions:

```json
{ "name": "core:add_news", "text": "Arasaka stock slides", "org": "arasaka" }
{ "name": "core:add_heat", "channel": "ncpd", "value": 10 }
{ "name": "core:set_heat", "channel": "ncpd", "value": 0 }
{ "name": "core:change_standing", "org": "militech", "value": -15 }
{ "name": "core:set_standing", "org": "militech", "value": 50 }
{ "name": "core:market_shock", "ticker": "ARA", "value": -0.08 }
{ "name": "core:give_shares", "ticker": "MIL", "value": 10 }
{ "name": "core:person_opinion", "person": "p:12", "value": -20 }
{ "name": "core:person_status", "person": "p:12", "value": "hurt" }
{ "name": "core:person_remember", "person": "p:12", "kind": "saved", "text": "V pulled them out of a fire", "by": "player" }
{ "name": "core:person_relate", "person": "p:12", "other": "p:13", "value": "friend" }
{ "name": "core:person_affiliate", "person": "p:12", "org": "tygerclaws", "value": "member", "secret": true }
{ "name": "core:person_leave", "person": "p:12", "org": "tygerclaws" }
{ "name": "core:district_push", "district": "watson", "org": "maelstrom", "value": 10 }
{ "name": "core:report_incident", "kind": "shooting", "text": "Shots fired outside Lizzie's", "place": "mymod:lizzies", "person": "p:12", "role": "hurt", "by": "maelstrom", "severity": 3, "news": true }
{ "name": "core:hire", "person": "p:12", "org": "arasaka", "place": "mymod:office", "job": "analyst", "wage": 500 }
{ "name": "core:fire", "person": "p:12" }
{ "name": "core:pay_person", "person": "p:12", "value": 200 }
{ "name": "core:place_owner", "place": "mymod:lizzies", "owner": "mox" }
```

Triggers (the usual `expected` works):

```json
{ "name": "core:heat_above", "channel": "netwatch", "value": 50 }
{ "name": "core:standing_above", "org": "arasaka", "value": 20 }
{ "name": "core:standing_below", "org": "arasaka", "value": -20 }
{ "name": "core:share_price_above", "ticker": "ARA", "value": 900 }
{ "name": "core:owns_shares", "ticker": "ARA", "value": 1 }
{ "name": "core:person_opinion_above", "person": "p:12", "value": 30 }
{ "name": "core:person_opinion_below", "person": "p:12", "value": -30 }
{ "name": "core:person_status", "person": "p:12", "value": "alive" }
{ "name": "core:person_affiliated", "person": "p:12", "org": "tygerclaws" }
{ "name": "core:person_attitude_above", "person": "p:12", "value": 20 }
{ "name": "core:time_between", "from": 22, "to": 6 }
{ "name": "core:is_night" }
{ "name": "core:district_leader", "district": "watson", "org": "maelstrom" }
{ "name": "core:influence_above", "district": "watson", "org": "maelstrom", "value": 50 }
{ "name": "core:place_owner", "place": "mymod:lizzies", "owner": "mox" }
{ "name": "core:person_at", "person": "p:12", "place": "mymod:lizzies" }
{ "name": "core:person_money_above", "person": "p:12", "value": 1000 }
```

Variables kept in step: tag `core_heat` (key = channel), tag `core_standing` (key = organisation) and tag `core_opinion` (key = person id: what they think of V).

The code is in `mod/modules/sharedcore/`.
