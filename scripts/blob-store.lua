--
-- === Content-Addressable "BLOB" Store ===
--
-- Usage:
--
--    EVALSHA <hash> 1 <key> APPEND <json> ==> id
--    EVALSHA <hash> 1 <key> ACCESS <id>   ==> json
--
-- See more:
--
--    https://en.wikipedia.org/wiki/Content-addressable_storage
--
--------------------------------------------------------------------------------

local function pack (data)
        if type (data) == 'table' then
                local keys   = { }
                local values = { }

                for key, _ in pairs (data) do
                        table.insert (keys, key)
                end

                table.sort (keys)

                for index = 1, #keys do
                        local key   = keys[ index ]
                        local value = data[ key ]

                        values[ index ] = pack (value)
                end

                return {
                        keys   = keys,
                        values = values,
                }

        else
                return data
        end
end

local function unpack (data)
        if type (data) == 'table' then
                local result = { }

                for index = 1, #data.keys do
                        local key   = data.keys[ index ]
                        local value = data.values[ index ]

                        result[ key ] = unpack (value)
                end

                return result

        else
                return data
        end
end

local function encode (json)
        return cmsgpack.pack (pack (cjson.decode (json)))
end

local function decode (msgpack)
        return cjson.encode (unpack (cmsgpack.unpack (msgpack)))
end

--------------------------------------------------------------------------------

local function APPEND (store, json)
        local msgpack = encode (json)
        local hash    = redis.sha1hex (msgpack)

        redis.call ('HSET', store, hash, msgpack)

        return hash
end

local function ACCESS (store, hash)
        local msgpack = redis.call ('HGET', store, hash)

        return decode (msgpack)
end

--------------------------------------------------------------------------------

local command = string.upper (ARGV[ 1 ])

if command == 'APPEND' then
        local store = KEYS[ 1 ]
        local json  = ARGV[ 2 ]

        return APPEND (store, json)

elseif command == 'ACCESS' then
        local store = KEYS[ 1 ]
        local hash  = ARGV[ 2 ]

        return ACCESS (store, hash)

else
        local message = "Unknown command for blob store: %s"

        error (string.format (message, command))
end
