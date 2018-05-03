require 'busted.runner' ( )

describe ("promise redis script -", function ( )
        local script
        local cuid
        local lunajson
        local redis
        local publisher
        local subscriber
        local hash
        local alive
        local promises
        local futures

        setup (function ( )
                for line in io.lines ("./scripts/promise.lua") do
                        script = (script and script .. "\n" or "") ..line
                end

                cuid     = require 'cuid'
                lunajson = require 'lunajson'
                redis    = require 'redis'

                publisher = redis.connect ('127.0.0.1', 6379)

                publisher: config ('set', 'save', '')

                hash   = publisher: script ('load', script)
                script = nil
        end)

        teardown (function ( )
                publisher: quit ( )
        end)

        before_each (function ( )
                subscriber = redis.connect ('127.0.0.1', 6379)
                subscriber: config ('set', 'save', '')

                alive = publisher: ping ( ) and subscriber: ping ( )
                promises = {
                        "promise:" .. cuid.generate ( ),
                }
                futures = {
                        "future:" .. cuid.generate ( ),
                }
        end)

        after_each (function ( )
                publisher:  flushdb ( )
                subscriber: flushdb ( )
                subscriber: quit ( )
        end)

        randomize ( )

        it ("should be able to create promises", function ( )
                assert.truthy (alive)

                publisher: evalsha (
                        hash, 2, promises[ 1 ], futures[ 1 ], 'START'
                )

                local status = publisher: evalsha (
                        hash, 1, promises[ 1 ], 'STATUS'
                )

                assert.same (status, 'PENDING')
        end)

        it ("should be able to fulfill promises", function ( )
                assert.truthy (alive)

                subscriber: subscribe (futures[ 1 ])

                publisher: evalsha (
                        hash, 2, promises[ 1 ], futures[ 1 ], 'START'
                )

                publisher: evalsha (
                        hash, 1, promises[ 1 ], 'FULFILL', 5
                )

                local status = publisher: evalsha (
                        hash, 1, promises[ 1 ], 'STATUS'
                )

                assert.same (status, 'FULFILLED')

                local result = publisher: evalsha (
                        hash, 1, promises[ 1 ], 'RESULT'
                )

                assert.same (result, 5)

                local response
                local retries = 5

                repeat
                        response = subscriber: subscribe (futures[ 1 ])
                        retries  = retries - 1
                until response[ 1 ] == 'message' or retries < 0

                if retries < 0 then
                        error ("Could not read published message!")
                end

                local message = {
                        promise = promises[ 1 ],
                        status  = 'FULFILLED',
                        result  = 5,
                }

                assert.same (response[ 1 ], 'message')
                assert.same (response[ 2 ], futures[ 1 ])
                assert.same (lunajson.decode (response[ 3 ]), message)

                subscriber: unsubscribe (futures[ 1 ])
        end)

        it ("should be able to reject promises", function ( )
                assert.truthy (alive)

                subscriber: subscribe (futures[ 1 ])

                publisher: evalsha (
                        hash, 2, promises[ 1 ], futures[ 1 ], 'START'
                )

                publisher: evalsha (
                        hash, 1, promises[ 1 ], 'REJECT', "oops!"
                )

                local status = publisher: evalsha (
                        hash, 1, promises[ 1 ], 'STATUS'
                )

                assert.same (status, 'REJECTED')

                assert.error (function ( )
                        publisher: evalsha (
                                hash, 1, promises[ 1 ], 'RESULT'
                        )
                end)

                local response
                local retries = 5

                repeat
                        response = subscriber: subscribe (futures[ 1 ])
                        retries  = retries - 1
                until response[ 1 ] == 'message' or retries < 0

                if retries < 0 then
                        error ("Could not read published message!")
                end

                local message = {
                        promise = promises[ 1 ],
                        status  = 'REJECTED',
                        result  = "oops!",
                }

                assert.same (response[ 1 ], 'message')
                assert.same (response[ 2 ], futures[ 1 ])
                assert.same (lunajson.decode (response[ 3 ]), message)

                subscriber: unsubscribe (futures[ 1 ])
        end)

        it ("should fail on unknown promise commands", function ( )
                assert.truthy (alive)

                assert.error (function ( )
                        publisher: evalsha (hash, 1, promises[ 1 ], 'THEN')
                end)
        end)
end)
