local tx = require 'pl.tablex'

local RETRY_DEFAULT = 5
local TAG = 'flaky'
-- like [#flaky (3/5) Some desc maybe]
local FMT = '[#{tag} ({attempt}/{attempts}) {name}]'
local WAIT = 0

local NOOP = function() end


local function relay(busted)

  local enabled = false

  -- noop
  local track = function() end

  local function handler(cb)
    return function(...)
      -- noop
      if not enabled then return nil, true end

      return cb(track, ...)
    end
  end

  return {
    off = function() enabled = false end,
    on = function(cb)
      enabled = true
      track = cb
    end,
    attach = function(topic, cb)
      busted.subscribe(topic, handler(cb), { priority = 1 })
    end,
  }
end


local function fmt(template, words)
  local w = template:gsub('(%b{})', function(m)
    return words[m:sub(2, -2)] or m
  end)
  return w:gsub('%s-%b{}%s-', '')
end


return function(busted, helper, options)

  local block = require 'busted.block'(busted)

  local cli = require 'cliargs'

  cli:set_name('flaky')
  cli:option('--attempts=NUM', 'number of attempts for flaky blocks', RETRY_DEFAULT)
  cli:option('--tag=TAG', 'tag for marking flaky blocks', TAG)
  cli:option('--format=FORMAT', 'format string for flaky blocks', FMT)
  cli:option('--wait=TIME', 'seconds to wait between retries', WAIT)

  local cli_args = cli:parse(options.arguments)

  local tag = cli_args.tag
  local tag_fmt = cli_args.format
  local max_attempts = tonumber(cli_args.attempts)
  local wait = tonumber(cli_args.wait)

  local hammer = relay(busted)
  -- Now everything looks like a nail

  hammer.attach({'error'}, function(track, ...)
    track(busted.status('error'))

    -- do not propagate errors
    return nil, false
  end)

  hammer.attach({'failure'}, function(track, ...)
    track(busted.status('failure'))

    -- do not propagate errors
    return nil, false
  end)

  hammer.attach({'test', 'end'}, function(track, element, parent, status)
    track(busted.status(status))

    -- do not propagate errors
    return nil, not(status == 'failure' or status == 'error')
  end)

  local function flaky(element)
    local ctx = busted.context.get()
    local parent = busted.context.parent(element)

    busted.safe_publish(tag, { tag, 'start' }, element, parent)

    local name = element.name

    -- accept element level customization
    local attributes = element.attributes

    local wait = attributes and attributes.wait or wait
    local tag_fmt = attributes and attributes.fmt or tag_fmt
    local max_attempts = attributes and attributes.attempts or max_attempts
    local retry_callback = attributes and attributes.callback or NOOP


    local status
    hammer.on(function(s) status:update(s) end)

    local attempts = 1

    while true do
      -- last attempt is chatty
      if attempts == max_attempts then hammer.off() end

      status = busted.status('success')

      element.name = fmt(tag_fmt, {
        tag = element.descriptor,
        name = name,
        attempt = attempts,
        attempts = max_attempts
      })

      block.execute("flaky", element)

      -- bye
      if status:success() or attempts == max_attempts then break end

      attempts = attempts + 1

      -- nuke childrens for next run
      tx.clear(busted.context.children(element))

      retry_callback(element, status, attempts, ctx)

      busted.sleep(wait)
    end

    hammer.off()

    busted.safe_publish(tag, { tag, 'end' }, element, parent, status)
  end


  local function patch_publisher(descriptor)
    local _publisher = busted.executors[descriptor]

    -- special publisher that accepts per-block attributes
    local publisher = function(name, fn, attributes)
      if not attributes and type(fn) == 'table' then
        attributes = fn
        fn = name
        name = descriptor
      elseif not attributes then
        -- publisher call without attributes, bailout
        return _publisher(name, fn)
      end

      local ctx = busted.context.get()
      local trace = attributes.trace or
                    ( busted.context.parent(ctx) and
                      busted.getTrace(ctx, 3, name) )

      local publish = function(f)
        busted.publish({ 'register', descriptor }, name, f, trace, attributes)
      end

      if fn then publish(fn) else return publish end
    end

    busted.executors[descriptor] = publisher
    busted.export(descriptor, publisher)
  end

  -- register `flaky` block
  busted.register('flaky', flaky)

  -- patch publishers to accept block level attributes
  patch_publisher('it')
  patch_publisher('flaky')
  patch_publisher('describe')


  local function wrap(descriptor, tag, block)
    return function(name, fn, trace, attributes)
      -- could use options.predicate on subscribe
      if not name or not name:find('#' .. tag) then return nil, true end

      -- remove tag from name
      local name = name:gsub('%s-%#' .. tag ..'%s-', '')

      local attributes = tx.update({ trace = trace }, attributes or {})

      -- wrap `descriptor` around a block
      busted.executors[block](function()
        busted.executors[descriptor](name, function()
          return fn()
        end, attributes)
      end, { trace = trace })

      -- Do not allow calls from any other subscriber
      return nil, false
    end
  end


  -- shortcut: wrap #tag on 'it' and 'describe' blocks with a `flaky` block
  busted.subscribe({'register', 'it'}, wrap('it', tag, 'flaky'), { priority = 1 })
  busted.subscribe({'register', 'describe'}, wrap('describe', tag, 'flaky'), { priority = 1 })

  return true
end
