----------------------------------------------------------------------------------------------------
-- Inventory cache subsystem
----------------------------------------------------------------------------------------------------
-- The "recent cache" attempts to cache the items that have been most recently removed
-- from the inventory table.  This lets us re-identify those items very quickly if we
-- add them back to the inventory at some point.  For example, we may want to drop a bag
-- of keys and then pick it up again later.  In that case we don't want to re-identify
-- everything.  Also, we don't want to re-identify everything in our entire inventory
-- if we die and lose all of our items.
--
-- The recent cache is indexed by objId because we are tracking specific item instances.
-- This differs from the "frequently acquired" cache that is indexed by an item's name.
--
-- The "frequently acquired" cache tracks items that are frequently added to your inventory.
-- For example, we don't want to re-identify the same healing potion 50 times if you buy a
-- stack of 50 potions.  We keep a generic item entry for items that don't change but are
-- acquired a lot.  We can skip the full identification procedure if the name of a potion,
-- pill, food, etc. matches a key in the cache.  In that case, we use the cached details
-- without performing the identification.
--
-- The "custom" cache contains user-specified customizations to items.  For example, an
-- item may have been assigned a custom keyword or a container may have been assigned one
-- or more organize queries.  The recent cache can hold some items including any customizations
-- for each item.  However, there can be a lot of turnover in the recent cache -- especially
-- during catastrophic events such as dying where your entire inventory may overflow the cache.
-- Entries in the "custom" cache are much longer-lived than entries in the recent cache and
-- this greatly reduces the odds that someone will lose a customization that they actually
-- want.  Also, the custom cache can support more entries than the recent cache because only
-- custom fields need to be saved.
--
-- Functions:
--   inv.cache.init.atActive()
--   inv.cache.fini(doSaveState)
--
--   inv.cache.config(cacheName, numEntries)
--   inv.cache.save()
--   inv.cache.load()
--
--   inv.cache.saveRecent()
--   inv.cache.saveFrequent()
--   inv.cache.saveCustom()
--
--   inv.cache.reset() -- reset all caches
--   inv.cache.resetRecent()
--   inv.cache.resetFrequent()
--   inv.cache.resetCustom()
--
--   inv.cache.resetCache(cacheName) -- reset a single specific cache
--   inv.cache.add
--   inv.cache.remove
--   inv.cache.prune
-- 
--   inv.cache.get
--   inv.cache.getSize
--   inv.cache.setSize
-- 
--   inv.cache.dump
--   inv.cache.clearOld
-- 
-- Data:
--   inv.cache.recent.table
--   inv.cache.frequent.table
--   inv.cache.custom.table
----------------------------------------------------------------------------------------------------

inv.cache          = {}
inv.cache.init     = {}
inv.cache.recent   = {}
inv.cache.frequent = {}
inv.cache.custom   = {}

inv.cache.recent.table   = nil
inv.cache.frequent.table = nil
inv.cache.custom.table   = nil

inv.cache.recent.name   = "recent"
inv.cache.frequent.name = "frequent"
inv.cache.custom.name   = "custom"

inv.cache.recent.stateName   = "inv-cache-recent.state"
inv.cache.frequent.stateName = "inv-cache-frequent.state"
inv.cache.custom.stateName   = "inv-cache-custom.state"

inv.cache.recent.defaultNumEntries   = 1000
inv.cache.frequent.defaultNumEntries = 100
inv.cache.custom.defaultNumEntries   = 1500

inv.cache.recent.prunePercent   = 0.20
inv.cache.frequent.prunePercent = 0.10
inv.cache.custom.prunePercent   = 0.05


function inv.cache.init.atActive()
  local retval = DRL_RET_SUCCESS

  retval = inv.cache.load()
  if (retval ~= DRL_RET_SUCCESS) then
    dbot.warn("inv.cache.init.atActive: failed to load cache data from storage: " ..
              dbot.retval.getString(retval))
  end -- if

  return retval
end -- inv.cache.init.atActive


