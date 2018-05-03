# Redis' Scripts

My own personal list of custom Lua <=> Redis scripts.

[![Build Status](https://travis-ci.org/marcoonroad/redis-scripts.svg?branch=master)](https://travis-ci.org/marcoonroad/redis-scripts)

Such scripts are pure in some sense. They don't rely on non-deterministic stuff
such as commands like **TIME**, **RANDOMKEY**, and so on. Also, they're fully
parametrized on the Redis keys, that is, they don't assume anything implicitly
except some invariants here and there about the underlying structure (on most
times, a hash table).

### Installation

Just type the following command below inside this root project directory:

```shell
$ make load
```

Every script will be printed with its name and its consequent Redis hash.

### Usage

Please, refer to test suite on `spec/` folder. Alternatively, there's some
minor documentation on the scripts themselves for general usage.

### Why/Rationale

Running scripts inside Redis sandboxed environment provides a lot of benefits.
The first of they is the complete transaction control. If the scripts fail due
some error/reason, the changes performed by they aren't propagated. Also, there
is a performance improvement by running such scripts inside Redis itself.

### Testing

To run the test suite, just type the following commands (I'm assuming a
properly configured Luarocks environment, for example, with `luarocks path`):

```shell
$ make deps
$ make test
```

### Remarks

PRs & issues are welcome, as they often say. Happy hacking! :moon: :tada:
