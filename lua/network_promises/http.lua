NP.http = {}

-- Returns a promise that resolves after t seconds
-- fail : Should the promise reject after timeout
function NP.timeout( t, fail )
    local d = promise.new()
    local method = fail and d.reject or d.resolve
    timer.Simple( t, function()
        method( d, "Timeout" )
    end )
    return d
end

local function responseSuccess( d, body, status, headers )
    if math.floor( status / 100 ) == 2 then
        d:resolve( body, status, headers )
    else
        d:reject( body, status, headers )
    end
end

-- http.post as a promise, resolves whenever http finishes, or never if it doesn't ( Looking at you, ISteamHTTP )
-- url    : post url
-- data   : post args as table
-- resolves to function( data, statusCode, headers )
function NP.http.postIndef( url, data )
    local d = promise.new() -- promise itself
    http.Post( url, data, function( body, len, headers, status )
        responseSuccess( d, body, status, headers )
    end, function( err )
        d:reject( err, -1 )
    end )
    return d
end

-- Same as above but for fetch
function NP.http.fetchIndef( url )
    local d = promise.new()
    http.Fetch( url, function( body, len, headers, status )
        responseSuccess( d, body, status, headers )
    end, function( err )
        d:reject( err, -1 )
    end )
    return d
end

-- HTTP as a promise, resolves whenever http finishes, or never if it doesn't (Looking at you, ISteamHTTP)
-- method    : GET, PUT, etc.
-- url       : 
-- overrides : Table to be merged with the http struct (includes authToken as Token alias)
-- resolves to function( data, statusCode, headers )
function NP.http.requestIndef( method, url, overrides )
    method = method or "GET"
    local d = promise.new()
    overrides = overrides or {}

    local struct = {
        failed = function( err )
            d:reject( err, -1 )
        end,
        success = function( status, body, headers )
            responseSuccess( d, body, status, headers )
        end,
        method = method,
        url = url,
        parameters = overrides.params,
        type = "application/json",
        Token = overrides.authToken
    }

    table.Merge( struct, overrides )
    HTTP( struct )

    return d
end

-- Post but with enforced timeout
-- This promise is guaranteed to resolve/reject eventually
-- url     : post url
-- data    : post args as table
-- timeout : optional timeout in seconds ( def 5 )
-- resolves to function( data, statusCode, headers )
function NP.http.post( url, data, timeout )
    timeout = timeout or 5
    return promise.first{
        NP.http.postIndef( url, data ),
        NP.timeout( timeout, true )
    }
end

-- Same as above but for fetch
function NP.http.fetch( url, timeout )
    timeout = timeout or 5
    return promise.first{
        NP.http.fetchIndef( url ),
        NP.timeout( timeout, true )
    }
end

-- Same as above but for request
function NP.http.request( method, url, overrides )
    overrides = overrides or {}
    local timeout = overrides.timeout or 5
    return promise.first{
        NP.http.requestIndef( method, url, overrides ),
        NP.timeout( timeout, true )
    }
end