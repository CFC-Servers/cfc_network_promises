require( "cfc_detached_timer" )

local deferred = include( "network_promises/include/deferred.lua" )
promise = deferred -- Create global promise variable for other scripts

networkPromise = {}
NP = networkPromise -- shorthand name, networkPromise will get a bit cumbersome

include( "network_promises/http.lua" )
include( "network_promises/net.lua" )
include( "network_promises/async.lua" )
include( "network_promises/util.lua" )

-- Returns a promise that resolves after t seconds
-- fail : Should the promise reject after timeout
function NP.timeout( t, fail )
    local prom = promise.new()
    local method = fail and prom.reject or prom.resolve

    dTimer.Simple( t, function()
        method( prom, "Timeout" )
    end )

    return prom
end
