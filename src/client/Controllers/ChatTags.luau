-- Gold tags before names in chat: [DEV] for admins and the owner, [VIP] for VIP pass owners.
-- The server sets the player's Dev and Vip attributes, so every client sees the same tags.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local DEV_TAG = '<font color="#FFC82D">[DEV]</font> '
local VIP_TAG = '<font color="#FFC82D">[VIP]</font> '

TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local speaker = source and Players:GetPlayerByUserId(source.UserId)
	if speaker then
		local tags = ""
		if speaker:GetAttribute("Dev") then
			tags ..= DEV_TAG
		end
		if speaker:GetAttribute("Vip") then
			tags ..= VIP_TAG
		end
		if tags ~= "" then
			props.PrefixText = tags .. message.PrefixText
		end
	end
	return props
end

return nil
