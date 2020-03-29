local promiseReturn

promiseReturn = function( f, coInput, state, ownPInput, debugInfo )
    return function( ... )
        local ownP = ownPInput
        local isRoot = ownP == nil
        local co = coInput
        if isRoot then
            ownP = promise.new()
            co = coroutine.create( f )
        end

        local ret
        if state ~= nil then
            ret = { coroutine.resume( co, state, ... ) }
        else
            ret = { coroutine.resume( co, ... ) }
        end
        local ok = ret[1]
        if ok then
            if ret[2] and type( ret[2] ) == "table" and ret[2].next then
                ret[2]:next( promiseReturn( f, co, true, ownP, debugInfo ), promiseReturn( f, co, false, ownP, debugInfo ) )
            else
                table.remove( ret, 1 )
                -- Delay to escape any enclosing pcalls
                timer.Simple( 0, function()
                    if state ~= false then
                        ownP:resolve( unpack( ret ) )
                    else
                        ownP:reject( unpack( ret ) )
                    end
                end )
            end
        else
            -- Delay to escape any enclosing pcalls
            timer.Simple( 0, function()
                ownP:reject( ret[2], "\nContaining async function defined in " .. debugInfo.short_src .. " at line " .. debugInfo.linedefined .. "\n" )
            end )
        end

        if isRoot then
            return ownP
        end
    end
end

-- Make a function async
function async( f )
    -- Debug info for error locations as they are propagated down the promise chain, and their location is lost in the stack
    return promiseReturn( f, nil, nil, nil, debug.getinfo( f, "S" ) )
end

-- Make a function async and call it
function asyncCall( f )
    return async( f )()
end

-- Wait for a promise to resolve in an async function
function await( p )
    assert( coroutine.running(), "Cannot use await outside of async function" )
    return coroutine.yield( p )
end

--[[

Possible new await implementation??

ERROR_RETURN = 0
ERROR_PROPAGATE = 1
ERROR_MESSAGE_OVERRIDE = 2
ERROR_HANDLER = 3

-- Wait for a promise to resolve in an async function
function await( p, awaitType, arg )
    assert( coroutine.running(), "Cannot use await outside of async function" )

    awaitType = awaitType or ERROR_RETURN
    local data = { coroutine.yield( p ) }
    local success = table.remove( data, 1 )

    if awaitType == ERROR_RETURN then
        return success, unpack( data )
    elseif awaitType == ERROR_PROPAGATE then
        if success then
            return unpack( data )
        else
            error( data[1] )
        end
    elseif awaitType == ERROR_MESSAGE_OVERRIDE then
        error( arg )
    elseif awaitType == ERROR_HANDLER then
        if not success then
            arg( unpack( data ) )
        end
        return success, unpack( data )
    end
end
]]