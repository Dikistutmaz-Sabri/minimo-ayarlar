-- Title bars on Minimo's free windows, as in Plasma: the title, and at the top
-- right put away (into the dock), maximize and close; a double click on the bar
-- maximizes. Hyprland's own hyprbars plugin (the AUR package
-- hyprland-plugin-hyprbars, which follows Hyprland's version), loaded here
-- only: no other session has it. Tiled windows have no bar: the tile is all theirs.

hl.plugin.load("/usr/lib/libhyprbars.so")

local MAX = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })'"

hl.config({
	plugin = {
		hyprbars = {
			bar_height = 30,
			bar_text_font = "Adwaita Sans",
			bar_text_size = 11,
			bar_text_weight = "medium",
			bar_text_align = "center",
			bar_buttons_alignment = "right",
			bar_part_of_window = true,
			bar_precedence_over_border = true,
			bar_padding = 10,
			bar_button_padding = 8,
			on_double_click = MAX,
		},
	},
})

-- Right to left: close, maximize, put away.
hl.plugin.hyprbars.add_button({ bg_color = "rgb(e0655a)", fg_color = "rgb(ffffff)", size = 16, icon = "✕",
	action = "hyprctl dispatch 'hl.dsp.window.close()'" })
hl.plugin.hyprbars.add_button({ bg_color = "rgba(6e6e6e8c)", fg_color = "rgb(ffffff)", size = 16, icon = "□", action = MAX })
hl.plugin.hyprbars.add_button({ bg_color = "rgba(6e6e6e8c)", fg_color = "rgb(ffffff)", size = 16, icon = "–",
	action = "hyprctl eval 'minimo_gizle()'" })

hl.window_rule({ match = { float = false }, ["hyprbars:no_bar"] = true })
-- Chrome draws its own title bar and buttons: no second one over it.
hl.window_rule({ match = { class = "^(google-chrome.*|chromium|Google-chrome.*)$" }, ["hyprbars:no_bar"] = true })

-- Minimo's light or dark theme (~/.config/minimo-os/state.json): the bar takes
-- its colours —the dock's own—, at start and whenever the dock sees the theme
-- change (it calls minimo_cubuk_tema). The buttons read on both.
function minimo_cubuk_tema(dark)
	hl.config({
		plugin = {
			hyprbars = {
				bar_color = dark and "rgba(1f2022ff)" or "rgba(f6f6f5ff)",
				["col.text"] = dark and "rgb(e8e8e8)" or "rgb(2b2b2b)",
				inactive_button_color = dark and "rgba(ffffff1a)" or "rgba(0000001a)",
			},
		},
	})
end
do
	local f = io.open(os.getenv("HOME") .. "/.config/minimo-os/state.json")
	local text = f and f:read("a") or ""
	if f then f:close() end
	minimo_cubuk_tema(text:match('"theme"%s*:%s*"dark"') ~= nil)
end
