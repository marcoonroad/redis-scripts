all: test

test:
	luacheck --std max+busted . spec
	busted --verbose spec

load:
	redis-cli SCRIPT LOAD "`cat ./account.lua`"
