-- Starts every server system in order. All game logic lives in the modules beside this.
-- (Farms and the old gate course are switched off while the road system replaces them.)
local Map = require(script.Parent.Map)
local Data = require(script.Parent.Data)
local Game = require(script.Parent.Game)

Map.build()
Game.start()
Data.start()
