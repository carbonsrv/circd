-- CIRCd settings
return {

	-- The Name of the Server
	servername = "circd.lua",

	-- Port it is binding on. Format: "ip:port"
	-- Note: If you want to bind to all, just leave out the IP part like ":port"
	bind = ":6667",

	-- Rate limiting: How much time between messages is the minimum.
	-- Global:
	rate_limit_global = 0.1, -- seconds
	-- Overrides:
	rate_limit_override = {
		["vifino!vifino@127.0.0.1"] = 0, -- no limit
		["spammy_bot!bot@8.8.8.8"] = 1, -- one second between messages minimum
	},

	-- Pings: Delay between pings/timeout.
	ping_rate = 180, -- seconds

	-- MOTD: Here you need to apply some creativity.
	motd = [[
 _                   _______
| |   _   _  __ _   / /___ /
| |  | | | |/ _` | / /  |_ \
| |__| |_| | (_| | \ \ ___) |
|_____\__,_|\__,_|  \_\____/
        Fo Shizzlez!
]],
}
