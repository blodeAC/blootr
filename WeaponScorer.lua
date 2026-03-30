-------------------------------------------------------------------------------
-- WeaponScorer.lua
--
-- Scores melee, missile, and caster weapons as per-stat percentiles (0–1).
-- Two server modes: SERVER_ORIGINAL (txt PMF) and SERVER_CUSTOM (analytical).
--
-- PRIMARY ENTRY POINTS:
--
--   WS.scoreWeapon(weapon, mutationsRoot, serverType, weights)
--     weapon is a flat table — use weenieToWeapon() or scoreWeenie() to
--     build one from a live weenie object with IntValues/FloatValues.
--     Tier is never a parameter.  For the original server it is derived
--     internally from weapon.WieldDifficulty.  For the custom server it is
--     read from weapon.tier (populated by weenieToWeapon from the server's
--     custom Tier property).
--
--   WS.scoreWeenie(weenie, meta, mutationsRoot, serverType, weights)
--     Convenience wrapper: calls weenieToWeapon(weenie, meta) then scoreWeapon.
--
-- FLAT WEAPON TABLE — FIELDS USED BY scoreWeapon():
--
--   All categories:
--     weaponCategory  "MeleeWeapon" | "MissileWeapon" | "Caster"
--     WieldDifficulty integer wield requirement (original server tier source)
--     tier            integer 1-8 (custom server only; from weenie IntValues)
--
--   Original melee:
--     weaponSkill, weaponType, Damage, DamageVariance, WeaponOffense,
--     WeaponDefense, weaponSpeedMod, missileDef, magicDef
--
--   Custom melee:
--     weaponSkill, weaponType, isDoubleStrike, isTripleStrike, isTwoHanded,
--     isAmmoLauncher, baseWeaponTime, baseVariance, Damage, DamageVariance,
--     WeaponOffense, WeaponPhysicalDefense, WeaponMagicalDefense, weaponTime
--     + subtype: criticalFrequency | criticalMultiplier | ignoreArmor |
--                staminaCostReductionMod
--
--   Custom missile:
--     weaponSkill, DamageMod, WeaponOffense,
--     WeaponPhysicalDefense, WeaponMagicalDefense, weaponTime, baseWeaponTime
--     + subtype: criticalFrequency | criticalMultiplier | ignoreArmor
--
--   Custom caster:
--     weaponSkill ("WarMagic"|"LifeMagic"),
--     ElementalDamageMod, WeaponWarMagicMod | WeaponLifeMagicMod,
--     WeaponPhysicalDefense, WeaponMagicalDefense
--     + subtype: ignoreWard | criticalFrequency | criticalMultiplier |
--                subtypeDefenseBonus
--
--   Original missile:
--     weaponType, isElemental, DamageMod, ElementalDamageBonus (elemental only),
--     WeaponDefense, weaponSpeedMod, missileDef, magicDef
--
--   Original caster:
--     isElemental, ElementalDamageMod, WeaponDefense, ManaConversionMod,
--     missileDef, magicDef
-------------------------------------------------------------------------------

local WeaponScorer = {}

WeaponScorer.SERVER_ORIGINAL = "original"
WeaponScorer.SERVER_CUSTOM   = "custom"
WeaponScorer.serverType      = WeaponScorer.SERVER_ORIGINAL

-- Derives the tier index (1-8) for a weapon on the original server by scanning
-- the mutation list for the file that was already loaded for this weapon type.
-- For each tier, finds the highest WieldDifficulty that tier's outcomes can
-- produce.  Returns the lowest tier whose maximum WieldDifficulty is >= the
-- weapon's WieldDifficulty.  Tiers that share the same maximum (e.g. bows at
-- T5-T8 all cap at the same value) will resolve to the lowest of them, which
-- is fine because their PMF distributions are identical.
local function deriveTierFromMutations(mutationList, wieldDiff)
  wieldDiff = wieldDiff or 0
  
  local tierMaxWield = {}
  for tier = 1, 8 do
    local maxWield = 0
    for _, mutation in ipairs(mutationList) do
      if (mutation.tierProb[tier] or 0) > 0 then
        for _, outcome in ipairs(mutation.outcomes) do
          local wd = outcome.stats.WieldDifficulty
          if wd and type(wd.value) == "number" and wd.value > maxWield then
            maxWield = wd.value
          end
        end
      end
    end
    tierMaxWield[tier] = maxWield
  end
  
  for tier = 1, 8 do
    if tierMaxWield[tier] >= wieldDiff then
      return tier
    end
  end
  return 8
end

-------------------------------------------------------------------------------
-- COMBAT STYLE ENUM
-------------------------------------------------------------------------------

local CombatStyle = setmetatable(
{
  Undef              = 0x00000,
  Unarmed            = 0x00001,
  OneHanded          = 0x00002,
  OneHandedAndShield = 0x00004,
  TwoHanded          = 0x00008,
  Bow                = 0x00010,
  Crossbow           = 0x00020,
  Sling              = 0x00040,
  ThrownWeapon       = 0x00080,
  DualWield          = 0x00100,
  Magic              = 0x00200,
  Atlatl             = 0x00400,
  ThrownShield       = 0x00800,
  Reserved1          = 0x01000,
  Reserved2          = 0x02000,
  Reserved3          = 0x04000,
  Reserved4          = 0x08000,
  StubbornMagic      = 0x10000,
  StubbornProjectile = 0x20000,
  StubbornMelee      = 0x40000,
  StubbornMissile    = 0x80000,
  All                = 0xFFFF,
},
{
  __index = function(table, key)
    if key == "Melee" then
      local v = table.Unarmed + table.OneHanded + table.OneHandedAndShield
      + table.TwoHanded + table.DualWield
      rawset(table, key, v)
      return v
    elseif key == "Missile" then
      local v = table.Bow + table.Crossbow + table.Sling
      + table.ThrownWeapon + table.Atlatl + table.ThrownShield
      rawset(table, key, v)
      return v
    end
  end,
})

local function isAmmoLauncher(weenie)
  local s = weenie.IntValues[IntId.DefaultCombatStyle]
  return s == CombatStyle.Bow or s == CombatStyle.Crossbow
end

local function isTwoHanded(weenie)
  return weenie.IntValues[IntId.DefaultCombatStyle] == CombatStyle.TwoHanded
end

WeaponScorer.CombatStyle    = CombatStyle
WeaponScorer.isAmmoLauncher = isAmmoLauncher
WeaponScorer.isTwoHanded    = isTwoHanded

-------------------------------------------------------------------------------
-- ATTACK TYPE BITMASKS
--
-- DoubleStrike = 0x0020|0x0080|0x0800|0x2000 = 0x28A0
-- TripleStrike = 0x0040|0x0100|0x1000|0x4000 = 0x5140
-------------------------------------------------------------------------------

local ATTACK_DOUBLE_STRIKE_MASK = 0x28A0
local ATTACK_TRIPLE_STRIKE_MASK = 0x5140

-------------------------------------------------------------------------------
-- WEENIE PROPERTY ADAPTER
--
-- Builds a flat weapon table from a live weenie object.  Everything is read
-- directly from the weenie's IntValues / FloatValues / StringValues tables.
--
-- Speed scoring differs by server:
--   original server: RollWeaponSpeedMod stores the rolled float directly as a
--                    property (weaponSpeedMod from FloatValues["WeaponSpeed"],
--                    [VERIFY key name]).  No base time needed.
--   custom server:   speed is derived from weaponTime / baseWeaponTime ratio.
-------------------------------------------------------------------------------

local bit = require("bit")
local ORIG_MISSILE_SCRIPT_NAME

