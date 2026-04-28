-- Extracted LoadSavedSettings logic for testing outside the WoW client.
-- Mirrors the DEFAULTS table and initialization algorithm from AVQueueHelper.lua.

local M = {}

M.LOG_LEVEL = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}

M.DEFAULTS = {
    logLevel = M.LOG_LEVEL.INFO,
    keybind  = "F12",
}

--- Pure-function version of LoadSavedSettings.
-- @param db  The persisted AVQueueHelperDB value (may be nil, partial, or full).
-- @return db      The (possibly newly-created) settings table.
-- @return config  A table with LOG_LEVEL and KEYBIND derived from the final db.
function M.LoadSavedSettings(db)
    if db == nil then
        db = {}
    end
    for k, v in pairs(M.DEFAULTS) do
        if db[k] == nil then
            db[k] = v
        end
    end
    local config = {
        LOG_LEVEL = db.logLevel,
        KEYBIND   = db.keybind,
    }
    return db, config
end

return M
