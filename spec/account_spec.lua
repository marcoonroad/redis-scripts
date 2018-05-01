require 'busted.runner' ( )

describe ("account redis script -", function ( )
        local script
        local cuid
        local redis
        local client
        local hash
        local alive
        local accounts

        setup (function ( )
                for line in io.lines ("account.lua") do
                        script = (script and script .. "\n" or "") ..line
                end

                cuid  = require 'cuid'
                redis = require 'redis'

                client = redis.connect('127.0.0.1', 6379)
                hash   = client: script ("load", script)
                script = nil
        end)

        teardown (function ( )
                client: shutdown ("nosave")
        end)

        before_each (function ( )
                alive = client: ping ( )
                accounts = {
                        "account:" .. cuid.generate ( ),
                        "account:" .. cuid.generate ( )
                }
        end)

        after_each (function ( )
                client: flushdb ( )
        end)

        randomize ( )

        it ("should be able to open accounts", function ( )
                assert.truthy (alive)

                client: evalsha (hash, 1, accounts[ 1 ], "OPEN")

                local balance = client: evalsha (
                        hash, 1, accounts[ 1 ], "BALANCE"
                )

                assert.same (balance, 0)
        end)

        it ("should be able to deposit money", function ( )
                assert.truthy (alive)

                client: evalsha (hash, 1, accounts[ 1 ], "OPEN")
                client: evalsha (hash, 1, accounts[ 1 ], "DEPOSIT", 230)

                local balance = client: evalsha (
                        hash, 1, accounts[ 1 ], "BALANCE"
                )

                assert.same (balance, 230)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "DEPOSIT", 0
                        )
                end)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "DEPOSIT", -35
                        )
                end)
        end)

        it ("should be able to withdraw money", function ( )
                assert.truthy (alive)

                client: evalsha (hash, 1, accounts[ 1 ], "OPEN")
                client: evalsha (hash, 1, accounts[ 1 ], "DEPOSIT", 230)
                client: evalsha (hash, 1, accounts[ 1 ], "WITHDRAW", 110)

                local balance = client: evalsha (
                        hash, 1, accounts[ 1 ], "BALANCE"
                )

                assert.same (balance, 120)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "WITHDRAW", 0
                        )
                end)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "WITHDRAW", -35
                        )
                end)
        end)

        it ("should fail on any attempt to overdraw", function ( )
                assert.truthy (alive)

                client: evalsha (hash, 1, accounts[ 1 ], "OPEN")
                client: evalsha (hash, 1, accounts[ 1 ], "DEPOSIT", 150)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "WITHDRAW", 250
                        )
                end)

                client: evalsha (hash, 1, accounts[ 1 ], "WITHDRAW", 150)

                local balance = client: evalsha (
                        hash, 1, accounts[ 1 ], "BALANCE"
                )

                assert.same (balance, 0)
        end)

        it ("should be able to transfer money between accounts", function ( )
                assert.truthy (alive)

                local source = accounts[ 1 ]
                local target = accounts[ 2 ]

                client: evalsha (hash, 1, source, "OPEN")
                client: evalsha (hash, 1, target, "OPEN")
                client: evalsha (hash, 1, source, "DEPOSIT", 500)
                client: evalsha (hash, 1, target, "DEPOSIT", 200)

                client: evalsha (hash, 2, source, target, "TRANSFER", 100)

                assert.same (client: evalsha (
                        hash, 1, source, "BALANCE"
                ), 400)

                assert.same (client: evalsha (
                        hash, 1, target, "BALANCE"
                ), 300)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1,
                                accounts[ 1 ], accounts[ 2 ],
                                "TRANSFER", 0
                        )
                end)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1,
                                accounts[ 1 ],
                                "TRANSFER", -75
                        )
                end)
        end)

        it ("should fail on invalid account commands", function ( )
                assert.truthy (alive)

                assert.error (function ( )
                        client: evalsha (hash, 1, accounts[ 1 ], "STEAL")
                end)
        end)

        it ("should be able to partially lock an account", function ( )
                assert.truthy (alive)

                client: evalsha (hash, 1, accounts[ 1 ], "OPEN")
                client: evalsha (hash, 1, accounts[ 1 ], "DEPOSIT", 800)
                client: evalsha (hash, 1, accounts[ 1 ], "LOCK", 300)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "WITHDRAW", 600
                        )
                end)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "LOCK", 550
                        )
                end)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "UNLOCK", 950
                        )
                end)

                client: evalsha (hash, 1, accounts[ 1 ], "DEPOSIT", 200)
                client: evalsha (hash, 1, accounts[ 1 ], "LOCK", 100)

                assert.same (
                        client: evalsha (hash, 1, accounts[ 1 ], "LOCKED"),
                        400
                )

                client: evalsha (hash, 1, accounts[ 1 ], "WITHDRAW", 600)

                assert.same (
                        client: evalsha (hash, 1, accounts[ 1 ], "BALANCE"),
                        400
                )

                assert.same (
                        client: evalsha (hash, 1, accounts[ 1 ], "LOCKED"),
                        400
                )

                client: evalsha (hash, 1, accounts[ 1 ], "UNLOCK", 200)
                client: evalsha (hash, 1, accounts[ 1 ], "WITHDRAW", 100)

                assert.same (
                        client: evalsha (hash, 1, accounts[ 1 ], "BALANCE"),
                        300
                )

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "LOCK", 0
                        )
                end)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "LOCK", -185
                        )
                end)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "UNLOCK", 0
                        )
                end)

                assert.error (function ( )
                        client: evalsha (
                                hash, 1, accounts[ 1 ], "UNLOCK", -200
                        )
                end)
        end)
end)