function WeaponScorer.weenieToWeapon(weenie)
  local weapon = {}
  
  weapon.wcid           = weenie.wcid
  weapon.weaponCategory = tostring(weenie.objectType)
  
  local weaponSkillRaw  = weenie.IntValues["WeaponSkill"]
  weapon.weaponSkill    = weaponSkillRaw and tostring(SkillId.Undef + weaponSkillRaw) or "Undef"
  
  -- MaceJitte shares the "Mace" enum value; detect by name substring.
  local weaponTypeRaw  = weenie.IntValues["WeaponType"]
  local weaponTypeName = weaponTypeRaw and tostring(WeaponType.Undef + weaponTypeRaw) or "Undef"
  if weaponTypeName == "Mace" then
    local itemName = weenie.StringValues["Name"] or ""
    if itemName:lower():find("jitte") then
      weaponTypeName = "MaceJitte"
    end
  elseif weaponTypeName == "Undef" then
    local itemName = weenie.StringValues["Name"] or ""
    for key,_ in pairs(ORIG_MISSILE_SCRIPT_NAME) do
      if itemName:find(key) then
        weaponTypeName = key
      end
    end
  end
  weapon.weaponType = weaponTypeName
  
  -- Attack type flags derived from raw bitmask integer.
  -- DoubleStrike = 0x28A0, TripleStrike = 0x5140
  local attackTypeRaw   = weenie.IntValues["AttackType"] or 0
  weapon.attackTypeRaw  = attackTypeRaw
  weapon.isDoubleStrike = bit.band(attackTypeRaw, ATTACK_DOUBLE_STRIKE_MASK) > 0
  weapon.isTripleStrike = bit.band(attackTypeRaw, ATTACK_TRIPLE_STRIKE_MASK) > 0
  weapon.isMultiStrike  = weapon.isDoubleStrike or weapon.isTripleStrike
  weapon.attackType     = tostring(AttackType.Undef + attackTypeRaw)
  
  -- isElemental: true if DamageType is set to anything nonzero.
  weapon.isElemental = (weenie.IntValues["DamageType"] or 0) > 0
  
  -- Original server: RollWeaponSpeedMod stores the rolled speedMod float
  -- directly as a property.  Passed straight to cdfOriginalSpeed.
  -- [VERIFY: confirm "WeaponSpeed" is the correct FloatValues key on your server]
  weapon.weaponSpeedMod = weenie.IntValues["WeaponTime"]
  
  -- Custom server: speed derived from weaponTime / baseWeaponTime ratio.
  weapon.baseWeaponTime = weenie.IntValues["WeaponTime"]
  weapon.baseVariance   = weenie.FloatValues["DamageVariance"]
  
  weapon.isTwoHanded    = isTwoHanded(weenie)
  weapon.isAmmoLauncher = isAmmoLauncher(weenie)
  
  -- cleaving > 0 on two-handed non-spear weapons.
  weapon.cleaving = weenie.IntValues["Cleaving"] or 0
  
  -- Wield difficulty and requirements — used by the original server scorer.
  -- WieldRequirements: 2 = RawSkill (elemental caster), 7 = Level (non-elemental caster), nil = no requirement
  weapon.WieldDifficulty   = weenie.IntValues["WieldDifficulty"]
  weapon.WieldRequirements = weenie.IntValues["WieldRequirements"]
  
  -- Tier — custom server only; supplied directly by the server.
  weapon.tier = weenie.IntValues["Tier"]
  
  -- Damage.
  weapon.Damage = weenie.IntValues["Damage"]
  
  -- Float properties — post-mutation live values.
  weapon.DamageVariance = weenie.FloatValues["DamageVariance"]
  weapon.WeaponOffense  = weenie.FloatValues["WeaponOffense"]
  weapon.weaponTime     = weenie.IntValues["WeaponTime"]
  
  -- Defense — original server property names.
  weapon.WeaponDefense = weenie.FloatValues["WeaponDefense"]
  weapon.missileDef    = weenie.FloatValues["WeaponMissileDefense"]
  weapon.magicDef      = weenie.FloatValues["WeaponMagicDefense"]
  
  -- Defense — custom server property names [VERIFY with your server].
  weapon.WeaponPhysicalDefense = weenie.FloatValues["WeaponPhysicalDefense"]
  weapon.WeaponMagicalDefense  = weenie.FloatValues["WeaponMagicalDefense"]
  
  -- Melee subtype stats.
  weapon.criticalFrequency       = weenie.FloatValues["CriticalFrequency"]
  weapon.criticalMultiplier      = weenie.FloatValues["CriticalMultiplier"]
  weapon.ignoreArmor             = weenie.FloatValues["IgnoreArmor"]
  weapon.staminaCostReductionMod = weenie.FloatValues["StaminaCostReductionMod"]
  
  -- Missile stats.
  weapon.DamageMod            = weenie.FloatValues["DamageMod"]
  weapon.ElementalDamageBonus = weenie.IntValues["ElementalDamageBonus"]
  
  -- Caster stats [VERIFY key names with your custom server].
  weapon.ElementalDamageMod  = weenie.FloatValues["ElementalDamageMod"]
  weapon.ManaConversionMod   = weenie.FloatValues["ManaConversionMod"]
  weapon.WeaponWarMagicMod   = weenie.FloatValues["WeaponWarMagicMod"]
  weapon.WeaponLifeMagicMod  = weenie.FloatValues["WeaponLifeMagicMod"]
  weapon.ignoreWard          = weenie.FloatValues["IgnoreWard"]
  -- [VERIFY: confirm "SubtypeDefenseBonus" is the correct FloatValues key]
  weapon.subtypeDefenseBonus = weenie.FloatValues["SubtypeDefenseBonus"]
  
  return weapon
end

-------------------------------------------------------------------------------
-- ORIGINAL SERVER: PATH BUILDING
-------------------------------------------------------------------------------

local PATH_SEP = "/"

local function trimWhitespace(str)
  local match = Regex.Match(str, [[^\s*(.*)\s*$]])
  if match.Success then
    return match.Groups[1].value
  else
    return str
  end
end

local SKILL_COMBINED_NAME = {
  HeavyWeapons    = "heavy",
  LightWeapons    = "light_finesse",
  FinesseWeapons  = "light_finesse",
  TwoHandedCombat = "two_handed",
}

local SKILL_NAME_REMAP = {
  MartialWeapons = "HeavyWeapons",
}

-- Used only by getTwoHandedShortName to distinguish sword/mace/axe/spear
-- within "TwoHanded" for the offense/defense file name.
local TwoHandedWeaponsMatrix =
{
  { 40760, 40761, 40762, 40763, 40764 }, --  0 - Nodachi
  { 41067, 41068, 41069, 41070, 41071 }, --  1 - Shashqa
  { 40618, 40619, 40620, 40621, 40622 }, --  2 - Spadone
  { 41057, 41058, 41059, 41060, 41061 }, --  3 - Great Star Mace
  { 40623, 40624, 40625, 40626, 40627 }, --  4 - Quadrelle
  { 41062, 41063, 41064, 41065, 41066 }, --  5 - Khanda-handled Mace
  { 40635, 40636, 40637, 40638, 40639 }, --  6 - Tetsubo
  { 41052, 41053, 41054, 41055, 41056 }, --  7 - Great Axe
  { 41036, 41037, 41038, 41039, 41040 }, --  8 - Assagai
  { 41046, 41047, 41048, 41049, 41050 }, --  9 - Pike
  { 40818, 40819, 40820, 40821, 40822 }, -- 10 - Corsesca
  { 41041, 41042, 41043, 41044, 41045 }, -- 11 - Magari Yari
}

-- Damage file: cleaver vs spear distinguished by Cleaving property.
local function getTwoHandedScriptName(weapon)
  return (weapon.cleaving and weapon.cleaving > 0) and "cleaver" or "spear"
end

-- Offense/defense file: must distinguish sword/mace/axe/spear; uses wcid matrix.
local function getTwoHandedShortName(weapon)
  for i, row in ipairs(TwoHandedWeaponsMatrix) do
    for _, wcid in ipairs(row) do
      if wcid == weapon.wcid then
        if i < 4 then return "two_handed_sword" end
        if i < 7 then return "two_handed_mace"  end
        if i < 8 then return "two_handed_axe"   end
        return "two_handed_spear"
      end
    end
  end
  return "two_handed_sword"
end

-- Damage file script names.
-- MaceJitte → "mace" (no separate damage file).
-- MS suffix for Dagger/Sword is appended dynamically in buildMeleePaths.
local WEAPON_TYPE_SCRIPT_NAME = {
  Axe       = "axe",
  Dagger    = "dagger",
  Mace      = "mace",
  MaceJitte = "mace",
  Spear     = "spear",
  Staff     = "staff",
  Sword     = "sword",
  Unarmed   = "unarmed",
}

-- Offense/defense file short names.
-- MaceJitte has its own file; MS variants collapse to the base name.
local WEAPON_TYPE_SHORT_NAME = {
  Axe       = "axe",
  Dagger    = "dagger",
  Mace      = "mace",
  MaceJitte = "mace_jitte",
  Spear     = "spear",
  Staff     = "staff",
  Sword     = "sword",
  Unarmed   = "unarmed",
}

local function buildMeleePaths(mutationsRoot, weaponSkill, weaponType, weapon)
  local canonicalSkill    = SKILL_NAME_REMAP[weaponSkill] or weaponSkill
  local skillCombinedName = SKILL_COMBINED_NAME[canonicalSkill]
  local isTH              = (weaponType == "TwoHanded")
  
  local typeScriptName, typeShortName
  if isTH then
    typeScriptName = getTwoHandedScriptName(weapon)
    typeShortName  = getTwoHandedShortName(weapon)
  else
    typeScriptName = WEAPON_TYPE_SCRIPT_NAME[weaponType]
    typeShortName  = WEAPON_TYPE_SHORT_NAME[weaponType]
    if weapon.isMultiStrike and (weaponType == "Dagger" or weaponType == "Sword") then
      typeScriptName = typeScriptName .. "_ms"
    end
  end
  
  if not skillCombinedName then
    return nil, nil, "buildMeleePaths: no combined name for skill: " .. tostring(canonicalSkill)
  end
  if not typeScriptName then
    return nil, nil, "buildMeleePaths: no script name for weapon type: " .. tostring(weaponType)
  end
  if not typeShortName then
    return nil, nil, "buildMeleePaths: no short name for weapon type: " .. tostring(weaponType)
  end
  
  local damageFilePath = table.concat(
  { mutationsRoot, "MeleeWeapons", "Damage_WieldDifficulty_DamageVariance",
  skillCombinedName .. "_" .. typeScriptName .. ".txt" },
  PATH_SEP)
  
  local offenseDefenseFilePath = table.concat(
  { mutationsRoot, "MeleeWeapons", "WeaponOffense_WeaponDefense",
  typeShortName .. "_offense_defense.txt" },
  PATH_SEP)
  
  return damageFilePath, offenseDefenseFilePath
end

-------------------------------------------------------------------------------
-- ORIGINAL SERVER: MUTATION FILE PARSER + PMF BUILDER
-------------------------------------------------------------------------------

local io = require("filesystem").GetScript()

