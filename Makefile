all: test

deps:
	luarocks install cuid
	luarocks install redis-lua
	luarocks install lua-cjson
	luarocks install busted
	luarocks install luacheck

check:
	luacheck scripts spec

test: check
	busted --verbose spec

load:
	redis-cli SCRIPT LOAD "`cat ./scripts/account.lua`"
	redis-cli SCRIPT LOAD "`cat ./scripts/promise.lua`"
	redis-cli SCRIPT LOAD "`cat ./scripts/blob-store.lua`"