function inv.cache.fini(doSaveState)
  local retval = DRL_RET_SUCCESS

  if (doSaveState) then
    -- Save our current data
    retval = inv.cache.save()
    if (retval ~= DRL_RET_SUCCESS) and (retval ~= DRL_RET_UNINITIALIZED) then
      dbot.warn("inv.cache.fini: Failed to save inv.cache module data: " .. dbot.retval.getString(retval))
    end -- if
  end -- if

  return retval
end -- inv.cache.fini


function inv.cache.config(cacheName, numEntries)
  local retval = DRL_RET_SUCCESS

  if (cacheName ~= inv.cache.recent.name)   and
     (cacheName ~= inv.cache.frequent.name) and
     (cacheName ~= inv.cache.custom.name)   then
    dbot.warn("inv.cache.config: Invalid cache name \"" .. (cacheName or "nil") .. "\"")
    return DRL_RET_INVALID_PARAM
  end -- if

  if (numEntries == nil) or (tonumber(numEntries) == nil) then
    dbot.warn("inv.cache.config: Invalid numEntries parameter: It is not a number")
    return DRL_RET_INVALID_PARAM
  end -- if

  -- Build the cache data structure
  local cache      = {}
  cache.entries    = {}
  cache.name       = cacheName
  cache.maxEntries = tonumber(numEntries)

  if (cacheName == inv.cache.recent.name) then
    inv.cache.recent.table = cache
    retval = inv.cache.saveRecent()

  elseif (cacheName == inv.cache.frequent.name) then
    inv.cache.frequent.table = cache
    retval = inv.cache.saveFrequent()

  elseif (cacheName == inv.cache.custom.name) then
    inv.cache.custom.table = cache
    retval = inv.cache.saveCustom()

  else
    dbot.error("inv.cache.config: Invalid cache name detected: \"" .. (cacheName or "nil") .. "\"")
    return DRL_RET_INTERNAL_ERROR
  end -- if

  return retval
end -- inv.cache.config


function inv.cache.save()
  local recentRetval   = inv.cache.saveRecent()
  local frequentRetval = inv.cache.saveFrequent()
  local customRetval   = inv.cache.saveCustom()

  if (recentRetval ~= DRL_RET_SUCCESS) then
    return recentRetval
  elseif (frequentRetval ~= DRL_RET_SUCCESS) then
    return frequentRetval
  else
    return customRetval
  end -- if

end -- inv.cache.save


function inv.cache.saveRecent()
  local retval = DRL_RET_SUCCESS

  if (inv.cache.recent.table ~= nil) then
    retval = dbot.storage.saveTable(dbot.backup.getCurrentDir() .. inv.cache.recent.stateName,
                                    "inv.cache.recent.table", inv.cache.recent.table)
    if (retval ~= DRL_RET_SUCCESS) and (retval ~= DRL_RET_UNINITIALIZED) then
      dbot.warn("inv.cache.saveRecent: Failed to save cache.recent table: " ..
                dbot.retval.getString(retval))
    end -- if
  end -- if

  return retval
end -- inv.cache.saveRecent


function inv.cache.saveFrequent()
  local retval = DRL_RET_SUCCESS

  if (inv.cache.frequent.table ~= nil) then
    retval = dbot.storage.saveTable(dbot.backup.getCurrentDir() .. inv.cache.frequent.stateName,
                                    "inv.cache.frequent.table", inv.cache.frequent.table)
    if (retval ~= DRL_RET_SUCCESS) and (retval ~= DRL_RET_UNINITIALIZED) then
      dbot.warn("inv.cache.saveFrequent: Failed to save cache.frequent table: " ..
                dbot.retval.getString(retval))
    end -- if
  end -- if

  return retval
end -- inv.cache.saveFrequent