local function parseMutationFile(filePath)
  local fileHandle = io.ReadLines(filePath)
  if not fileHandle then
    error("WeaponScorer: cannot open mutation file: " .. tostring(filePath))
  end
  
  local mutationList    = {}
  local currentMutation = nil
  local currentOutcome  = nil
  
  for _, rawLine in ipairs(fileHandle) do
    local line = trimWhitespace(rawLine)
    
    local mutationIndex = line:match("Mutation #(%d+)")
    if mutationIndex then
      currentMutation = {
        index    = tonumber(mutationIndex),
        tierProb = {},
        outcomes = {},
      }
      table.insert(mutationList, currentMutation)
      currentOutcome = nil
    end
    
    if currentMutation then
      local tierChanceStr = line:match("^Tier chances:%s*(.+)$")
      if tierChanceStr then
        local tierIndex = 1
        for tierValue in tierChanceStr:gmatch("[%d%.]+") do
          currentMutation.tierProb[tierIndex] = tonumber(tierValue) or 0
          tierIndex = tierIndex + 1
        end
      end
      
      local chanceStr = line:match("^%-%s*Chance:%s*([%d%.]+)%%%s*:?$")
      if chanceStr then
        currentOutcome = {
          prob  = tonumber(chanceStr) / 100.0,
          stats = {},
        }
        table.insert(currentMutation.outcomes, currentOutcome)
      end
      
      if currentOutcome then
        local statName, statValue = line:match("^(%a%w*)%s*%+=%s*([%d%.%-]+)$")
        if statName then
          currentOutcome.stats[statName] = { op = "add", value = tonumber(statValue) }
        end
        
        if not statName then
          statName, statValue = line:match("^(%a%w*)%s*=%s*([%d%.%-%w]+)$")
          if statName and statName ~= "Tier" then
            local numericValue = tonumber(statValue)
            currentOutcome.stats[statName] = {
              op    = "set",
              value = (numericValue ~= nil) and numericValue or statValue,
            }
          end
        end
      end
    end
  end
  
  return mutationList
end

local function collapsePMF(entries)
  local valueToEntry   = {}
  local orderedEntries = {}
  
  for _, entry in ipairs(entries) do
    local key = ("%.8g"):format(entry[1])
    if valueToEntry[key] then
      valueToEntry[key][2] = valueToEntry[key][2] + entry[2]
    else
      local newEntry = { entry[1], entry[2] }
      valueToEntry[key] = newEntry
      table.insert(orderedEntries, newEntry)
    end
  end
  
  return orderedEntries
end

-- Builds per-tier PMFs from the parsed mutation list.
-- Tier is used only internally here to select the right mutations from the file.
local function buildPMFs(mutationList)
  table.sort(mutationList, function(a, b) return a.index < b.index end)
  
  local tierPMFs = {}
  
  for tier = 1, 8 do
    local pmfsForTier = {}
    local activeMuts  = {}
    
    for _, mutation in ipairs(mutationList) do
      if (mutation.tierProb[tier] or 0) > 0 then
        table.insert(activeMuts, mutation)
      end
    end
    
    for _, mutation in ipairs(activeMuts) do
      local totalProb = 0
      for _, outcome in ipairs(mutation.outcomes) do
        totalProb = totalProb + outcome.prob
      end
      if totalProb < 1e-9 then totalProb = 1 end
      
      local setDistributions = {}
      local addDistributions = {}
      
      for _, outcome in ipairs(mutation.outcomes) do
        local normalizedProb = outcome.prob / totalProb
        for statName, assignment in pairs(outcome.stats) do
          if type(assignment.value) == "number" then
            if assignment.op == "set" then
              setDistributions[statName] = setDistributions[statName] or {}
              table.insert(setDistributions[statName], { assignment.value, normalizedProb })
            else
              addDistributions[statName] = addDistributions[statName] or {}
              table.insert(addDistributions[statName], { assignment.value, normalizedProb })
            end
          end
        end
      end
      
      for statName, dist in pairs(setDistributions) do
        pmfsForTier[statName] = collapsePMF(dist)
      end
      
      local tierProb = (mutation.tierProb and mutation.tierProb[tier]) or 1.0
      for statName, deltas in pairs(addDistributions) do
        if tierProb < 1.0 - 1e-9 then
          for _, d in ipairs(deltas) do d[2] = d[2] * tierProb end
          table.insert(deltas, { 0.0, 1.0 - tierProb })
        end
        if not pmfsForTier[statName] then
          pmfsForTier[statName] = collapsePMF(deltas)
        else
          local convolved = {}
          for _, baseEntry in ipairs(pmfsForTier[statName]) do
            for _, deltaEntry in ipairs(deltas) do
              table.insert(convolved, {
                baseEntry[1] + deltaEntry[1],
                baseEntry[2] * deltaEntry[2],
              })
            end
          end
          pmfsForTier[statName] = collapsePMF(convolved)
        end
      end
    end
    
    tierPMFs[tier] = pmfsForTier
  end
  
  return tierPMFs
end

local pmfFileCache     = {}
local rawMutationCache = {}

local function loadPMFsCached(filePath)
  if not pmfFileCache[filePath] then
    local mutationList         = parseMutationFile(filePath)
    rawMutationCache[filePath] = mutationList
    pmfFileCache[filePath]     = buildPMFs(mutationList)
  end
  return pmfFileCache[filePath]
end

-------------------------------------------------------------------------------
-- ORIGINAL SERVER: HARDCODED DISTRIBUTIONS
-------------------------------------------------------------------------------

local MISS_MAG_PMF_T1T6 = {
  { false, 0.900 },
  { 1.005, 0.010 },
  { 1.010, 0.020 },
  { 1.015, 0.040 },
  { 1.020, 0.020 },
  { 1.025, 0.010 },
}
local MISS_MAG_PMF_T7T8 = {
  { false, 0.900 },
  { 1.005, 0.005 },
  { 1.010, 0.010 },
  { 1.015, 0.015 },
  { 1.020, 0.020 },
  { 1.025, 0.020 },
  { 1.030, 0.015 },
  { 1.035, 0.010 },
  { 1.040, 0.005 },
}

local QUALITY_THRESHOLDS = {
  [1] = { 1.0,  0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0   },
  [2] = { 0.75, 1.0,  0,    0,    0,    0,    0,    0,    0,    0,    0,    0   },
  [3] = { 0.20, 0.50, 0.80, 1.0,  0,    0,    0,    0,    0,    0,    0,    0   },
  [4] = { 0,    0.10, 0.30, 0.70, 0.90, 1.0,  0,    0,    0,    0,    0,    0   },
  [5] = { 0,    0,    0.10, 0.30, 0.70, 0.90, 1.0,  0,    0,    0,    0,    0   },
  [6] = { 0,    0,    0,    0.10, 0.25, 0.50, 0.75, 0.90, 1.0,  0,    0,    0   },
  [7] = { 0,    0,    0,    0,    0.10, 0.25, 0.50, 0.75, 0.90, 1.0,  0,    0   },
  [8] = { 0,    0,    0,    0,    0,    0,    0.10, 0.25, 0.50, 0.75, 0.90, 1.0 },
}

local QUALITY_TIER_PROBABILITY = { 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0, 1.0 }

local function cdfOriginalSpeed(speedModValue, tier)
  if speedModValue > 1.0 + 1e-9 then return 0.0 end
  if speedModValue < 0.675 - 1e-9 then return 1.0 end
  
  local qualityThresholds = QUALITY_THRESHOLDS[tier]
  local tierQualityProb   = QUALITY_TIER_PROBABILITY[tier]
  local cumulative        = 1.0 - tierQualityProb
  local prevThreshold     = 0.0
  
  for qualityLevel = 1, 12 do
    local curThreshold = qualityThresholds[qualityLevel] or 0.0
    local bandProb     = tierQualityProb * (curThreshold - prevThreshold)
    
    if bandProb > 1e-9 then
      local bandHigh = 1.0 - (qualityLevel - 1) * 0.025
      local bandLow  = 1.0 - (qualityLevel + 1) * 0.025
      
      if speedModValue <= bandLow then
        cumulative = cumulative + bandProb
      elseif speedModValue < bandHigh then
        cumulative = cumulative + bandProb * (bandHigh - speedModValue) / (bandHigh - bandLow)
      end
    end
    
    prevThreshold = curThreshold
  end
  
  return math.min(1.0, math.max(0.0, cumulative))
end

-------------------------------------------------------------------------------
-- ORIGINAL SERVER: PERCENTILE HELPERS
-------------------------------------------------------------------------------

local PMF_FLOAT_EPSILON = 1e-4

local function pctAtOrBelow(pmf, value)
  local cumulative = 0.0
  for _, entry in ipairs(pmf) do
    if type(entry[1]) == "number" and entry[1] <= value + PMF_FLOAT_EPSILON then
      cumulative = cumulative + entry[2]
    end
  end
  return math.min(cumulative, 1.0)
end

local function pctDefenseProc(pmf, value)
  if value == false or value == nil then return 0.0 end
  local cumulative = 0.0
  for _, entry in ipairs(pmf) do
    if entry[1] == false
    or (type(entry[1]) == "number" and entry[1] <= value + PMF_FLOAT_EPSILON) then
      cumulative = cumulative + entry[2]
    end
  end
  return math.min(cumulative, 1.0)
end

local function pmfMax(pmf)
  local best = nil
  for _, entry in ipairs(pmf) do
    if type(entry[1]) == "number" then
      if best == nil or entry[1] > best then best = entry[1] end
    end
  end
  return best
end

local function scorePMFStat(pmfsForTier, statName, value)
  if value == nil then return 0.5 end
  if pmfsForTier and pmfsForTier[statName] then
    return pctAtOrBelow(pmfsForTier[statName], value)
  end
  return 0.5
