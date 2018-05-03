all: test

deps:
	luarocks --local install cuid
	luarocks --local install redis-lua
	luarocks --local install lua-cjson
	luarocks --local install busted
	luarocks --local install luacheck

check:
	luacheck --std max+busted scripts spec

test: check
	busted --verbose spec

load:
	redis-cli SCRIPT LOAD "`cat ./scripts/account.lua`"
	redis-cli SCRIPT LOAD "`cat ./scripts/promise.lua`"
	redis-cli SCRIPT LOAD "`cat ./scripts/blob-store.lua`"
