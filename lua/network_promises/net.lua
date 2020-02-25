NP.net = {}
local netSendId = 0
local netSends = {}

-- I don't know if we want this, could be convenient, remove if not.
local function ensureNetworkString( str )
    local pooled = util.NetworkStringToID( str ) ~= 0
    if SERVER and not pooled then util.AddNetworkString( str ) end
end

-- Send a net message with vararg data, requires receiver to use NP.net.receive
-- name : net message name
-- ...  : netArg1, netArg2
function NP.net.send( name, ... )
    ensureNetworkString( name )
    local d = promise.new()
    net.Start( name )
    net.WriteInt( netSendId, 16 )
    net.WriteTable{ ... }
    net.SendToServer()

    -- Incase a message is sent multiple times before a reply
    -- Store it to a table so the correct response matches the correct promise
    netSends[netSendId] = d
    net.Receive( name, function( len, ply )
        local id = net.ReadInt( 16 )
        local success = net.ReadBool()
        local p = netSends[id]
        if not p then return end
        if success then
            p:resolve( unpack( net.ReadTable() ) )
        else
            p:reject( unpack( net.ReadTable() ) )
        end
    end )

    return d
end

-- net.Receive wrapper that removes need for net.ReadThis and net.ReadThat
-- name : net message name
-- func : function( player, netArg1, netArg2 )
function NP.net.receive( name, func )
    ensureNetworkString( name )
    net.Receive( name, function( len, ply )
        local id = net.ReadInt( 16 )
        local data = net.ReadTable()
        local ret = { func( ply, unpack( data ) ) }

        local function finish( status, args )
            net.Start( name )
            net.WriteInt( id, 16 )
            net.WriteBool( status )
            net.WriteTable( args )
            net.Send( ply )
        end
        if ret[1] and type(ret[1]) == "table" and ret[1].next then
            ret[1]:next( function( ... )
                finish( true, { ... } )
            end,
            function( ... )
                finish( false, { ... } )
            end )
        else
            finish( true, ret )
        end

    end )
end
