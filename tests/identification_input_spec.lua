-- Run from the repository root: clua tests/identification_input_spec.lua
-- Real send hook, identification parser and coordinator; simulated host,
-- ordered server responses and persistence. This is not a client-shim test.
local assertions, failures = 0, 0
local clock, scheduled, nextId, triggers, enabled, sent, saved, result, completions, state
local inSend, reenter
local function equal(actual, expected)
  assertions = assertions + 1
  assert(actual == expected, tostring(actual) .. ' ~= ' .. tostring(expected))
end
timer_flag = {Enabled=1, OneShot=2, Temporary=4}
trigger_flag = {Enabled=1, RegularExpression=32, Replace=1024, OneShot=32768, OmitFromOutput=2}
error_code = {eOK=0, eTimerNotFound=1}
custom_colour, sendto = {NoChange=0, Custom11=11}, {script=12}
function Version() return '5.07' end
function GetUniqueNumber() nextId = nextId + 1; return nextId end
function AddTimer(name, hours, minutes, seconds, _, _, callback)
  scheduled[name] = {at=clock+hours*3600+minutes*60+seconds, callback=callback}
  return 0
end
function DeleteTimer(name) scheduled[name] = nil; return 0 end
function IsTimer(name) return scheduled[name] and 0 or 1 end
function EnableTrigger(name, value) enabled[name] = value; return 0 end
function DeleteTrigger(name) triggers[name] = nil; return 0 end
function AddTriggerEx(name, pattern, script)
  triggers[name] = {pattern=pattern, script=script}
  return 0
