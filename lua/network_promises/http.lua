NP.http = {}

local function responseSuccess( prom, body, status, headers )
    local isSuccessStatus = math.floor( status / 100 ) == 2

    if isSuccessStatus then
        prom:resolve( body, status, headers )
    else
        prom:reject( body, status, headers )
    end
end

-- http.post as a promise, resolves whenever http finishes, or never if it doesn't ( Looking at you, ISteamHTTP )
-- url    : post url
-- data   : post args as table
-- resolves to function( data, statusCode, headers )
function NP.http.postIndef( url, data )
    local prom = promise.new() -- promise itself

    local function onSuccess( body, _, headers, status )
        responseSuccess( prom, body, status, headers )
    end

    local function onFailure( err )
        prom:reject( err, -1 )
    end

    http.Post( url, data, onSuccess, onFailure )

    return prom
end

-- Same as above but for fetch
function NP.http.fetchIndef( url )
    local prom = promise.new() -- promise itself

    local function onSuccess( body, _, headers, status )
        responseSuccess( prom, body, status, headers )
    end

    local function onFailure( err )
        prom:reject( err, -1 )
    end

    http.Fetch( url, onSuccess, onFailure )

    return prom
end

-- HTTP as a promise, resolves whenever http finishes, or never if it doesn't (Looking at you, ISteamHTTP)
-- method    : GET, PUT, etc.
-- url       :
-- overrides : Table to be merged with the http struct (includes authToken as Token alias)
-- resolves to function( data, statusCode, headers )
function NP.http.requestIndef( method, url, overrides )
    method = method or "GET"
    overrides = overrides or {}

    local prom = promise.new()

    local struct = {
        failed = function( err )
            prom:reject( err, -1 )
        end,
        success = function( status, body, headers )
            responseSuccess( prom, body, status, headers )
        end,
        method = method,
        url = url,
        parameters = overrides.params,
        type = "application/json",
        headers = {}
    }

    table.Merge( struct, overrides )
    struct.headers.Authorization = overrides.authToken
    if struct.parameters then
        struct.body = util.TableToJSON( struct.parameters )
    end

    HTTP( struct )

    return prom
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
