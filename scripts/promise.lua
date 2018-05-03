--
-- === Promise Abstract Data Type ===
--
-- Usage:
--    EVALSHA <hash> 2 <key> <channel> START           ==> 1
--    EVALSHA <hash> 1 <key>           STATUS          ==> string
--    EVALSHA <hash> 1 <key>           FULFILL <value> ==> 1
--    EVALSHA <hash> 1 <key>           REJECT  <value> ==> 1
--    EVALSHA <hash> 1 <key>           RESULT          ==> value
--
-- See more:
--
--    https://en.wikipedia.org/wiki/Futures_and_promises
--
--------------------------------------------------------------------------------

local function convert (value)
        local result = tonumber (value)

        if rawequal (result, nil) then
                return value

        else
                return result
        end
end

--------------------------------------------------------------------------------

local function START (promise, future)
        redis.call ('HSETNX', promise, 'status', 'PENDING')
        redis.call ('HSETNX', promise, 'future',  future)
        redis.call ('HSETNX', promise, 'result',  0)
end

local function STATUS (promise)
        return redis.call ('HGET', promise, 'status')
end

local function resolve (promise, status, value)
        local current = STATUS (promise)

        if current == 'PENDING' then
                redis.call ('HSET', promise, 'status',  status)
                redis.call ('HSET', promise, 'result',  value)

                local event = cjson.encode ({
                        promise = promise,
                        status  = status,
                        result  = value,
                })

                local future = redis.call ('HGET', promise, 'future')

                redis.call ('PUBLISH', future, event)

        else
                local message = "The promise is already resolved for: %s"

                error (string.format (message, promise))
        end
end

local function FULFILL (promise, value)
        return resolve (promise, 'FULFILLED', value)
end

local function REJECT (promise, value)
        return resolve (promise, 'REJECTED', value)
end

local function RESULT (promise)
        local status = STATUS (promise)
        local result = redis.call ('HGET', promise, 'result')

        if status == 'FULFILLED' then
                return convert (result)

        elseif status == 'REJECTED' then
                error (tostring (result))

        else
                return nil
        end
end

--------------------------------------------------------------------------------

local command = string.upper (ARGV[ 1 ])

if command == 'START' then
        local promise = KEYS[ 1 ]
        local future  = KEYS[ 2 ]

        START (promise, future)

elseif command == 'FULFILL' then
        local promise = KEYS[ 1 ]
        local value   = convert (ARGV[ 2 ])

        FULFILL (promise, value)

elseif command == 'REJECT' then
        local promise = KEYS[ 1 ]
        local value   = convert (ARGV[ 2 ])

        REJECT (promise, value)

elseif command == 'STATUS' then
        local promise = KEYS[ 1 ]

        return STATUS (promise)

elseif command == 'RESULT' then
        local promise = KEYS[ 1 ]

        return RESULT (promise)

else
        local message = "Invalid command for promises: %s"

        error (string.format (message, command))
end

return true
