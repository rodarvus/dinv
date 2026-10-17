-- Run from the repository root with Lua 5.1: clua tests/runtime_spec.lua
-- Portable scheduler tests; deliberately no client shim or network.
local clock, scheduled, sent, nextId, assertions
local function equal(actual, expected)
  assertions = assertions + 1
  assert(actual == expected, tostring(actual) .. ' ~= ' .. tostring(expected))
end
DRL_RET_SUCCESS, DRL_RET_UNINITIALIZED, DRL_RET_INVALID_PARAM = 0, -1, -2
DRL_RET_BUSY, DRL_RET_TIMEOUT, DRL_RET_HALTED = -4, -6, -7
DRL_RET_INTERNAL_ERROR, DRL_RET_NOT_ACTIVE = -8, -10
invStateIdle, invStatePaused, invItemsRefreshDirty = 'idle', 'paused', 'dirty'
timer_flag = {Enabled=1, OneShot=2, Temporary=4}
trigger_flag = {OneShot=1, OmitFromOutput=2}
drlTriggerFlagsBaseline, custom_colour, sendto = 4, {NoChange=0}, {script=12}
function GetUniqueNumber() nextId = nextId + 1; return nextId end
function AddTimer(name, hours, minutes, seconds, _, _, callback)
  scheduled[name] = {at=clock+hours*3600+minutes*60+seconds, callback=callback}
  return 0
