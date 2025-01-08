local state = require("ConfigurableStackSize.state")
local mod = {}

---@param msgId string
local function getMessage(msgId)
	return state.modName .. "." .. msgId
end

---@enum Message
local Message = {
	ServerSendConfig = getMessage("Server.SendConfig"),
	ClientRequestConfig = getMessage("Client.RequestConfig"),
}

local server = {}

-- Used Gather Resources Quickly for reference.
-- https://steamcommunity.com/sharedfiles/filedetails/?id=3337144393

---@param cfg Config
---@param client? Barotrauma.Networking.Client
function server.sendConfig(cfg, client)
	local msg = Networking.Start(Message.ServerSendConfig)
	msg.WriteString(tostring(cfg))

	Networking.Send(msg, client and client.Connection or nil) -- nil is every connected client
end

---@param getConfig fun():Config
function server.setSendConfigHandler(getConfig)
	Networking.Receive(Message.ClientRequestConfig, function(_msg, client)
		server.sendConfig(getConfig(), client)
	end)
end

local client = {}

function client.requestReceiveConfig()
	Networking.Send(Networking.Start(Message.ClientRequestConfig))
end

---@param cb fun(serializedConfig: string)
function client.setReceiveConfigHandler(cb)
	Networking.Receive(Message.ServerSendConfig, function(msg, _server)
		---@cast msg Barotrauma.Networking.IReadMessage
		cb(msg.ReadString() --[[@as string]])
	end)
end

mod.getMessage = getMessage
mod.Message = Message
mod.server = server
mod.client = client

return mod
