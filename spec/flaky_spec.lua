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