end

-------------------------------------------------------------------------------
-- CUSTOM SERVER: ANIMATION LENGTHS
-------------------------------------------------------------------------------

local MELEE_ANIMATION_LENGTH = {
  DoubleSlash         = 2.62,
  DoubleStrike        = 2.62,
  DoubleThrust        = 3.05,
  Kick                = 1.10,
  MultiStrike         = 2.67,
  Offhand             = 1.0,
  OffhandDoubleSlash  = 2.1,
  OffhandDoubleThrust = 2.1,
  OffhandPunch        = 0.87,
  OffhandSlash        = 1.20,
  OffhandThrust       = 1.20,
  OffhandTripleSlash  = 2.67,
  OffhandTripleThrust = 2.67,
  Punch               = 1.10,
  Punches             = 1.10,
  Slash               = 1.33,
  Slashes             = 1.33,
  Thrust              = 1.38,
  Thrusts             = 1.38,
  ThrustSlash         = 1.33,
  TripleSlash         = 3.18,
  TripleStrike        = 3.18,
  TripleThrust        = 4.64,
  Unarmed             = 1.10,
}

local MISSILE_BASE_ANIMATION = {
  Bow            = 1.057,
  Crossbow       = 1.590,
  ThrownWeapon   = 1.850,
  MissileWeapons = 1.850,
}

local MISSILE_RELOAD_TIME = {
  Bow            = 0.32,
  Crossbow       = 0.26,
  ThrownWeapon   = 0.73,
  MissileWeapons = 0.73,
}

local THROWN_MELEE_RELOAD = 0.9777778

local function getAnimationLength(weapon)
  if weapon.isTwoHanded then return 1.85 end
  if not weapon.isAmmoLauncher then
    if weapon.weaponSkill == "ThrownWeapon" then return 2.33 end
    return MELEE_ANIMATION_LENGTH[weapon.attackType] or 1.0
  end
  return MISSILE_BASE_ANIMATION[weapon.weaponSkill] or 1.0
end

-------------------------------------------------------------------------------
-- CUSTOM SERVER: DPS / DAMAGE RANGE TABLES (indexed by tier internally)
-------------------------------------------------------------------------------

local WEAPON_BASE_DPS_PER_TIER = { 5.0, 10.0, 15.0, 22.0, 33.0, 50.0, 75.0, 110.0 }
local AVG_QUICKNESS_PER_TIER   = { 45, 65, 93, 118, 140, 160, 180, 195 }
local DAMAGE_RANGE_FRACTION    = 0.25
local TIER_BONUS_MOD           = { 0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.075, 0.1 }

local function computeCustomMeleeDamageRange(weapon, tier)
  local animationLength = getAnimationLength(weapon)
  local avgQuickness    = AVG_QUICKNESS_PER_TIER[tier]
  local baseWeaponTime  = weapon.baseWeaponTime or 0
  local speedMod        = 1.0 + (1 - baseWeaponTime / 100.0) + avgQuickness / 600.0
  local epsBase         = 1.0 / (animationLength / speedMod)
  
  local effectiveAttacksPerSecond
  if weapon.isTwoHanded or weapon.isDoubleStrike then
    effectiveAttacksPerSecond = epsBase * 2
  elseif weapon.isTripleStrike then
    effectiveAttacksPerSecond = epsBase * 3
  elseif weapon.weaponSkill == "ThrownWeapon" then
    effectiveAttacksPerSecond = 1.0 / (animationLength - THROWN_MELEE_RELOAD + (THROWN_MELEE_RELOAD * speedMod))
  else
    effectiveAttacksPerSecond = epsBase
  end
  
  local avgHitDamage   = WEAPON_BASE_DPS_PER_TIER[tier] / effectiveAttacksPerSecond
  local baseVariance   = weapon.baseVariance or 0.5
  local avgHitFraction = ((1 - baseVariance) + 1) / 2
  local avgMaxDamage   = avgHitDamage / (avgHitFraction * 0.9 + 0.2)
  local maxMaxDamage   = (avgMaxDamage * 2) / (1.0 + (1.0 - DAMAGE_RANGE_FRACTION))
  local minMaxDamage   = maxMaxDamage * (1.0 - DAMAGE_RANGE_FRACTION)
  
  return minMaxDamage, avgMaxDamage
end

local AMMO_BASE_MAX_DAMAGE = {
  Bow            = {  6,  8, 10, 12, 14, 16, 18, 20 },
  Crossbow       = {  9, 12, 15, 18, 21, 24, 27, 30 },
  ThrownWeapon   = { 12, 16, 20, 24, 28, 32, 36, 40 },
  MissileWeapons = { 12, 16, 20, 24, 28, 32, 36, 40 },
}

local AMMO_VARIANCE_BY_SKILL = {
  Bow            = 0.6,
  Crossbow       = 0.4,
  ThrownWeapon   = 0.6,
  MissileWeapons = 0.75,
}

local function computeCustomMissileDamageModRange(weapon, tier)
  local weaponSkill     = weapon.weaponSkill
  local baseWeaponTime  = weapon.baseWeaponTime or 50
  local avgQuickness    = AVG_QUICKNESS_PER_TIER[tier]
  local animationLength = MISSILE_BASE_ANIMATION[weaponSkill] or 1.85
  local reloadTime      = MISSILE_RELOAD_TIME[weaponSkill] or 0.73
  local speedMod        = 1.0 + (1 - baseWeaponTime / 100.0) + avgQuickness / 600.0
  local eps             = 1.0 / (animationLength - reloadTime + (reloadTime / speedMod))
  
  local ammoMaxDamage  = (AMMO_BASE_MAX_DAMAGE[weaponSkill] or AMMO_BASE_MAX_DAMAGE.Bow)[tier]
  local ammoVariance   = AMMO_VARIANCE_BY_SKILL[weaponSkill] or 0.6
  local ammoMinDamage  = ammoMaxDamage * (1 - ammoVariance)
  local ammoAvgDamage  = (ammoMaxDamage + ammoMinDamage) / 2
  local targetAvgHit   = WEAPON_BASE_DPS_PER_TIER[tier] / eps
  local avgDamageMod   = targetAvgHit / (ammoAvgDamage * 0.9 + ammoMaxDamage * 0.2)
  local maxDamageMod   = (avgDamageMod * 2) / (1.0 + (1.0 - DAMAGE_RANGE_FRACTION))
  local minDamageMod   = maxDamageMod * (1.0 - DAMAGE_RANGE_FRACTION)
  
  return minDamageMod, avgDamageMod
end

-------------------------------------------------------------------------------
-- CUSTOM SERVER: ANALYTICAL CDFs
-------------------------------------------------------------------------------

local function cdfCustomOffenseDefenseMod(liveValue, tier)
  local tierBonus = TIER_BONUS_MOD[tier] or 0.0
  if liveValue < 1.0 - 1e-9 then return 0.0 end
  if liveValue < 1.0 + 1e-9 then return 0.25 end
  
  local cumulative = 0.25
  local rawAmount  = liveValue - 1.0
  
  local baseRollArg = (rawAmount - 0.1 - tierBonus) / 0.1
  if baseRollArg > 0 then
    cumulative = cumulative + 0.25 * math.min(1.0, math.sqrt(baseRollArg))
  end
  
  local threeQuarterArg = (rawAmount - 0.075 - 0.75 * tierBonus) / 0.075
  if threeQuarterArg > 0 then
    cumulative = cumulative + 0.50 * math.min(1.0, math.sqrt(threeQuarterArg))
  end
  
  return math.min(cumulative, 1.0)
end

local function cdfCustomMagicSkillMod(rawValue, tier)
  local tierBonus = TIER_BONUS_MOD[tier] or 0.0
  if rawValue < 1e-9 then return 0.25 end
  
  local cumulative = 0.25
  
  local baseRollArg = (rawValue - 0.1 - tierBonus) / 0.1
  if baseRollArg > 0 then
    cumulative = cumulative + 0.25 * math.min(1.0, math.sqrt(baseRollArg))
  end
  
  local threeQuarterArg = (rawValue - 0.075 - 0.75 * tierBonus) / 0.075
  if threeQuarterArg > 0 then
    cumulative = cumulative + 0.50 * math.min(1.0, math.sqrt(threeQuarterArg))
  end
  
  return math.min(cumulative, 1.0)
end

local function cdfCustomDamageRoll(rolledValue, rangeMin, rangeAvg)
  if rangeMin == nil or rangeAvg == nil then return nil end
  local rollRange = rangeAvg - rangeMin
  if rollRange < 1e-9 then return 1.0 end
  local normalised = (rolledValue - rangeMin) / rollRange
  return math.min(1.0, math.max(0.0, math.sqrt(math.max(0.0, normalised))))
end

local function cdfCustomDamageVariance(rolledVariance, baseVariance)
  if baseVariance == nil then return nil end
  local rangeLow  = baseVariance - 0.1
  local rangeHigh = baseVariance + 0.1
  if rolledVariance <= rangeLow  then return 0.0 end
  if rolledVariance >= rangeHigh then return 1.0 end
  return (rolledVariance - rangeLow) / (rangeHigh - rangeLow)
end

local function cdfMeleeWeaponSpeed(weaponTime, baseWeaponTime)
  if weaponTime == nil or baseWeaponTime == nil or baseWeaponTime == 0 then return nil end
  return math.min(1.0, math.max(0.0, (1.05 - weaponTime / baseWeaponTime) / 0.10))
end