function inv.cache.saveCustom()
  local retval = DRL_RET_SUCCESS

  if (inv.cache.custom.table ~= nil) then
    retval = dbot.storage.saveTable(dbot.backup.getCurrentDir() .. inv.cache.custom.stateName,
                                    "inv.cache.custom.table", inv.cache.custom.table)
    if (retval ~= DRL_RET_SUCCESS) and (retval ~= DRL_RET_UNINITIALIZED) then
      dbot.warn("inv.cache.saveCustom: Failed to save cache.custom table: " ..
                dbot.retval.getString(retval))
    end -- if
  end -- if

  return retval
end -- inv.cache.saveCustom


function inv.cache.load()
  local retval = DRL_RET_SUCCESS

  local recentRetval = dbot.storage.loadTable(dbot.backup.getCurrentDir() .. inv.cache.recent.stateName,
                                              inv.cache.resetRecent)
  if (recentRetval ~= DRL_RET_SUCCESS) then
    dbot.warn("inv.cache.load: Failed to load cache table from file \"@R" .. 
              dbot.backup.getCurrentDir() .. inv.cache.recent.stateName .. "@W\": " ..
              dbot.retval.getString(recentRetval))
    retval = recentRetval
  end -- if

  local frequentRetval = dbot.storage.loadTable(dbot.backup.getCurrentDir() .. inv.cache.frequent.stateName,
                                                inv.cache.resetFrequent)
  if (frequentRetval ~= DRL_RET_SUCCESS) then
    dbot.warn("inv.cache.load: Failed to load cache table from file \"@R" .. 
              dbot.backup.getCurrentDir() .. inv.cache.frequent.stateName .. "@W\": " ..
              dbot.retval.getString(frequentRetval))
    retval = frequentRetval
  end -- if

  local customRetval = dbot.storage.loadTable(dbot.backup.getCurrentDir() .. inv.cache.custom.stateName,
                                              inv.cache.resetCustom)
  if (customRetval ~= DRL_RET_SUCCESS) then
    dbot.warn("inv.cache.load: Failed to load cache table from file \"@R" .. 
              dbot.backup.getCurrentDir() .. inv.cache.custom.stateName .. "@W\": " ..
              dbot.retval.getString(customRetval))
    retval = customRetval
  end -- if

  if (inv.version.table ~= nil) and (inv.version.table.tableFormat ~= nil) and
     (inv.config.table ~= nil) and (inv.config.table.tableFormat ~= nil) and
     (inv.version.table.cacheFormat ~= nil) and (inv.config.table.cacheFormat ~= nil) then
    -- Check if the inventory table version we loaded is compatible with the current code
    if (inv.version.table.tableFormat.major ~= inv.config.table.tableFormat.major) and
       (inv.version.table.tableFormat.minor ~= inv.config.table.tableFormat.minor) then
      -- TODO: This is a placeholder for when (or if?) we ever change the table format
    end -- if

    -- Check if the inventory cache version we loaded is compatible with the current code
    if (inv.version.table.cacheFormat.major ~= inv.config.table.cacheFormat.major) and
       (inv.version.table.cacheFormat.minor ~= inv.config.table.cacheFormat.minor) then
      -- TODO: This is a placeholder for when (or if?) we ever change the cache format
    end -- if
  else
    dbot.error("inv.cache.load: Missing inv.version components")
    retval = DRL_RET_INTERNAL_ERROR
  end -- if

  return retval

end -- inv.cache.load


function inv.cache.reset()
  local recentRetval   = inv.cache.resetRecent()
  local frequentRetval = inv.cache.resetFrequent()
  local customRetval   = inv.cache.resetCustom()

  if (recentRetval ~= DRL_RET_SUCCESS) then
    return recentRetval
  elseif (frequentRetval ~= DRL_RET_SUCCESS) then
    return frequentRetval
  else
    return customRetval
  end -- if

end -- inv.cache.reset


function inv.cache.resetRecent()
  local retval = DRL_RET_SUCCESS

  if (inv.cache.recent ~= nil) then
    retval = inv.cache.resetCache(inv.cache.recent.name)
    if (retval ~= DRL_RET_SUCCESS) then
      dbot.warn("inv.cache.resetRecent: recent cache reset failed: " .. dbot.retval.getString(recentRetval))
    end -- if
  end -- if

  return retval
