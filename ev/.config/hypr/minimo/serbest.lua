-- Free windows and putting windows away, as in pleamar-wm, in Minimo's session.
-- Every window floats from the start (free); Super+W tiles them
-- (minimo-oturum.lua loads it after Minimo's own keys).
--   Super+W        tiled or free: every window floats, and each new one; again,
--                  the ones floated here go back to the tiles (not the ones a
--                  rule floats, such as Nautilus).
--   Super+G        a window group (Minimo had it on Super+W).
--   Super+M        put the window away (into the dock: special:minimo).
--   Super+Shift+M  bring back the last one put away.
-- The dock (minimo-dock) reads the mode from $XDG_RUNTIME_DIR/minimo-serbest.

local free = true     -- Minimo starts with free windows; Super+W tiles them
local floated = {}    -- address → true: the windows this mode floated
local hidden = {}     -- the order they were put away, the last at the end
local STATE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/minimo-serbest"

local function say()
	local f = io.open(STATE, "w")
	if f then f:write(free and "1" or "0"); f:close() end
end

--  Floated, a window that was a tile may cover the screen, its top at the very
--  edge: its title bar (cubuk.lua, above the window) would be off the screen.
--  Then it is made 80 % of the room and centred.
local BAR = 30
local function fit(addr)
	for _, w in ipairs(hl.get_windows()) do
		if w.address == addr then
			local m = hl.get_active_monitor()
			local W, H = m.width / m.scale, m.height / m.scale
			local r = m.reserved or {}
			local top, bottom = r.top or 0, r.bottom or 0
			local room = H - top - bottom - BAR - 16
			local sx, sy = w.size.x, w.size.y
			if sx > W - 32 or sy > room or w.at.y < top + BAR then
				local nx, ny = math.min(sx, math.floor(W * 0.8)), math.min(sy, math.floor(room * 0.85))
				hl.dispatch(hl.dsp.window.resize({ x = nx, y = ny, window = "address:" .. addr }))
				hl.dispatch(hl.dsp.window.center({ window = "address:" .. addr }))
			end
			return
		end
	end
end

local function float(addr, on)
	hl.dispatch(hl.dsp.window.float({ action = on and "set" or "unset", window = "address:" .. addr }))
	if on then pcall(fit, addr) end
end

function minimo_serbest(on)
	if on == nil then on = not free end
	free = on
	if free then
		for _, w in ipairs(hl.get_windows()) do
			if not w.floating and w.mapped then floated[w.address] = true; float(w.address, true)
			elseif w.floating and w.mapped then pcall(fit, w.address) end
		end
	else
		for _, w in ipairs(hl.get_windows()) do
			if floated[w.address] and w.floating then float(w.address, false) end
		end
		floated = {}
	end
	say()
	hl.exec_cmd("notify-send -a Minimo -t 1500 '" .. (free and "Serbest pencereler" or "Döşeli pencereler") .. "'")
end

hl.on("window.open", function(w)
	if free and w and not w.floating then floated[w.address] = true; float(w.address, true)
	elseif w and w.floating then pcall(fit, w.address) end
end)
hl.on("window.close", function(w)
	if w then floated[w.address] = nil end
end)

--  Put away into the dock, as in pleamar-wm, where it waits as a small picture
--  of itself: taken just before it goes (with its title bar, at a quarter of
--  its size) into $XDG_RUNTIME_DIR/minimo-kucuk/<address>-<time>.png, then it
--  goes. The dock shows the newest picture of each.
local THUMBS = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/minimo-kucuk"
function minimo_gizle()
	local w = hl.get_active_window()
	if not w then return end
	local addr = w.address
	hidden[#hidden + 1] = addr
	local top = (w.floating and BAR or 0)
	local geo = string.format("%d,%d %dx%d", w.at.x, w.at.y - top, w.size.x, w.size.y + top)
	local move = "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:minimo\", window = \"address:" .. addr .. "\", follow = false })'"
	hl.exec_cmd(string.format("sh -c 'mkdir -p %s; rm -f %s/%s-*.png; grim -s 0.25 -g \"%s\" %s/%s-%d.png; %s' ",
		THUMBS, THUMBS, addr, geo, THUMBS, addr, os.time(), move:gsub("'", "'\\''")))
end

function minimo_getir(addr)
	if addr == nil then addr = table.remove(hidden) end
	if addr == nil then return end
	for i = #hidden, 1, -1 do if hidden[i] == addr then table.remove(hidden, i) end end
	local ws = hl.get_active_workspace()
	hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws and ws.id or 1), window = "address:" .. addr, follow = false }))
	hl.dispatch(hl.dsp.focus({ window = "address:" .. addr }))
end

hl.unbind("SUPER + W")
hl.bind("SUPER + W", function() minimo_serbest() end)
hl.bind("SUPER + G", hl.dsp.group.toggle())
-- (Minimo 1.2.3 put «screen off» on Super+Shift+M; here it brings back what
-- was put away, as in pleamar-wm. The screen goes off with Super+Shift+P.)
hl.unbind("SUPER + M")
hl.unbind("SUPER + SHIFT + M")
hl.bind("SUPER + M", function() minimo_gizle() end)
hl.bind("SUPER + SHIFT + M", function() minimo_getir() end)

--  Loaded (the session starting, or the config read again): free, every
--  window there is floats too, quietly.
if free then
	for _, w in ipairs(hl.get_windows()) do
		if not w.floating and w.mapped then floated[w.address] = true; float(w.address, true)
		elseif w.floating and w.mapped then pcall(fit, w.address) end
	end
end
say()
