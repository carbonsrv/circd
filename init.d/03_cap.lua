-- CAP
-- yay fakery


-- TODO: actually make it work
command.new("cap", function(client, cmd, ...)
	local clib = require("libs.clib")

	local nick = clib.getnick(client.id) or "*"

	if not cmd then
		return 461, nick, "CAP", ":Not enough parameters"
	end

	cmd = cmd:upper()

	if cmd == "LS" then
		kvstore._set("circd:client:"..client.id..":cap", true)
		return "CAP", nick, cmd, ":potato"
	elseif cmd == "END" then
		--clib.srvmsg(client, "CAP", nick, cmd) --!?!?
		if not clib.isconnected(client.id) then
			kvstore._del("circd:client:"..client.id..":cap")
			if clib.getnick(client.id) and clib.getuser(client.id) then
				event.fire("circd:init_message", client)
			end
		end
	else
		return 410, nick, cmd, ":Invalid CAP subcommand"
	end
end)
