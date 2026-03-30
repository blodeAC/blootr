-- property_manifest.lua
-- Merges base and daralet manifests, exposes forCategory() and probeEntry().

local Base    = require("manifest")
local server = require("manifest_" .. game.ServerName)
local C       = require("item_category").Category

-- ── Flatten all sub-tables into one ordered list ──────────────────────────────

local Manifest = {}
local _additionalProperties

local function append(t)
  for _, entry in ipairs(t) do
    table.insert(Manifest, entry)
  end
end

-- Base entries
append(Base.universal)
append(Base.weapon)
append(Base.wand)
append(Base.armor)
append(Base.magic)

-- Server entries
if server ~= nil then
  append(server.armor_mods)
  append(server.weapon_mods)
  append(server.gear_ratings)
  _additionalProperties = server._additionalProperties
end

-- ── Category filter ───────────────────────────────────────────────────────────

local function matchesCategory(entry, category)
  if entry.categories == "*" then return true end
  for _, c in ipairs(entry.categories) do
    if c == category then return true end
  end
  return false
end

local function forCategory(category)
  local result = {}
  for _, entry in ipairs(Manifest) do
    if matchesCategory(entry, category) then
      table.insert(result, entry)
    end
  end
  return result
end

-- ── Property probing ──────────────────────────────────────────────────────────
-- Resolves propKey vs propId, dispatches to the right InqXxx helper.
-- The Daralet metatables make string keys work transparently with InqXxx.

local function probeEntry(entry, itemData)
  local key
  if entry.propKey then
    key = entry.propKey
  elseif entry.propId then
    key = entry.propId  -- pass enum directly, InqInt does tostring() which gives the name
  end

  if entry.propType == "spells" then
    local has = itemData.spells ~= nil and itemData.spells ~= ""
    return has, itemData.spells or ""
  elseif entry.propType == "wieldReq" then
    -- present if any wield requirement slot is populated
    local suffixes = { "", "2", "3", "4" }
    for _, s in ipairs(suffixes) do
      if itemData.IntValues and itemData.IntValues["WieldRequirements" .. s] then
        local reqType   = itemData.IntValues["WieldRequirements" .. s]
        local skillType = itemData.IntValues["WieldSkilltype" .. s] or 0
        local diff      = itemData.IntValues["WieldDifficulty" .. s] or 1
        return true, { reqType=reqType, skillType=skillType, difficulty=diff }
      end
    end
    return false, nil
  end
  if key == nil then return false, nil end

  if     entry.propType == "IntValues"    then return InqInt(itemData, key)
  elseif entry.propType == "FloatValues"  then return InqFloat(itemData, key)
  elseif entry.propType == "BoolValues"   then return InqBool(itemData, key)
  elseif entry.propType == "StringValues" then return InqString(itemData, key)
  elseif entry.propType == "Int64Values"  then return InqInt64(itemData, key)
  end
  return false, nil
end

return {
  Manifest    = Manifest,
  forCategory = forCategory,
  probeEntry  = probeEntry,
  _additionalProperties = _additionalProperties
}