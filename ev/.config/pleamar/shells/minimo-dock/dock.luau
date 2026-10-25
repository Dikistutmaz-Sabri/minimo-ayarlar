-- Minimo OS's dock, as pleamar-wm's shore: what is on it, read from Hyprland
-- twice a second.
--   · the programs kept on it (~/.config/minimo-os/dock.json; the first time,
--     pleamar-wm's own `dock` line in session.conf), in their order;
--   · then the others with windows, by their window class;
-- each with its windows (a drop each), the urgent one in coral; then the
-- windows put away (special:minimo, Super+M). It hides itself when a window
-- comes over it or one is fullscreen; the mouse at the bottom edge brings it
-- back (the scene), and leaving it hides it again (here).
-- Putting away, bringing back and free windows are Hyprland's own
-- (~/.config/hypr/minimo/serbest.lua): here they are only called.

local HOME = sys.ask("env", "HOME") or ""
local PINS = HOME .. "/.config/minimo-os/dock.json"
local STATE = HOME .. "/.config/minimo-os/state.json"
local SESSION = HOME .. "/.config/pleamar/session.conf"
local RUNTIME = sys.ask("env", "XDG_RUNTIME_DIR") or "/tmp"

local apps = {}
local pins = nil
local shown, away, pools = {}, {}, {}
local THUMBS = RUNTIME .. "/minimo-kucuk"
local dropped_paths = nil
local last_dark = nil

sys.watch("apps", function(list) if type(list) == "table" then apps = list end end)

local function id_of(a) return (tostring(a.id or ""):gsub("%.desktop$", "")) end
local function app_by_id(id)
    id = tostring(id):lower()
    for _, a in ipairs(apps) do if id_of(a):lower() == id then return a end end
    for _, a in ipairs(apps) do
        local cmd = (tostring(a.exec or ""):match("^%S+") or ""):match("([^/]+)$") or ""
        if cmd:lower() == id or tostring(a.wmclass or ""):lower() == id then return a end
    end
    return nil
end
--  Whose a window is: its class against the app's StartupWMClass, its
--  .desktop name, or its command.
local function app_of(class)
    class = tostring(class or ""):lower()
    if class == "" then return nil end
    for _, a in ipairs(apps) do
        local id = id_of(a):lower()
        if tostring(a.wmclass or ""):lower() == class or id == class or id:match("([^.]+)$") == class then return a end
    end
    for _, a in ipairs(apps) do
        local cmd = tostring(a.exec or ""):match("^%S+") or ""
        if (cmd:match("([^/]+)$") or ""):lower() == class then return a end
    end
    return nil
end
local function name_of(a)
    local n = a.local_name
    return (type(n) == "string" and n ~= "") and n or tostring(a.name or "")
end

local function save_pins()
    run("sh", { "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", PINS, json.encode(pins) }, function() end)
end
--  Yours if you have changed them here; the first time, pleamar-wm's.
local function load_pins(done)
    run("sh", { "-c", 'cat "$1" 2>/dev/null; echo "@@"; grep -m1 "^dock " "$2" 2>/dev/null', "sh", PINS, SESSION }, function(out)
        local mine, theirs = tostring(out or ""):match("^(.-)@@(.*)$")
        local ok, v = pcall(json.decode, mine or "")
        if ok and type(v) == "table" and #v > 0 then pins = v
        else
            pins = {}
            for id in tostring(theirs or ""):gsub("^%s*dock%s+", ""):gmatch("%S+") do pins[#pins + 1] = id end
            if #pins == 0 then pins = { "com.mitchellh.ghostty", "org.gnome.Nautilus", "google-chrome-beta" } end
        end
        done()
    end)
end

local function hypr(lua) run("hyprctl", { "dispatch", lua }, function() end) end
local function eval(lua) run("hyprctl", { "eval", lua }, function() end) end
local function focus(addr) hypr('hl.dsp.focus({ window = "address:' .. addr .. '" })') end

-- ── reading Hyprland ──
local function read()
    if pins == nil then return end
    run("sh", { "-c", 'hyprctl clients -j; echo "@@"; hyprctl activewindow -j; echo "@@"; hyprctl workspaces -j; echo "@@"; hyprctl activeworkspace -j; echo "@@"; '
        .. 'hyprctl repl "local w = hl.get_urgent_window() return w and w.address or \\"\\""; echo "@@"; cat "$1" 2>/dev/null; echo "@@"; cat "$2" 2>/dev/null; '
        .. 'echo "@@"; hyprctl monitors -j; echo "@@"; hyprctl cursorpos; echo "@@"; ls "$3" 2>/dev/null',
        "sh", RUNTIME .. "/minimo-serbest", STATE, THUMBS }, function(out)
        local parts = {}
        for p in (tostring(out or "") .. "@@"):gmatch("(.-)@@") do parts[#parts + 1] = p end
        local okc, clients = pcall(json.decode, parts[1] or "")
        if not okc or type(clients) ~= "table" then return end
        local oka, active = pcall(json.decode, parts[2] or "")
        local okw, spaces = pcall(json.decode, parts[3] or "")
        local okaw, aws = pcall(json.decode, parts[4] or "")
        local urgent = tostring(parts[5] or ""):match("(0x%x+)") or ""
        local active_addr = oka and type(active) == "table" and active.address or ""
        fact.free = tostring(parts[6] or ""):match("1") ~= nil
        local okt, st = pcall(json.decode, parts[7] or "")
        local dark = okt and type(st) == "table" and st.theme == "dark" or false
        --  The windows' title bars follow the theme too (~/.config/hypr/minimo/cubuk.lua).
        if dark ~= last_dark then
            last_dark = dark
            run("hyprctl", { "eval", "if minimo_cubuk_tema then minimo_cubuk_tema(" .. tostring(dark) .. ") end" }, function() end)
        end

        --  Each window, to its program (or to its class, when no program is known).
        local by_key, order = {}, {}
        local function entry(key, app, class)
            if not by_key[key] then
                by_key[key] = { key = key, app = app, class = class, windows = {} }
                order[#order + 1] = key
            end
            return by_key[key]
        end
        for _, id in ipairs(pins) do
            local a = app_by_id(id)
            if a then entry(id_of(a), a, nil).pinned = true end
        end
        table.sort(clients, function(x, y) return (x.focusHistoryID or 0) < (y.focusHistoryID or 0) end)
        local away_rows = {}
        away = {}
        local thumb = {}
        for name in tostring(parts[10] or ""):gmatch("[^\n]+") do
            local ad, tm = name:match("^(0x%x+)%-(%d+)%.png$")
            if ad and (not thumb[ad] or tonumber(tm) > thumb[ad].t) then thumb[ad] = { t = tonumber(tm), path = THUMBS .. "/" .. name } end
        end
        for _, c in ipairs(clients) do
            local ws = type(c.workspace) == "table" and tostring(c.workspace.name or "") or ""
            if c.mapped ~= false and (ws:sub(1, 8) ~= "special:" or ws == "special:minimo") and tostring(c.class or "") ~= "" then
                local a = app_of(c.class)
                local e = a and entry(id_of(a), a, c.class) or entry("class:" .. tostring(c.class), nil, c.class)
                local w = { addr = c.address, title = tostring(c.title or ""), hidden = ws == "special:minimo",
                            active = c.address == active_addr, urgent = c.address == urgent }
                e.windows[#e.windows + 1] = w
                if w.hidden and #away < 8 then
                    away[#away + 1] = w
                    local th = thumb[c.address]
                    away_rows[#away_rows + 1] = { icon = a and tostring(a.icon or "") or tostring(c.class):lower(), title = w.title,
                                                  thumb = th and th.path or "", has_thumb = th ~= nil }
                end
            end
        end
        local rows = {}
        shown = {}
        for _, k in ipairs(order) do
            local e = by_key[k]
            local act, urg = false, false
            for _, w in ipairs(e.windows) do
                if w.active then act = true end
                if w.urgent then urg = true end
            end
            shown[#shown + 1] = e
            rows[#rows + 1] = {
                icon = e.app and tostring(e.app.icon or "") or tostring(e.class or ""):lower(),
                name = e.app and name_of(e.app) or tostring(e.class or ""),
                wins = #e.windows, active = act, urgent = urg, pinned = e.pinned == true,
            }
            if #rows >= 16 then break end
        end
        model.items = rows
        fact.n = #rows
        model.away = away_rows
        fact.a = #away_rows

        --  Smart hide: a window of this workspace over the dock's strip, or one
        --  fullscreen, hides it; the mouse back at the bottom edge shows it (the
        --  scene's edge), until it goes up and away again.
        --  The pools: those with windows, the one you are on, and an empty one past the last.
        local here_ws = okaw and type(aws) == "table" and tonumber(aws.id) or 1
        local count, last = {}, 0
        if okw and type(spaces) == "table" then
            for _, sp in ipairs(spaces) do
                local id = tonumber(sp.id)
                if id and id > 0 then count[id] = tonumber(sp.windows) or 0; if id > last then last = id end end
            end
        end
        if here_ws > last then last = here_ws end
        local prow = {}
        pools = {}
        for id = 1, 3 do   -- Minimo has three (~/.config/hypr/minimo/masaustu.lua)
            pools[#pools + 1] = id
            prow[#prow + 1] = { active = id == here_ws, wins = count[id] or 0 }
        end
        model.pools = prow
        fact.p = #prow

        local okm, mons = pcall(json.decode, parts[8] or "")
        local mon = okm and type(mons) == "table" and mons[1] or nil
        if mon then
            local W, H = mon.width / mon.scale, mon.height / mon.scale
            local here = okaw and type(aws) == "table" and tonumber(aws.id) or 1
            local dw = 28 + #rows * 60 + (#away_rows > 0 and 20 + #away_rows * 76 or 0) + 20 + #prow * 26 + 52
            local x1, x2, y1 = (W - dw) / 2, (W + dw) / 2, H - 80
            local over = false
            for _, c in ipairs(clients) do
                local ws = type(c.workspace) == "table" and tonumber(c.workspace.id) or -1
                if ws == here and c.mapped ~= false and c.hidden ~= true then
                    if (tonumber(c.fullscreen) or 0) > 0 then over = true; break end
                    local cx, cy, cw, ch = c.at[1], c.at[2], c.size[1], c.size[2]
                    if cx < x2 and cx + cw > x1 and cy + ch > y1 then over = true; break end
                end
            end
            fact.hide = over
            local py = tonumber(tostring(parts[9] or ""):match(",%s*(%-?%d+)"))
            if fact.reveal and py and py < H - 120 then fact.reveal = false end
        end
    end)
end

local function launch(e, paths)
    if not (e and e.app) then return end
    local exec = tostring(e.app.exec or "")
    if paths and #paths > 0 then
        local q = {}
        for i, p in ipairs(paths) do q[i] = "'" .. p:gsub("'", "'\\''") .. "'" end
        local files = table.concat(q, " ")
        local n
        exec, n = exec:gsub("%%[fFuU]", files, 1)
        if n == 0 then exec = exec .. " " .. files end
    end
    --  Started by Hyprland, not by the dock: it belongs to the session, so the
    --  dock restarting never takes it with it.
    exec = exec:gsub("%%[dDnNickvm]", ""):gsub("%%[fFuU]", ""):gsub("%s+$", "")
    run("hyprctl", { "eval", "hl.exec_cmd([==[" .. exec .. "]==])" }, function() end)
end

-- ── pressing ──
--  It goes to its window —put away, it comes back; pressed again, the next
--  one—, or the program starts.
on("pick", function(i)
    local e = shown[(tonumber(i) or 0) + 1]
    if not e then return end
    if #e.windows == 0 then launch(e); return end
    for k = #e.windows, 1, -1 do
        if e.windows[k].hidden then eval('minimo_getir("' .. e.windows[k].addr .. '")'); after(150, read); return end
    end
    for k, w in ipairs(e.windows) do
        if w.active then focus(e.windows[k % #e.windows + 1].addr); after(150, read); return end
    end
    focus(e.windows[1].addr)
    after(150, read)
end)

--  Held: its windows, to pick one.
local peeking = nil
on("peek_at", function(i)
    peeking = shown[(tonumber(i) or 0) + 1]
    local rows = {}
    if peeking then
        for k, w in ipairs(peeking.windows) do
            if k > 8 then break end
            rows[k] = { title = w.title ~= "" and w.title or name_of(peeking.app or {}), hidden = w.hidden }
        end
    end
    if #rows == 0 then rows[1] = { title = "Açık penceresi yok", hidden = false } end
    model.peeks = rows
end)
on("go", function(r)
    local w = peeking and peeking.windows[(tonumber(r) or 0) + 1]
    if not w then return end
    if w.hidden then eval('minimo_getir("' .. w.addr .. '")') else focus(w.addr) end
    after(150, read)
end)

--  The right button: keep it or let it go, another window, close them.
local menued = nil
local function pinned_at(e)
    if not (e and e.app) then return nil end
    local id = id_of(e.app):lower()
    for k, p in ipairs(pins) do if tostring(p):lower() == id then return k end end
    return nil
end
on("menu_at", function(i)
    menued = shown[(tonumber(i) or 0) + 1]
    text["menu.pin"] = pinned_at(menued) and "Dock'tan çıkar" or "Dock'ta tut"
    fact["menu.wins"] = menued and #menued.windows or 0
end)
on("menu_do", function(k)
    local e = menued
    if not e then return end
    k = tonumber(k) or -1
    if k == 0 then
        local at = pinned_at(e)
        if at then table.remove(pins, at) elseif e.app then pins[#pins + 1] = id_of(e.app) end
        save_pins()
    elseif k == 1 then
        launch(e)
    elseif k == 2 then
        for _, w in ipairs(e.windows) do hypr('hl.dsp.window.close({ window = "address:' .. w.addr .. '" })') end
    end
    after(200, read)
end)

--  Carried up off the dock: let go.
on("unpin", function(i)
    local at = pinned_at(shown[(tonumber(i) or 0) + 1])
    if at then table.remove(pins, at); save_pins() end
    after(100, read)
end)

--  A file dropped on it: opened with it. What was dropped comes first, then
--  which one it fell on (or the other way round): whichever is second does it.
local dropped_on = nil
local function open_dropped()
    if dropped_paths and dropped_on then
        launch(shown[dropped_on + 1], dropped_paths)
        dropped_paths, dropped_on = nil, nil
    end
end
on("drop:touch", function(data)
    local paths = {}
    for line in tostring(data or ""):gmatch("[^\r\n]+") do
        local p = line:match("^file://(.+)$")
        if p then paths[#paths + 1] = (p:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
    end
    if #paths > 0 then dropped_paths = paths; open_dropped() end
end)
on("dropped", function(i) dropped_on = tonumber(i) or 0; open_dropped(); after(1000, function() dropped_on = nil end) end)

on("back", function(i)
    local w = away[(tonumber(i) or 0) + 1]
    if w then eval('minimo_getir("' .. w.addr .. '")'); after(150, read) end
end)
on("pool", function(i)
    local id = pools[(tonumber(i) or 0) + 1]
    if id then hypr('hl.dsp.focus({ workspace = "' .. id .. '" })'); after(150, read) end
end)
on("mode", function() eval("minimo_serbest()"); after(200, read) end)

load_pins(read)
every(500, read)