end
function DeleteTimer(name) scheduled[name] = nil; return 0 end
function AddTriggerEx() return 0 end
function DeleteTrigger() return 0 end
function check(rv) assert(rv == 0) end
function SendNoEcho(command) sent[#sent+1] = command; return 0 end
local function reset()
  clock, scheduled, sent, nextId, assertions = 0, {}, {}, 0, assertions or 0
  proteles = nil
  utils = {timer=function() return clock end}
  inv = {init={initializedActive=true}, state=invStateIdle, items={abortCapture=function() end,
    refreshGetPeriods=function() return 0 end}, statBonus={timer={update=function() end}},
    portal={}, tags={stop=function() end}}
  dbot = {stateActive='3', stateCombat='8', stateRunning='12', gmcp={getState=function() return '3' end},
    execute={bypassPrefix='DINV_BYPASS '}, warn=function() end,
    wish={timer={min=1,sec=0},get=function() end}}
  dofile('dinv_runtime.lua'); dofile('dinv_commands.lua')
end
local function advance(seconds)
  local untilTime = clock + seconds
  for _=1,1000 do
    local name, timer
    for n,t in pairs(scheduled) do
      if t.at<=untilTime and (not timer or t.at<timer.at) then name,timer=n,t end
    end
    if not timer then clock=untilTime; return end
    clock=timer.at; scheduled[name]=nil
    assert(timer.callback=='inv.runtime.fire')
    inv.runtime.fire(name)
  end
  error('timer loop did not quiesce')
end
local function request(command, timeout, cleanup, callback)
  local result = {}
  local rv, op = inv.commands.enqueue({command}, nil, nil, callback, result,
    {framed=true, timeout=timeout, cleanup=cleanup})
  equal(rv, DRL_RET_SUCCESS)
  return op, result
end

reset()
local cleanupCount, resultCount = 0, 0
local op, result = request('inspect', 1, function() cleanupCount=cleanupCount+1 end,
  function() resultCount=resultCount+1 end)
advance(0.1)
equal(#sent, 1)
advance(1)
equal(result.retval, DRL_RET_TIMEOUT)
inv.commands.cancel(op, DRL_RET_HALTED); inv.commands.complete(op, DRL_RET_SUCCESS)
equal(cleanupCount, 1); equal(resultCount, 1); equal(inv.commands.active, nil)

reset()
request('blocking', 30)
local queued, queuedResult = request('expired', 1)
advance(2)
equal(queuedResult.retval, DRL_RET_TIMEOUT); equal(#sent, 1)
inv.commands.complete(inv.commands.active, DRL_RET_SUCCESS)
advance(1)
equal(#sent, 1)

reset()
local resumed
inv.runtime.start(function()
  local _, future = request('inspect', 30)
  resumed = inv.runtime.await(future, 0.5)
end)
advance(1)
equal(resumed, DRL_RET_TIMEOUT); equal(next(inv.runtime.tasks), nil)

reset()
local owner = {package={}}
inv.runtime.start(function()
  request('inspect', 30)
  inv.runtime.sleep(0.1)
  error('injected exception')
end, owner, 'package')
advance(0.2)
equal(owner.package, nil); equal(inv.commands.active, nil); equal(next(inv.runtime.tasks), nil)

reset()
local oldGeneration = inv.runtime.generation
inv.runtime.start(function() inv.runtime.sleep(1); inv.commands.send('obsolete') end)
inv.runtime.cancelAll(DRL_RET_HALTED)
advance(10)
equal(#sent, 0); equal(inv.runtime.generation, oldGeneration+1)

reset()
request('inspect', 30)
advance(0.1)
inv.commands.userInput('look')
equal(inv.commands.active.done, nil)
inv.commands.userInput('invdata')
equal(inv.commands.active, nil)
equal(inv.commands.needsBoundary, true)
request('fresh', 30)
advance(0.1)
equal(#sent, 2) -- first request plus a boundary, no fresh request yet
local boundary = inv.commands.active.trigger
inv.commands.marker(boundary)
advance(0.1)
equal(sent[3], 'DINV_BYPASS fresh')

reset()
dbot.execute.noteIsPending = true
local _, blocked = request('do-not-send', 30)
advance(0.1)
equal(blocked.retval, DRL_RET_NOT_ACTIVE); equal(#sent, 0)

reset()
local rv = inv.commands.enqueue({'do-not-send'}, function() error('setup failure') end, nil, nil, {},
  {framed=true})
equal(rv, DRL_RET_SUCCESS)
advance(0.1)
equal(#sent, 0); equal(inv.commands.active, nil)

-- Unrelated output cannot corrupt a command acknowledgement. Reports still
-- reject interference, with raw snapshot requests conflicting only with framed
-- snapshots (or unstructured capture), not parser-free command bursts.
for _, mode in ipairs({'commands', 'report', 'framed'}) do
  for _, command in ipairs({'look', 'eq', "cast 'energy shield'", 'invdata'}) do
    reset()
    local setup = mode ~= 'commands' and function() end or nil
    local future = {}
    local _, active = inv.commands.enqueue({'test'}, setup, nil, nil, future,
      {framed=mode == 'framed'})
    advance(0.1)
    inv.commands.userInput(command)
    local canceled = mode == 'report' or (mode == 'framed' and command == 'invdata')
    equal(future.retval, canceled and DRL_RET_BUSY or nil)
    equal(active.done == true, canceled)
  end
end

-- A rejected or throwing precondition must send no mutation, deliver once and
-- release ownership, so a later request can still proceed.
for _, precondition in ipairs({function() return DRL_RET_BUSY end,
    function() error('precondition failure') end, function() return nil end}) do
  reset()
  local completions, future = 0, {}
  inv.commands.enqueue({'must-not-send'}, nil, nil, function() completions=completions+1 end,
    future, {beforeDispatch=precondition})
  advance(0.1)
  inv.commands.marker(inv.commands.active.trigger)
  advance(1)
  equal(#sent, 1); equal(completions, 1); equal(inv.commands.active, nil)
  equal(future.retval == DRL_RET_BUSY or future.retval == DRL_RET_INTERNAL_ERROR, true)
  request('fresh', 30)
  advance(0.1)
  inv.commands.marker(inv.commands.active.trigger)
  advance(0.1)
  equal(sent[#sent], 'DINV_BYPASS fresh')
end

-- Reservation survives inter-request gaps and releases even on an exception.
for _, ending in ipairs({'success', 'exception', 'cancel'}) do
  reset()
  local cleaned = 0
  inv.runtime.start(function()
    return inv.commands.exclusive(function()
      local first, future = request('first', 30)
      inv.runtime.after(0.2, function() inv.commands.complete(first, DRL_RET_SUCCESS) end)
      inv.runtime.await(future, 30)
      inv.runtime.sleep(0.5)
      if ending == 'exception' then error('workflow exception') end
      local last, future = request('last', 30)
      inv.runtime.after(0.2, function() inv.commands.complete(last, DRL_RET_SUCCESS) end)
      return inv.runtime.await(future, 30)
    end, function() cleaned=cleaned+1 end)
  end)
  advance(0.1)
  request('outside', 30)
  advance(0.3)
  equal(#sent, 1); equal(sent[1], 'DINV_BYPASS first')
  if ending == 'cancel' then inv.runtime.cancelAll(DRL_RET_HALTED) end
  advance(2)
  equal(cleaned, 1); equal(inv.commands.leaseOwner, nil)
  if ending == 'success' then
    equal(sent[2], 'DINV_BYPASS last'); equal(sent[3], 'DINV_BYPASS outside')
  else equal(#sent, 1) end
end

-- Late canceled echoes have no effect on new work. Retention has a hard bound.
reset()
for _=1,70 do
  local future = {}
  inv.commands.enqueue({'never'}, nil, nil, nil, future)
  advance(0.02)
  inv.commands.cancel(inv.commands.active, DRL_RET_HALTED)
end
equal(#inv.commands.retired, 64)
local old = inv.commands.retired[1]
request('fresh', 30)
advance(0.02)
local current = inv.commands.active
inv.commands.marker(old)
equal(inv.commands.active, current); equal(#inv.commands.retired, 63)

print('PASS: ' .. assertions .. ' portable scheduler assertions')
