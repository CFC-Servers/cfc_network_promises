NP.http = {}

-- Returns a promise that resolves after t seconds
local timeoutId = 0
local function timeoutPromise( t )
	local d = promise.new()
	timer.Create( "timeout" .. timeoutId, t, 1, function()
		d:reject( "Timeout" )
	end )
	return d
end

-- http.post as a promise, resolves whenever http finishes, or never if it doesn't (Looking at you, ISteamHTTP)
-- url    : post url
-- data   : post args as table
-- resolves to function( statusCode, data, headers )
function NP.http.postIndef( url, data )
	local d = promise.new() -- promise itself
	http.Post( url, data, function( body, len, headers, status ) 
		-- Check body is valid Json, if not, reject
		local data = util.JSONToTable( body )
		if not data then 
			d:reject( "Invalid json response" ) 
		else
			d:resolve( status, data, headers )
		end
	end, function( err ) 
		d:reject( err )
	end )
	return d
end

-- Same as above but for fetch
function NP.http.fetchIndef( url )
	local d = promise.new()
	http.Fetch( url, function( body, len, headers, status ) 
		local data = util.JSONToTable( body )
		if not data then 
			d:reject( "Invalid json response" ) 
		else
			d:resolve( status, data, headers )
		end
	end, function( err ) 
		d:reject( err )
	end )
	return d
end

-- Post but with enforced timeout
-- This promise is guaranteed to resolve/reject eventually
-- url     : post url
-- data    : post args as table
-- timeout : optional timeout in seconds (def 5)
-- resolves to function( statusCode, data, headers )
function NP.http.post( url, data, timeout )
	timeout = timeout or 5
	return promise.first{
		NP.http.postIndef( url, data ),
		timeoutPromise( timeout )
	}
end

-- Same as above but for fetch
function NP.http.fetch( url, timeout )
	timeout = timeout or 5
	return promise.first{
		NP.http.fetchIndef( url ),
		timeoutPromise( timeout )
	}
end