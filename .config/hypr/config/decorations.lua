-- 1. Import your colors.lua file using its relative configuration module path
local theme = require("config.colors")

-- Look and feel configuration
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 10,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                -- 2. Use the imported primary color
                colors = { theme.primary, theme.primary },
                angle = 45,
            },
            -- A clean fallback color from your theme for the inactive window border
            inactive_border = theme.surface_container, 
        },
    },
    group = {
        col = {
            border_active = theme.primary,
            border_inactive = theme.on_surface,
            border_locked_active = theme.primary_container,
            border_locked_inactive = theme.on_surface,
        },
        groupbar = {
            col = {
                active = theme.tertiary,
                inactive = theme.on_surface,
                locked_active = theme.primary_container,
                locked_inactive = theme.on_surface,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 5,
        active_opacity = 1,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1,
        blur = {
            size = 10,
            passes = 4,
            special = true,
        },
    },
})