end -- inv.cache.resetRecent


function inv.cache.resetFrequent()
  local retval = DRL_RET_SUCCESS

  if (inv.cache.frequent ~= nil) then
    retval = inv.cache.resetCache(inv.cache.frequent.name)
    if (retval ~= DRL_RET_SUCCESS) then
      dbot.warn("inv.cache.resetFrequent: frequent cache reset failed: " ..
                dbot.retval.getString(frequentRetval))
    end -- if
  end -- if

  return retval
end -- inv.cache.resetFrequent


function inv.cache.resetCustom()
  local retval = DRL_RET_SUCCESS

  if (inv.cache.custom ~= nil) then
    retval = inv.cache.resetCache(inv.cache.custom.name)
    if (retval ~= DRL_RET_SUCCESS) then
      dbot.warn("inv.cache.resetCustom: custom cache reset failed: " .. dbot.retval.getString(customRetval))
    end -- if
  end -- if

  return retval
end -- inv.cache.resetCustom


function inv.cache.resetCache(cacheName)
  if (cacheName == nil) or (cacheName == "") then
    dbot.warn("inv.cache.reset: Missing cache name")
    return DRL_RET_INVALID_PARAM
  end -- if

  local numEntries = 0

  if (cacheName == inv.cache.recent.name) then
    numEntries = inv.cache.recent.defaultNumEntries
  elseif (cacheName == inv.cache.frequent.name) then
    numEntries = inv.cache.frequent.defaultNumEntries
  elseif (cacheName == inv.cache.custom.name) then
    numEntries = inv.cache.custom.defaultNumEntries
  end -- if
 
  local retval = inv.cache.config(cacheName, numEntries)
  if (retval ~= DRL_RET_SUCCESS) then
    dbot.warn("inv.cache.resetCache: Failed to configure cache: " .. dbot.retval.getString(retval))
  end -- if

  return retval
end -- inv.cache.resetCache


function inv.cache.add(cache, objId)
  assert(cache ~= nil, "Cache is nil!!!")
  local retval = DRL_RET_SUCCESS

  assert(objId ~= nil, "Received nil objId!!!")
  objId = tonumber(objId)

  local entry = inv.items.getEntry(objId)
  if (entry == nil) then
    dbot.warn("inv.cache.add: Cannot add item to cache because it is not in the inventory table")
    return DRL_RET_MISSING_ENTRY
  end -- if

  -- Cache the object if we've done some type of identification on it
  local idLevel = inv.items.getField(objId, invFieldIdentifyLevel)
  if (idLevel ~= nil) then
    if (cache.name == inv.cache.recent.name) then
      cache.entries[objId] = { timeCached = dbot.getTime(), entry = dbot.table.getCopy(entry) }
    elseif (cache.name == inv.cache.frequent.name) then
      local name = inv.items.getStatField(objId, invStatFieldName)
      if (name ~= nil) and (name ~= "") then
        -- invdata strips out commas in the names of items.  As a result, we won't find items in
        -- the cache unless we also store them in a form without commas.
        name = string.gsub(name, ",", "")
        cache.entries[name] = { timeCached = dbot.getTime(), entry = dbot.table.getCopy(entry) }
      end -- if
    elseif (cache.name == inv.cache.custom.name) then
      local newEntry = {}
      newEntry.keywords = inv.items.getStatField(objId, invStatFieldKeywords) or ""
      newEntry.organize = inv.items.getStatField(objId, invQueryKeyOrganize)  or ""
      cache.entries[objId] = { timeCached = dbot.getTime(), entry = newEntry }
    else
      dbot.warn("inv.cache.add: Unknown cache name \"" .. (cache.name or "nil") .. "\"")
    end -- if

    dbot.debug("Added \"" .. (inv.items.getField(objId, "colorName") or "Unidentified") .. "@W\" " ..
               "to the \"" .. cache.name .. "\" cache")
  end -- if

  -- Check if the cache is full and remove entries as needed to reduce the size.  We always
  -- remove the least recently used item when necessary.  As an optimization once the cache
  -- starts to get full, we whack a certain percentage (10%? 20%?) of entries when we prune the
  -- cache so that we don't need to go through the overhead of sorting everything every time
  -- we drop an item.
  if (dbot.table.getNumEntries(cache.entries) > cache.maxEntries) then
    retval = inv.cache.prune(cache)
  end -- if

  -- Note: To cut down on overhead, we currently do not call inv.cache.save() here.  Instead,
  --       the lossy caches (recent and frequent) are saved in inv.cache.fini.  There is a chance
  --       we may miss some cache updates this way if mush exits uncleanly, but the downside is
  --       low because we we'll just re-identify anything we need if that happens.  On the other
  --       hand, we must save the custom cache after a batch add so that we don't lose what the
  --       user entered.

  return retval
