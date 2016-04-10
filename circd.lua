#!/usr/bin/env carbon
-- CIRCd

-- Load libs
event = require("libs.event")
logger = require("libs.logger")
loader = require("libs.loader")
command = require("libs.command")
local clib = require("libs.clib")

-- Config. Yayzers.
local settings
if arg[1] then
	local src, err = fs.readfile(arg[1])
	if err then
		error(err, 0)
	end
	settings = loadstring(src, arg[1])()
else
	error("Usage: carbon circd.lua <settings.lua>", 0)
end

-- Global so every file can use it.
config = settings

-- Use it with: local settings = config

-- Listen
local sv = assert(net.listen("tcp", (config.bind or ":6667")))

-- Store stuff in KVStore
kvstore.set("circd:sv", sv)
kvstore.set("circd:servername", "circd.lua")

-- Helpers
local function send(client, txt)
	net.write(client.sock, txt.."\r\n")
end
local function close(client, reason)
	local event = require("libs.event")
	if client then
		local host = kvstore._get("circd:client:hostmask:"..client.id)
		if host then
			send(client, ":"..host.." QUIT :"..(reason or "Client Quit"))
		end
		-- ERROR :Closing Link: 127.0.0.1 (Client Quit)
		send(client, "ERROR :Closing Link: "..client.ip)
		client.sock.Close()
		event.fire("circd:disconnect", client, reason)
	end
end

-- Load init.d
logger.log("Main", logger.normal, "Loading Init files...")
local loaded, loadtime = loader.load(var.root.."/init.d/*")
logger.log("Main", logger.normal, "Loaded "..tostring(loaded).." Init Files. Took "..tostring(loadtime).."s.")

-- Main
function tpairs(tbl)
	local s={}
	local c=1
	for k,v in pairs(tbl) do
		s[c]=k
		c=c+1
	end
	c=0
	return function()
		c=c+1
		return s[c],tbl[s[c]]
	end
end

-- TODO: change id scheme
local id = 0

-- rate limits
local rate_limit_global = settings.rate_limit_global
local rate_limit_override = settings.rate_limit_override

while true do
	local cl, err=sv.Accept()
	if err then
		error(err)
	end
	id = id + 1
	local client = {
		sock = cl,
		ip = cl.RemoteAddr().String():gsub(":%d-$", ""),
		id = tostring(id),
		send = send,
		close = close,
	}
	event.force_fire("circd:newclient", client)
	thread.run(function()
		local event = require("libs.event")
		local clib = require("libs.clib")
		local buff = ""
		while true do
			local txt, err = net.read(cl, 1)
			if err then
				if err == "EOF" then
					event.fire("circd:disconnect", client, "Connection Terminated")
					break
				else
					print("client err: ".. err)
					close(client, "Error: "..err)
					event.fire("circd:disconnect", client, err)
					break
				end
			end
			local tmp = (buff .. txt)
			buff = string.gsub(tmp, "(.-)[\r\n+]", function(line)
				if line:gsub("[\r\n]", "") ~= "" then
					event.fire("circd:raw", client, line:gsub("[\r\n+]", ""):sub(1,256))
					local override
					local host = clib.gethost(client.id)
					if host then
						override = rate_limit_override[host]
					end

					-- Perfect Rate Limiting(tm)
					local time = override or rate_limit_global
					if time ~= 0 then
						os.sleep(override or rate_limit_global)
					end
				end
				return ""
			end)
		end
	end)
end
