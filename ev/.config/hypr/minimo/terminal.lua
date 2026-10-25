-- Minimo's terminal is kitty, not Ghostty (minimo-oturum.lua loads it after
-- Minimo's own keys, which bind Super+T to ghostty).
hl.unbind("SUPER + T")
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))
