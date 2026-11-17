# +1 Car Evolution

Roblox car simulator built with Rojo, Luau and Claude Code. Inspired by "+1 Car Escape", with our own original designs and assets only.

## Pitch
Train Horsepower on pads, level up and watch your car evolve. Click or press Space to build a road out over the valley and steer it with your camera. Earn Wins, spend them, and rebirth later.

## Vibe
Bright, chunky, outdoor toy-brick look: a studded two-tone green field ringed by blocky hills and pines, big outlined Fredoka text, flat gradient buttons with thin dark outlines.

## Map (built in code by `src/server/Map.luau`)
- Studded green field (240 x 240) with a cliff along the front edge looking over a valley.
- Blue checkered launch pad in the middle ("Build a Road!").
- Six training pads down the right side (Starter x1 up to Ultra x40, placeholder tiers).
- Shop stall, three leaderboards at the middle of the back, worlds portal angled into the back-left corner.
- See-through Stage walls near the cliff edge that you can walk through; each shows its name and required level (Config.Stages, placeholder levels).

## HUD (`src/client/Controllers/Hud.luau`)
Wins pill, Index/Rebirth/Trails/Daily buttons, tutorial card with a "Click! 0/3" hint that counts real clicks, x2 Wins / x2 Horsepower / Fast Training passes, Horsepower level bar and +HP product buttons. Index isn't built yet (it says "coming soon").

## Daily rewards
The Daily button (red dot when a gift is ready) opens a 7-day streak: one gift a day, better each day, a big one on day 7, then round again. New days start at midnight UTC; missing a day starts again at day 1. Gifts are Wins (scaled to the stage your level is recommended for), minutes of Horsepower on your best treadmill, and 15-minute personal x2 Wins / x2 Horsepower boosts (timer pills beside Wins). Numbers are in Config.Daily. Test with DevTools: `Set("DailyLast", os.time() // 86400 - 1)` makes today's gift continue the streak.

## Code layout
- `src/shared`: Config (every number), Format (1.2K, 3.4M...), EquipmentLooks.
- `src/server`: Main boots Map, Game, Data. Game holds clicks (crits rolled on the server). Data saves with session locking.
- `src/client`: Main starts the Hud controller. Ui has shared styles; Icons draws our own icons from UI shapes.
- The server owns all values. Clients read them from Player attributes and only send requests.
- Leftovers from the old clicker (Course, Farm, Farms, gates) are switched off until the road system replaces them.

## Testing
- Rojo: `rojo serve --port 34873` (34872 is Steal a Present's). Use the Edit tool, not `sed -i`, while Rojo is running: its temp files crash Rojo.
- DevTools (Studio only, during a playtest): `game.ServerStorage.DevTools:Invoke("Set", "Wins", 1000)`.

## Not built yet
The player as a car, road building, working training pads, levels and evolution, rebirths, working buttons, Robux passes and products, car names.
