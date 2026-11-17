-- Starts every client system. The client only shows things and sends requests;
-- the server decides everything.
-- (The Course and Farm controllers are switched off while the road system replaces them.)
local Controllers = script.Parent:WaitForChild("Controllers")

for _, name in { "Hud", "Cars", "Movers", "Treadmills", "Cans", "ChatTags", "Admin", "Settings" } do
	task.spawn(require, Controllers:WaitForChild(name))
end

