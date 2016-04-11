-- channels

local pubsub = require("pubsub")
local event = require("libs.event")

pubsub.sub("event:circd:chan", function()
	local msgpack = require("msgpack")
	local logger = require("libs.logger")
	local event = require("libs.event")
	local prettify = require("prettify")
	local clib = require("libs.clib")
	local command = require("libs.command")

	function print(...)
		logger.log("circd:chan", logger.normal, prettify(...))
	end

	local recv = function()
		local src = com.receive(threadcom)
		local args
		if src then
			return unpack(msgpack.unpack(src))
		end
	end

	local chans = {}

	while true do
		-- receive command
		local cmd, id, chan, arg = recv()

		if chan then
			chan = chan:gsub("%s+", "")
		end

		if cmd == "join" then -- join channel
			chans[chan] = chans[chan] or {}
			kvstore._set("circd:chan:exists:"..chan, true)
			chans[chan][id] = arg or ""
			local host = clib.gethost(id)
			if host then
				local msg = ":"..host.." JOIN "..chan
				for u_id, _ in pairs(chans[chan]) do
					--if u_id ~= id then
						local client = clib.getclient(u_id)
						clib.send(client, msg)
					--end
				end
				local client = clib.getclient(id)
				command.run("names", client, chan)
				event.fire("circd:chan:join", id, chan)
			end
		elseif cmd == "mode" then -- update mode
			chans[chan] = chans[chan] or {}
			chans[chan][id] = arg
		elseif cmd == "part" then -- leave channel
			chans[chan] = chans[chan] or {}
			chans[chan][id] = nil
			local msg = ":"..clib.gethost(id).." PART "..chan .. " :" .. (arg or "User left the channel.")
			local users = 0
			for u_id, _ in pairs(chans[chan]) do
				--if u_id ~= id then
					local client = clib.getclient(u_id)
					clib.send(client, msg)
					users = users + 1
				---end
			end
			if users <= 1 then
				chans[chan] = nil
				kvstore._del("circd:chan:exists:"..chan)
			end
			event.fire("circd:chan:part", id, chan, (arg or "User left the channel."))
		elseif cmd == "quit" then -- quit irc
			local to_clients = {}
			for name, users_chan in pairs(chans) do
				if users_chan[id] then
					chans[name][id] = nil
					local users = 0
					for u_id, _ in pairs(users_chan) do
						to_clients[u_id] = true
						users = users + 1
					end
					if users == 0 then
						chans[name] = nil
						kvstore._del("circd:chan:exists:"..name)
					end
				end
			end
			for u_id, _ in pairs(to_clients) do
				local client = clib.getclient(u_id)
				clib.send(client, ":"..clib.gethost(id).." QUIT :"..(arg or "Client Quit"))
			end
			clib.deleteuser(id)
			event.fire("circd:quit", id, (arg or "Client Quit"))
		elseif cmd == "send" then -- send to channel
			for u_id, _ in pairs(chans[chan] or {}) do
				if u_id ~= id then
					local client = clib.getclient(u_id)
					clib.send(client, arg)
				end
			end
		elseif cmd == "getusers" then -- get channels list of users
			com.send(arg, msgpack.pack(chans[chan]))
		elseif cmd == "getchannels" then -- get users list of channels
			local res = {}
			for chan_name, members in pairs(chans) do
				if members[id] then
					table.insert(res, chan_name)
				end
			end
			com.send(arg, msgpack.pack(res))
		else
			print("Unknown command: "..cmd)
		end
	end
end)

-- events
event.handle("circd:disconnect", function(client, err) -- ded
	local event = require("libs.event")
	event.fire("circd:chan", "quit", client.id, nil, err)
end)

event.handle("circd:chan:join", function(id, chan) -- topic
	local clib = require("libs.clib")
	local nick = clib.getnick(id)
	local topic = clib.gettopic(chan)
	if topic then
		clib.srvmsg(332, nick, chan, ":"..topic)
	end
end)

-- Commands
command.new("join", function(client, chan)
	local clib = require("libs.clib")
	if not chan then
		return 461, "JOIN", "Not enough parameters"
	end
	for word in string.gmatch(chan, '([^,]+)') do
		if word:match("^#[%w%d]*$") then
			if not clib.in_channel(chan, id) then
				clib.join_chan(client.id, word)
			end
		else
			return 403, chan, "No such channel"
		end
	end
end)

command.new("part",function(client, chan, reason)
	local clib = require("libs.clib")
	if not chan then
		return 461, "JOIN", "Not enough parameters"
	end
	if clib.in_channel(chan, client.id) then
		clib.part_chan(client.id, chan, reason)
	end
end)

command.new("privmsg", function(cl, to, msg)
	local clib = require("libs.clib")
	local nick = clib.getnick(cl.id)
	if not to then
		return 411, nick, "No recipient given (PRIVMSG)"
	end
	if not msg then
		return 412, nick, "No text to send"
	end
	if not clib.privmsg(cl.id, to, msg) then
		return 401, chan, "No such nick/channel"
	end
end)

command.new("notice", function(cl, to, msg)
	local clib = require("libs.clib")
	local nick = clib.getnick(cl.id)
	if not (to or msg) then
		return
	end
	if not clib.privmsg(cl.id, to, msg) then
		return 401, chan, "No such nick/channel"
	end
end)

command.new("names", function(cl, chan)
	print("names")
	if not chan then
		return 461, "NAMES", "Not enough parameters"
	end
	local clib = require("libs.clib")
	local nick = clib.getnick(cl.id)
	local users = clib.list_users(chan)
	if users then
		local ids = {}
		for id, mode in pairs(users) do
			print(id)
			table.insert(ids, id)
		end
		for l1=1, #ids, 50 do
			local o = {}
			for l2=l1, l1+49 do
				local id = ids[l2]
				if id then
					table.insert(o, (users[id] or "")..clib.getnick(id))
				end
			end
			clib.srvmsg(cl, 353, nick, "@", chan, ":"..table.concat(o, " "))
		end
	end
	clib.srvmsg(cl, 366, nick, chan, ":End of /NAMES list.")
end)
