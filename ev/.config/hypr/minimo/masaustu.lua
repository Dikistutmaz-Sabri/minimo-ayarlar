-- Minimo has three workspaces, 1 to 3: they are always there (the island's
-- dots and the dock's pools show the three), Super+4…9 go nowhere, and a
-- three-finger swipe past the last does not make a fourth. The relative keys
-- (Super+PgUp/PgDn, Super+wheel) only go round the existing ones.
for i = 1, 3 do
	hl.workspace_rule({ workspace = tostring(i), persistent = true })
end
for i = 4, 9 do
	hl.unbind("SUPER + " .. i)
	hl.unbind("SUPER + SHIFT + " .. i)
end
hl.config({ gestures = { workspace_swipe_create_new = false } })
