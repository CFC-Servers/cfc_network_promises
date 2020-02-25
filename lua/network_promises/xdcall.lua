networkPromise.oldYield = networkPromise.oldYield or coroutine.yield
local oldYield = networkPromise.oldYield

-- like pcall but returns a real traceback back as well
-- xpcall allows you to get a traceback, but its not very good. Getting the trace from an errored coroutine is more accurate

-- Unique object that nothing else could return
local trueYield = {}

local function capturedYield( ... )
    return oldYield( trueYield, ... )
end

-- takes func, args
-- if success, returns true, retArgs
-- if not, returns false, error, stack
function xdcall( func, ... )
    local co = coroutine.create( func )
    local args = { ... }
    while true do
        coroutine.yield = capturedYield
        local data = { coroutine.resume( co, unpack( args ) ) }
        coroutine.yield = oldYield

        local success = table.remove( data, 1 )
        if success then
            if data[1] == trueYield then
                -- They called yield internally
                table.remove( data, 1 )
                args = { oldYield( unpack( data ) ) }
            else
                -- successfully finished running
                return true, unpack( data )
            end
        else
            -- thats an error, dawg
            local err = data[1]
            return false, err, debug.traceback( co )
        end
    end
end