end -- inv.cache.add


function inv.cache.remove(cache, key)
  assert(cache ~= nil, "Cache is nil!!!")
  assert(key ~= nil, "Received nil key!!!")
  local cacheKey = key

  -- The recent and custom caches use a numeric object ID as a key and we do a little extra parameter
  -- checking in this case because I'm paranoid...
  if (cache.name == inv.cache.recent.name) or (cache.name == inv.cache.custom.name) then
    cacheKey = tonumber(key)
    if (cacheKey == nil) then
      dbot.warn("inv.cache.remove: failed to remove item for non-numeric objId key " .. key)
      return DRL_RET_INVALID_PARAM
    end -- if

    dbot.debug("Removed \"" .. (inv.items.getField(key, "colorName") or "Unidentified") .. "\" " ..
               "from the \"" .. cache.name .. "\" cache")
  end -- if

  cache.entries[cacheKey] = nil

  -- Note: To cut down on overhead, we currently do not call inv.cache.save() here.  Instead,
  --       the cache is saved in inv.cache.fini when we disconnect or reload the plugin.  There
  --       is a chance we may miss some cache updates this way if mush exits uncleanly, but the
  --       downside is low because we we'll just re-identify anything we need if that happens.

  return DRL_RET_SUCCESS
end -- inv.cache.remove