local function cdfMissileWeaponSpeed(weaponTime, baseWeaponTime)
  if weaponTime == nil or baseWeaponTime == nil or baseWeaponTime == 0 then return nil end
  return math.min(1.0, math.max(0.0, math.sqrt((1.0 - weaponTime / baseWeaponTime) / 0.10)))
end

local CASTER_MAX_MOD_PER_TIER = { 0.10, 0.20, 0.30, 0.40, 0.50, 0.75, 1.00, 1.26 }

local function cdfCasterElementalDamageMod(edm, tier, isWarMagic)
  if edm == nil then return nil end
  local maxMod = CASTER_MAX_MOD_PER_TIER[tier]
  if maxMod == nil then return nil end
  local minMod     = maxMod / 2.0
  local damageRoll = isWarMagic and edm or ((edm - 1.0) / 0.5 + 1.0)
  local rollRange  = maxMod - minMod
  if rollRange < 1e-9 then return 1.0 end
  local normalised = (damageRoll - minMod) / rollRange
  return math.min(1.0, math.max(0.0, math.sqrt(math.max(0.0, normalised))))
end

-------------------------------------------------------------------------------
-- SUBTYPE BONUS CDFs
-------------------------------------------------------------------------------

local CRIT_CHANCE_MIN_PER_TIER  = { 0.0, 0.01, 0.015, 0.02, 0.025, 0.03,  0.04,  0.05  }
local CRIT_DAMAGE_MIN_PER_TIER  = { 0.0, 0.1,  0.15,  0.2,  0.25,  0.3,   0.4,   0.5   }
local STAMINA_COST_MIN_PER_TIER = { 0.0, 0.01, 0.02,  0.03, 0.04,  0.05,  0.075, 0.1   }

local function cdfSubtypeBonus(rolledValue, minMod, rollRange)
  if rollRange < 1e-9 then return 1.0 end
  local normalised = (rolledValue - minMod) / rollRange
  return math.min(1.0, math.max(0.0, math.sqrt(math.max(0.0, normalised))))
end

local MELEE_SUBTYPE_KIND_BY_TYPE = {
  Axe       = "critChance",
  Dagger    = "critChance",
  Mace      = "critDamage",
  MaceJitte = "critDamage",
  Staff     = "critDamage",
  Spear     = "armorCleave",
  Sword     = "stamCost",
  Unarmed   = "stamCost",
}

local MISSILE_SUBTYPE_KIND_BY_SKILL = {
  Bow            = "critChance",
  Crossbow       = "armorCleave",
  MissileWeapons = "critDamage",
}

local THROWN_SUBTYPE_KIND = {
  [0] = "critChance",
  [1] = "critDamage",
  [2] = "critChance",
  [3] = "armorCleave",
  [4] = "armorCleave",
  [5] = "critDamage",
}

local CASTER_SUBTYPE_KIND = {
  [0] = "wardCleave",
  [1] = "critChance",
  [2] = "critDamage",
  [3] = "defenseBonus",
}

local ThrownWeaponMatrix = {
  { 304,  3758, 3759, 3760, 3761 },
  { 310,  3770, 3771, 3772, 3773 },
  { 315,  3782, 3783, 3784, 3785 },
  { 316,  3786, 3787, 3788, 3789 },
  { 320,  3798, 3799, 3800, 3801 },
  { 343,  3861, 3862, 3863, 3864 },
}

local function getThrownWeaponsSubType(weapon)
  for i, row in ipairs(ThrownWeaponMatrix) do
    for _, wcid in ipairs(row) do
      if wcid == weapon.wcid then return i - 1 end
    end
  end
  return 0
end

local TimelineCasterWeaponsMatrix = {
  { 2366, 2548, 2472, 2547 },
  { 1050101, 1050102, 1050103, 1050104, 1050105, 1050106, 1050107 },
  { 29265, 29264, 29260, 29263, 29262, 29259, 29261 },
  { 31819, 31825, 31821, 31824, 31823, 31820, 31822 },
  { 37223, 37222, 37225, 37221, 37220, 37224, 37219 },
}

local function getCasterSubType(weapon)
  for i, row in ipairs(TimelineCasterWeaponsMatrix) do
    for j, wcid in ipairs(row) do
      if wcid == weapon.wcid then
        return i == 1 and j - 1 or i - 1
      end
    end
  end
  return 0
end

local function resolveSubtypeKind(weapon, weaponCategory)
  if weaponCategory == "missile" then
    if weapon.weaponSkill == "ThrownWeapon" then
      return THROWN_SUBTYPE_KIND[getThrownWeaponsSubType(weapon)] or "critChance"
    end
    return MISSILE_SUBTYPE_KIND_BY_SKILL[weapon.weaponSkill] or "critChance"
    
  elseif weaponCategory == "caster" then
    return CASTER_SUBTYPE_KIND[getCasterSubType(weapon)]
    
  else
    if weapon.weaponType == "TwoHanded" then
      local isTHSpear = not (weapon.cleaving and weapon.cleaving > 0)
      return isTHSpear and "armorCleave" or "stamCost"
    end
    return MELEE_SUBTYPE_KIND_BY_TYPE[weapon.weaponType]
  end
end

local function scoreSubtypeBonus(weapon, tier, weaponCategory)
  local subtypeKind = resolveSubtypeKind(weapon, weaponCategory)
  
  if not subtypeKind then
    return 0.5, true, nil
  end
  
  if subtypeKind == "critChance" then
    if weapon.criticalFrequency == nil then return 0.5, true, "criticalFrequency" end
    local bonus = weapon.criticalFrequency - 0.1
    return cdfSubtypeBonus(bonus, CRIT_CHANCE_MIN_PER_TIER[tier], 0.05), false, "critChance"
    
  elseif subtypeKind == "critDamage" then
    if weapon.criticalMultiplier == nil then return 0.5, true, "criticalMultiplier" end
    local bonus = weapon.criticalMultiplier - 1.0
    return cdfSubtypeBonus(bonus, CRIT_DAMAGE_MIN_PER_TIER[tier], 0.5), false, "critDamage"
    
  elseif subtypeKind == "armorCleave" then
    if weapon.ignoreArmor == nil then return 0.5, true, "ignoreArmor" end
    local bonus = 1.0 - weapon.ignoreArmor
    return cdfSubtypeBonus(bonus, 0.1, 0.1), false, "armorCleave"
    
  elseif subtypeKind == "stamCost" then
    if weapon.staminaCostReductionMod == nil then return 0.5, true, "staminaCostReductionMod" end
    return cdfSubtypeBonus(weapon.staminaCostReductionMod, STAMINA_COST_MIN_PER_TIER[tier], 0.1), false, "stamCost"
    
  elseif subtypeKind == "wardCleave" then
    if weapon.ignoreWard == nil then return 0.5, true, "ignoreWard" end
    local bonus = 1.0 - weapon.ignoreWard
    return cdfSubtypeBonus(bonus, 0.1, 0.1), false, "wardCleave"
    
  elseif subtypeKind == "defenseBonus" then
    if weapon.subtypeDefenseBonus == nil then return 0.5, true, "subtypeDefenseBonus" end
    return cdfSubtypeBonus(weapon.subtypeDefenseBonus, STAMINA_COST_MIN_PER_TIER[tier], 0.1), false, "defenseBonus"
  end
  
  return 0.5, true, nil
end

-------------------------------------------------------------------------------
-- DEFAULT WEIGHTS
-------------------------------------------------------------------------------

local ORIG_MELEE_WEIGHTS = {
  Damage          = 0.40,
  DamageVariance  = 0.15,
  WeaponOffense   = 0.20,
  WeaponDefense   = 0.20,
  weaponSpeed     = 0,--0.03,
  missileDef      = 0.01,
  magicDef        = 0.01,
}

local ORIG_MISSILE_WEIGHTS = {
  DamageMod            = 0.40,
  ElementalDamageBonus = 0.10,
  WeaponDefense        = 0.25,
  weaponSpeed          = 0,--0.15,
  missileDef           = 0.05,
  magicDef             = 0.05,
}

local ORIG_CASTER_WEIGHTS = {
  ElementalDamageMod = 0.50,
  WeaponDefense      = 0.20,
  ManaConversionMod  = 0.10,
  missileDef         = 0.10,
  magicDef           = 0.10,
}

local CUST_MELEE_WEIGHTS = {
  Damage                 = 0.35,
  DamageVariance         = 0.10,
  WeaponOffense          = 0.20,
  WeaponPhysicalDefense  = 0.10,
  WeaponMagicalDefense   = 0.10,
  weaponSpeed            = 0.05,
  subtypeBonus           = 0.10,
}

local CUST_MISSILE_WEIGHTS = {
  DamageMod             = 0.45,
  WeaponOffense         = 0.20,
  WeaponPhysicalDefense = 0.10,
  WeaponMagicalDefense  = 0.10,
  weaponSpeed           = 0.05,
  subtypeBonus          = 0.10,
}

local CUST_CASTER_WEIGHTS = {
  ElementalDamageMod    = 0.40,
  magicSkillMod         = 0.20,
  WeaponPhysicalDefense = 0.10,
  WeaponMagicalDefense  = 0.10,
  subtypeBonus          = 0.20,
}

-------------------------------------------------------------------------------
-- COMPOSITE SCORE HELPER
-------------------------------------------------------------------------------

local function computeCompositeScore(result, weights)
  local weightedSum = 0.0
  local totalWeight = 0.0
  
  for statName, weight in pairs(weights) do
    if result[statName] ~= nil then
      weightedSum = weightedSum + result[statName] * weight
      totalWeight = totalWeight + weight
    end
  end
  
  result.composite = totalWeight > 0 and (weightedSum / totalWeight) or 0.0
