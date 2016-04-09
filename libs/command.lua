-- command

local command = {}

function command.new(name, fn)
	print("Adding command "..name)
	kvstore._set("circd:command:is_registered:"..name, true)
	event.handle("circd:command:"..name:lower(), function(client, ...)
		local clib = require("libs.clib")
		local ret = {func(client, ...)}
		if #ret > 0 then
			clib.srvmsg(client, unpack(ret))
		end
	end, {
		func=fn
	})
end

function command.run(client, cmd, ...)
	event.fire("circd:command:"..name:lower(), cmd, client, ...)
end

return command
