-- Run from the repository root: clua tests/portal_cli_spec.lua
-- Real CLI callback, portal workflow, dbot and coordinator; simulated host,
-- GMCP and inventory acknowledgements. This does not exercise a client shim.
local clock, scheduled, triggers, nextId, state, sent, notes, locations, entries
local assertions = 0
local function equal(actual, expected)
  assertions = assertions + 1
  assert(actual == expected, tostring(actual) .. ' ~= ' .. tostring(expected))
end

timer_flag = {Enabled=1, OneShot=2, Temporary=4}
trigger_flag = {Enabled=1, RegularExpression=32, Replace=1024, OneShot=32768, OmitFromOutput=2}
custom_colour, sendto = {NoChange=0}, {script=12}
pluginNameCmd = 'dinv'
invStateIdle, invStatePaused, invItemsRefreshDirty = 'idle', 'paused', 'dirty'
invFieldObjLoc, invItemLocInventory = 'location', 'inventory'
invWearableLocPortal, invWearableLocHold, invWearableLocSecond = 31, 26, 25
function Version() return '5.07' end
function GetUniqueNumber() nextId = nextId + 1; return nextId end
function check(rv) assert(rv == 0) end
function AddTimer(name, hours, minutes, seconds, _, _, callback)
  scheduled[name] = {at=clock+hours*3600+minutes*60+seconds, callback=callback}
  return 0
end
function DeleteTimer(name) scheduled[name] = nil; return 0 end
function AddTriggerEx(name, pattern, script)
  triggers[name] = {pattern=pattern, script=script}
  return 0
end
function DeleteTrigger(name) triggers[name] = nil; return 0 end
function gmcp(package)
  assert(package == 'char.status')
  return {state=state}
end

