local deferred = include( "network_promises/include/deferred.lua" )
promise = deferred -- Create global promise variable for other scripts

networkPromise = {}
NP = networkPromise -- shorthand name, networkPromise will get a bit cumbersome

include( "network_promises/http.lua" )
include( "network_promises/net.lua" )
include( "network_promises/async.lua" )
include( "network_promises/xdcall.lua" )