end
function check(rv) assert(rv == 0) end
function SendNoEcho(command)
  if inSend and not reenter then sent[#sent+1] = command; return 0 end
  local nested = inSend
  inSend = true
  local allow = OnPluginSend(command)
  inSend = nested
  if allow then sent[#sent+1] = command end
  return 0
end

-- Load the actual hook without the client's bootstrap requires/path setup.
local file = assert(io.open('dinv_init.lua'))
local sendHook = assert(file:read('*a'):match('(function setPending%(msg%).-end %-%- OnPluginSend)'))
file:close()

local function reset(reentry)
  clock, scheduled, nextId, triggers, enabled, sent = 0, {}, 0, {}, {}, {}
  saved, result, completions, state, inSend, reenter = 0, nil, 0, '3', false, reentry
  proteles = reentry and {} or nil
  utils = {timer=function() return clock end}
  inv = {}
  dofile('dinv_dbot.lua')
  dofile('dinv_items.lua')
  dofile('dinv_data.lua')
  dofile('dinv_runtime.lua')
  dofile('dinv_commands.lua')
  inv.cli = {}
  dofile('dinv_capture.lua')
  assert(loadstring(sendHook))()
  inv.init, inv.state = {initializedActive=true}, invStateIdle
  inv.statBonus, inv.portal = {}, {}
  dbot.gmcp.isInitialized = true
  dbot.gmcp.getState = function() return state end
  dbot.debug, dbot.info = function() end, function() end
  dbot.warn = function(message) error(message) end
  dinv_db = {transaction=function(fn) return fn() end,
    saveItem=function() saved = saved + 1; return DRL_RET_SUCCESS end}
  inv.items.table[101] = {[invFieldObjLoc]=invItemLocInventory,
    [invFieldIdentifyLevel]=invIdLevelNone, stats={id=101, name='Prior name'}}
end

local function advance(seconds)
  local untilTime = clock + seconds
  for _=1,1000 do
    local name, timer
    for n,t in pairs(scheduled) do
      if t.at <= untilTime and (not timer or t.at < timer.at or
          (t.at == timer.at and n < name)) then name, timer = n, t end
    end
    if not timer then clock = untilTime; return end
    clock = timer.at; scheduled[name] = nil
    assert(timer.callback == 'inv.runtime.fire')
    inv.runtime.fire(name)
  end
  error('Timer loop did not quiesce')
end

local function receive(line)
  for name, trigger in pairs(triggers) do
    if trigger.pattern == '^' .. line .. '$' then
      triggers[name] = nil
      assert(loadstring(trigger.script))()
      return true
    end
  end
  if enabled[inv.items.trigger.itemIdStartName] and
      (line:match('^%+%-%-') or line == 'You do not have that item.') then
    inv.items.trigger.itemIdStart(line)
    return true
  elseif enabled[inv.items.trigger.itemIdStatsName] and line:match('^| ') then
    inv.items.trigger.itemIdStats(line)
    return true
  end
  return false
end

local function start(timeout)
  inv.runtime.start(function()
    local commands = {}
    equal(inv.items.identifyItem(101, idCommandBasic, {}, commands), DRL_RET_SUCCESS)
    result = dbot.execute.safe.blocking(commands, inv.items.identifyAtomicSetup, nil,
      inv.items.identifyAtomicCleanup, timeout or 10)
    completions = completions + 1
  end)
  advance(0.02)
  local op = assert(inv.commands.active)
  equal(op.phase, 'prefix')
  return op
end

local function dispatch(op)
  equal(receive(op.marker), true)
  advance(0.02)
  equal(op.phase, 'suffix')
end

local function report(id)
  receive('+-----------------------------------------------------------------+')
  receive('| Name       : Identified item                                   |')
  receive('| Id         : ' .. (id or 101) .. '                                              |')
  receive('| Type       : Armor                     Level  :    10           |')
  equal(receive(inv.items.identifyFence), true)
end

local function completed(op)
  equal(receive(op.marker), true)
  advance(0.02)
  equal(result, DRL_RET_SUCCESS)
  equal(completions, 1)
  equal(saved, 1)
  equal(inv.items.getField(101, invFieldIdentifyLevel), invIdLevelFull)
  equal(inv.items.identifyPkg, nil)
  equal(inv.commands.active, nil)
  equal(next(inv.runtime.tasks), nil)
  equal(enabled[inv.items.trigger.itemIdStartName], false)
  equal(enabled[inv.items.trigger.itemIdStatsName], false)
  equal(next(triggers), nil)
end

local function test(name, fn, reentry)
  reset(reentry)
  local ok, err = pcall(fn)
  print((ok and 'PASS ' or 'FAIL ') .. name)
  if not ok then failures = failures + 1; print(err) end
end

for _, reentry in ipairs({false, true}) do
  for _, command in ipairs({'who area', "cast 'protection'", 'identify 999', 'invdata'}) do
    test('input after dispatch: ' .. command .. ' (reentry=' .. tostring(reentry) .. ')', function()
      local op = start()
      dispatch(op)
      local closingSend = #sent
      equal(sent[closingSend], 'echo ' .. op.marker)
      SendNoEcho(command)
      equal(sent[closingSend+1], command)
      equal(op.done, nil)
      equal(result, nil)
      report()
      completed(op)
      -- Even identify-like output for the later command is outside this capture.
      equal(receive('| Name       : Unrelated item                                   |'), false)
      equal(inv.items.getStatField(101, invStatFieldName), 'Identified item')
    end, reentry)
  end
end

for _, gap in ipairs({'waiting for opening fence', 'opening fence received, dispatch pending'}) do
  test('input while ' .. gap, function()
    local op = start()
    local opening, deadline = op.marker, op.deadline
    if gap == 'opening fence received, dispatch pending' then receive(opening) end
    SendNoEcho("cast 'protection'")
    equal(op.done, nil)
    if gap == 'waiting for opening fence' then receive(opening) end
    advance(0.02)
    equal(op.phase, 'prefix')
    equal(op.marker ~= opening, true)
    equal(op.setupStarted, nil)
    equal(#sent, 3) -- original opening fence, user command, replacement fence
    equal(sent[2], "cast 'protection'")
    equal(sent[3], 'echo ' .. op.marker)
    equal(op.deadline, deadline)
    equal(receive('| Name       : Earlier command output                           |'), false)
    dispatch(op)
    report()
    completed(op)
  end)
end

test('repeated input cannot extend the identification deadline', function()
  local op = start(1)
  local deadline = op.deadline
  for _=1,3 do
    SendNoEcho('look')
    equal(receive(op.marker), true)
    advance(0.2)
    equal(op.phase, 'prefix')
    equal(op.setupStarted, nil)
    equal(op.deadline, deadline)
  end
  local lateMarker = op.marker
  advance(0.5)
  equal(result, DRL_RET_TIMEOUT)
  equal(completions, 1)
  equal(saved, 0)
  equal(inv.items.identifyPkg, nil)
  equal(inv.commands.active, nil)
  local count = #sent
  equal(receive(lateMarker), true)
  advance(1)
  equal(#sent, count)
  equal(completions, 1)
end)

test('mismatched item identity is still rejected', function()
  local op = start()
  dispatch(op)
  SendNoEcho('who area')
  report(999)
  receive(op.marker)
  advance(0.02)
  equal(result, DRL_RET_BUSY)
  equal(saved, 0)
  equal(inv.items.getStatField(101, invStatFieldName), 'Prior name')
  equal(inv.items.getField(101, invFieldIdentifyLevel), invIdLevelNone)
end)

for _, ending in ipairs({'timeout', 'cancel', 'state change'}) do
  test(ending .. ' still discards an incomplete identification', function()
    local op = start(1)
    dispatch(op)
    SendNoEcho('who area')
    receive('+-----------------------------------------------------------------+')
    receive('| Id         : 101                                              |')
    if ending == 'timeout' then advance(1)
    elseif ending == 'cancel' then inv.runtime.cancelAll(DRL_RET_HALTED)
    else state = dbot.stateSleeping; inv.commands.stateChanged() end
    advance(0.02)
    equal(op.resultData.retval, ending == 'timeout' and DRL_RET_TIMEOUT or
      ending == 'cancel' and DRL_RET_HALTED or DRL_RET_NOT_ACTIVE)
    equal(saved, 0)
    equal(inv.items.identifyPkg, nil)
    equal(enabled[inv.items.trigger.itemIdStatsName], false)
    equal(receive(op.marker), true)
    advance(0.02)
    equal(inv.commands.active, nil)
    equal(next(inv.runtime.tasks), nil)
    equal(inv.items.getStatField(101, invStatFieldName), 'Prior name')
  end)
end

test('pending note mode still prevents dispatch', function()
  local op = start()
  SendNoEcho('note write')
  receive(op.marker)
  advance(0.02)
  equal(result, DRL_RET_NOT_ACTIVE)
  equal(op.setupStarted, nil)
  equal(#sent, 2)
end)

assert(failures == 0, failures .. ' regression test(s) failed')
print(assertions .. ' identification assertions passed')
