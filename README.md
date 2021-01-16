
# cfc_network_promises
Network-based promise library

## Requirements
- [cfc_detached_timer](https://github.com/CFC-Servers/cfc_detached_timer)

## Async + Await
This project implements a C#/javascript style async and await functionality.  
Similarly to Javascript, this is built on top of promises.  

The `await` function takes a promise, and stops the execution thread until that promise resolves or rejects.  
However, `await` can only be used in an `async` function, defined as `myFunc = async(function( a, b ) /* My code */end)`  

`async` functions return a promise, and thus can be used in `await` themselves. This allows you to chain async functions as you would with promises.

## Usage
 - `NP.net.send( name, ... )`  
Send a net message on `name` containing the varargs `...`, no need for any `net.WriteString` or likewise.  
Returns a promise resolving or rejecting with whatever data returned via `NP.net.receive()`  
**Note:** This function sends more than just the varargs, only receive this with `NP.net.receive()`  

 - `NP.net.sendBlind( name, ... )`  
 Similar to `NP.net.send` but it does not wait for a response from the server, the returned promise resolves immediately.
 **Note:** Any data returned by `NP.net.receive` from a blind message is discarded.

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

- `NP.http.request( method, endPoint, params, settings )`  
This is a more in-depth way to make http requests, the arguments are as follows:  
  - `method` - One of [these http methods](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods)
  - `endPoint` - The endpoint string to be appended to settings.apiRoot
  - `params` - Parameters for GET, POST, HEAD
  - `settings` - In the following structure:
    ```lua
    {
      apiRoot: "http://www.mywebsite.com/",
      apikey: "somesupersecretkey",
      timeout: 5 -- optional
    }
    ```

- `async( func )`  
Wraps the function `func` in a coroutine, passing any arguments onto it. This is required for `await` to be used.  
The new function will return a promise, which will resolve with any return args of the inner function, or reject with any errors.  

- `asyncCall( func )`  
Equivalent to calling `async( func )()` but nicer looking.  

- `await( promise )`  
Halts an enclosing coroutine until the promise resolves/rejects, returns `resolved, ...` where `...` are the return args of the promise, or the error.  
**NOTE:** This MUST be called within an async function.

## Example
Server side:
```lua
    -- "getData" automatically pooled by this function.
    -- Receive on getData, return the result of fetching the scripting url
    NP.net.receive( "getData", function( ply )
        return NP.http.fetch( "https://cfcservers.org/getData" )
    end )

    -- Alternative implementation:
    NP.net.receive( "getData", async( function( ply )
        local success, body, status = await( NP.http.fetch( "https://cfcservers.org/getData" ) )
        if success then
            return body, status
        else
            error( "Failed to reach end point" )
        end
    end ) )
```
Client side:
```lua
    -- Send net message, print result or error
    NP.net.send( "getData" ):next( function( body, status, headers )
        -- Success
        print( status ) -- Hopefully 200
        PrintTable( util.JSONToTable( body ) ) -- Some data
    end, function( err )
        -- Failure
        print( "Error: ", err )
    end )

    -- Alternative implementation:
    asyncCall( function()
        -- Thread is halted until the net send finishes, allowing you to treat it as a synchronous function.
        local success, body, status = await( NP.net.send( "getData" ) )
        if success then
            print( status )
            PrintTable( util.JSONToTable( body ) )
        else
            print( "Error: ", err )
        end
    end )
```


## Credit
The deferred library (`lua/network_promises/include/deferred.lua`) was written by [zserge](https://github.com/zserge), [here](https://github.com/zserge/lua-promises), and modified for CFC to support varargs in promise resolves and rejects.
