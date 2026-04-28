-- Feature: av-queue-config, Property 2: 日志级别更新一致性
-- Validates: Requirements 9.5
--
-- For any valid log level (DEBUG=1, INFO=2, WARN=3, ERROR=4),
-- after calling ApplyLogLevel, CONFIG.LOG_LEVEL and AVQueueHelperDB.logLevel
-- must both equal the selected value.

local applyLogLevel = require("tests.apply_log_level")

describe("ApplyLogLevel - Property 2: 日志级别更新一致性", function()
    local VALID_LEVELS = { 1, 2, 3, 4 }

    it("CONFIG.LOG_LEVEL and db.logLevel both equal the selected level for all valid levels (100 iterations)", function()
        math.randomseed(os.time())

        for i = 1, 100 do
            -- Pick a random valid log level
            local level = VALID_LEVELS[math.random(#VALID_LEVELS)]

            -- Start with arbitrary prior state
            local config = { LOG_LEVEL = VALID_LEVELS[math.random(#VALID_LEVELS)] }
            local db     = { logLevel  = VALID_LEVELS[math.random(#VALID_LEVELS)] }

            -- Apply the new level
            local resultConfig, resultDb = applyLogLevel.ApplyLogLevel(level, config, db)

            -- Property: both must equal the selected level
            assert.are.equal(level, resultConfig.LOG_LEVEL,
                string.format("Iteration %d: config.LOG_LEVEL expected %d, got %s", i, level, tostring(resultConfig.LOG_LEVEL)))
            assert.are.equal(level, resultDb.logLevel,
                string.format("Iteration %d: db.logLevel expected %d, got %s", i, level, tostring(resultDb.logLevel)))
        end
    end)
end)
