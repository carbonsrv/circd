-- 00_init.lua: New connections.

-- localize config to bind to threads
local settings = config

local function encode(client, code, ...)
	local p = {...}
	if (p[#p] or ""):match("%s") then
		p[#p] = ":"..p[#p]:gsub("^:?", "")
	end

	if type(code) == "number" then
		code = tostring(code)
		code = ("0"):rep(math.max(0,3-#code))..code
	end

	return ":"..kvstore.get("circd:servername").." "..(kvstore.get("circd:client:nick:"..client.id) or "*").." "..table.concat(p, " ")
end

event.handle("circd:newclient", function(cl)
	local servername = kvstore.get("circd:servername")
	cl:send(":"..servername.." NOTICE * :Hello! This is "..servername)
end)

event.handle("circd:raw", function(client, txt) -- handle client messages
	local clib = require("libs.clib")
	print ("Raw '" .. tostring(txt) .. "'")
	local cmd, params = txt:match("^(%S*)%s?(.*)")
	print ("1. pattern applied '" .. tostring (cmd) .. "', '" .. tostring(params) .. "'")

	if cmd:gsub("^ +", "") ~= "" then
		cmd=cmd:lower()
		print("Got command: '"..tostring(cmd).."'")
		if clib.isconnected(client.id) or cmd == "nick" or cmd == "user" or cmd == "pong" or cmd == "cap" then
			local long = params:match("%s:(.*)$")
			print ("2. long applied '" .. tostring (long)  .. "'")
			if long then
				params = params:gsub("%s:.*$", "")
				print ("3. params matching '" .. tostring (params) .. "'")
			end

			local pr = {}
			for item in params:gmatch("%S+") do
				table.insert(pr, item)
			end

			print ("4. iterating pr:")
			for k,v in pairs (pr) do
				print ("| '" .. tostring (v) .. "'")
			end

			local last = pr[#pr]
			if last then
				pr[#pr] = last:gsub("^:", "")
				print ("5. removed ':' '" .. tostring (pr[#pr]) .. "' ")
			end

			if long then
				table.insert(pr, long)
			end

			print("Params: "..params.." :"..(long or ""))
			print(pr)
			local nick = clib.getnick(client.id)
			if clib.is_command(cmd) then
				event.fire("circd:command:"..cmd, client, unpack(pr))
			elseif nick then
				print("No such command")
				clib.srvmsg(client, 421, nick, cmd, ":Unknown Command")
			end
		else
			print("Unknown command")
			clib.srvmsg(client, 421, "*", cmd, ":Unknown Command or not allowed in this context.")
		end
	end
end)

local function validnick(nick)
	return nick:match("^[%a%^_\\|%[%]][%a%d%^_\\|%[%]]*$") and #nick<17
end

-- NICK testuser
command.new("nick", function(client, nick)
	local clib = require("libs.clib")
	local nick_before = (clib.getnick(client.id) or "*")
	print(nick_before.." set their nick to \""..(nick or "").."\"")
	if not nick then
		print("461")
		return 461, nick_before, "No nickname given"
	elseif clib.nick_used(nick) then
		print("433")
		return 433, nick_before, "Nickname is already in use"
	elseif not validnick(nick) then
		print("432")
		return 432, nick_before, "Erroneuous Nickname"
	end

	if nick_before ~= "*" then
		kvstore.del("circd:client:nick:"..client.id)
		kvstore.del("circd:client:id:"..nick_before)
	end

	client.nick = nick
	clib.setclient(client.id, client)
	clib.setid(nick, client.id)
	clib.setnick(client.id, nick)

	local user = clib.getuser(client.id)

	if user then
		clib.sethost(client.id, nick.."!"..user.."@"..client.ip)
	end

	if not clib.isconnected(client.id) and user then
		print("Queued up for connection...")
		if not kvstore._get("circd:client:"..client.id..":cap") then
			event.fire("circd:connect", client)
		end
	elseif user then
		local old_hostmask = nick_before.."!"..user.."@"..client.ip
		clib.send_all_with_user(client.id, ":"..old_hostmask.." NICK "..nick)
		client:send(":"..old_hostmask.." NICK "..nick)
	end
end)

-- USER testuser ~ ~ :Hi, I am testuser.
command.new("user",function(client, username,_ ,_ , realname)
	local clib = require("libs.clib")
	print("user")
	if not clib.isconnected(client.id) then
		if not (username and realname) then
			return 461, "*", "USER", "Not enough parameters"
		end
		clib.setuser(client.id, username:gsub("[^%a%d]",""):sub(1,8))
		clib.setreal(client.id, realname)
		local nick = clib.getnick(client.id)
		if nick then
			clib.sethost(client.id, nick.."!"..username:gsub("[^%a%d]",""):sub(1,8).."@"..client.ip)
			if not kvstore._get("circd:client:"..client.id..":cap") then
				event.fire("circd:connect", client)
			end
		end
	else
		return 462, (clib.getnick(client.id) or "*"), "You may not reregister."
	end
end)

-- Init message.
kvstore.set("circd:settings:motd", settings.motd)

event.handle("circd:init_message", function(cl)
	local clib = require("libs.clib")
	clib.setconnected(cl.id, true)

	local nick = clib.getnick(cl.id) or "*"
	local function msg(code, ...)
		clib.srvmsg(cl, code, nick, ...)
	end

	-- TODO: make this actually output correct data.
	msg(001, "Welcome to my irc server, "..nick)
	msg(002, "Your host is Server, running CIRCd version 0.0-0")
	msg(003, "This server was created Jan 1 0000 at 00:00:00 UTC")
	msg(004, "Server","CIRCd0.0-0","DQRSZagiloswz","CFILPQbcefgijklmnopqrstvz","bkloveqjfI")
	msg(005, "CHANTYPES=#","EXCEPTS","INVEX","CHANMODES=eIbq,k,flj,CFPcgimnpstz","CHANLIMIT=#:50","PREFIX=(ov)@+","MAXLIST=bqeI:100","MODES=4","NETWORK="..kvstore.get("circd:servername"),"KNOCK","STATUSMSG=@+","CALLERID=g","are supported by this server")
	msg(005, "CASEMAPPING=rfc1459","CHARSET=ascii","NICKLEN=30","CHANNELLEN=50","TOPICLEN=390","ETRACE","CPRIVMSG","CNOTICE","DEAF=D","MONITOR=100","FNC","TARGMAX=NAMES:1,LIST:1,KICK:1,WHOIS:1,PRIVMSG:4,NOTICE:4,ACCEPT:,MONITOR:","are supported by this server")
	msg(005, "EXTBAN=$,acjorsxz","WHOX","CLIENTVER=3.0","SAFELIST ELIST=CTU","are supported by this server")
	msg(251, "There are 1337 users and 1337 invisible on 1337 servers")
	msg(252, 1337, "IRC Operators online")
	msg(253, 1337, "unknown connection(s)")
	msg(254, 1337, "channels formed")
	msg(255, "I have 1337 clients and 1337 servers")
	msg(265, 1337, 1337,"Current local users 1337, max 1337")
	msg(266, 1337, 1337,"Current global users 1337, max 1337")
	msg(250, "Highest connection count: 1337 (1337 clients) (1337 connections received)")

	msg(375, "- "..kvstore.get("circd:servername").." Message of the Day -")
	for line in string.gmatch(kvstore._get("circd:settings:motd"), "(.-)[\r\n]") do
		if string.gsub(line, "[%s\r\n]+", "") ~= "" then
			msg(372, line)
		end
	end
	msg(376, "End of /MOTD command.")

	clib.send(cl, ":"..clib.gethost(cl.id).." MODE "..nick.." :+i")
	--clib.join_chan(cl.id, "#lobby")
end)

command.new("motd", function(cl)
	local clib = require("libs.clib")

	local nick = clib.getnick(cl.id) or "*"
	local function msg(code, ...)
		clib.srvmsg(cl, code, nick, ...)
	end

	msg(375, "- "..kvstore.get("circd:servername").." Message of the Day -")
	for line in string.gmatch(kvstore._get("circd:settings:motd"), "(.-)[\r\n]") do
		if string.gsub(line, "[%s\r\n]+", "") ~= "" then
			msg(372, line)
		end
	end
	msg(376, "End of /MOTD command.")
end)

event.handle("circd:disconnect", function(client)
	print("User ID:"..client.id.." disconnected.")
end)

command.new("quit", function(client, reason)
	if reason then
		reason = reason:gsub("^:", "")
	end
	client:close(reason or "Client Quit")
	event.fire("circd:disconnect", client, reason or "Client Quit")
end)
