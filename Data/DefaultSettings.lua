-- BloomBuddy — Data/DefaultSettings
-- Default SavedVariables structure (BloomBuddyDB). Deep-merged with the
-- saved data on load, so new keys added in future versions are safe.

---@type BB
local _, BB = ...;

BB.Data = BB.Data or {};

---@class DefaultSettings
BB.Data.DefaultSettings = {
    enabled = true,     -- Master switch.
    scale = 1.5,        -- Icon size multiplier (baseSize * scale).
    party = true,       -- Scale on party frames.
    raid = true,        -- Scale on raid frames.
    showTimer = false,  -- Digital countdown on the overlay (default off; the cooldown swipe is always shown).
    showSwipe = true,   -- Native cooldown swipe (darkening clockwise) on the overlay. False → clear+hide the swipe, icon only.
    overlayPosX = 0,    -- Stub: overlay X offset (px). Persisted, NOT applied yet (future repositioning).
    overlayPosY = 0,    -- Stub: overlay Y offset (px). Persisted, NOT applied yet (future repositioning).
};

return BB;
