local deferred = include( "network_promises/include/deferred.lua" )
promise = deferred -- Create global promise variable for other scripts

networkPromise = {}
NP = networkPromise -- shorthand name, networkPromise will get a bit cumbersome

include( "network_promises/http.lua" )
include( "network_promises/net.lua" )

-- Remove this for example
do return end

-- Example:
if CLIENT then
	-- Send net message, print result or error
	NP.net.send( "getFactions" ):next( function( status, data )
		print( status )
		PrintTable( data )
	end, function( err )
	    print( "Error: ", err )
	end )
else
	-- Receive on getServerStatus, return the result of fetching the scripting url
	NP.net.receive( "getFactions", function( ply )
		return NP.http.fetch( "https://factions.cfcservers.org/dev/factions" )
	end )
end