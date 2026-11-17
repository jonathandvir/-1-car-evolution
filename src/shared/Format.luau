-- Short big numbers: 1.25K, 3.4M, 7.1Qa...
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

function Format.short(n)
	n = math.floor(n or 0)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local tier = math.min(math.floor(math.log10(math.abs(n)) / 3), #SUFFIXES - 1)
	local value = n / 10 ^ (tier * 3)
	local text = if value >= 100 then string.format("%d", value) elseif value >= 10 then string.format("%.1f", value) else string.format("%.2f", value)
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "") -- 1.50K -> 1.5K, 2.00K -> 2K, but 150K stays 150K
	end
	return text .. SUFFIXES[tier + 1]
end

return Format
