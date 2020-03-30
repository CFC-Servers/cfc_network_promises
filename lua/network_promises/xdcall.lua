networkPromise.oldYield = networkPromise.oldYield or coroutine.yield
local oldYield = networkPromise.oldYield

-- like pcall but returns a real traceback back as well
-- xpcall allows you to get a traceback, but its not very good. Getting the trace from an errored coroutine is more accurate

-- Unique object that nothing else could return
local trueYield = {}

-- When running a coroutine, we need to treat the code inside as if it is not running in a coroutine
-- To do this, we must propagate any real yields to whatever surrounding coroutine xdcall may be in
-- We differentiate between failure yields and real yields by overriding coroutine.yield to pass a unique table as it's first arg
local function capturedYield( ... )
    return oldYield( trueYield, ... )
end

local function resumeCaptured( co, args )
    coroutine.yield = capturedYield
    local data = { coroutine.resume( co, unpack( args ) ) }
    coroutine.yield = oldYield

    return table.remove( data, 1 ), data
end

-- takes func, args
-- if success, returns true, retArgs
-- if not, returns false, error, stack
function xdcall( func, ... )
    local co = coroutine.create( func )
    local args = { ... }

    while true do
        local success, data = resumeCaptured( co, args )

        if success then
            if data[1] == trueYield then
                -- They called yield internally
                -- Remove the unique table, and propagate the yield as if nothing happened
                table.remove( data, 1 )
                args = { oldYield( unpack( data ) ) }
            else
                -- successfully finished running
                return true, unpack( data )
            end
        else
            -- The coroutine errored, return the error and a traceback of the coroutine
            local err = data[1]
            return false, err, debug.traceback( co )
        end
    end
end
