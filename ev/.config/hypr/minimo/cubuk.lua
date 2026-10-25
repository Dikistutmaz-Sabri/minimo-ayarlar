-- Free windows' frame, as pleamar-wm draws it: a 30 px title bar, darker green
-- when the window has the keyboard (#1d2b27) and grey when it has not
-- (#1a1e22), its title on the left (faded without the keyboard), and on the
-- right three drops: put away (amber), maximize (mint), close (coral), each
-- showing what it does when the mouse is on it. Rounded 12 px, a mint edge
-- round the window with the keyboard. A double click on the bar maximizes.
-- Hyprland's own hyprbars plugin (the AUR package hyprland-plugin-hyprbars,
-- which follows Hyprland's version), loaded here only: no other session has
-- it. Tiled windows have no bar, as in pleamar-wm: the tile is all theirs.

--  The edge and corners of pleamar-wm's windows (before the plugin: they stand
--  even if it could not be loaded).
hl.config({
	general = {
		border_size = 2,
		["col.active_border"] = "rgba(9ed6bdb3)",
		["col.inactive_border"] = "rgba(00000000)",
	},
	decoration = { rounding = 12 },
})

hl.plugin.load("/usr/lib/libhyprbars.so")

local MAX = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })'"

hl.config({
	plugin = {
		hyprbars = {
			bar_height = 30,
			bar_color = "rgb(1d2b27)",
			["col.text"] = "rgb(f5f7f5)",
			bar_text_font = "Noto Sans",
			bar_text_size = 12,
			bar_text_weight = "medium",
			bar_text_align = "left",
			bar_buttons_alignment = "right",
			bar_part_of_window = true,
			bar_precedence_over_border = true,
			bar_padding = 14,
			bar_button_padding = 8,
			icon_on_hover = true,
			inactive_button_color = "rgba(f5f7f52e)",
			on_double_click = MAX,
		},
	},
})

-- Right to left: close, maximize, put away (pleamar-wm's coral, mint, amber).
hl.plugin.hyprbars.add_button({ bg_color = "rgb(ef7a66)", fg_color = "rgb(4a140b)", size = 12, icon = "✕",
	action = "hyprctl dispatch 'hl.dsp.window.close()'" })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(9ed6bd)", fg_color = "rgb(0f3d2f)", size = 12, icon = "□", action = MAX })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(e8c26a)", fg_color = "rgb(4a3308)", size = 12, icon = "–",
	action = "hyprctl eval 'minimo_gizle()'" })

hl.window_rule({ match = { float = false }, ["hyprbars:no_bar"] = true })

-- Programs that draw their own title bar and buttons (GNOME's, Chrome's tabs,
-- Firefox's): no second bar over theirs.
local OWN = "^(org\\.gnome\\..*|google-chrome.*|Google-chrome.*|chromium|firefox|zen)$"
hl.window_rule({ match = { class = OWN }, ["hyprbars:no_bar"] = true })
-- Without the keyboard, the bar is grey and its title faded, as in pleamar-wm
-- (not on those above: a colour rule brought their bar back).
pcall(hl.window_rule, { match = { focus = false, class = "negative:" .. OWN }, ["hyprbars:bar_color"] = "rgb(1a1e22)", ["hyprbars:title_color"] = "rgba(f5f7f58c)" })

-- pleamar-wm's frame is always its own dark one, whatever Minimo's theme; the
-- dock still calls this when the theme changes, and nothing changes.
function minimo_cubuk_tema(dark) end
