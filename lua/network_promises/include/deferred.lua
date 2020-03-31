-- This lib was written by zserge, https://github.com/zserge/lua-promises
-- Modified for CFC to allow varargs in resolve and reject, along with enforcing rejected promises to be handled

--- A+ promises in Lua.
--- @module deferred

local M = {}

local Deferred = {}
Deferred.__index = Deferred

local PENDING = 0
local RESOLVING = 1
local REJECTING = 2
local RESOLVED = 3
local REJECTED = 4

local function finish( deferred, state )
    state = state or REJECTED
    for i, f in ipairs( deferred.queue ) do
        if state == RESOLVED then
            f:resolve( unpack( deferred.value ) )
        else
            f:reject( unpack( deferred.value ) )
        end
    end
    if state == REJECTED and #deferred.queue == 0 then
        timer.Simple( 0, function()
            local errText = ""
            for k, v in ipairs( deferred.value ) do
                if type( v ) == "table" then
                    errText = errText .. table.ToString( v ) .. "\n"
                else
                    errText = errText .. tostring( v ) .. "\n"
                end
            end
            if #errText > 500 then
                errText = errText:sub( 1, 500 ) .. "..."
            end
            error( "Uncaught rejection or exception in promise:\n" .. errText .. "IGNORE FOLLOWING 4 LINES" )
        end )
    end
    deferred.state = state
end

local function promise( deferred, next, success, failure, nonpromisecb )
    if type( deferred ) == "table" and type( deferred.value[1] ) == "table" and isfunction( next ) then
        local called = false
        local ok, err, stack = xdcall( next, deferred.value[1], function( ... )
            if called then return end
            called = true
            deferred.value = { ... }
            success()
        end, function( ... )
            if called then return end
            called = true
            deferred.value = { ... }
            failure()
        end )
        if not ok and not called then
            deferred.value = { err, stack }
            failure()
        end
    else
        nonpromisecb()
    end
end

local function fire( deferred )
    local next
    if type( deferred.value[1] ) == "table" then
        next = deferred.value[1].next
    end
    promise( deferred, next, function()
        deferred.state = RESOLVING
        fire( deferred )
    end, function()
        deferred.state = REJECTING
        fire( deferred )
    end, function()
        local ok
        local v
        if deferred.state == RESOLVING and isfunction( deferred.success ) then
            local ret = { xdcall( deferred.success, unpack( deferred.value ) ) }
            ok = table.remove( ret, 1 )
            v = ret
            if not ok then
                table.insert( ret, "\nContaining next defined in " .. deferred.successInfo.short_src ..
                    " at line " .. deferred.successInfo.linedefined .. "\n" )
            end
        elseif deferred.state == REJECTING  and isfunction( deferred.failure ) then
            local ret = { xdcall( deferred.failure, unpack( deferred.value ) ) }
            ok = table.remove( ret, 1 )
            v = ret
            if ok then
                deferred.state = RESOLVING
            else
                table.insert( ret, "\nContaining next defined in " .. deferred.failureInfo.short_src ..
                    " at line " .. deferred.failureInfo.linedefined .. "\n" )
            end
        end

        if ok ~= nil then
            if ok then
                deferred.value = v
            else
                deferred.value = v
                return finish( deferred )
            end
        end

        if deferred.value[1] == deferred then
            deferred.value = { pcall( error, "resolving promise with itself" ) }
            return finish( deferred )
        else
            promise( deferred, next, function()
                finish( deferred, RESOLVED )
            end, function( state )
                finish( deferred, state )
            end, function()
                finish( deferred, deferred.state == RESOLVING and RESOLVED )
            end )
        end
    end )
end

local function resolve( deferred, state, ... )
    if deferred.state == PENDING then
        deferred.value = { ... }
        deferred.state = state
        fire( deferred )
    end
    return deferred
end

--
-- PUBLIC API
--
function Deferred:resolve( ... )
    return resolve( self, RESOLVING, ... )
end

function Deferred:reject( ... )
    return resolve( self, REJECTING, ... )
end

