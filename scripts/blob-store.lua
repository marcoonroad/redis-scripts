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

local function encode (json)
        return cmsgpack.pack (cjson.decode (json))
end

local function decode (msgpack)
        return cjson.encode (cmsgpack.unpack (msgpack))
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
