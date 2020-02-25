NP.http = {}

-- Returns a promise that resolves after t seconds
-- fail : Should the promise reject after timeout
function NP.timeout( t, fail )
    local method = fail and "reject" or "resolve"
    local d = promise.new()
    timer.Simple( t, function()
        d[method]( d, "Timeout" )
    end )
    return d
end

local function responseSuccess( d, body, status, headers )
    -- Check body is valid Json, if not, reject
    local data = util.JSONToTable( body )
    local method = "reject"
    if math.floor( status / 100 ) == 2 and data then
        method = "resolve"
    end
    d[method]( d, data or "Invalid json response", status, headers )
end

-- http.post as a promise, resolves whenever http finishes, or never if it doesn't (Looking at you, ISteamHTTP)
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
-- method   : GET, PUT, etc.
-- endPoint : Appended to settings.apiRoot
-- params   : params for GET, POST, HEAD
-- settings : { apiRoot = "myRoot", apiKey = "myKey", timeout = 5 } - timeout only functional in NP.http.request
-- resolves to function( data, statusCode, headers )
function NP.http.requestIndef( method, endPoint, params, settings )
    method = method or "GET"
    local d = promise.new()
    local url = settings.apiRoot .. endPoint

    local struct = HTTPRequest( {
        failed = function( err )
            d:reject( err, -1 )
        end,
        success = function( status, body, headers )
            responseSuccess( d, body, status, headers )
        end,
        method = method,
        url = url,
        parameters = params,
        type = "application/json",
        Token = settings.apiKey
    } )

    HTTP( struct )
end

-- Post but with enforced timeout
-- This promise is guaranteed to resolve/reject eventually
-- url     : post url
-- data    : post args as table
-- timeout : optional timeout in seconds (def 5)
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
function NP.http.request( method, endPoint, params, settings )
    local timeout = settings.timeout or 5
    return promise.first{
        NP.http.fetchIndef( url ),
        NP.timeout( timeout, true )
    }
end