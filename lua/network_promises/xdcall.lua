-- Same as pcall, but returns error message and traceback on error
function xdcall( func, ... )
    local traceback
    local data = { xpcall( func, function( err )
        traceback = debug.traceback()
        return err
    end, ... ) }

    local success = table.remove( data, 1 )

    if success then
        return true, unpack( data )
    end

    return false, data[1], traceback
end
