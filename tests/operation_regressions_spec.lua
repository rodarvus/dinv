-- Run from the repository root: clua tests/operation_regressions_spec.lua
-- Real analysis, refresh and consumption code; simulated clock, game I/O and
-- persistence. These checks do not exercise the client shim or a live server.
local assertions, failures = 0, 0
local clock, scheduled, nextId, messages, results
local function equal(actual, expected)
  assertions = assertions + 1
  assert(actual == expected, tostring(actual) .. ' ~= ' .. tostring(expected))
end
timer_flag = {Enabled=1, OneShot=2, Temporary=4}
error_code = {eOK=0, eTimerNotFound=1}
trigger_flag = {Enabled=1, RegularExpression=32, Replace=1024, OneShot=32768, OmitFromOutput=2}
function Version() return '5.07' end
function GetUniqueNumber() nextId = nextId + 1; return nextId end
function AddTimer(name, hours, minutes, seconds, _, _, callback)
  scheduled[name] = {at=clock+hours*3600+minutes*60+seconds, callback=callback}
  return 0
end
function DeleteTimer(name) scheduled[name] = nil; return 0 end
function IsTimer(name) return scheduled[name] and 0 or 1 end
function EnableTrigger() return 0 end
function DeleteTrigger() return 0 end
function ColourTell() end
function strip_colours(s) return s end
function check(rv) assert(rv == 0) end

