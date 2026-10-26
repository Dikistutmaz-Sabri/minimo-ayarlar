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

--  Put away into the dock, as in pleamar-wm: a small picture of it is taken
--  (with its title bar, at a quarter of its size, into
--  $XDG_RUNTIME_DIR/minimo-kucuk/<address>-<time>.png: the dock shows it), then
--  it shrinks and slides down into the dock —Hyprland's own window animation—
--  and goes. Brought back, it grows out of the dock to where it was.
--  The window: the one given (the dock's press), or the one with the keyboard.
local THUMBS = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/minimo-kucuk"
local was = {}        -- address → { x, y, w, h }: where it was, to go back there
local function window_of(addr)
	for _, w in ipairs(hl.get_windows()) do if w.address == addr then return w end end
	return nil
end
function minimo_gizle(addr)
	local w = addr and window_of(addr) or hl.get_active_window()
	if not w then return end
	addr = w.address
	hidden[#hidden + 1] = addr
	was[addr] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y, floating = w.floating }
	local top = (w.floating and BAR or 0)
	local geo = string.format("%d,%d %dx%d", w.at.x, w.at.y - top, w.size.x, w.size.y + top)
	--  Where the dock is: the bottom of the screen, in the middle.
	local m = hl.get_active_monitor()
	local W, H = m.width / m.scale, m.height / m.scale
	local sel = "address:" .. addr
	local steps = {
		string.format("hyprctl dispatch 'hl.dsp.window.resize({ x = 96, y = 60, window = \"%s\" })'", sel),
		string.format("hyprctl dispatch 'hl.dsp.window.move({ x = %d, y = %d, window = \"%s\" })'", math.floor(W / 2 - 48), math.floor(H - 70), sel),
		"sleep 0.32",
		string.format("hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:minimo\", window = \"%s\", follow = false })'", sel),
	}
	--  Only a free window can be shrunk and slid; a tiled one just goes.
	if not w.floating then steps = { steps[4] } end
	local script = string.format("mkdir -p %s; rm -f %s/%s-*.png; grim -s 0.25 -g \"%s\" %s/%s-%d.png; %s",
		THUMBS, THUMBS, addr, geo, THUMBS, addr, os.time(), table.concat(steps, "; "))
	hl.exec_cmd("sh -c '" .. script:gsub("'", "'\\''") .. "'")
end

function minimo_getir(addr)
	if addr == nil then addr = table.remove(hidden) end
	if addr == nil then return end
	for i = #hidden, 1, -1 do if hidden[i] == addr then table.remove(hidden, i) end end
	local ws = hl.get_active_workspace()
	local sel = "address:" .. addr
	hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws and ws.id or 1), window = sel, follow = false }))
	--  Out of the dock, back to its size and place: it grows there.
	local g = was[addr]
	if g and g.floating then
		hl.dispatch(hl.dsp.window.resize({ x = g.w, y = g.h, window = sel }))
		hl.dispatch(hl.dsp.window.move({ x = g.x, y = g.y, window = sel }))
	end
	was[addr] = nil
	hl.dispatch(hl.dsp.focus({ window = sel }))
end

-- Going to a window (the dock, a key) leaves the mouse where it is: it does
-- not jump to the middle of that window.
hl.config({ cursor = { no_warps = true } })

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
