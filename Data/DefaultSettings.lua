---@type BB
local _, BB = ...;

BB.Data = BB.Data or {};

BB.Data.DefaultSettings = {
    enabled = true,

    -- Minimum/default Lifebloom icon size.
    scale = 1.0,

    party = true,
    raid = true,

    -- Digital countdown is enabled by default.
    showTimer = true,

    -- Circular cooldown darkening is enabled by default.
    showSwipe = true,

    -- Centered horizontally.
    overlayPosX = 5,

    -- Special default: align the icon with the top edge
    -- of the raid frame HP bar.
    overlayPosY = "TOP",
};

return BB;