end

-------------------------------------------------------------------------------
-- SCORER: ORIGINAL SERVER — MELEE
-------------------------------------------------------------------------------

local function scoreOriginalMelee(weapon, mutationsRoot, weights)
  local damageFilePath, offenseFilePath, buildError =
  buildMeleePaths(mutationsRoot, weapon.weaponSkill, weapon.weaponType, weapon)
  if buildError then return { error = buildError } end
  local ok, allDamagePMFs = pcall(loadPMFsCached, damageFilePath)
  if not ok then return { error = tostring(allDamagePMFs) } end
  local ok2, allOffensePMFs = pcall(loadPMFsCached, offenseFilePath)
  if not ok2 then return { error = tostring(allOffensePMFs) } end
  
  local tier        = deriveTierFromMutations(rawMutationCache[damageFilePath],  weapon.WieldDifficulty)
  local offenseTier = deriveTierFromMutations(rawMutationCache[offenseFilePath], weapon.WieldDifficulty)
  
  local damagePmfs  = allDamagePMFs[tier]
  local offensePmfs = allOffensePMFs[offenseTier]
  
  local missMagDefPmf = (tier >= 7) and MISS_MAG_PMF_T7T8 or MISS_MAG_PMF_T1T6
  local result        = { tier = tier, category = "orig_melee" }
  result.Damage         = scorePMFStat(damagePmfs, "Damage",         weapon.Damage)    
  result.DamageVariance = scorePMFStat(damagePmfs,  "DamageVariance", weapon.DamageVariance)
  result.WeaponOffense  = scorePMFStat(offensePmfs, "WeaponOffense",  weapon.WeaponOffense)
  result.WeaponDefense  = scorePMFStat(offensePmfs, "WeaponDefense",  weapon.WeaponDefense)
  
  if weapon.weaponSpeedMod ~= nil then
    result.weaponSpeed    = cdfOriginalSpeed(weapon.weaponSpeedMod, tier)
    result.weaponSpeedMod = weapon.weaponSpeedMod
  else
    result.weaponSpeed   = 0.5
    result.weaponSpeedNA = true
  end
  
  result.missileDef = pctDefenseProc(missMagDefPmf, weapon.missileDef)
  result.magicDef   = pctDefenseProc(missMagDefPmf, weapon.magicDef)
  
  computeCompositeScore(result, weights)
  return result
end

-------------------------------------------------------------------------------
-- SCORER: ORIGINAL SERVER — MISSILE
-------------------------------------------------------------------------------

ORIG_MISSILE_SCRIPT_NAME = {
  Bow      = "bow",
  Crossbow = "crossbow",
  Atlatl   = "atlatl",
  Thrown   = "atlatl"
}

local function buildOrigMissilePaths(mutationsRoot, scriptName, isElemental)
  local elementalStr = isElemental and "elemental" or "non_elemental"
  local damagePath  = table.concat(
  { mutationsRoot, "MissileWeapons", scriptName .. "_" .. elementalStr .. ".txt" }, PATH_SEP)
  local defensePath = table.concat(
  { mutationsRoot, "MissileWeapons", "weapon_defense.txt" }, PATH_SEP)
  return damagePath, defensePath
end

local function scoreOriginalMissile(weapon, mutationsRoot, weights)
  local scriptName = ORIG_MISSILE_SCRIPT_NAME[weapon.weaponType]
  
  if not scriptName then
    return { error = "scoreOriginalMissile: cannot resolve script name from weaponType=" .. tostring(weapon.weaponType) }
  end
  
  local damagePath, defensePath = buildOrigMissilePaths(mutationsRoot, scriptName, weapon.isElemental)
  
  local ok,  allDamagePMFs  = pcall(loadPMFsCached, damagePath)
  if not ok  then return { error = tostring(allDamagePMFs)  } end
  local ok2, allDefensePMFs = pcall(loadPMFsCached, defensePath)
  if not ok2 then return { error = tostring(allDefensePMFs) } end
  
  local tier        = deriveTierFromMutations(rawMutationCache[damagePath],  weapon.WieldDifficulty)
  local defenseTier = deriveTierFromMutations(rawMutationCache[defensePath], weapon.WieldDifficulty)
  
  local damagePmfs  = allDamagePMFs[tier]
  local defensePmfs = allDefensePMFs[defenseTier]
  
  local missMagDefPmf = (tier >= 7) and MISS_MAG_PMF_T7T8 or MISS_MAG_PMF_T1T6
  local result        = { tier = tier, category = "orig_missile" }
  
  result.DamageMod     = scorePMFStat(damagePmfs, "DamageMod", weapon.DamageMod)
  
  if weapon.isElemental then
    result.ElementalDamageBonus = scorePMFStat(damagePmfs, "ElementalDamageBonus", weapon.ElementalDamageBonus)
    if weapon.ElementalDamageBonus == nil then result.elemBonusNA = true end
  end
  
  result.WeaponDefense = scorePMFStat(defensePmfs, "WeaponDefense", weapon.WeaponDefense)
  
  if weapon.weaponSpeedMod ~= nil then
    result.weaponSpeed    = cdfOriginalSpeed(weapon.weaponSpeedMod, tier)
    result.weaponSpeedMod = weapon.weaponSpeedMod
  else
    result.weaponSpeed   = 0.5
    result.weaponSpeedNA = true
  end
  
  result.missileDef = pctDefenseProc(missMagDefPmf, weapon.missileDef)
  result.magicDef   = pctDefenseProc(missMagDefPmf, weapon.magicDef)
  
  computeCompositeScore(result, weights)
  return result
end

-------------------------------------------------------------------------------
-- SCORER: ORIGINAL SERVER — CASTER
-------------------------------------------------------------------------------

local function scoreOriginalCaster(weapon, mutationsRoot, weights)
  local manaConvPath = table.concat({ mutationsRoot, "Casters", "caster.txt" }, PATH_SEP)
  local defensePath  = table.concat({ mutationsRoot, "Casters", "weapon_defense.txt" }, PATH_SEP)
  
  local ok,  allManaConvPMFs = pcall(loadPMFsCached, manaConvPath)
  if not ok  then return { error = tostring(allManaConvPMFs) } end
  local ok2, allDefensePMFs  = pcall(loadPMFsCached, defensePath)
  if not ok2 then return { error = tostring(allDefensePMFs)  } end
  
  local tier
  local edmPmfs = nil
  
  if weapon.WieldRequirements == 2 then
    -- Elemental caster: WieldDifficulty is a magic skill level.
    -- Derive tier from caster_elemental.txt which has skill-based WieldDifficulty.
    local edmPath = table.concat({ mutationsRoot, "Casters", "caster_elemental.txt" }, PATH_SEP)
    local ok3, allEdmPMFs = pcall(loadPMFsCached, edmPath)
    if not ok3 then return { error = tostring(allEdmPMFs) } end
    tier    = deriveTierFromMutations(rawMutationCache[edmPath], weapon.WieldDifficulty)
    edmPmfs = allEdmPMFs[tier]
    
  elseif weapon.WieldRequirements == 7 then
    -- Non-elemental caster: WieldDifficulty is a character level (150 or 180).
    -- Map directly: level 180 = T8, level 150 = T7, anything else = T6.
    local lvl = weapon.WieldDifficulty or 0
    if lvl >= 180 then
      tier = 8
    elseif lvl >= 150 then
      tier = 7
    else
      tier = 6
    end
    local edmPath = table.concat({ mutationsRoot, "Casters", "caster_non_elemental.txt" }, PATH_SEP)
    local ok3, allEdmPMFs = pcall(loadPMFsCached, edmPath)
    if not ok3 then return { error = tostring(allEdmPMFs) } end
    edmPmfs = allEdmPMFs[tier]
    
  else
    -- Regular caster: no wield requirement, no edm file.
    -- WieldDifficulty is 0/nil so tier = 1.
    tier = deriveTierFromMutations(rawMutationCache[manaConvPath], weapon.WieldDifficulty)
  end
  
  local manaConvPmfs  = allManaConvPMFs[tier]
  local defensePmfs   = allDefensePMFs[tier]
  local missMagDefPmf = (tier >= 7) and MISS_MAG_PMF_T7T8 or MISS_MAG_PMF_T1T6
  local result        = { tier = tier, category = "orig_caster" }
  
  if edmPmfs then
    result.ElementalDamageMod = scorePMFStat(edmPmfs, "ElementalDamageMod", weapon.ElementalDamageMod)
  end
  
  result.WeaponDefense = scorePMFStat(defensePmfs, "WeaponDefense", weapon.WeaponDefense)
  
  if weapon.ManaConversionMod ~= nil then
    result.ManaConversionMod = scorePMFStat(manaConvPmfs, "ManaConversionMod", weapon.ManaConversionMod)
  else
    result.ManaConversionMod = 0.5
    result.manaConvNA        = true
  end
  
  result.missileDef = pctDefenseProc(missMagDefPmf, weapon.missileDef)
  result.magicDef   = pctDefenseProc(missMagDefPmf, weapon.magicDef)
  
  computeCompositeScore(result, weights)
  return result
end

-------------------------------------------------------------------------------
-- SCORER: CUSTOM SERVER — MELEE
-------------------------------------------------------------------------------

