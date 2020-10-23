--[[
Warning: This is a complex file!
Make sure you are familiar with JavaScript style Promises before attempting to modify this.
]]

function isPromise( p )
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

-- Table for checking yield was from await
local awaitFlag = { awaitFlag = true }
local function isAwaitFlag( v )
    return tobool( type( v ) == "table" and v.awaitFlag )
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
            if isAwaitFlag( ret[1] ) then
                -- If it's a promise, set that promise's reject and resolve to put it on the promise stack
                local awaitPromise = ret[2]

                local resolve = promiseReturn( f, true, co, rootPromise, debugInfo )
                local reject = promiseReturn( f, false, co, rootPromise, debugInfo )

                awaitPromise:next( resolve, reject )
            elseif isPromise( ret[1] ) then
                -- Return result was a promise, make it's reject and resolve forward to rootPromise
                ret[1]:next( function( ... )
                    rootPromise:resolve( ... )
                end, function( ... )
                    rootPromise:reject( ... )
                end )
            else
                -- If it's not a promise, this means the coroutine finished or the promise stack is empty ( from errors )
                delayResolve( rootPromise, unpack( ret ) )
            end
        else
            -- There was a normal error in the coroutine, just reject with the error and location
            local err = ret[1]
            if type( err ) == "table" and err.reject then
                delayReject( rootPromise, unpack( err.reject ) )
            else
                local locationText = "\nContaining async function defined in " .. debugInfo.short_src .. " at line " .. debugInfo.linedefined .. "\n"
                delayReject( rootPromise, err, debug.traceback( co ), locationText )
            end
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

    if not isPromise( p ) then
        -- If not a promise, it doesn't need to be waited for
        return p
    end

    awaitType = awaitType or AwaitTypes.RETURN
    local data = { coroutine.yield( awaitFlag, p ) }
    local success = table.remove( data, 1 )

    if awaitType == AwaitTypes.RETURN then
        return success, unpack( data )
    elseif awaitType == AwaitTypes.PROPAGATE then
        if not success then
            reject( unpack( data ) )
        end

        return unpack( data )
    elseif awaitType == AwaitTypes.MESSAGE_OVERRIDE then
        reject( arg )
    elseif awaitType == AwaitTypes.HANDLER then
        if not success then
            arg( unpack( data ) )
        end

        return success, unpack( data )
    end
end

local function stringifyArgs( ... )
    local out = {}
    for k, v in pairs{ ... } do
        if istable( v ) then
            out[k] = table.ToString( v )
        else
            out[k] = tostring( v )
        end
    end
    return table.concat( out, ", " )
end

function reject( ... )
    if inAsync() then
        error( { reject = { ... } } )
    else
        error( stringifyArgs( ... ) )
    end
end

function inAsync()
    return tobool( coroutine.running() )
end

--[[
Old simpler await definition, in case we decide to change back.

-- Wait for a promise to resolve in an async function
function await( p )
    assert( coroutine.running(), "Cannot use await outside of async function" )
    return coroutine.yield( p )
end
]]