-- Acknowledge each command on the next simulated client turn, in send order.
-- Inventory updates arrive before the following fence is acknowledged.
function SendNoEcho(wire)
  local command = assert(wire:match('^DINV_BYPASS (.*)$'))
  sent[#sent+1] = command
  inv.runtime.after(0.01, function()
    local echo = command:match('^echo (.*)$')
    if echo then
      for name, trigger in pairs(triggers) do
        if trigger.pattern == '^' .. echo .. '$' then
          triggers[name] = nil
          assert(loadstring(trigger.script))()
          return
        end
      end
      error('Unexpected fence: ' .. echo)
    elseif command == 'remove 101' then
      equal(locations[101], 'portal'); locations[101] = 'inventory'
    elseif command == 'get 102 999' then
      equal(locations[102], '999'); locations[102] = 'inventory'
    elseif command == 'hold 102' then
      equal(locations[102], 'inventory'); locations[102] = 'portal'
    elseif command == 'enter' then
      equal(locations[102], 'portal'); entries = entries + 1
    elseif command == 'wear 101 portal' then
      equal(locations[101], 'inventory')
      locations[101], locations[102] = 'portal', 'inventory'
    elseif command == 'put 102 999' then
      equal(locations[102], 'inventory'); locations[102] = '999'
    else
      error('Unexpected command: ' .. command)
    end
  end)
  return 0
end

local function reset(initialState)
  clock, scheduled, triggers, nextId = 0, {}, {}, 0
  state, sent, notes, locations, entries = initialState, {}, {}, {[101]='portal', [102]='999'}, 0
  proteles = nil
  utils = {timer=function() return clock end}
  inv = {init={initializedActive=true}, state=invStateIdle,
    wearLoc={[31]='portal', [26]='hold', [25]='second'},
    items={table={[101]={}, [102]={}}, abortCapture=function() end,
      getField=function(id, field) assert(field == invFieldObjLoc); return locations[id] end},
    statBonus={}, tags={}}
  dofile('dinv_dbot.lua')
  dofile('dinv_runtime.lua')
  dofile('dinv_commands.lua')
  dofile('dinv_portal.lua')
  dofile('dinv_cli.lua')
  dbot.gmcp.isInitialized = true
  dbot.wish.has = function(wish) assert(wish == 'Portal'); return true end
  dbot.debug = function() end
  dbot.info = function(message) notes[#notes+1] = message end
  dbot.warn = function(message)
    assert(not message:match('^Operation failed:') and not message:match('^Scheduled operation failed:'), message)
    notes[#notes+1] = message
  end
end

local function advance(seconds)
  local untilTime = clock + seconds
  for _=1,1000 do
    local name, timer
    for n,t in pairs(scheduled) do
      if t.at <= untilTime and (not timer or t.at < timer.at or
          (t.at == timer.at and tonumber(n:match('%d+$')) < tonumber(name:match('%d+$')))) then
        name, timer = n, t
      end
    end
    if not timer then clock = untilTime; return end
    clock = timer.at; scheduled[name] = nil
    assert(timer.callback == 'inv.runtime.fire')
    inv.runtime.fire(name)
  end
  error('Timer loop did not quiesce')
end

local function changeState(newState)
  state = newState
  inv.commands.stateChanged()
end

local function portalCommand()
  -- These are the arguments supplied by dinv.xml's portal alias. Deliberately
  -- enter at the CLI callback: calling inv.portal.use directly misses the guard.
  return inv.cli.portal.fn('', 'dinv portal use 102', {'use', '102'})
end

local function released()
  equal(inv.portal.inProgress, false)
  equal(inv.commands.leaseOwner, nil)
  equal(inv.commands.active, nil)
  equal(next(inv.runtime.tasks), nil)
end

local function completedHop()
  local actions = {}
  for _, command in ipairs(sent) do
    if not command:match('^echo ') then actions[#actions+1] = command end
  end
  equal(table.concat(actions, ';'), 'remove 101;get 102 999;hold 102;enter;wear 101 portal;put 102 999')
  equal(entries, 1)
  equal(locations[101], 'portal'); equal(locations[102], '999')
  equal(#notes, 0)
  released()
end

-- Reproduce admission one millisecond before Active, and a longer Running
-- period that reaches the coordinator's waitingState phase before resuming.
for _, delay in ipairs({0.001, 0.1}) do
  reset('12')
  portalCommand()
  equal(inv.portal.inProgress, true)
  equal(#notes, 0)
  advance(delay)
  equal(#sent, 0)
  if delay > 0.01 then equal(inv.commands.active.phase, 'waitingState') end
  changeState('3')
  advance(1)
  completedHop()
end

-- Existing Active and Combat admission still completes the same workflow.
for _, readyState in ipairs({'3', '8'}) do
  reset(readyState)
  portalCommand(); advance(1); completedHop()
end

-- Waiting must expire or cancel without any late travel when Active arrives.
for _, ending in ipairs({'timeout', 'cancel'}) do
  reset('12')
  portalCommand(); advance(0.1)
  equal(inv.commands.active.phase, 'waitingState')
  local result = inv.commands.active.resultData
  if ending == 'timeout' then advance(inv.portal.maxHopSeconds + 1)
  else inv.runtime.cancelAll(DRL_RET_HALTED) end
  equal(result.retval, ending == 'timeout' and DRL_RET_TIMEOUT or DRL_RET_HALTED)
  released()
  changeState('3'); advance(20)
  equal(#sent, 0); equal(entries, 0)
  equal(locations[101], 'portal'); equal(locations[102], '999')
  -- Cleanup must allow a fresh, deliberate request.
  notes = {}
  portalCommand(); advance(1); completedHop()
end

-- Initialization is still mandatory, including while Running.
for _, initialState in ipairs({'3', '12'}) do
  reset(initialState)
  inv.init.initializedActive = false
  equal(portalCommand(), DRL_RET_UNINITIALIZED)
  equal(notes[1]:find('plugin is not yet initialized', 1, true) ~= nil, true)
  advance(1); equal(#sent, 0); released()
end

-- All other character states retain the original rejection behavior.
for _, blockedState in ipairs({'1', '2', '4', '5', '6', '7', '9', '10', '11'}) do
  reset(blockedState)
  equal(portalCommand(), DRL_RET_NOT_ACTIVE)
  equal(notes[1], "Skipping portal request: character's state does not allow actions")
  advance(1); equal(#sent, 0); released()
end

-- The shared guard remains strict for other commands while Running.
reset('12')
equal(inv.cli.requireReadyStateFor('get'), DRL_RET_NOT_ACTIVE)
equal(dbot.gmcp.statePreventsActions(), true)

print('PASS: ' .. assertions .. ' portal CLI assertions')