local function scoreCustomMelee(weapon, tier, weights)
  local result = { tier = tier, category = "custom_melee" }
  
  local damageRollMin, damageRollMax = computeCustomMeleeDamageRange(weapon, tier)
  
  local damagePercentile = cdfCustomDamageRoll(weapon.Damage, damageRollMin, damageRollMax)
  if damagePercentile ~= nil then
    result.Damage        = damagePercentile
    result.damageRollMin = damageRollMin
    result.damageRollMax = damageRollMax
  else
    result.Damage   = 0.5
    result.damageNA = true
  end
  
  local variancePercentile = cdfCustomDamageVariance(weapon.DamageVariance, weapon.baseVariance)
  if variancePercentile ~= nil then
    result.DamageVariance = variancePercentile
  else
    result.DamageVariance = 0.5
    result.varianceNA     = true
  end
  
  result.WeaponOffense         = cdfCustomOffenseDefenseMod(weapon.WeaponOffense        or 1.0, tier)
  result.WeaponPhysicalDefense = cdfCustomOffenseDefenseMod(weapon.WeaponPhysicalDefense or 1.0, tier)
  result.WeaponMagicalDefense  = cdfCustomOffenseDefenseMod(weapon.WeaponMagicalDefense  or 1.0, tier)
  
  local speedPercentile = cdfMeleeWeaponSpeed(weapon.weaponTime, weapon.baseWeaponTime)
  if speedPercentile ~= nil then
    result.weaponSpeed    = speedPercentile
    result.weaponSpeedMod = weapon.weaponTime / weapon.baseWeaponTime
  else
    result.weaponSpeed   = 0.5
    result.weaponSpeedNA = true
  end
  
  local subtypePercentile, subtypeIsNA, subtypeKind = scoreSubtypeBonus(weapon, tier, "melee")
  result.subtypeBonus     = subtypePercentile
  result.subtypeBonusNA   = subtypeIsNA
  result.subtypeBonusKind = subtypeKind
  
  computeCompositeScore(result, weights)
  return result
end

-------------------------------------------------------------------------------
-- SCORER: CUSTOM SERVER — MISSILE
-------------------------------------------------------------------------------

local function scoreCustomMissile(weapon, tier, weights)
  local result = { tier = tier, category = "custom_missile" }
  
  local damageModRollMin, damageModRollMax = computeCustomMissileDamageModRange(weapon, tier)
  
  local damageModPercentile = cdfCustomDamageRoll(weapon.DamageMod, damageModRollMin, damageModRollMax)
  if damageModPercentile ~= nil then
    result.DamageMod        = damageModPercentile
    result.damageModRollMin = damageModRollMin
    result.damageModRollMax = damageModRollMax
  else
    result.DamageMod   = 0.5
    result.damageModNA = true
  end
  
  result.WeaponOffense         = cdfCustomOffenseDefenseMod(weapon.WeaponOffense        or 1.0, tier)
  result.WeaponPhysicalDefense = cdfCustomOffenseDefenseMod(weapon.WeaponPhysicalDefense or 1.0, tier)
  result.WeaponMagicalDefense  = cdfCustomOffenseDefenseMod(weapon.WeaponMagicalDefense  or 1.0, tier)
  
  local speedPercentile = cdfMissileWeaponSpeed(weapon.weaponTime, weapon.baseWeaponTime)
  if speedPercentile ~= nil then
    result.weaponSpeed    = speedPercentile
    result.weaponSpeedMod = weapon.weaponTime / weapon.baseWeaponTime
  else
    result.weaponSpeed   = 0.5
    result.weaponSpeedNA = true
  end
  
  local subtypePercentile, subtypeIsNA, subtypeKind = scoreSubtypeBonus(weapon, tier, "missile")
  result.subtypeBonus     = subtypePercentile
  result.subtypeBonusNA   = subtypeIsNA
  result.subtypeBonusKind = subtypeKind
  
  computeCompositeScore(result, weights)
  return result
end

-------------------------------------------------------------------------------
-- SCORER: CUSTOM SERVER — CASTER
-------------------------------------------------------------------------------

local function scoreCustomCaster(weapon, tier, weights)
  local result     = { tier = tier, category = "custom_caster" }
  local isWarMagic = (weapon.weaponSkill == "WarMagic")
  
  if tier == 1 then
    result.ElementalDamageMod = 0.5
    result.edmNA              = true
  else
    local edmPercentile = cdfCasterElementalDamageMod(weapon.ElementalDamageMod, tier, isWarMagic)
    if edmPercentile ~= nil then
      result.ElementalDamageMod = edmPercentile
    else
      result.ElementalDamageMod = 0.5
      result.edmNA              = true
    end
  end
  
  local magicSkillModValue = isWarMagic and weapon.WeaponWarMagicMod or weapon.WeaponLifeMagicMod
  result.magicSkillMod = cdfCustomMagicSkillMod(magicSkillModValue or 0.0, tier)
  
  result.WeaponPhysicalDefense = cdfCustomOffenseDefenseMod(weapon.WeaponPhysicalDefense or 1.0, tier)
  result.WeaponMagicalDefense  = cdfCustomOffenseDefenseMod(weapon.WeaponMagicalDefense  or 1.0, tier)
  
  local subtypePercentile, subtypeIsNA, subtypeKind = scoreSubtypeBonus(weapon, tier, "caster")
  result.subtypeBonus     = subtypePercentile
  result.subtypeBonusNA   = subtypeIsNA
  result.subtypeBonusKind = subtypeKind
  
  computeCompositeScore(result, weights)
  return result
end

-------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------

-- Scores a flat weapon table.  Tier is never a parameter:
--   custom server  → weapon.tier from weenie.IntValues["Tier"]
--   original server → derived internally from the weapon's mutation file
function WeaponScorer.scoreWeapon(weapon, mutationsRoot, serverType, weights)
  serverType = serverType or WeaponScorer.serverType
  
  local weaponCategory = weapon.weaponCategory or "MeleeWeapon"
  
  if serverType == WeaponScorer.SERVER_CUSTOM then
    local tier = math.max(1, math.min(8, math.floor(weapon.tier or 1)))
    
    if weaponCategory == "MissileWeapon" then
      return scoreCustomMissile(weapon, tier, weights or CUST_MISSILE_WEIGHTS)
    elseif weaponCategory == "Caster" then
      return scoreCustomCaster(weapon, tier, weights or CUST_CASTER_WEIGHTS)
    else
      return scoreCustomMelee(weapon, tier, weights or CUST_MELEE_WEIGHTS)
    end
  else
    if weaponCategory == "Caster" then
      return scoreOriginalCaster(weapon, mutationsRoot, weights or ORIG_CASTER_WEIGHTS)
    elseif weaponCategory == "MissileWeapon" then
      return scoreOriginalMissile(weapon, mutationsRoot, weights or ORIG_MISSILE_WEIGHTS)
    else
      return scoreOriginalMelee(weapon, mutationsRoot, weights or ORIG_MELEE_WEIGHTS)
    end
  end
end

-- Convenience wrapper: builds a flat weapon table from a live weenie then scores it.
function WeaponScorer.scoreWeenie(weenie, mutationsRoot, serverType, weights)
  local weapon = WeaponScorer.weenieToWeapon(weenie)
  return WeaponScorer.scoreWeapon(weapon, mutationsRoot, serverType, weights)
end

-- Expose computed damage range for debugging/display (custom server, melee).
function WeaponScorer.computeDamageRange(weapon)
  local tier = math.max(1, math.min(8, math.floor(weapon.tier or 1)))
  return computeCustomMeleeDamageRange(weapon, tier)
end

-- Expose computed missile damage mod range for debugging/display.
function WeaponScorer.computeMissileDamageModRange(weapon)
  local tier = math.max(1, math.min(8, math.floor(weapon.tier or 1)))
  return computeCustomMissileDamageModRange(weapon, tier)
end

-------------------------------------------------------------------------------
-- PRINT SCORE
-- tier is read from result.tier (stored there by the scorer).
-------------------------------------------------------------------------------