function inv.cache.prune(cache)
  assert(cache ~= nil, "Cache is nil!!!")

  local retval = DRL_RET_SUCCESS
  local numEntriesInCache = dbot.table.getNumEntries(cache.entries)
  local numEntriesToPrune = 0

  -- Determine how many entries in the cache to remove in this call.  We don't want
  -- to need to prune things on every cache access because it is expensive to sort
  -- the arrays.  Instead, if we detect a full cache, we whack several cache entries
  -- at once so that we can amortize the overhead of pruning over several accesses.
  if (cache.name == inv.cache.recent.name) then
    numEntriesToPrune = math.floor(numEntriesInCache * inv.cache.recent.prunePercent) + 1 or 0
  elseif (cache.name == inv.cache.frequent.name) then
    numEntriesToPrune = math.floor(numEntriesInCache * inv.cache.frequent.prunePercent) + 1 or 0
  elseif (cache.name == inv.cache.custom.name) then
    numEntriesToPrune = math.floor(numEntriesInCache * inv.cache.custom.prunePercent) + 1 or 0
  end -- if

  dbot.debug("The " .. cache.name .. " cache is full, removing the " .. 
             numEntriesToPrune .. " least recently used items")

  -- Sort the cache entries.  We create a temporary array of the entries so that we can sort them
  -- (you can't sort a table.)
  local entryArray = {}

  -- The custom cache only prunes items that aren't currently in inventory.  If an item is not
  -- in inventory, we first get rid of items that are no longer even in the recent cache before
  -- we remove recently cached items.  If all else fails, we sort things by cache time.
  if (cache.name == inv.cache.custom.name) then
    for k,v in pairs(cache.entries) do
      if (inv.items.getEntry(k) == nil) then
        table.insert(entryArray, { key=k, timeCached=v.timeCached })
      end -- if
    end -- for
    table.sort(entryArray,
               function (e1, e2)
                 local recent1 = inv.cache.recent.table.entries[e1]
                 local recent2 = inv.cache.recent.table.entries[e2]

                 if (recent1 == nil) and (recent2 ~= nil) then
                   return true
                 elseif (recent1 ~= nil) and (recent2 == nil) then
                   return false
                 else
                   return e1.timeCached < e2.timeCached
                 end -- if
               end) -- function

  -- The recent and frequent caches sort by the last access time
  else
    for k,v in pairs(cache.entries) do
      table.insert(entryArray, { key=k, timeCached=v.timeCached })
    end -- for
    table.sort(entryArray, function (entry1, entry2) return entry1.timeCached < entry2.timeCached end)
  end -- if

  -- Remove the "numEntriesToPrune" first entries in the array
  for i = 1, numEntriesToPrune do
    if (entryArray[i] == nil) then
      break
    end -- if

    local key = entryArray[i].key
    retval = inv.cache.remove(cache, key)
    if (retval ~= DRL_RET_SUCCESS) then
      dbot.warn("inv.cache.prune: Failed to remove cache item " .. key)
      break
    end -- if
  end -- for

  return retval
end -- inv.cache.prune


function inv.cache.get(cache, key)

  if (cache == nil) or (key == nil) or (key == "") then
    return nil
  end -- if

  local cacheKey = key

  -- The recent and custom caches use a numeric object ID as a key and we do a little extra parameter
  -- checking in this case because I'm paranoid...
  if (cache.name == inv.cache.recent.name) or (cache.name == inv.cache.custom.name) then
    cacheKey = tonumber(key)
    if (cacheKey == nil) then
      dbot.warn("inv.cache.get: failed to get item for non-numeric objId key " .. key)
      return nil
    end -- if
  end -- if

  local cacheEntry = cache.entries[cacheKey]
  if (cacheEntry == nil) then
    return nil -- it isn't in the cache
  end -- if

  -- Update the timestamp
  cacheEntry.timeCached = dbot.getTime()

  -- Return a copy of the cached entry (we don't want the caller directly modifying the entry in our cache)
  return dbot.table.getCopy(cacheEntry.entry)
end -- inv.cache.get


function inv.cache.getSize(cache)
  assert(cache ~= nil, "Cache is nil!!!")

  return cache.maxEntries
end -- inv.cache.getSize


function inv.cache.setSize(cache, numEntries)
  local retval = DRL_RET_SUCCESS

  assert(cache ~= nil, "Cache is nil!!!")
  assert(tonumber(numEntries) ~= nil, "numEntries parameter is not numeric!")

  cache.maxEntries = numEntries

  if (cache.name == inv.cache.recent.name) then
    retval = inv.cache.saveRecent()

  elseif (cache.name == inv.cache.frequent.name) then
    retval = inv.cache.saveFrequent()

  elseif (cache.name == inv.cache.custom.name) then
    retval = inv.cache.saveCustom()

  else
    dbot.warn("inv.cache.setSize: Invalid cache name detected: \"" .. (cache.name or "nil") .. "\"")
    retval = DRL_RET_INTERNAL_ERROR
  end -- if

  return retval

end -- inv.cache.setSize


function inv.cache.dump(cache)
  assert(cache ~= nil, "Cache is nil!!!")

  tprint(cache)
  return DRL_RET_SUCCESS
end -- inv.cache.dump


-- Remove all cached items older than ageInSec
-- We don't currently use this, but it might be handy at some point
function inv.cache.clearOld(cache, ageInSec)
  assert(cache ~= nil, "Cache is nil!!!")
  local currentTime = dbot.getTime()

  for key,cacheEntry in pairs(cache.entries) do
    if (cacheEntry == nil) or (cacheEntry.timeCached == nil) or 
       (currentTime - cacheEntry.timeCached > ageInSec) then
      inv.cache.remove(cache, key)
    end -- if
  end -- for
end -- inv.cache.clearOld


