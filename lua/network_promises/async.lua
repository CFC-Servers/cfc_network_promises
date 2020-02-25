local promiseReturn

promiseReturn = function( co, state, ownP, debugInfo )
	return function( ... )
		local isRoot = ownP == nil
		if isRoot then
			ownP = promise.new()
		end

		local ret
		if state ~= nil then
			ret = { coroutine.resume( co, state, ... ) }
		else
			ret = { coroutine.resume( co, ... ) }
		end
		local ok = ret[1]
		if ok then
			if ret[2] and ret[2].next then
				ret[2]:next( promiseReturn( co, true, ownP, debugInfo ), promiseReturn( co, false, ownP, debugInfo ) )
			else
				table.remove( ret, 1 )
				-- Delay to escape any enclosing pcalls
				timer.Simple( 0, function()
					if state then
						ownP:resolve( unpack( ret ) )
					else
						ownP:reject( unpack( ret ) )
					end
				end )
			end
		else
			-- Delay to escape any enclosing pcalls
			timer.Simple( 0, function()
				ownP:reject( ret[2], "\nContaining async function defined in " .. debugInfo.short_src .. " at line " .. debugInfo.linedefined .. "\n" )
			end )
		end

		if isRoot then
			return ownP
		end
	end
end

-- Make a function async
function async( f )
	-- Debug info for error locations as they are propagated down the promise chain, and their location is lost in the stack
	return promiseReturn( coroutine.create( f ), nil, nil, debug.getinfo( f, "S" ) )
end

-- Make a function async and call it
function asyncCall( f )
	return async( f )()
end

-- Wait for a promise to resolve in an async function
function await( p, errHandler )
	assert( coroutine.running(), "Cannot use await outside of async function" )
	return coroutine.yield( p )
end

