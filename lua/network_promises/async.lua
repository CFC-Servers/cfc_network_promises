--[[
Warning: This is a complex file!
Make sure you are familiar with JavaScript style Promises before attempting to modify this.
]]

local function isPromise( p )
    return type( p ) == "table" and p.next ~= nil
end

-- Delay to escape any enclosing pcalls
local function delayPromise( prom, method, ... )
    local data = { ... }
    timer.Simple( 0, function()
        prom[method]( prom, unpack( data ) )
    end )
end

local function delayResolve( prom, ... )
    delayPromise( prom, "resolve", ... )
end

local function delayReject( prom, ... )
    delayPromise( prom, "reject", ... )
end

--[[
How this works:

For every await call in the async function, we move deeper into a promise stack by 1.
The rootPromise is the promise that will be returned by the call to the await function.
    This is what will be resolved/rejected after all promises (await calls) in our promise stack finish

In order to stop execution of the async function upon await call, async pushes the function call into a coroutine.
Calling await simply yields the the coroutine with the promise that is being awaited
]]
-- Separate local definition so it can be recursive
local promiseReturn
promiseReturn = function( f, state, coInput, rootPromiseInput, debugInfoInput )
    return function( ... )
        -- Take local copies of arguments that we intend to change (so the async function can be called more than once)
        local rootPromise = rootPromiseInput
        local co = coInput
        local debugInfo = debugInfoInput

        -- If not rootPromise exists, we must be at the root of the async function, aka the async function itself
        local isRoot = rootPromise == nil
        if isRoot then
            -- Initialize the rootPromise, coroutine and debugInfo
            -- This is done here as a new coroutine is needed for every call of the async function
            rootPromise = promise.new()
            co = coroutine.create( f )
            -- Get information on where the function is for error reporting
            debugInfo = debug.getinfo( f, "S" )
        end

        -- Don't pass in state for root, arguments to async function should be sent perfectly to it's internal function
        local ret
        if isRoot then
            ret = { coroutine.resume( co, ... ) }
        else
            ret = { coroutine.resume( co, state, ... ) }
        end

        local success = table.remove( ret, 1 )

        if success then
            -- ret[1] will be a promise whenever await is called
            if isPromise( ret[1] ) then
                -- If it's a promise, set that promise's reject and resolve to put it on the promise stack
                local resolve = promiseReturn( f, true, co, rootPromise, debugInfo )
                local reject = promiseReturn( f, false, co, rootPromise, debugInfo )

                ret[1]:next( resolve, reject )
            else
                -- If it's not a promise, this means the coroutine finished or the promise stack is empty ( from errors )
                delayResolve( rootPromise, unpack( ret ) )
            end
        else
            -- There was a normal error in the coroutine, just reject with the error and location
            local err = ret[1]
            local locationText = "\nContaining async function defined in " .. debugInfo.short_src .. " at line " .. debugInfo.linedefined .. "\n"
            delayReject( rootPromise, err, locationText )
        end

        -- We only return the rootPromise at root, else it will cause every "next" call above to be waiting on the rootPromise
        if isRoot then
            return rootPromise
        end
    end
end

-- Make a function async
function async( f )
    return promiseReturn( f )
end

-- Make a function async and call it
function asyncCall( f, ... )
    return async( f )( ... )
end

AwaitTypes = {
    RETURN = 0,
    PROPAGATE = 1,
    MESSAGE_OVERRIDE = 2,
    HANDLER = 3,
}

-- Wait for a promise to resolve in an async function
function await( p, awaitType, arg )
    assert( coroutine.running(), "Cannot use await outside of async function" )

    awaitType = awaitType or AwaitTypes.RETURN
    local data = { coroutine.yield( p ) }
    local success = table.remove( data, 1 )

    if awaitType == AwaitTypes.RETURN then
        return success, unpack( data )
    elseif awaitType == AwaitTypes.PROPAGATE then
        if not success then
            error( data[1] )
        end

        return unpack( data )
    elseif awaitType == AwaitTypes.MESSAGE_OVERRIDE then
        error( arg )
    elseif awaitType == AwaitTypes.HANDLER then
        if not success then
            arg( unpack( data ) )
        end

        return success, unpack( data )
    end
end

--[[
Old simpler await definition, in case we decide to change back.

-- Wait for a promise to resolve in an async function
function await( p )
    assert( coroutine.running(), "Cannot use await outside of async function" )
    return coroutine.yield( p )
end
]]
