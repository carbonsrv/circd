-- clib
local clib = {}
local event = require("libs.event")
local msgpack = require("msgpack")

----
--- client Helpers
----

-- Get stored data
function clib.getclient(id) -- get client assigned to id
	local client = msgpack.unpack(kvstore._get("circd:client:"..id))
	client.sock = clib.getsock(id)
	return client
end
function clib.getsock(id) -- get client assigned to id
	return kvstore._get("circd:client:sock:"..id)
end
function clib.isconnected(id) -- get connection status
	return kvstore._get("circd:client:connected:"..id)
end
function clib.getnick(id) -- get nick
	return kvstore._get("circd:client:nick:"..id)
end
function clib.getuser(id) -- get username
	return kvstore._get("circd:client:username:"..id)
end
function clib.getreal(id) -- set realname
	return kvstore._get("circd:client:realname:"..id)
end
function clib.gethost(id) -- get hostmask
	return kvstore._get("circd:client:hostmask:"..id)
end

-- Set stored data
function clib.setclient(id, client, nosock) -- set client behind id
	if not nosock then
		clib.setsock(id, client.sock)
	end
	kvstore._set("circd:client:"..id, msgpack.pack(client))
end
function clib.setsock(id, sock) -- set client behind id
	kvstore._set("circd:client:sock:"..id, sock)
end

function clib.setid(nick, id) -- set id assigned to nick
	kvstore._set("circd:client:id:"..nick, id)
end
function clib.setconnected(id, connected) -- set connection status
	kvstore._set("circd:client:connected:"..id, connected)
end
function clib.setnick(id, nick) -- setnickname
	kvstore._set("circd:client:nick:"..id, nick)
end
function clib.setuser(id, user) -- set username
	kvstore._set("circd:client:username:"..id, user)
end
function clib.setreal(id, real) -- set realname
	kvstore._set("circd:client:realname:"..id, real)
end
function clib.sethost(id, host) -- set hostmask
	kvstore._set("circd:client:hostmask:"..id, host)
end

-- disconnect
function clib.deleteuser(id, nick) -- delete user data, when disconnected and such
	if not nick then
		nick = clib.getnick(id)
	end
	kvstore.del("circd:client:nick:"..id)
	kvstore.del("circd:client:username:"..id)
	kvstore.del("circd:client:realname:"..id)
	kvstore.del("circd:client:hostmask:"..id)
	kvstore.del("circd:client:connected:"..id)
	if nick then
		kvstore.del("circd:client:id:"..nick)
	end
end

----
--- Checks
----

function clib.nick_used(nick) -- check if nick is used
	return kvstore.get("circd:client:id:"..nick) ~= nil
end
function clib.is_command(cmd)
	return kvstore._get("circd:command:is_registered:"..cmd) == true
end

----
--- Send
----

function clib.send(client, msg) -- send message to client
	net.write(client.sock, msg.."\r\n")
end
function clib.srvmsg(client, code, ...) -- server message, encoding it properly
	local id
	if type(client) == "table" then
		id = client.id
	else
		id = client
	end

	if not code then
		error("No code given!")
	end

	local p = {...}
	if (p[#p] or ""):match("%s") then
		p[#p] = ":"..p[#p]:gsub("^:?", "")
	end

	if type(code) == "number" then
		code = tostring(code)
		code = ("0"):rep(math.max(0,3-#code))..code
	end

	net.write(client.sock or clib.getsock(id), ":"..(kvstore.get("circd:servername") or "circd").." "..code.." "..table.concat(p, " ").."\r\n")
end

----
--- chan Helpers
----

-- basics, join, part and send*
function clib.join_chan(id, chan) -- join channel
	event.fire("circd:chan", "join", id, chan)
end
function clib.part_chan(id, chan, reason) -- leave channel
	event.fire("circd:chan", "part", id, chan, reason)
end
function clib.send_chan(id, chan, msg, to_sender) -- send msg to every user of the channel
	print("send_chan to "..chan)
	local id_excluded
	if not to_sender then
		id_excluded = id
	end
	event.fire("circd:chan", "send", id_excluded, chan, msg)
end
function clib.send_all_with_user(id, msg, to_sender)
	local chans = clib.get_channels(id)
	for _, chan in pairs(chans) do
		clib.send_chan(id, chan, msg, to_sender)
	end
end

-- checks
function clib.channel_exists(chan)
	return kvstore._get("circd:chan:exists:"..chan) == true
end
function clib.list_users(chan) -- get users of channel
	local c = com.create()
	event.fire("circd:chan", "getusers", nil, chan, c)
	local res = com.receive(c)
	com.close(c)
	return msgpack.unpack(res)
end
function clib.get_channels(id) -- get list of channels user is in
	local c = com.create()
	event.fire("circd:chan", "getchannels", id, nil, c)
	local res = com.receive(c)
	com.close(c)
	local users = msgpack.unpack(res)
	print("users for "..chan)
	for k, v in pairs(users) do
		print(k..": "..v)
	end
	return users
end
function clib.in_channel(chan, id)
	local users = clib.list_users(chan)
	if not users then
		return false
	end
	for user, _ in pairs(users) do
		print("users: "..user)
		if user == id then
			return true
		end
	end
end

-- chan get...
function clib.gettopic(chan)
	return kvstore._get("circd:chan:topic:"..chan)
end

-- chan set...
function clib.settopic(chan, topic)
	return kvstore._get("circd:chan:topic:"..chan, topic)
end

----
--- helpers for both chan and users
----

function clib.privmsg(id, to, msg)
	print("PRIVMSG to "..to)
	local host = clib.gethost(id)
	if clib.channel_exists(to) then -- channel
		clib.send_chan(id, to, ":"..host.." PRIVMSG "..to.." :"..msg)
		return true
	else -- user
		local client = clib.getclient(to)
		if client then
			clib.send(client, ":"..host.." PRIVMSG "..to.." :"..msg)
			return true
		else
			return false
		end
	end
end
function clib.notice(id, to, msg)
	local host = clib.gethost(id)
	if to:match("^#") then -- channel
		clib.send_chan(id, to, ":"..host.." NOTICE "..to.." :"..msg)
	else -- user
		local client = clib.getclient(to)
		if client then
			clib.send(client, ":"..host.." NOTICE "..to.." :"..msg)
		end
	end
end

return clib
