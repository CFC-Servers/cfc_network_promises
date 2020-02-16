
# cfc_network_promises
Network-based promise library

## Usage
 - `NP.net.send( name, ... )`
Send a net message on `name` containing the varargs `...`, no need for any `net.WriteString` or likewise.
Returns a promise resolving or rejecting with whatever data returned via `NP.net.receive()`
**Note:** This function sends more than just the varargs, only receive this with `NP.net.receive()`

 - `NP.net.receive( name, func )`
Receive a net message on `name` calling `func`, where func is of the form:
`function( callingPly, ... )`
The `...` will be whatever they were in the corresponding `NP.net.send()`
**Note:** Both send and receive will check if the name is already pooled, and if not, will add it as a network string ( `NP.net.send` will still error if called on client using an unpooled name )

- `NP.http.post( url, data, timeout )`
Post data to a `url`, with an optional `timeout` ( defaulting to 5 seconds ).
Returns a promise resolving in the form:
`function( statusCode, jsonData, headers )`
where jsonData is parsed from the post body, or rejecting in the form:
`function ( errorStr )`
**Note:** The url must return in JSON, if the JSON cannot be parsed with `util.JSONToTable()` then the promise will reject.

- `NP.http.fetch( url, timeout )`
Identical to `NP.http.post()` but fetches instead.

## Example
Server side:
```lua
	-- "getData" automatically pooled by this function.
	-- Receive on getServerStatus, return the result of fetching the scripting url
	NP.net.receive( "getData", function( ply )
		return NP.http.fetch( "https://my.website.com/getData" )
	end )
```
Client side:
```lua
	-- Send net message, print result or error
	NP.net.send( "getData" ):next( function( status, data )
		-- Success
		print( status ) -- Hopefully 200
		PrintTable( data ) -- Some data
	end, function( err )
		-- Failure
	    print( "Error: ", err )
	end )
```
## Credit
The deferred library (`lua/network_promises/include/deferred.lua`) was written by [zserge](https://github.com/zserge), [here](https://github.com/zserge/lua-promises), and modified for CFC to support varargs in promise resolves and rejects.