function WeaponScorer.printScore(label, result)
  if result.error then
    print("WeaponScorer ERROR: " .. result.error)
    return
  end
  
  local tier = result.tier or 0
  
  local function bar(percentile)
    local filled = math.floor(percentile * 20 + 0.5)
    return "[" .. string.rep("#", filled) .. string.rep(".", 20 - filled) .. "]"
  end
  
  local function pct(percentile)
    return ("%5.1f%%"):format(percentile * 100)
  end
  
  local function row(statName, percentile, isNA)
    if isNA or percentile == nil then
      print(("  %-34s  N/A"):format(statName))
    else
      print(("  %-34s %s %s"):format(statName, bar(percentile), pct(percentile)))
    end
  end
  
  local function speedRow()
    if result.weaponSpeedNA or result.weaponSpeed == nil then
      print("  WeaponSpeed                         N/A")
    else
      print(("  %-34s %s %s  (speedMod %.3f)"):format(
      "WeaponSpeed", bar(result.weaponSpeed), pct(result.weaponSpeed), result.weaponSpeedMod or 0))
    end
  end
  
  local function subtypeRow()
    if result.subtypeBonus == nil then return end
    local statLabel = result.subtypeBonusKind
    and ("SubtypeBonus (" .. result.subtypeBonusKind .. ")")
    or  "SubtypeBonus"
    row(statLabel, result.subtypeBonus, result.subtypeBonusNA)
  end
  
  local detectedCategory = result.category or "orig_melee"
  
  print(("\n=== %s  [Tier %d] ==="):format(label, tier))
  
  if detectedCategory == "orig_melee" then
    row("Damage",         result.Damage,         result.damageNA)
    row("DamageVariance", result.DamageVariance, result.varianceNA)
    speedRow()
    row("WeaponOffense",  result.WeaponOffense,  false)
    print()
    row("WeaponDefense",  result.WeaponDefense,  false)
    row("MissileDef",     result.missileDef,     false)
    row("MagicDef",       result.magicDef,       false)
    
  elseif detectedCategory == "custom_melee" then
    row("Damage",            result.Damage,                result.damageNA)
    row("DamageVariance",    result.DamageVariance,        result.varianceNA)
    speedRow()
    row("WeaponOffense",     result.WeaponOffense,         false)
    row("WeaponPhysicalDef", result.WeaponPhysicalDefense, false)
    row("WeaponMagicalDef",  result.WeaponMagicalDefense,  false)
    if result.damageRollMin then
      print(("  Damage range auto: [%.1f, %.1f]"):format(result.damageRollMin, result.damageRollMax))
    end
    subtypeRow()
    
  elseif detectedCategory == "orig_missile" then
    row("DamageMod", result.DamageMod, false)
    if result.ElementalDamageBonus ~= nil then
      row("ElementalDmgBonus", result.ElementalDamageBonus, result.elemBonusNA)
    end
    speedRow()
    row("WeaponDefense", result.WeaponDefense, false)
    row("MissileDef",    result.missileDef,    false)
    row("MagicDef",      result.magicDef,      false)
    
  elseif detectedCategory == "custom_missile" then
    row("DamageMod",         result.DamageMod,             result.damageModNA)
    speedRow()
    row("WeaponOffense",     result.WeaponOffense,         false)
    row("WeaponPhysicalDef", result.WeaponPhysicalDefense, false)
    row("WeaponMagicalDef",  result.WeaponMagicalDefense,  false)
    if result.damageModRollMin then
      print(("  DamageMod range auto: [%.3f, %.3f]"):format(result.damageModRollMin, result.damageModRollMax))
    end
    subtypeRow()
    
  elseif detectedCategory == "orig_caster" then
    row("ElementalDamageMod", result.ElementalDamageMod, false)
    row("WeaponDefense",      result.WeaponDefense,      false)
    row("ManaConversionMod",  result.ManaConversionMod,  result.manaConvNA)
    row("MissileDef",         result.missileDef,         false)
    row("MagicDef",           result.magicDef,           false)
    
  elseif detectedCategory == "custom_caster" then
    row("ElementalDamageMod", result.ElementalDamageMod,    result.edmNA)
    row("MagicSkillMod",      result.magicSkillMod,         false)
    row("WeaponPhysicalDef",  result.WeaponPhysicalDefense, false)
    row("WeaponMagicalDef",   result.WeaponMagicalDefense,  false)
    subtypeRow()
  end
  
  print(string.rep("-", 68))
  row("COMPOSITE", result.composite, false)
  print("")
end

-- Returns best achievable stats at or below weapon.WieldDifficulty (original server).
function WeaponScorer.bestStats(weapon, mutationsRoot)
  local damageFilePath, offenseFilePath, buildError =
  buildMeleePaths(mutationsRoot, weapon.weaponSkill, weapon.weaponType, weapon)
  if buildError then return { error = buildError } end
  
  local ok,  err  = pcall(loadPMFsCached, damageFilePath)
  if not ok  then return { error = err  } end
  local ok2, err2 = pcall(loadPMFsCached, offenseFilePath)
  if not ok2 then return { error = err2 } end
  
  local damageRaw  = rawMutationCache[damageFilePath]
  local offenseRaw = rawMutationCache[offenseFilePath]
  local wieldCap   = weapon.WieldDifficulty
  
  local function bestFromRaw(mutationList)
    local best = {}
    local base = {}
    
    for _, mutation in ipairs(mutationList) do
      for _, outcome in ipairs(mutation.outcomes) do
        local wield   = outcome.stats.WieldDifficulty
        local wieldOk = (wieldCap == nil)
        or (wield == nil)
        or (type(wield.value) == "number" and wield.value <= wieldCap)
        
        for statName, assignment in pairs(outcome.stats) do
          if statName ~= "WieldDifficulty"
          and statName ~= "WieldRequirements"
          and statName ~= "WieldSkillType"
          and type(assignment.value) == "number" then
            if assignment.op == "set" then
              if base[statName] == nil or assignment.value > base[statName] then
                base[statName] = assignment.value
              end
            elseif assignment.op == "add" and wieldOk then
              if best[statName] == nil or assignment.value > best[statName] then
                best[statName] = assignment.value
              end
            end
          end
        end
      end
    end
    
    local result = {}
    for statName, baseVal in pairs(base) do
      result[statName] = baseVal + (best[statName] or 0)
    end
    for statName, delta in pairs(best) do
      if not base[statName] then result[statName] = delta end
    end
    return result
  end
  
  local damageBest  = bestFromRaw(damageRaw)
  local offenseBest = bestFromRaw(offenseRaw)
  
  return {
    Damage         = damageBest.Damage,
    DamageVariance = damageBest.DamageVariance,
    WeaponOffense  = offenseBest.WeaponOffense,
    WeaponDefense  = offenseBest.WeaponDefense,
    missileDef     = pmfMax(MISS_MAG_PMF_T7T8),
    magicDef       = pmfMax(MISS_MAG_PMF_T7T8),
  }
end

function WeaponScorer.getScoreRows(result)
  if result.error then
    return { { label = "ERROR", value = nil, isNA = true, text = result.error } }
  end
  
  local rows = {}
  
  local function addRow(label, percentile, isNA)
    table.insert(rows, {
      label = label,
      value = isNA and nil or percentile,
      isNA  = isNA or (percentile == nil),
    })
  end
  
  local function speedRow()
    if result.weaponSpeedNA or result.weaponSpeed == nil then
      addRow("WeaponSpeed", nil, true)
    else
      table.insert(rows, {
        label   = "WeaponSpeed",
        value   = result.weaponSpeed,
        isNA    = false,
        extra   = ""--("speedMod %.3f"):format(result.weaponSpeedMod or 0),
      })
    end
  end
  
  local function subtypeRow()
    if result.subtypeBonus == nil then return end
    local label = result.subtypeBonusKind
    and ("SubtypeBonus (" .. result.subtypeBonusKind .. ")")
    or  "SubtypeBonus"
    addRow(label, result.subtypeBonus, result.subtypeBonusNA)
  end
  
  local cat = result.category or "orig_melee"
  
  if cat == "orig_melee" then
    addRow("Damage",         result.Damage,         result.damageNA)
    addRow("DamageVariance", result.DamageVariance, result.varianceNA)
    --speedRow()
    addRow("WeaponOffense",  result.WeaponOffense,  false)
    addRow("WeaponDefense",  result.WeaponDefense,  false)
    addRow("MissileDef",     result.missileDef,     false)
    addRow("MagicDef",       result.magicDef,       false)
    
  elseif cat == "custom_melee" then
    addRow("Damage",            result.Damage,                result.damageNA)
    addRow("DamageVariance",    result.DamageVariance,        result.varianceNA)
    --speedRow()
    addRow("WeaponOffense",     result.WeaponOffense,         false)
    addRow("WeaponPhysicalDef", result.WeaponPhysicalDefense, false)
    addRow("WeaponMagicalDef",  result.WeaponMagicalDefense,  false)
    if result.damageRollMin then
      table.insert(rows, {
        label = "Damage range",
        value = nil,
        isNA  = false,
        extra = ("%.1f – %.1f"):format(result.damageRollMin, result.damageRollMax),
      })
    end
    subtypeRow()
    
  elseif cat == "orig_missile" then
    addRow("DamageMod",         result.DamageMod,             false)
    addRow("ElementalDmgBonus", result.ElementalDamageBonus,  result.elemBonusNA)
    --speedRow()
    addRow("WeaponDefense",     result.WeaponDefense,         false)
    addRow("MissileDef",        result.missileDef,            false)
    addRow("MagicDef",          result.magicDef,              false)
    
  elseif cat == "custom_missile" then
    addRow("DamageMod",         result.DamageMod,             result.damageModNA)
    --speedRow()
    addRow("WeaponOffense",     result.WeaponOffense,         false)
    addRow("WeaponPhysicalDef", result.WeaponPhysicalDefense, false)
    addRow("WeaponMagicalDef",  result.WeaponMagicalDefense,  false)
    if result.damageModRollMin then
      table.insert(rows, {
        label = "DamageMod range",
        value = nil,
        isNA  = false,
        extra = ("%.3f – %.3f"):format(result.damageModRollMin, result.damageModRollMax),
      })
    end
    subtypeRow()
    
  elseif cat == "orig_caster" then
    addRow("ElementalDamageMod", result.ElementalDamageMod, false)
    addRow("WeaponDefense",      result.WeaponDefense,      false)
    addRow("ManaConversionMod",  result.ManaConversionMod,  result.manaConvNA)
    addRow("MissileDef",         result.missileDef,         false)
    addRow("MagicDef",           result.magicDef,           false)
    
  elseif cat == "custom_caster" then
    addRow("ElementalDamageMod", result.ElementalDamageMod,    result.edmNA)
    addRow("MagicSkillMod",      result.magicSkillMod,         false)
    addRow("WeaponPhysicalDef",  result.WeaponPhysicalDefense, false)
    addRow("WeaponMagicalDef",   result.WeaponMagicalDefense,  false)
    subtypeRow()
  end
  
  table.insert(rows, { label = "---", value = nil, isSeparator = true })
  addRow("COMPOSITE", result.composite, false)
  
  return rows
end

return WeaponScorer