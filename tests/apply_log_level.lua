-- Extracted ApplyLogLevel logic for testing outside the WoW client.
-- Mirrors the log level update behavior from ConfigPanel.lua.

local M = {}

M.LOG_LEVEL = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}

--- Pure-function version of the log level dropdown callback.
-- @param level   The new log level value (1–4).
-- @param config  The CONFIG table (must have LOG_LEVEL field).
-- @param db      The AVQueueHelperDB table (must have logLevel field).
-- @return config, db  The updated tables.
function M.ApplyLogLevel(level, config, db)
    config.LOG_LEVEL = level
    db.logLevel = level
    return config, db
end

return M
