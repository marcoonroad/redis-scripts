require 'busted.runner' ( )

describe ("content-addressable append-only store script -", function ( )
        local script
        local cuid
        local lunajson
        local redis
        local client
        local alive
        local stores
        local hash

        setup (function ( )
                for line in io.lines ("./scripts/blob-store.lua") do
                        script = (script and script .. "\n" or "") ..line
                end

                cuid     = require 'cuid'
                lunajson = require 'lunajson'
                redis    = require 'redis'

                client = redis.connect ('127.0.0.1', 6379)

                client: config ('set', 'save', '')

                hash   = client: script ('load', script)
                script = nil
        end)

        teardown (function ( )
                client: quit ( )
        end)

        before_each (function ( )
                alive = client: ping ( )

                stores = {
                        "store:" .. cuid.generate ( ),
                }
        end)

        after_each (function ( )
                client: flushdb ( )
        end)

        randomize ( )

        it ("should be able to store and retrieve data", function ( )
                assert.truthy (alive)

                local hero = {
                        name = "Mario",
                        health = 78,
                        level  = 12,
                }

                local id = client: evalsha (
                        hash, 1, stores[ 1 ], 'APPEND', lunajson.encode (hero)
                )

                local result = client: evalsha (
                        hash, 1, stores[ 1 ], 'ACCESS', id
                )

                assert.same (hero, lunajson.decode (result))
        end)

        it ("should be idempotent and independent of any order", function ( )
                assert.truthy (alive)

                local weapon = {
                        name  = "Excalibur",
                        power = 500,
                        critical = 0.75,
                }

                local id = client: evalsha (
                        hash, 1, stores[ 1 ], 'APPEND',
                        lunajson.encode (weapon)
                )

                assert.same (id, client: evalsha (
                        hash, 1, stores[ 1 ], 'APPEND',
                        lunajson.encode (weapon)
                ))

                assert.same (id, client: evalsha (
                        hash, 1, stores[ 1 ], 'APPEND', lunajson.encode ({
                                critical = 0.75,
                                power    = 500,
                                name     = "Excalibur",
                        })
                ))

                assert.same (id, client: evalsha (
                        hash, 1, stores[ 1 ], 'APPEND', lunajson.encode ({
                                critical = 0.75,
                                name     = "Excalibur",
                                power    = 500,
                        })
                ))

                assert.same (id, client: evalsha (
                        hash, 1, stores[ 1 ], 'APPEND', lunajson.encode ({
                                name     = "Excalibur",
                                critical = 0.75,
                                power    = 500,
                        })
                ))

                assert.same (id, client: evalsha (
                        hash, 1, stores[ 1 ], 'APPEND', lunajson.encode ({
                                power    = 500,
                                name     = "Excalibur",
                                critical = 0.75,
                        })
                ))
        end)

        it ("should fail on unknown store commands", function ( )
                assert.truthy (alive)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, stores[ 1 ], 'RESET'
                        )
                end)
        end)
end)
