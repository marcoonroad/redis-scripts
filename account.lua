--
-- === Account Abstract Datatype ===
--
-- Usage:
--    EVALSHA <hash> 1 <key>     OPEN
--    EVALSHA <hash> 1 <key>  BALANCE
--    EVALSHA <hash> 1 <key>  DEPOSIT <amount>
--    EVALSHA <hash> 1 <key> WITHDRAW <amount>
--    EVALSHA <hash> 1 <key>   LOCKED
--    EVALSHA <hash> 1 <key>     LOCK <amount>
--    EVALSHA <hash> 1 <key>   UNLOCK <amount>
--
--    EVALSHA <hash> 2 <source> <target> TRANSFER <amount>
--
--------------------------------------------------------------------------------

local function positive (value)
        local number = tonumber (value)

        if number > 1 then
                return number

        else
                local message = "Invalid number - must be greater than 1"

                error (message)
        end
end

--------------------------------------------------------------------------------

local function OPEN (account)
        redis.call ('HSETNX', account, 'balance', 0)
        redis.call ('HSETNX', account, 'locked', 0)
end

local function BALANCE (account)
        return tonumber (redis.call ('HGET', account, 'balance'))
end

local function LOCKED (account)
        return tonumber (redis.call ('HGET', account, 'locked'))
end

local function LOCK (account, amount)
        local balance = BALANCE (account)
        local locked  = LOCKED  (account)

        if (amount + locked) > balance then
                local message = "Can't lock more than funds for account: %s"

                error (string.format (message, account))

        else
                redis.call ('HINCRBY', account, 'locked', amount)
        end
end

local function UNLOCK (account, amount)
        local locked = LOCKED (account)

        if amount > locked then
                local message = "Can't unlock more than locked for account: %s"

                error (message)

        else
                redis.call ('HSET', account, 'locked', locked - amount)
        end
end

local function DEPOSIT (account, amount)
        redis.call ('HINCRBY', account, 'balance', amount)
end

local function WITHDRAW (account, amount)
        local locked  = LOCKED  (account)
        local balance = BALANCE (account)

        if (locked + amount) > balance then
                local message = "Insufficient funds for account: %s"

                error (string.format (message, account))

        else
                redis.call ('HSET', account, 'balance', balance - amount)
        end
end

local function TRANSFER (source, amount, target)
        WITHDRAW (source, amount)
        DEPOSIT  (target, amount)
end

--------------------------------------------------------------------------------

local command = string.upper (ARGV[ 1 ])

if command == 'OPEN' then
        local account = KEYS[ 1 ]

        OPEN (account)

elseif command == 'BALANCE' then
        local account = KEYS[ 1 ]

        return BALANCE (account)

elseif command == 'LOCKED' then
        local account = KEYS[ 1 ]

        return LOCKED (account)

elseif command == 'LOCK' then
        local account = KEYS[ 1 ]
        local amount  = positive (ARGV[ 2 ])

        return LOCK (account, amount)

elseif command == 'UNLOCK' then
        local account = KEYS[ 1 ]
        local amount  = positive (ARGV[ 2 ])

        return UNLOCK (account, amount)

elseif command == 'DEPOSIT' then
        local account = KEYS[ 1 ]
        local amount  = positive (ARGV[ 2 ])

        DEPOSIT (account, amount)

elseif command == 'WITHDRAW' then
        local account = KEYS[ 1 ]
        local amount  = positive (ARGV[ 2 ])

        WITHDRAW (account, amount)

elseif command == 'TRANSFER' then
        local source = KEYS[ 1 ]
        local amount = positive (ARGV[ 2 ])
        local target = KEYS[ 2 ]

        TRANSFER (source, amount, target)

else
        local message = "Invalid account command: %s"

        error (string.format (message, command))
end

return true