--- Returns a new promise object.
--- @treturn Promise New promise
--- @usage
--- local deferred = require( "deferred" )
---
--- --
--- -- Converting callback-based API into promise-based is very straightforward:
--- --
--- -- 1 ) Create promise object
--- -- 2 ) Start your asynchronous action
--- -- 3 ) Resolve promise object whenever action is finished ( only first resolution
--- --    is accepted, others are ignored )
--- -- 4 ) Reject promise object whenever action is failed ( only first rejection is
--- --    accepted, others are ignored )
--- -- 5 ) Return promise object letting calling side to add a chain of callbacks to
--- --    your asynchronous function
---
--- function read( f )
---   local d = deferred.new()
---   readasync( f, function( contents, err )
---       if err == nil then
---         d:resolve( contents )
---       else
---         d:reject( err )
---       end
---   end )
---   return d
--- end
---
--- -- You can now use read() like this:
--- read( "file.txt" ):next( function( s )
---     print( "File.txt contents: ", s )
---   end, function( err )
---     print( "Error", err )
--- end )
function M.new( options )
    if isfunction( options ) then
        local d = M.new()
        local ok, err = pcall( options, d )
        if not ok then
            d:reject( err )
        end
        return d
    end
    options = options or {}
    local d
    d = {
        next = function( self, success, failure )
            local next = M.new( { success = success, failure = failure, extend = options.extend } )
            if d.state == RESOLVED then
                next:resolve( unpack( d.value ) )
            elseif d.state == REJECTED then
                next:reject( unpack( d.value ) )
            else
                table.insert( d.queue, next )
            end
            return next
        end,
        state = PENDING,
        queue = {},
        success = options.success,
        failure = options.failure,
    }
    if options.success and isfunction( options.success ) then
        d.successInfo = debug.getinfo( options.success, "S" )
    end
    if options.failure and isfunction( options.failure ) then
        d.failureInfo = debug.getinfo( options.failure, "S" )
    end
    d = setmetatable( d, Deferred )
    if isfunction( options.extend ) then
        options.extend( d )
    end
    return d
end

--- Returns a new promise object that is resolved when all promises are resolved/rejected.
--- @param args list of promise
--- @treturn Promise New promise
--- @usage
--- deferred.all( {
---     http.get( "http://example.com/first" ),
---     http.get( "http://example.com/second" ),
---     http.get( "http://example.com/third" ),
---   } ):next( function( results )
---       -- handle results here ( all requests are finished and there has been
---       -- no errors )
---     end, function( results )
---       -- handle errors here ( all requests are finished and there has been
---       -- at least one error )
---   end )
function M.all( args )
    local d = M.new()
    if #args == 0 then
        return d:resolve( {} )
    end
    local method = "resolve"
    local pending = #args
    local results = {}
    local multi = false

    local function synchronizer( i, resolved )
        return function( ... )
            local data = { ... }
            results[i] = data
            if #d > 1 then
                multi = true
            end

            if not resolved then
                method = "reject"
            end
            pending = pending - 1
            if pending == 0 then
                if not multi then
                    for k, v in ipairs( results ) do
                        results[k] = v[1]
                    end
                end
                d[method]( d, results )
            end
            return ...
        end
    end

    for i = 1, pending do
        args[i]:next( synchronizer( i, true ), synchronizer( i, false ) )
    end
    return d
end

--- Returns a new promise object that is resolved with the values of sequential application of function fn to each element in the list. fn is expected to return promise object.
--- @function map
--- @param args list of promise
--- @param fn promise used to resolve the list of promise
--- @return a new promise
--- @usage
--- local items = {"a.txt", "b.txt", "c.txt"}
--- -- Read 3 files, one by one
--- deferred.map( items, read ):next( function( files )
---     -- here files is an array of file contents for each of the files
---   end, function( err )
---     -- handle reading error
--- end )
function M.map( args, fn )
    local d = M.new()
    local results = {}
    local function donext( i )
        if i > #args then
            d:resolve( results )
        else
            fn( args[i] ):next( function( res )
                table.insert( results, res )
                donext( i + 1 )
            end, function( err )
                d:reject( err )
            end )
        end
    end
    donext( 1 )
    return d
end

--- Returns a new promise object that is resolved as soon as the first of the promises gets resolved/rejected.
--- @param args list of promise
--- @treturn Promise New promise
--- @usage
--- -- returns a promise that gets rejected after a certain timeout
--- function timeout( sec )
---   local d = deferred.new()
---   settimeout( function()
---       d:reject( "Timeout" )
---     end, sec )
---   return d
--- end
---
--- deferred.first( {
---     read( somefile ), -- resolves promise with contents, or rejects with error
---     timeout( 5 ),
---   } ):next( function( result )
---       -- file was read successfully...
---     end, function( err )
---       -- either timeout or I/O error...
---   end )
function M.first( args )
    local d = M.new()
    for _, v in ipairs( args ) do
        v:next( function( ... )
            d:resolve( ... )
        end, function( ... )
            d:reject( ... )
        end )
    end
    return d
end

--- A promise is an object that can store a value to be retrieved by a future object.
--- @type Promise

--- Wait for the promise object.
--- @function next
--- @tparam function cb resolve callback ( function( value ) end )
--- @tparam[opt] function errcb rejection callback ( function( reject_value ) end )
--- @usage
--- -- Reading two files sequentially:
--- read( "first.txt" ):next( function( s )
---     print( "File file:", s )
---     return read( "second.txt" )
--- end ):next( function( s )
---     print( "Second file:", s )
--- end ):next( nil, function( err )
---     -- error while reading first or second file
---     print( "Error", err )
--- end )

--- Resolve promise object with value.
--- @function resolve
--- @param value promise value
--- @return resolved future result

--- Reject promise object with value.
--- @function reject
--- @param value promise value
--- @return rejected future result

return M