local function reset()
  clock, scheduled, nextId, messages, results = 0, {}, 0, {}, {}
  utils = {timer=function() return clock end}
  inv = {}
  dofile('dinv_dbot.lua')
  dofile('dinv_items.lua')
  dofile('dinv_data.lua')
  dofile('dinv_cache.lua')
  dofile('dinv_consume.lua')
  dofile('dinv_analyze.lua')
  dofile('dinv_cli.lua')
  dofile('dinv_runtime.lua')
  dofile('dinv_commands.lua')
  dofile('dinv_capture.lua')
  inv.init, inv.state = {initializedActive=true}, invStateIdle
  inv.config = {table={doIgnoreKeyring=false}}
  inv.tags = {stop=function(_, _, result) results[#results+1] = result; return result end}
  dbot.gmcp.isInitialized = true
  dbot.gmcp.getState = function() return dbot.stateActive end
  dbot.gmcp.getTier = function() return 0 end
  dbot.gmcp.getLevel = function() return 201 end
  dbot.gmcp.getName = function() return 'Test character', '' end
  dbot.prompt.hide, dbot.prompt.show = function() end, function() end
  dbot.print = function(message)
    assert(not message:find('Operation failed:', 1, true) and
           not message:find('Scheduled operation failed:', 1, true), message)
    messages[#messages+1] = message
  end
  inv.items.save = function() return DRL_RET_SUCCESS end
  dinv_db = {saveItem=function() return DRL_RET_SUCCESS end}
end

local function advance(seconds)
  local untilTime = clock + seconds
  for _=1,10000 do
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

local function test(name, fn)
  reset()
  local ok, err = pcall(fn)
  print((ok and 'PASS ' or 'FAIL ') .. name)
  if not ok then failures = failures + 1; print(err) end
end

test('analysis reports after a calculation longer than 60 seconds', function()
  local levels, reports = 0, 0
  inv.set = {table={}, save=function() end, create=function()
    inv.runtime.sleep(0.375)
    levels = levels + 1
    return DRL_RET_SUCCESS
  end}
  inv.statBonus = {save=function() end}
  inv.analyze.display = function() reports = reports + 1; return DRL_RET_SUCCESS end
  inv.cli.analyzePkg = {priorityName='test', wearableLocs='', skip=1, endTag={}}
  inv.runtime.start(inv.cli.analyzeCR, inv.cli, 'analyzePkg')
  advance(61)
  equal(#results, 0)
  equal(reports, 0)
  advance(20)
  equal(levels, 201)
  equal(reports, 1)
  equal(#results, 1)
  equal(results[1], DRL_RET_SUCCESS)
  equal(inv.cli.analyzePkg, nil)
  equal(inv.analyze.setsPkg, nil)
  equal(next(inv.runtime.tasks), nil)
end)

test('explicit missing responses retain their result through request cleanup', function()
  for _, line in ipairs({'You do not have that item.', 'This shop currently holds no inventory.',
      'There is no auction item with that id.', 'There is no marketplace item with that id.',
      'The shopkeeper does not have that item for sale.'}) do
    local package = {objId=101, lines={}}
    inv.items.identifyPkg = package
    equal(inv.items.trigger.itemIdStart(line), DRL_RET_MISSING_ENTRY)
    equal(package.retval, DRL_RET_MISSING_ENTRY)
    equal(inv.items.cleanupRequest({identification=package}, DRL_RET_SUCCESS), DRL_RET_MISSING_ENTRY)
    equal(inv.items.identifyPkg, nil)
  end
end)

test('an unfinished identification is still a timeout', function()
  local package = {objId=101, lines={}}
  inv.items.identifyPkg = package
  equal(inv.items.trigger.itemIdEnd(false), DRL_RET_TIMEOUT)
  equal(package.retval, DRL_RET_TIMEOUT)
end)

local function item(id, name, location, kind, identified)
  return {[invFieldColorName]=name, [invFieldObjLoc]=location,
    [invFieldIdentifyLevel]=identified and invIdLevelFull or invIdLevelNone,
    stats={[invStatFieldId]=id, [invStatFieldName]=name, [invStatFieldLevel]=10,
      [invStatFieldType]=kind}}
end

local function refreshFixture(failure)
  local bag = 900
  inv.items.table = {
    [101]=item(101, 'Gone potion', invItemLocInventory, invmon.typeStr[invmonTypePotion]),
    [102]=item(102, 'Moved item', invItemLocInventory, 'Armor'),
    [103]=item(103, 'Present item', invItemLocInventory, 'Armor'),
    [bag]=item(bag, 'Test bag', invItemLocInventory, invmon.typeStr[invmonTypeContainer], true),
  }
  local scanned, attempts, saved = {}, {}, {}
  inv.items.discoverLocation = function(location)
    scanned[location] = true
    if location == invItemLocInventory then
      inv.items.currentItems[103], inv.items.currentItems[bag] = {}, {}
    elseif location == bag then
      inv.items.currentItems[102] = {}
      inv.items.table[102][invFieldObjLoc] = bag
    end
    return DRL_RET_SUCCESS
  end
  inv.items.keyword = function() return DRL_RET_SUCCESS end
  inv.items.identifyItem = function(id, _, _, commands)
    commands[1] = id
    return DRL_RET_SUCCESS
  end
  dbot.execute.safe.blocking = function(commands)
    local id = commands[1]
    attempts[id] = (attempts[id] or 0) + 1
    if id == 101 or (id == 102 and not scanned[bag]) then return failure end
    inv.items.table[id][invFieldIdentifyLevel] = invIdLevelFull
    return DRL_RET_SUCCESS
  end
  dinv_db.saveItem = function(id) saved[id] = true; return DRL_RET_SUCCESS end
  inv.items.refreshPkg = {refreshLocations=invItemsRefreshLocAll, maxNumItems=0}
  return scanned, attempts, saved
end

test('full refresh skips missing items, scans bags and prunes only absent items', function()
  local scanned, attempts, saved = refreshFixture(DRL_RET_MISSING_ENTRY)
  equal(inv.items.refreshCR(), DRL_RET_SUCCESS)
  equal(scanned[900], true)
  equal(attempts[103], 1)
  equal(attempts[102], 2)
  equal(saved[101], nil)
  equal(inv.cache.get(inv.cache.frequent.table, 'Gone potion'), nil)
  equal(inv.items.table[101], nil)
  equal(inv.items.getField(102, invFieldObjLoc), 900)
  equal(inv.items.getField(102, invFieldIdentifyLevel), invIdLevelFull)
  equal(inv.items.fullScanCompleted, true)
end)

test('partial refresh skips missing entries without pruning unscanned inventory', function()
  local scanned, _, saved = refreshFixture(DRL_RET_MISSING_ENTRY)
  inv.items.refreshPkg.refreshLocations = invItemsRefreshLocMain
  equal(inv.items.refreshCR(), DRL_RET_SUCCESS)
  equal(scanned[900], nil)
  equal(inv.items.table[101] ~= nil, true)
  equal(inv.items.table[102] ~= nil, true)
  equal(saved[101], nil)
  equal(saved[102], nil)
  equal(inv.items.fullScanCompleted, false)
end)

for _, errorName in ipairs({'DRL_RET_TIMEOUT', 'DRL_RET_BUSY', 'DRL_RET_HALTED', 'DRL_RET_NOT_ACTIVE'}) do
  test(errorName .. ' still aborts refresh without orphan pruning', function()
    local failure = _G[errorName]
    local scanned = refreshFixture(failure)
    equal(inv.items.refreshCR(), failure)
    equal(scanned[900], nil)
    equal(inv.items.table[101] ~= nil, true)
    equal(inv.items.table[102] ~= nil, true)
    equal(inv.items.fullScanCompleted, false)
  end)
end

test('consumption count is visible at standard verbosity', function()
  inv.consume.table.heal = {{level=10, fullName='Test potion'}}
  inv.items.table = {
    [101]=item(101, 'Test potion', invItemLocInventory, 'Potion', true),
    [102]=item(102, 'Test potion', 900, 'Potion', true),
  }
  equal(dbot.notify.level[notifyLevelDebug].enabled, false)
  equal(dbot.notify.level[notifyLevelInfo].enabled, true)
  local id, retval = inv.consume.get('heal', drlConsumeBig)
  equal(id, 101)
  equal(retval, DRL_RET_SUCCESS)
  equal(#messages, 1)
  equal(messages[1]:find('2 available', 1, true) ~= nil, true)
end)

assert(failures == 0, failures .. ' regression test(s) failed')
print(assertions .. ' assertions passed')
