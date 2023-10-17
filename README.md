# busted-flaky

`busted-flaky` is a [busted](https://olivinelabs.com/busted/) extension for
handling flaky specs, heavily inspired on RSpec::Retry. Using `busted-flaky`
any block can be retried a specified number of times until it succeeds.

## What is test flakiness?

> A flaky test is a test that both passes and fails periodically without any
code changes. Flaky tests are definitely annoying but they can also be quite
> costly since they often require engineers to retrigger entire builds on CI and
> often waste a lot of time waiting for new builds to complete successfully.
>
> --- [Test Flakiness – Methods for identifying and dealing with flaky tests](https://engineering.atspotify.com/2019/11/18/test-flakiness-methods-for-identifying-and-dealing-with-flaky-tests/)

## Installation

```bash
$ luarocks install busted-flaky
```

## Usage

`busted-flaky` adds a new block called `flaky`. Use it around `it` and
`describe` blocks for these to be retried an specific number of times until
they succeed. All setup / teardown / finally blocks enclosed will also get
executed.


```lua
describe("some thing", function()

  it("does stuff", function()

  end)

  flaky(function()

    it("does sometimes fail stuff", function()

    end)
  end)

  flaky("accepts a description too", function()

    describe("has a feature", function()
      lazy_setup(function()

      end)

      teardown(function()

      end)

      it("does stuff", function()

      end)
    end)
  end)
end)
```

A name level shortcut is available to wrap blocks on runtime, by tagging them
with `#flaky`.

```lua
describe("some thing", function()

  it("does stuff", function()

  end)

  it("does sometimes fail stuff #flaky", function()

  end)

  describe("has a #flaky feature", function()

    lazy_setup(function()

    end)

    teardown(function()

    end)

    it("does stuff", function()

    end)
  end)
end)
```

The extension needs to be loaded by busted on runtime using the `--helper`
argument for the runner.

```bash
$ busted -o gtest --helper=flaky path/to/some_spec.lua
```

## Configuration

### attempts

> default: `5`

Set the number of attempts the block will be retried until it succeeds.

### format

> default `[#{tag} ({attempt}/{attempts}) {name}]`
> like: [#flaky (3/5) some comment]

Format string for flaky attempts.

### wait

> default `0`

Number of seconds to wait between flaky attempts.

### callback

A callback that will be run between attempts. Can only configured through
block attributes.


```lua

flaky("some flaky block", function()
  it(...)
end, {
  callback = function(element, status, attempts, ctx)
    -- gets run on every attempt
  end,
})
```

### tag

> default: `flaky`

The tag used for name level wrapping shortcut. Can only be configured through
cli arguments.

### cli arguments

```
  --attempts=NUM    number of attempts for flaky blocks (default: 5)
  --tag=TAG         tag for marking flaky blocks (default: 'flaky')
  --format=FORMAT   format string for flaky blocks
  --wait=TIME       seconds to wait between retries (default: 0)
```

```bash
$ busted --helper=flaky -Xhelper --attempts=10 -Xhelper --tag=failure ...
```

### block attributes

flaky blocks accept block level attributes to customize them.

```lua
describe("something", function()
  it("does stuff", function() end)

  flaky(function()
    -- something
  end, {
    -- block level attributes
    wait = 5,
    retry = 10,
    callback = function(element, status, attempts, ctx)
      -- ...
    end
  })
```

## Example


```lua
-- spec/flaky_spec.lua

local NOOP = function() end

describe("busted-flaky:", function()

  describe("when unused", function()
    describe("does leave describe blocks alone", function()
      it("and it blocks too", NOOP)
    end)
  end)

  describe("flaky block", function()

    describe("description", function()

      flaky("some description of the issue", function()
        it("can use an (optional) description", NOOP)
      end)

      flaky(function()
        it("does work without a description too", NOOP)
      end)

      flaky(function()
        it("does accept a different description format", NOOP)
      end, { fmt = "[ #flaky run {attempt} of {attempts} ]" })
    end)

    describe("contained blocks get retried until they succeed", function()

      local n = 1
      local p = 1

      after_each(function()
        p = p * 2
      end)

      flaky("only works the 3rd time", function()
        describe("assert", function()

          after_each(function()
            n = n + 1
          end)

          it(tostring(n) .. " == 3", function()
            assert.is_equal(3, n)
          end)
        end)
      end)

      describe("more attempts can be specified", function()
        flaky("only works the 7th time", function()
          it(tostring(p) .. " == 512", function()
            assert.is_equal(512, p)
          end)
        end, { attempts = 10 })
      end)

    end)

    describe("a tag shortcut can be used too", function()

      local n = 1
      local p = 1

      after_each(function()
        p = p * 2
      end)

      describe("#flaky assert", function()

        after_each(function()
          n = n + 1
        end)

        it(tostring(n) .. " == 3", function()
          assert.is_equal(3, n)
        end)
      end)

    end)

  end)

end)
```

```bash
$ busted -o gtest --helper=flaky spec/flaky_spec.lua
[==========] Running tests from scanned files.
[----------] Global test environment setup.
[----------] Running tests from example_spec.lua
[ RUN      ] example_spec.lua @ 7: busted-flaky: when unused does leave describe blocks alone and it blocks too
[       OK ] example_spec.lua @ 7: busted-flaky: when unused does leave describe blocks alone and it blocks too (0.58 ms)
[ RUN      ] example_spec.lua @ 16: busted-flaky: flaky block description [#flaky (1/5) some description of the issue] can use an (optional) description
[       OK ] example_spec.lua @ 16: busted-flaky: flaky block description [#flaky (1/5) some description of the issue] can use an (optional) description (0.50 ms)
[ RUN      ] example_spec.lua @ 20: busted-flaky: flaky block description [#flaky (1/5)] does work without a description too
[       OK ] example_spec.lua @ 20: busted-flaky: flaky block description [#flaky (1/5)] does work without a description too (0.54 ms)
[ RUN      ] example_spec.lua @ 24: busted-flaky: flaky block description [ #flaky run 1 of 5 ] does accept a different description format
[       OK ] example_spec.lua @ 24: busted-flaky: flaky block description [ #flaky run 1 of 5 ] does accept a different description format (0.54 ms)
[ RUN      ] example_spec.lua @ 44: busted-flaky: flaky block contained blocks get retried until they succeed [#flaky (1/5) only works the 3rd time] assert 1 == 3
example_spec.lua:45: Expected objects to be equal.
Passed in:
(number) 1
Expected:
(number) 3
[ RUN      ] example_spec.lua @ 44: busted-flaky: flaky block contained blocks get retried until they succeed [#flaky (2/5) only works the 3rd time] assert 2 == 3
example_spec.lua:45: Expected objects to be equal.
Passed in:
(number) 2
Expected:
(number) 3
[ RUN      ] example_spec.lua @ 44: busted-flaky: flaky block contained blocks get retried until they succeed [#flaky (3/5) only works the 3rd time] assert 3 == 3
[       OK ] example_spec.lua @ 44: busted-flaky: flaky block contained blocks get retried until they succeed [#flaky (3/5) only works the 3rd time] assert 3 == 3 (0.62 ms)
[ RUN      ] example_spec.lua @ 52: busted-flaky: flaky block contained blocks get retried until they succeed more attempts can be specified [#flaky (1/10) only works the 7th time] 8 == 512
example_spec.lua:53: Expected objects to be equal.
Passed in:
(number) 8
Expected:
(number) 512
[ RUN      ] example_spec.lua @ 52: busted-flaky: flaky block contained blocks get retried until they succeed more attempts can be specified [#flaky (2/10) only works the 7th time] 16 == 512
example_spec.lua:53: Expected objects to be equal.
Passed in:
(number) 16
Expected:
(number) 512
[ RUN      ] example_spec.lua @ 52: busted-flaky: flaky block contained blocks get retried until they succeed more attempts can be specified [#flaky (3/10) only works the 7th time] 32 == 512
example_spec.lua:53: Expected objects to be equal.
Passed in:
(number) 32
Expected:
(number) 512
[ RUN      ] example_spec.lua @ 52: busted-flaky: flaky block contained blocks get retried until they succeed more attempts can be specified [#flaky (4/10) only works the 7th time] 64 == 512
example_spec.lua:53: Expected objects to be equal.
Passed in:
(number) 64
Expected:
(number) 512
[ RUN      ] example_spec.lua @ 52: busted-flaky: flaky block contained blocks get retried until they succeed more attempts can be specified [#flaky (5/10) only works the 7th time] 128 == 512
example_spec.lua:53: Expected objects to be equal.
Passed in:
(number) 128
Expected:
(number) 512
[ RUN      ] example_spec.lua @ 52: busted-flaky: flaky block contained blocks get retried until they succeed more attempts can be specified [#flaky (6/10) only works the 7th time] 256 == 512
example_spec.lua:53: Expected objects to be equal.
Passed in:
(number) 256
Expected:
(number) 512
[ RUN      ] example_spec.lua @ 52: busted-flaky: flaky block contained blocks get retried until they succeed more attempts can be specified [#flaky (7/10) only works the 7th time] 512 == 512
[       OK ] example_spec.lua @ 52: busted-flaky: flaky block contained blocks get retried until they succeed more attempts can be specified [#flaky (7/10) only works the 7th time] 512 == 512 (0.79 ms)
[ RUN      ] example_spec.lua @ 75: busted-flaky: flaky block a tag shortcut can be used too [#flaky (1/5) flaky]  assert 1 == 3
example_spec.lua:76: Expected objects to be equal.
Passed in:
(number) 1
Expected:
(number) 3
[ RUN      ] example_spec.lua @ 75: busted-flaky: flaky block a tag shortcut can be used too [#flaky (2/5) flaky]  assert 2 == 3
example_spec.lua:76: Expected objects to be equal.
Passed in:
(number) 2
Expected:
(number) 3
[ RUN      ] example_spec.lua @ 75: busted-flaky: flaky block a tag shortcut can be used too [#flaky (3/5) flaky]  assert 3 == 3
[       OK ] example_spec.lua @ 75: busted-flaky: flaky block a tag shortcut can be used too [#flaky (3/5) flaky]  assert 3 == 3 (0.61 ms)
[----------] 7 tests from example_spec.lua (27.96 ms total)

[----------] Global test environment teardown.
[==========] 7 tests from 1 test file ran. (29.37 ms total)
[  PASSED  ] 7 tests.
```

## Credits

* rspec:retry
* busted
