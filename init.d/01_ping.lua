-- Pings

-- localize config to bind to threads
local settings = config

kvstore.set("circd:settings:ping_rate", settings.ping_rate)

event.handle("circd:connect", function(cl)
	local event = require("libs.event")
	event.fire("circd:ping", cl)
end)

event.handle("circd:ping", function(cl)
	thread.run(function()
		local maxping = kvstore._get("circd:settings:ping_rate")
		local clib = require("libs.clib")

		local firstping = true
		local srvname = kvstore.get("circd:servername")

		while true do
			local pingdata
			if firstping then
				pingdata = carbon.randomstring(8)
				firstping = false
			else
				pingdata = srvname
			end

			local key = "clib:client:ping:"..cl.id..":"..pingdata
			print("ping data is "..pingdata)
			kvstore._set(key, true)
			cl:send("PING :"..pingdata)

			print("sleeping")
			os.sleep(maxping)
			print("ping or no ping?")
			local noreply = kvstore._get(key)
			print("No reply? "..tostring(noreply))
			if noreply == true then
				kvstore._del(key)
				print("didnt reply to ping in "..tostring(maxping).." seconds! Disconnecting...")
				local event = require("libs.event")
				cl:close("Ping Timeout ("..tostring(maxping).." Seconds)")
				event.fire("circd:disconnect", cl, "Ping Timeout ("..tostring(maxping).." Seconds)")
				break
			end
		end
	end)
end)

command.new("pong", function(cl, pongdata)
	pongdata = pongdata:gsub("^:", "")
	print("PONG!")
	local clib = require("libs.clib")
	local event = require("libs.event")
	if pongdata then
		print("PONG: "..pongdata)
		kvstore._del("clib:client:ping:"..cl.id..":"..pongdata)
		if not clib.isconnected(cl.id) then
			if not kvstore._get("circd:client:"..cl.id..":cap") then
				event.fire("circd:init_message", cl)
			end
		end
	end
end)

command.new("ping", function(cl, dat)
	cl:send("PONG :"..dat)
end)
