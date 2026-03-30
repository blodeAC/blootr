-- ItemExamine.lua

local bit = require("bit")

local ItemExamine = {}
ItemExamine.__index = ItemExamine

----------------------------------------------------------------------
-- Core Inq* helpers
----------------------------------------------------------------------

function InqInt(item, prop)
  prop = type(prop)=="string" and prop or tostring(prop)
  local v = item.IntValues and item.IntValues[prop]
  if v ~= nil then return true, v end
  return false, 0
end

function InqInt64(item, prop)
  prop = type(prop)=="string" and prop or tostring(prop)
  local v = item.Int64Values and item.Int64Values[prop]
  if v ~= nil then return true, v end
  return false, 0
end

function InqBool(item, prop)
  prop = type(prop)=="string" and prop or tostring(prop)
  local v = item.BoolValues and item.BoolValues[prop]
  if v ~= nil then return true, v end
  return false, false
end

function InqFloat(item, prop)
  prop = type(prop)=="string" and prop or tostring(prop)
  local v = item.FloatValues and item.FloatValues[prop]
  if v ~= nil then return true, v end
  return false, 0.0
end

function InqDataID(item, prop)
  prop = type(prop)=="string" and prop or tostring(prop)
  local v = item.DataValues and item.DataValues[prop]
  if v ~= nil then return true, v end
  return false, 0
end

function InqString(item, prop)
  prop = type(prop)=="string" and prop or tostring(prop)
  local v = item.StringValues and item.StringValues[prop]
  if v ~= nil then return true, v end
  return false, ""
end

----------------------------------------------------------------------
-- Utility helpers
----------------------------------------------------------------------
local imguiGreen = Vector4.new(0.3, 1.0, 0.3, 1.0)
local imguiRed   = Vector4.new(1.0, 0.3, 0.3, 1.0)

local function ModifierToString(rMod)
  local v1 = 1 - rMod
  if v1 < 1 then v1 = v1 * -1 end
  return string.format("%d%%", math.floor(v1 * 100.0 + 0.5))
end

local function SmallModifierToString(rMod)
  local v1 = 1.0 - rMod
  if (1.0 - rMod) < 0.0 then v1 = v1 * -1 end
  return string.format("%.1f%%", v1 * 100.0)
end

local function WeaponTimeToString(wtime)
  if wtime < 11 then      return "Very Fast"
  elseif wtime < 31 then  return "Fast"
  elseif wtime < 50 then  return "Average"
  elseif wtime < 80 then  return "Slow"
  else                    return "Very Slow" end
end

local function ClothingPriorityToString(priority)
  local byte1 = bit.rshift(priority, 8) % 0xFF
  local cover = {}
  local function add(cond, label) if cond then table.insert(cover, label) end end
  add(bit.band(byte1, 0x40) ~= 0, "Head")
  add(bit.band(priority, 0x8)    ~= 0 or bit.band(priority, 0x400)  ~= 0, "Chest")
  add(bit.band(priority, 0x10)   ~= 0 or bit.band(byte1, 0x8)       ~= 0, "Abdomen")
  add(bit.band(priority, 0x20)   ~= 0 or bit.band(byte1, 0x10)      ~= 0, "Upper Arms")
  add(bit.band(priority, 0x40)   ~= 0 or bit.band(byte1, 0x20)      ~= 0, "Lower Arms")
  add(bit.band(priority, 0x8000) ~= 0, "Hands")
  add(bit.band(priority, 0x2)    ~= 0 or bit.band(byte1, 0x1)       ~= 0, "Upper Legs")
  add(bit.band(priority, 0x4)    ~= 0 or bit.band(byte1, 0x2)       ~= 0, "Lower Legs")
  add(bit.band(priority, 0x10000)~= 0, "Feet")
  if #cover > 0 then return "Covers " .. table.concat(cover, ", ") end
  return ""
end

local function DamageResistanceToString(dtype, al, modifier)
  local d_text, modTxt = "", ""
  if modifier >= 0 then
    if     dtype == 1    then d_text = "Slashing: "
    elseif dtype == 2    then d_text = "Piercing: "
    elseif dtype == 4    then d_text = "Bludgeoning: "
    elseif dtype == 8    then d_text = "Cold: "
    elseif dtype == 16   then d_text = "Fire: "
    elseif dtype == 32   then d_text = "Acid: "
    elseif dtype == 64   then d_text = "Electric: "
    elseif dtype == 1024 then d_text = "Nether: "
    else return "" end
    if     modifier >= 2.0 then modTxt = "Unparalleled"; modifier = 2.0
    elseif modifier >= 1.6 then modTxt = "Excellent"
    elseif modifier >= 1.2 then modTxt = "Above Average"
    elseif modifier >= 0.8 then modTxt = "Average"
    elseif modifier >= 0.4 then modTxt = "Below Average"
    elseif modifier >= 0   then modTxt = "Poor" end
  else
    if     dtype == 1    then d_text = "Your armor will rend and slash you if hit."
    elseif dtype == 2    then d_text = "Your armor will cave in and pierce you if hit."
    elseif dtype == 4    then d_text = "Your armor will shatter and bruise you if hit."
    elseif dtype == 8    then d_text = "Your armor is unnaturally cold."
    elseif dtype == 16   then d_text = "Your armor is flammable."
    elseif dtype == 32   then d_text = "Your armor itches and burns your skin."
    elseif dtype == 64   then d_text = "Your armor is extremely conductive."
    elseif dtype == 1024 then d_text = "Your armor is infused with shadow."
    else return "" end
    return d_text
  end
  local al_mod = al * modifier
  return string.format("%s%s  (%.0f)", d_text, modTxt, al_mod)
end

local function DeltaTimeToString(time)
  local months  = math.floor(time / 0x278D00)
  local days    = math.floor(time % 0x278D00 / 0x15180)
  local v4      = time % 0x278D00 % 0x15180
  local hours   = math.floor(v4 / 0xE10)
  v4            = v4 % 0xE10
  local seconds = math.floor(v4 % 0x3C)
  local minutes = math.floor(v4 / 0x3C)
  local parts   = {}
  if months  > 1 then table.insert(parts, months  .. " months")  end
  if days    > 1 then table.insert(parts, days    .. " days")    end
  if hours   > 1 then table.insert(parts, hours   .. " hours")   end
  if minutes > 0 then table.insert(parts, minutes .. " minutes") end
  table.insert(parts, seconds .. " seconds.")
  return table.concat(parts, ", ")
end

local function InqHeritageGroupDisplayName(type_)
  if     type_ == 1  then return true, "Aluvian"
  elseif type_ == 2  then return true, "Gharu'ndim"
  elseif type_ == 3  then return true, "Sho"
  elseif type_ == 4  then return true, "Viamontian"
  elseif type_ == 5  then return true, "Umbraen"
  elseif type_ == 6  then return true, "Gearknight"
  elseif type_ == 7  then return true, "Tumerok"
  elseif type_ == 8  then return true, "Lugian"
  elseif type_ == 9  then return true, "Empyrean"
  elseif type_ == 10 then return true, "Penumbraen"
  elseif type_ == 11 then return true, "Undead"
  elseif type_ == 12 or type_ == 13 then return true, "Olthoi"
  else return false, "" end
end

local function InqAttributeName(iSkill)
  if     iSkill == 1 then return "Strength"
  elseif iSkill == 2 then return "Endurance"
  elseif iSkill == 3 then return "Quickness"
  elseif iSkill == 4 then return "Coordination"
  elseif iSkill == 5 then return "Focus"
  elseif iSkill == 6 then return "Self"
  else return "" end
end

local function InqAttribute2ndName(iSkill)
  if     iSkill == 1 then return "Maximum Health"
  elseif iSkill == 2 then return "Health"
  elseif iSkill == 3 then return "Maximum Stamina"
  elseif iSkill == 4 then return "Stamina"
  elseif iSkill == 5 then return "Maximum Mana"
  elseif iSkill == 6 then return "Mana"
  else return "" end
end

local ValidSkills = {
  "MeleeDefense","MissileDefense","ArcaneLore","MagicDefense","ManaConversion",
  "ItemTinkering","AssessPerson","Deception","Healing","Jump","Lockpick","Run",
  "AssessCreature","WeaponTinkering","ArmorTinkering","MagicItemTinkering",
  "CreatureEnchantment","ItemEnchantment","LifeMagic","WarMagic","Leadership",
  "Loyalty","Fletching","Alchemy","Cooking","Salvaging","TwoHandedCombat",
  "VoidMagic","HeavyWeapons","LightWeapons","FinesseWeapons","MissileWeapons",
  "Shield","DualWield","Recklessness","SneakAttack","DirtyFighting","Summoning"
}

local function InqSkillName(iSkill)
  ---@diagnostic disable-next-line
  for _,sk in ipairs(SkillId.GetValues()) do
    if sk.ToNumber()==iSkill then return tostring(sk) end
  end
  return "UnknownSkill"
end

local function InqCreatureDisplayName(iType)
  local t = {
    [1]="Olthoi",[2]="Banderling",[3]="Drudge",[4]="Mosswart",[5]="Lugian",[6]="Tumerok",
    [7]="Mite",[8]="Tusker",[9]="Phyntos Wasp",[10]="Rat",[11]="Auroch",[12]="Cow",
    [13]="Golem",[14]="Undead",[15]="Gromnie",[16]="Reedshark",[17]="Armoredillo",
    [18]="Fae",[19]="Virindi",[20]="Wisp",[21]="Knathtead",[22]="Shadow",[23]="Mattekar",
    [24]="Mumiyah",[25]="Rabbit",[26]="Sclavus",[27]="Shallows Shark",[28]="Monouga",
    [29]="Zefir",[30]="Skeleton",[31]="Human",[32]="Shreth",[33]="Chittick",[34]="Moarsman",
    [35]="Olthoi Larvae",[36]="Slithis",[37]="Deru",[38]="Fire Elemental",[39]="Snowman",
    [40]="Unknown",[41]="Bunny",[42]="Lightning Elemental",[43]="Rockslide",[44]="Grievver",
    [45]="Niffis",[46]="Ursuin",[47]="Crystal",[48]="Hollow Minion",[49]="Scarecrow",
    [50]="Idol",[51]="Empyrean",[52]="Hopeslayer",[53]="Doll",[54]="Marionette",
    [55]="Carenzi",[56]="Siraluun",[57]="Aun Tumerok",[58]="Hea Tumerok",[59]="Simulacrum",
    [60]="Acid Elemental",[61]="Frost Elemental",[62]="Elemental",[63]="Statue",[64]="Wall",
    [65]="Altered Human",[66]="Device",[67]="Harbinger",[68]="Dark Sarcophagus",[69]="Chicken",
    [70]="Gotrok Lugian",[71]="Margul",[72]="Bleached Rabbit",[73]="Nasty Rabbit",
    [74]="Grimacing Rabbit",[75]="Burun",[76]="Target",[77]="Ghost",[78]="Fiun",[79]="Eater",
    [80]="Penguin",[81]="Ruschk",[82]="Thrungus",[83]="Viamontian Knight",[84]="Remoran",
    [85]="Swarm",[86]="Moar",[87]="Enchanted Arms",[88]="Sleech",[89]="Mukkir",[90]="Merwart",
    [91]="Food",[92]="Paradox Olthoi",[93]="Harvest",[94]="Energy",[95]="Apparition",
    [96]="Aerbax",[97]="Touched",[98]="Blighted Moarsman",[99]="Gear Knight",[100]="Gurog",
    [101]="A'nekshay"
  }
  return t[iType] or ""
end

local function GetAppraisalStringFromRequirements(iReq, iSkill, iDiff)
  local result = ""
  if iReq == 2 or iReq == 4 or iReq == 6 then result = "base " end
  if iReq == 1 or iReq == 2 or iReq == 8 then
    result = result .. InqSkillName(iSkill)
  elseif iReq == 3 or iReq == 4 then
    result = result .. InqAttributeName(iSkill)
  elseif iReq == 5 or iReq == 6 then
    result = result .. InqAttribute2ndName(iSkill)
  elseif iReq == 9 or iReq == 10 then
    if     iSkill == 287 then result = "Standing with the Celestial Hand"
    elseif iSkill == 288 then result = "Standing with the Eldrytch Web"
    elseif iSkill == 289 then result = "Standing with the Radiant Blood"
    else result = "unknown quality" end
  elseif iReq == 7  then result = "level"
  elseif iReq == 11 then result = InqCreatureDisplayName(iDiff)
  elseif iReq == 12 then
    local ok, heritage = InqHeritageGroupDisplayName(iDiff)
    if ok then result = heritage end
  end
  return result
end

local function ItemTotalXPToLevel(gained_xp, base_xp, max_level, xp_scheme)
  local level = 0
  if xp_scheme == 1 then
    level = math.floor(gained_xp / base_xp)
  elseif xp_scheme == 2 then
    local levelXP  = base_xp
    local remainXP = gained_xp
    while remainXP >= levelXP do
      level    = level + 1
      remainXP = remainXP - levelXP
      levelXP  = levelXP * 2
    end
  elseif xp_scheme == 3 then
    if gained_xp >= base_xp and gained_xp < base_xp * 3 then
      level = 1
    else
      level = math.floor((gained_xp - base_xp) / base_xp)
    end
  end
  if level > max_level then level = max_level end
  return level
end

local function ItemLevelToTotalXP(itemLevel, baseXP, maxLevel, xpScheme)
  if itemLevel < 1 then return 0 end
  if itemLevel > maxLevel then itemLevel = maxLevel end
  if itemLevel == 1 then return baseXP end
  if xpScheme == 1 then
    return itemLevel * baseXP
  elseif xpScheme == 3 then
    return itemLevel * baseXP + baseXP
  else
    local levelXP = baseXP
    local totalXP = baseXP
    for _ = itemLevel - 1, 1, -1 do
      levelXP = levelXP * 2
      totalXP = totalXP + levelXP
    end
    return totalXP
  end
end

local function GetElementalModPKModifier(elementalModifier)
  local pkMod = 0.25
  return ((elementalModifier - 1.0) * pkMod + 1.0)
end

local function GetSkillChance(skill, difficulty, factor)
  factor = factor or 0.03
  local chance = 1.0 - (1.0 / (1.0 + math.exp(factor * (skill - difficulty))))
  if chance < 0.0 then chance = 0.0 end
  if chance > 1.0 then chance = 1.0 end
  return chance
end

local function pseudo_LockpickSuccessPercentToString(resistance)
  local lockpick_skill = 200
  local lr = GetSkillChance(lockpick_skill, resistance) * 100.0
  if     lr <= 0  then return "impossible"
  elseif lr < 5   then return "ridiculously difficult"
  elseif lr < 15  then return "extremely difficult"
  elseif lr < 35  then return "quite difficult"
  elseif lr < 50  then return "difficult"
  elseif lr < 70  then return "challenging"
  elseif lr < 85  then return "mildly challenging"
  elseif lr < 95  then return "easy"
  else                  return "trivial" end
end

---@type table
StringToMaterialType = setmetatable({
  ["Unknown"] = MaterialType.Ceramic.ToNumber()-1,
  ["Ceramic"] = MaterialType.Ceramic.ToNumber(),
  ["Porcelain"] = MaterialType.Porcelain.ToNumber(),
  ["Cloth"] = MaterialType.Porcelain.ToNumber()+1,
  ["Linen"] = MaterialType.Linen.ToNumber(),
  ["Satin"] = MaterialType.Satin.ToNumber(),
  ["Silk"] = MaterialType.Silk.ToNumber(),
  ["Velvet"] = MaterialType.Velvet.ToNumber(),
  ["Wool"] = MaterialType.Wool.ToNumber(),
  ["Gem"] = MaterialType.Wool.ToNumber()+1,
  ["Agate"] = MaterialType.Agate.ToNumber(),
  ["Amber"] = MaterialType.Amber.ToNumber(),
  ["Amethyst"] = MaterialType.Amethyst.ToNumber(),
  ["Aquamarine"] = MaterialType.Aquamarine.ToNumber(),
  ["Azurite"] = MaterialType.Azurite.ToNumber(),
  ["Black Garnet"] = MaterialType.BlackGarnet.ToNumber(),
  ["Black Opal"] = MaterialType.BlackOpal.ToNumber(),
  ["Bloodstone"] = MaterialType.Bloodstone.ToNumber(),
  ["Carnelian"] = MaterialType.Carnelian.ToNumber(),
  ["Citrine"] = MaterialType.Citrine.ToNumber(),
  ["Diamond"] = MaterialType.Diamond.ToNumber(),
  ["Emerald"] = MaterialType.Emerald.ToNumber(),
  ["Fire Opal"] = MaterialType.FireOpal.ToNumber(),
  ["Green Garnet"] = MaterialType.GreenGarnet.ToNumber(),
  ["Green Jade"] = MaterialType.GreenJade.ToNumber(),
  ["Hematite"] = MaterialType.Hematite.ToNumber(),
  ["Imperial Topaz"] = MaterialType.ImperialTopaz.ToNumber(),
  ["Jet"] = MaterialType.Jet.ToNumber(),
  ["Lapis Lazuli"] = MaterialType.LapisLazuli.ToNumber(),
  ["Lavender Jade"] = MaterialType.LavenderJade.ToNumber(),
  ["Malachite"] = MaterialType.Malachite.ToNumber(),
  ["Moonstone"] = MaterialType.Moonstone.ToNumber(),
  ["Onyx"] = MaterialType.Onyx.ToNumber(),
  ["Opal"] = MaterialType.Opal.ToNumber(),
  ["Peridot"] = MaterialType.Peridot.ToNumber(),
  ["Red Garnet"] = MaterialType.RedGarnet.ToNumber(),
  ["Red Jade"] = MaterialType.RedJade.ToNumber(),
  ["Rose Quartz"] = MaterialType.RoseQuartz.ToNumber(),
  ["Ruby"] = MaterialType.Ruby.ToNumber(),
  ["Sapphire"] = MaterialType.Sapphire.ToNumber(),
  ["Smokey Quartz"] = MaterialType.SmokeyQuartz.ToNumber(),
  ["Sunstone"] = MaterialType.Sunstone.ToNumber(),
  ["Tiger Eye"] = MaterialType.TigerEye.ToNumber(),
  ["Tourmaline"] = MaterialType.Tourmaline.ToNumber(),
  ["Turquoise"] = MaterialType.Turquoise.ToNumber(),
  ["White Jade"] = MaterialType.WhiteJade.ToNumber(),
  ["White Quartz"] = MaterialType.WhiteQuartz.ToNumber(),
  ["White Sapphire"] = MaterialType.WhiteSapphire.ToNumber(),
  ["Yellow Garnet"] = MaterialType.YellowGarnet.ToNumber(),
  ["Yellow Topaz"] = MaterialType.YellowTopaz.ToNumber(),
  ["Zircon"] = MaterialType.Zircon.ToNumber(),
  ["Ivory"] = MaterialType.Ivory.ToNumber(),
  ["Leather"] = MaterialType.Leather.ToNumber(),
  ["Armoredillo Hide"] = MaterialType.ArmoredilloHide.ToNumber(),
  ["Gromnie Hide"] = MaterialType.GromnieHide.ToNumber(),
  ["Reed Shark Hide"] = MaterialType.ReedSharkHide.ToNumber(),
  ["Metal"] = MaterialType.ReedSharkHide.ToNumber()+1,
  ["Brass"] = MaterialType.Brass.ToNumber(),
  ["Bronze"] = MaterialType.Bronze.ToNumber(),
  ["Copper"] = MaterialType.Copper.ToNumber(),
  ["Gold"] = MaterialType.Gold.ToNumber(),
  ["Iron"] = MaterialType.Iron.ToNumber(),
  ["Pyreal"] = MaterialType.Pyreal.ToNumber(),
  ["Silver"] = MaterialType.Silver.ToNumber(),
  ["Steel"] = MaterialType.Steel.ToNumber(),
  ["Stone"] = MaterialType.Steel.ToNumber()+1,
  ["Alabaster"] = MaterialType.Alabaster.ToNumber(),
  ["Granite"] = MaterialType.Granite.ToNumber(),
  ["Marble"] = MaterialType.Marble.ToNumber(),
  ["Obsidian"] = MaterialType.Obsidian.ToNumber(),
  ["Sandstone"] = MaterialType.Sandstone.ToNumber(),
  ["Serpentine"] = MaterialType.Serpentine.ToNumber(),
  ["Wood"] = MaterialType.Serpentine.ToNumber()+1,
  ["Ebony"] = MaterialType.Ebony.ToNumber(),
  ["Mahogany"] = MaterialType.Mahogany.ToNumber(),
  ["Oak"] = MaterialType.Oak.ToNumber(),
  ["Pine"] = MaterialType.Pine.ToNumber(),
  ["Teak"] = MaterialType.Teak.ToNumber()
}, {
  __index = function(src, key)
    if type(key) == "number" then
      for k, v in pairs(src) do
        if v == key then return k end
      end
    elseif type(key) == "key" then
      return rawget(src, key)
    end
    return nil
  end
})

local PlayerKillerStatus = {
  Undef       = 0x00, Protected  = 0x01, NPK     = 0x02, PK       = 0x04,
  Unprotected = 0x08, RubberGlue = 0x10, Free    = 0x20, PKLite   = 0x40
}

local function GetSocietyRank(tickets)
  if     tickets >= 1001 then return "Master"
  elseif tickets >= 601  then return "Lord"
  elseif tickets >= 301  then return "Knight"
  elseif tickets >= 101  then return "Adept"
  elseif tickets >= 1    then return "Initiate"
  else                        return "Free agent" end
end

----------------------------------------------------------------------
-- Set names
----------------------------------------------------------------------
SetNames = {
  [4]="Carraida's Benediction",[5]="Noble Relic",[6]="Ancient Relic",[7]="Relic Alduressa",
  [8]="Shou-jen",[9]="Empyrean Rings",[10]="Arm, Mind, Heart",[11]="Coat of the Perfect Light",
  [12]="Leggings of Perfect Light",[13]="Soldier's",[14]="Adept's",[15]="Archer's",
  [16]="Defender's",[17]="Tinker's",[18]="Crafter's",[19]="Hearty",[20]="Dexterous",[21]="Wise",
  [22]="Swift",[23]="Hardenend",[24]="Reinforced",[25]="Interlocking",[26]="Flame Proof",
  [27]="Acid Proof",[28]="Cold Proof",[29]="Lightning Proof",[30]="Dedication",
  [31]="Gladiatorial Clothing",[32]="Ceremonial Clothing",[33]="Protective Clothing",
  [35]="Sigil of Defense",[36]="Sigil of Destruction",[37]="Sigil of Fury",
  [38]="Sigil of Growth",[39]="Sigil of Vigor",[40]="Heroic Protector",[41]="Heroic Destroyer",
  [49]="Weave of Alchemy",[50]="Weave of Arcane Lore",[51]="Weave of Armor Tinkering",
  [52]="Weave of Assess Person",[53]="Weave of Light Weapons",[54]="Weave of Missile Weapons",
  [55]="Weave of Cooking",[56]="Weave of Creature Enchantment",[57]="Weave of Missile Weapons",
  [58]="Weave of Finesse",[59]="Weave of Deception",[60]="Weave of Fletching",
  [61]="Weave of Healing",[62]="Weave of Item Enchantment",[63]="Weave of Item Tinkering",
  [64]="Weave of Leadership",[65]="Weave of Life Magic",[66]="Weave of Loyalty",
  [67]="Weave of Light Weapons",[68]="Weave of Magic Defense",[69]="Weave of Magic Item Tinkering",
  [70]="Weave of Mana Conversion",[71]="Weave of Melee Defense",[72]="Weave of Missile Defense",
  [73]="Weave of Salvaging",[74]="Weave of Light Weapons",[75]="Weave of Light Weapons",
  [76]="Weave of Heavy Weapons",[77]="Weave of Missile Weapons",[78]="Weave of Two Handed Combat",
  [79]="Weave of Light Weapons",[80]="Weave of Void Magic",[81]="Weave of War Magic",
  [82]="Weave of Weapon Tinkering",[83]="Weave of Assess Creature ",[84]="Weave of Dirty Fighting",
  [85]="Weave of Dual Wield",[86]="Weave of Recklessness",[87]="Weave of Shield",
  [88]="Weave of Sneak Attack",[89]="Shou-Jen Shozoku",[90]="Weave of Summoning",
  [91]="Shrouded Soul",[92]="Darkened Mind",[93]="Clouded Spirit",
  [94]="Minor Stinging Shrouded Soul",[95]="Minor Sparking Shrouded Soul",
  [96]="Minor Smoldering Shrouded Soul",[97]="Minor Shivering Shrouded Soul",
  [98]="Minor Stinging Darkened Mind",[99]="Minor Sparking Darkened Mind",
  [100]="Minor Smoldering Darkened Mind",[101]="Minor Shivering Darkened Mind",
  [102]="Minor Stinging Clouded Spirit",[103]="Minor Sparking Clouded Spirit",
  [104]="Minor Smoldering Clouded Spirit",[105]="Minor Shivering Clouded Spirit",
  [106]="Major Stinging Shrouded Soul",[107]="Major Sparking Shrouded Soul",
  [108]="Major Smoldering Shrouded Soul",[109]="Major Shivering Shrouded Soul",
  [110]="Major Stinging Darkened Mind",[111]="Major Sparking Darkened Mind",
  [112]="Major Smoldering Darkened Mind",[113]="Major Shivering Darkened Mind",
  [114]="Major Stinging Clouded Spirit",[115]="Major Sparking Clouded Spirit",
  [116]="Major Smoldering Clouded Spirit",[117]="Major Shivering Clouded Spirit",
  [118]="Blackfire Stinging Shrouded Soul",[119]="Blackfire Sparking Shrouded Soul",
  [120]="Blackfire Smoldering Shrouded Soul",[121]="Blackfire Shivering Shrouded Soul",
  [122]="Blackfire Stinging Darkened Mind",[123]="Blackfire Sparking Darkened Mind",
  [124]="Blackfire Smoldering Darkened Mind",[125]="Blackfire Shivering Darkened Mind",
  [126]="Blackfire Stinging Clouded Spirit",[127]="Blackfire Sparking Clouded Spirit",
  [128]="Blackfire Smoldering Clouded Spirit",[129]="Blackfire Shivering Clouded Spirit",
  [130]="Shimmering Shadows"
}

local HIGHER_IS_BETTER = {
  ArmorLevel=true, Damage=true, ShieldLevel=true, Spellcraft=true,
  ManaMax=true, ItemLevel=true, Workmanship=true,
  WeaponOffenseBonus=true,
  Rating_Damage=true, Rating_DamageResist=true, Rating_Crit=true,
  Rating_CritDamage=true, Rating_CritResist=true,
  Rating_CritDamageResist=true, Rating_HealBoost=true,
  Rating_NetherResist=true, Rating_LifeResist=true, Rating_MaxHealth=true,
  Resist_Slash=true, Resist_Pierce=true, Resist_Bludgeon=true,
  Resist_Fire=true, Resist_Cold=true, Resist_Acid=true,
  Resist_Electric=true, Resist_Nether=true,
  MeleeDefenseBonus=true, MissileDefenseBonus=true, MagicDefenseBonus=true,
  ManaConversionBonus=true, ElementalDamageBonus=true, DamageVariance=true
}
local LOWER_IS_BETTER = {
  Value=true, Burden=true, WeaponSpeed=true
}


----------------------------------------------------------------------
-- ItemExamine core
----------------------------------------------------------------------
local serverLogic = require("ItemExamine_" .. game.ServerName)
local AllegianceTitle = require("AllegianceTitle")

function ItemExamine.new(itemData, creatureBool)
  local self = setmetatable({}, ItemExamine)
  self.lines = {}
  self.byKey = {}

  if serverLogic ~= nil then
    local ex = serverLogic.new(itemData)
    self.item = ex.item
    if ex.byKey then
      for key, entry in pairs(ex.byKey) do
        if not self.byKey[key] then
          entry._order   = self._keyOrder or 0
          self._keyOrder = (self._keyOrder or 0) + 1
          self.byKey[key] = entry
        end
      end
    end
    for k in pairs(serverLogic.HIGHER_IS_BETTER or {}) do HIGHER_IS_BETTER[k] = true end
    for k in pairs(serverLogic.LOWER_IS_BETTER  or {}) do LOWER_IS_BETTER[k]  = true end

  else
    self.item = itemData
  end

  if not creatureBool then
    self:ShowName()
    self:ShowValueInfo()
    self:ShowBurdenInfo()
    self:ShowTinkeringInfo()
    self:ShowWorkmanship()
    self:ShowSalvageCount()
    local hasSet     = self:ShowSet()
    local hasRatings = self:ShowRatings()
    if hasSet or hasRatings then self:Add("") end
    self:ShowWeaponAndArmorData()
    self:ShowDefenseModData()
    self:ShowArmorMods()
    self:ShowShortMagicInfo()
    self:ShowSpecialProperties()
    self:ShowUsage()
    self:ShowLevelLimitInfo()
    self:ShowWieldRequirements()
    self:ShowUsageLimitInfo()
    self:ShowItemLevelInfo()
    self:ShowActivationRequirements()
    self:ShowCasterData()
    self:ShowBoostValue()
    self:ShowHealKitValues()
    self:ShowCapacity()
    self:ShowLockAppraiseInfo()
    self:ShowManaStoneInfo()
    self:ShowRemainingUses()
    self:ShowCraftsman()
    self:ShowSellable()
    self:ShowRareInfo()
    self:ShowMagicInfo()
    self:ShowDescription()
    self:Add("")
  else
    self:ShowCreatureHeader()
    self:ShowCreatureAttributes()
    self:ShowCreatureAllegiance()
    self:ShowCreatureArmor()
    self:ShowCreatureRatings()
  end
  return self
end

----------------------------------------------------------------------
-- Add / AddTable / GetText
----------------------------------------------------------------------

-- propKey: optional stable string key for cross-item comparison lookups.
-- propVal: the raw numeric/typed value behind the displayed text.
-- If multiple lines share a key (e.g. per-resist rows) each is stored
-- individually under a unique derived key like "Resist_Fire".
function ItemExamine:Add(text, color, mods, propVal, propKey)
  local t = text or ""
  -- auto-derive a short label by stripping everything from the first ": " onward
  -- e.g. "Armor Level: 494" -> "Armor Level",  "Value: 31,140" -> "Value"
  local label = propKey and (t:match("^([^:]+)%s*:") or t:match("^([^%(]+)%s*%(") or propKey) or nil
  if label then label = label:match("^%s*(.-)%s*$") end  -- trim whitespace
  local line = { text=t, color=color, mods=mods or {}, propVal=propVal, propKey=propKey, label=label }
  table.insert(self.lines, line)
  if propKey and not self.byKey[propKey] then
    line._order     = self._keyOrder or 0
    self._keyOrder  = (self._keyOrder or 0) + 1
    self.byKey[propKey] = line
  end
end

function ItemExamine:AddTable(textTable)
  table.insert(self.lines, { textTable=textTable, mods={} })
end

function ItemExamine:AddLines(text, color, mods)
  if not text or text == "" then return end
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    self:Add(line, color, mods)
  end
end

function ItemExamine:GetText()
  local parts = {}
  for _, line in ipairs(self.lines) do table.insert(parts, line.text) end
  return table.concat(parts, "\n")
end

----------------------------------------------------------------------
-- Compare (static)
-- Returns an ordered list of rows:
--   { key, label, aVal, bVal, aText, bText, delta, deltaStr, higherIsBetter }
-- higherIsBetter: true  → green when B > A
--                 false → green when B < A
--                 nil   → no colouring
----------------------------------------------------------------------
function ItemExamine.Compare(examA, examB)
  local results = {}
  local seen    = {}

  local function fmtNum(n)
    if math.floor(n) ~= n then return string.format("%.2f", n) end
    return tostring(math.floor(n))
  end

  local function addRow(key, lineA, lineB)
    local aVal  = lineA and lineA.propVal
    local bVal  = lineB and lineB.propVal
    local aText = (lineA and lineA.text) or "—"
    local bText = (lineB and lineB.text) or "—"
    -- prefer the stored label, fall back to parsing from text, then key
    local label = (lineA and lineA.label)
               or (lineB and lineB.label)
               or aText:match("^([^:]+)%s*:")
               or key

    local delta, deltaStr
    local na, nb = tonumber(aVal), tonumber(bVal)
    if na and nb then
      delta = nb - na
      if     delta > 0 then deltaStr = "+" .. fmtNum(delta)
      elseif delta < 0 then deltaStr =        fmtNum(delta)
      else                  deltaStr = "=" end
    end

    local hib
    if    HIGHER_IS_BETTER[key] then hib = true
    elseif LOWER_IS_BETTER[key] then hib = false end

    local order = (lineA and lineA._order) or (lineB and lineB._order) or 9999
    table.insert(results, {
      key=key, label=label,
      aVal=aVal, bVal=bVal, aText=aText, bText=bText,
      delta=delta, deltaStr=deltaStr, higherIsBetter=hib,
      _order=order,
    })
  end

  if examA and examA.byKey then
    for key, lineA in pairs(examA.byKey) do
      seen[key] = true
      addRow(key, lineA, examB and examB.byKey and examB.byKey[key])
    end
  end
  if examB and examB.byKey then
    for key, lineB in pairs(examB.byKey) do
      if not seen[key] then
        addRow(key, nil, lineB)
      end
    end
  end

  table.sort(results, function(a, b) return a._order < b._order end)
  return results
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
function ItemExamine:BuildImguiFromManifest(itemData, category)
  local manifest  = require("property_manifest")
  local allForCat = manifest.forCategory(category)
  self.presentProps = {}
  self.absentProps  = {}
  for _, entry in ipairs(allForCat) do
    local has, val = self:probeEntry(entry, itemData)
    if has then
      table.insert(self.presentProps, { entry=entry, value=val })
    else
      table.insert(self.absentProps, entry)
    end
  end
end

function ItemExamine:probeEntry(entry, itemData)
  if     entry.propType == "IntValue"    then return InqInt(itemData, entry.propId)
  elseif entry.propType == "FloatValue"  then return InqFloat(itemData, entry.propId)
  elseif entry.propType == "BoolValue"   then return InqBool(itemData, entry.propId)
  elseif entry.propType == "StringValue" then return InqString(itemData, entry.propId)
  elseif entry.propType == "Int64Value"  then return InqInt64(itemData, entry.propId)
  elseif entry.propType == "HasSpell"    then
    local hasSpells = itemData.spells and itemData.spells ~= ""
    return hasSpells, itemData.spells or ""
  end
  return false, nil
end

local function format_int(number)
  local n = math.floor(tonumber(number) or 0)
  local negative = n < 0
  local s = tostring(math.abs(n))
  local result, len = "", #s
  for i = 1, len do
    if i > 1 and (len - i + 1) % 3 == 0 then result = result .. "," end
    result = result .. s:sub(i, i)
  end
  return (negative and "-" or "") .. result
end

----------------------------------------------------------------------
-- Appraisal methods
----------------------------------------------------------------------

function ItemExamine:ShowName()
  local materialString = ""
  local okM, material = InqInt(self.item, IntId.MaterialType)
  if okM then materialString = StringToMaterialType[material] .. " " end

  local stackSizeStr = ""
  local okS, stackSize = InqInt(self.item, IntId.StackSize)
  if stackSize > 1 then stackSizeStr = tostring(stackSize) .. " " end

  local okN, name = InqString(self.item, StringId.Name)
  if okN then
    self:Add(stackSizeStr .. materialString .. name .. (stackSize>1 and "s" or ""), "", {centered=true, underline=true})
  end
end

function ItemExamine:ShowValueInfo()
  local ok, val = InqInt(self.item, IntId.Value)
  if ok then
    self:Add("Value: " .. format_int(val), nil, nil, val, "Value")
  else
    self:Add("Value: ???", nil, nil, nil, "Value")
  end
end

function ItemExamine:ShowBurdenInfo()
  local ok, val = InqInt(self.item, IntId.EncumbranceVal)
  if ok then
    self:Add("Burden: " .. format_int(val), nil, nil, val, "Burden")
  else
    self:Add("Burden: Unknown")
  end
end

function ItemExamine:ShowSalvageCount()
  local okN, num = InqInt(self.item, IntId.NumItemsInMaterial)
  if okN then
    self:Add("Salvaged from " .. num .. " items.", nil, nil, num)
    self:Add("")
  end
end

function ItemExamine:ShowWorkmanship()
  local workmanship = ""
  local ok, val = InqInt(self.item, IntId.ItemWorkmanship)
  if ok and val then
    local okN, num = InqInt(self.item, IntId.NumItemsInMaterial)
    if okN then val = val / num end
    if     val >= 10 then workmanship = "Workmanship: Priceless"
    elseif val >= 9  then workmanship = "Workmanship: Incomparable"
    elseif val >= 8  then workmanship = "Workmanship: Utterly flawless"
    elseif val >= 7  then workmanship = "Workmanship: Flawless"
    elseif val >= 6  then workmanship = "Workmanship: Nearly flawless"
    elseif val >= 5  then workmanship = "Workmanship: Magnificent"
    elseif val >= 4  then workmanship = "Workmanship: Exquisitely crafted"
    elseif val >= 3  then workmanship = "Workmanship: Finely crafted"
    elseif val >= 2  then workmanship = "Workmanship: Well-crafted"
    elseif val >= 1  then workmanship = "Workmanship: Poorly crafted" end
    if okN then
      workmanship = workmanship .. string.format(" (%.2f)", val)
    else
      workmanship = workmanship .. string.format(" (%d)", val)
    end
    self:Add(workmanship, nil, nil, val, "Workmanship")
  end
  self:Add("")
end

function ItemExamine:ShowTinkeringInfo()
  local okT, cTinkers = InqInt(self.item, IntId.NumTimesTinkered)
  if okT then
    local plural = (cTinkers > 1) and "s" or ""
    self:Add(string.format("This item has been tinkered %d time%s.", cTinkers, plural), nil, nil, cTinkers, "Tinkers")
  end
  local okTk, tinkerer = InqString(self.item, StringId.TinkerName)
  if okTk and tinkerer ~= "" then
    self:Add("Last tinkered by " .. tinkerer .. ".", nil, nil, tinkerer)
  end
  local okImb, imbuer = InqString(self.item, StringId.ImbuerName)
  if okImb and imbuer ~= "" then
    self:Add("Imbued by " .. imbuer .. ".", nil, nil, imbuer)
  end
end

function ItemExamine:ShowSet()
  local ok, setBonus = InqInt(self.item, IntId.EquipmentSetId)
  if not ok then return false end
  local setName = SetNames[setBonus]
  if setName and setName ~= "" then
    self:Add("Set: " .. setName, nil, nil, setName, "Set")
    return true
  end
  return false
end

function ItemExamine:ShowRatings()
  local _, damage_rating        = InqInt(self.item, IntId.GearDamage)
  local _, damage_resist_rating = InqInt(self.item, IntId.GearDamageResist)
  local _, crit_rating          = InqInt(self.item, IntId.GearCrit)
  local _, crit_damage_rating   = InqInt(self.item, IntId.GearCritDamage)
  local _, crit_resist_rating   = InqInt(self.item, IntId.GearCritResist)
  local _, crit_dmg_resist      = InqInt(self.item, IntId.GearCritDamageResist)
  local _, healing_boost_rating = InqInt(self.item, IntId.GearHealingBoost)
  local _, nether_resist_rating = InqInt(self.item, IntId.GearNetherResist)
  local _, life_resist_rating   = InqInt(self.item, IntId.GearLifeResist)
  local _, gear_max_health      = InqInt(self.item, IntId.GearMaxHealth)

  local parts = {}
  if damage_rating        > 0 then table.insert(parts, "Dam "          .. damage_rating)        end
  if damage_resist_rating > 0 then table.insert(parts, "Dam Resist "   .. damage_resist_rating) end
  if crit_rating          > 0 then table.insert(parts, "Crit "         .. crit_rating)          end
  if crit_damage_rating   > 0 then table.insert(parts, "Crit Dam "     .. crit_damage_rating)   end
  if crit_resist_rating   > 0 then table.insert(parts, "Crit Resist "  .. crit_resist_rating)   end
  if crit_dmg_resist      > 0 then table.insert(parts, "Crit Dam Resist " .. crit_dmg_resist)   end
  if healing_boost_rating > 0 then table.insert(parts, "Heal Boost "   .. healing_boost_rating) end
  if nether_resist_rating > 0 then table.insert(parts, "Nether Resist " .. nether_resist_rating) end
  if life_resist_rating   > 0 then table.insert(parts, "Life Resist "  .. life_resist_rating)   end

  -- Direct byKey writes for ratings — never touch self.lines so invisible in text mode
  local function ratingKey(labelStr, val, key)
    if val > 0 then
      self.byKey[key] = { text="", label=labelStr, propVal=val, propKey=key, mods={}, _order=self._keyOrder or 0 }
      self._keyOrder  = (self._keyOrder or 0) + 1
    end
  end
  ratingKey("Dam",             damage_rating,        "Rating_Damage")
  ratingKey("Dam Resist",      damage_resist_rating, "Rating_DamageResist")
  ratingKey("Crit",            crit_rating,          "Rating_Crit")
  ratingKey("Crit Dam",        crit_damage_rating,   "Rating_CritDamage")
  ratingKey("Crit Resist",     crit_resist_rating,   "Rating_CritResist")
  ratingKey("Crit Dam Resist", crit_dmg_resist,      "Rating_CritDamageResist")
  ratingKey("Heal Boost",      healing_boost_rating, "Rating_HealBoost")
  ratingKey("Nether Resist",   nether_resist_rating, "Rating_NetherResist")
  ratingKey("Life Resist",     life_resist_rating,   "Rating_LifeResist")

  local hadOutput = false
  if #parts > 0 then
    self:Add("Ratings: " .. table.concat(parts, ", ") .. ".")
    hadOutput = true
  end
  if gear_max_health > 0 then
    self:Add("This item adds " .. gear_max_health .. " Vitality.", nil, nil, gear_max_health, "Rating_MaxHealth")
    hadOutput = true
  end
  if hadOutput then self:Add("") end
  return hadOutput
end

local function damageMaskToString(dmgTypeMask)
  local dest = ", "
  local DamageTypes = {
    [1]="Slashing",[2]="Piercing",[4]="Bludgeoning",[8]="Cold",[16]="Fire",
    [32]="Acid",[64]="Electric",[128]="Health",[256]="Stamina",[512]="Mana",
    [1024]="Nether",[2048]="Base",[268435456]="Prismatic"
  }
  for maskIndex, typeString in pairs(DamageTypes) do
    if dmgTypeMask == maskIndex then
      return ", " .. typeString
    elseif bit.band(dmgTypeMask, maskIndex) > 0 then
      dest = dest .. (#dest>2 and "/" or "") .. typeString
    end
  end
  return dest
end

function ItemExamine:ShowWeaponAndArmorData()
  local _, valid_locations = InqInt(self.item, IntId.ValidLocations)
  local _, ammoType        = InqInt(self.item, IntId.AmmoType)

  local IsWeaponSlot = bit.band(valid_locations, 0x3F00000) > 0
  local missileSlot  = bit.band(valid_locations, 0x400000) > 0
  local IsMissile    = missileSlot and ammoType > 0

  if IsWeaponSlot then
    if bit.band(valid_locations, 0x200000) > 0 then
      local ok, shieldLevel = InqInt(self.item, IntId.ShieldValue)
      if ok then
        self:Add("Base Shield Level: " .. format_int(shieldLevel), nil, nil, shieldLevel, "ShieldLevel")
      else
        self:Add("Shield Level: Unknown")
      end
    end

    local _, itemType = InqInt(self.item, IntId.ObjectType)
    if itemType == 1 or itemType == 256 or itemType == 257 or itemType == 32768 or itemType == 0x8101 then
      local okW, weaponSkillId = InqInt(self.item, IntId.WeaponSkill)
      if okW then
        local rhs = ""
        local okOld, oldSkill = InqInt(self.item, IntId.WeaponType)
        if okOld then
          local map = {
            [1]=" (Unarmed Weapon)",[2]=" (Sword)",[3]=" (Axe)",[4]=" (Mace)",[5]=" (Spear)",
            [6]=" (Dagger)",[7]=" (Staff)",[8]=" (Bow)",[9]=" (Crossbow)",[10]=" (Thrown)"
          }
          rhs = map[oldSkill] or ""
        end
        if weaponSkillId ~= 0 then
          self:Add("Skill: " .. tostring(weaponSkillId + SkillId.Undef):gsub("(%l)(%u)", "%1 %2") .. rhs)
        end
      end

      -- Damage
      local damageTxt = IsMissile and "Damage Bonus: " or "Damage: "
      local _, damageType = InqInt(self.item, IntId.DamageType)
      local okDmg, weaponDamage = InqInt(self.item, IntId.Damage)
      if okDmg then
        if weaponDamage < 0 then
          self:Add(damageTxt .. "Unknown")
        else
          local dest = ""
          if not IsMissile then
            if weaponDamage > 0 then dest = damageMaskToString(damageType) end
            if dest == "" then dest = ", unknown type" end
          end
          local _, damageVariance = InqFloat(self.item, FloatId.DamageVariance)
          local rhs = (1.0 - damageVariance) * weaponDamage
          local ability_txt
          if (weaponDamage - rhs) > 0.0002 then
            if rhs >= 10.0 then
              ability_txt = string.format("%s%.4g - %d%s", damageTxt, rhs, weaponDamage, dest)
            else
              ability_txt = string.format("%s%.3g - %d%s", damageTxt, rhs, weaponDamage, dest)
            end
          else
            ability_txt = string.format("%s%d%s", damageTxt, weaponDamage, dest)
          end
          local dmgColor = bit.band(self.item.IntValues["WeapHighlight"] or 0, WeaponHighlightMask.Damage.ToNumber()) > 0
            and (bit.band(self.item.IntValues["WeapColor"] or 0, WeaponHighlightMask.Damage.ToNumber()) > 0 and imguiGreen or imguiRed)
            or nil
          self:Add(ability_txt, dmgColor, nil, weaponDamage, "Damage")
          if damageVariance and damageVariance ~= 0 then
            self.byKey["DamageVariance"] = { text="", label="LowEnd(Variance)", propVal=rhs, propKey="DamageVariance", mods={}, _order=self._keyOrder or 0 }
            self._keyOrder = (self._keyOrder or 0) + 1
          end          
        end
      end

      local _, elemBonus = InqInt(self.item, IntId.ElementalDamageBonus)
      if elemBonus > 0 then
        self:Add(string.format("Elemental Damage Bonus: %d%s.", elemBonus, damageMaskToString(damageType)),
          nil, nil, elemBonus, "ElementalDamageBonus")
      end

      if IsMissile then
        local okMod, damageMod = InqFloat(self.item, FloatId.DamageMod)
        if okMod then
          local dmgModColor = bit.band(self.item.IntValues["WeapHighlight"] or 0, WeaponHighlightMask.DamageMod.ToNumber()) > 0
            and (bit.band(self.item.IntValues["WeapColor"] or 0, WeaponHighlightMask.DamageMod.ToNumber()) > 0 and imguiGreen or imguiRed)
            or nil
          self:Add("Damage Modifier: +" .. ModifierToString(damageMod) .. "%%.", dmgModColor, nil, damageMod, "DamageMod")
        end
      end

      -- Speed and range
      if bit.band(valid_locations, 0x2500000) > 0 then
        local _, weapTime = InqInt(self.item, "WeaponTime")
        if weapTime < 0 then
          self:Add("Speed:  Unknown")
          if IsMissile then self:Add("Range:  Unknown") end
        else
          local speedColor = bit.band(self.item.IntValues["WeapHighlight"] or 0, WeaponHighlightMask.Speed.ToNumber()) > 0
            and (bit.band(self.item.IntValues["WeapColor"] or 0, WeaponHighlightMask.Speed.ToNumber()) > 0 and imguiGreen or imguiRed)
            or nil
          self:Add("Speed: " .. WeaponTimeToString(weapTime) .. " (" .. weapTime .. ")", speedColor, nil, weapTime, "WeaponSpeed")
          if IsMissile then
            local _, maxVel = InqFloat(self.item, FloatId.MaximumVelocity)
            local fRange = (maxVel * maxVel) * 0.1020408163265306 * 1.094
            if fRange > 85 then fRange = 85 end
            local range
            if fRange >= 10 then range = fRange - (fRange % 5) else range = fRange end
            self:Add(string.format("Range: %d yds.", math.floor(range + 0.5)))
          end
        end
      end
    end

    local weaponOff = self.item.FloatValues["WeaponOffense"]
    if weaponOff ~= nil and weaponOff ~= 1.0 then
      local bonus = (weaponOff - 1.0) * 100.0
      local sign  = bonus < 0 and "-" or "+"
      local offColor = bit.band(self.item.IntValues["WeapHighlight"] or 0, WeaponHighlightMask.AttackSkill.ToNumber()) > 0
        and (bit.band(self.item.IntValues["WeapColor"] or 0, WeaponHighlightMask.AttackSkill.ToNumber()) > 0 and imguiGreen or imguiRed)
        or nil
      self:Add(string.format("Bonus to Attack Skill: %s%.0f%%%%.", sign, math.abs(bonus)), offColor, nil, weaponOff, "WeaponOffenseBonus")
    end

    -- Ammo text
    if bit.band(valid_locations, 0x400000) > 0 then
      if     ammoType == 1 then self:Add("Uses arrows as ammunition.")
      elseif ammoType == 2 then self:Add("Uses quarrels as ammunition.")
      elseif ammoType == 4 then self:Add("Uses atlatl darts as ammunition.") end
    else
      if     ammoType == 1 then self:Add("Used as ammunition by bows.")
      elseif ammoType == 2 then self:Add("Used as ammunition by crossbows.")
      elseif ammoType == 4 then self:Add("Uses atlatl darts as atlatls.") end
    end
  end

  local _, priority = InqInt(self.item, IntId.ClothingPriority)
  if bit.band(valid_locations, 0x8007FFF) > 0 and priority > 0 then
    local coverage = ClothingPriorityToString(priority)
    if coverage ~= "" then self:Add(coverage) end
  end
end

function ItemExamine:ShowDefenseModData()
  local ok, v = InqFloat(self.item, FloatId.WeaponDefense)
  if ok and v ~= 1.0 then
    local c = bit.band(self.item.IntValues["WeapHighlight"] or 0, WeaponHighlightMask.MeleeDefense.ToNumber()) > 0
      and (bit.band(self.item.IntValues["WeapColor"] or 0, WeaponHighlightMask.MeleeDefense.ToNumber()) > 0 and imguiGreen or imguiRed)
      or nil
    self:Add("Bonus to Melee Defense: +" .. SmallModifierToString(v) .. "%%.", c, nil, v, "MeleeDefenseBonus")
  end
  ok, v = InqFloat(self.item, FloatId.WeaponMissileDefense)
  if ok and v ~= 1.0 then
    self:Add("Bonus to Missile Defense: +" .. SmallModifierToString(v) .. "%%.", nil, nil, v, "MissileDefenseBonus")
  end
  ok, v = InqFloat(self.item, FloatId.WeaponMagicDefense)
  if ok and v ~= 1.0 then
    self:Add("Bonus to Magic Defense: +" .. SmallModifierToString(v) .. "%%.", nil, nil, v, "MagicDefenseBonus")
  end
end

function ItemExamine:ShowArmorMods()
  local okType, itemType = InqInt(self.item, IntId.ObjectType)
  local okAL, armorLevel = InqInt(self.item, IntId.ArmorLevel)
  if okType and okAL and armorLevel > 0 then
    self:Add("")
    local alColor = bit.band(self.item.IntValues["ProtHighlight"] or 0, ArmorHighlightMask.ArmorLevel.ToNumber()) > 0
      and (bit.band(self.item.IntValues["ProtHighlight"] or 0, ArmorHighlightMask.ArmorLevel.ToNumber()) > 0 and imguiGreen or imguiRed)
      or nil
    self:Add("Armor Level: " .. armorLevel, alColor, nil, armorLevel, "ArmorLevel")

    -- Resist key map: dtype int → propKey string
    local resistKeys = {
      [1]="Resist_Slash", [2]="Resist_Pierce",   [4]="Resist_Bludgeon",
      [8]="Resist_Cold",  [16]="Resist_Fire",     [32]="Resist_Acid",
      [64]="Resist_Electric", [1024]="Resist_Nether",
    }
    local resistProps = {
      {key="ArmorModVsSlash",    dmg=1},
      {key="ArmorModVsPierce",   dmg=2},
      {key="ArmorModVsBludgeon", dmg=4},
      {key="ArmorModVsCold",     dmg=8},
      {key="ArmorModVsFire",     dmg=16},
      {key="ArmorModVsAcid",     dmg=32},
      {key="ArmorModVsElectric", dmg=64},
      {key="ArmorModVsNether",   dmg=1024},
    }
    for _, rp in ipairs(resistProps) do
      local mod = self.item.FloatValues[rp.key]
      if mod then
        local line = DamageResistanceToString(rp.dmg, armorLevel, mod)
        if line ~= "" then
          local rc = bit.band(self.item.IntValues["ProtHighlight"] or 0, bit.lshift(rp.dmg, 1)) > 0
            and (bit.band(self.item.IntValues["ProtHighlight"] or 0, bit.lshift(rp.dmg, 1)) > 0 and imguiGreen or imguiRed)
            or nil
          self:Add(line, rc, nil, mod, resistKeys[rp.dmg])
        end
      end
    end
  end
end

function ItemExamine:ShowShortMagicInfo()
  local hasSpells = self.item.spells ~= nil and self.item.spells ~= ""
  if hasSpells then
    self:Add("")
    self:Add("Spells: " .. self.item.spells, nil, nil, self.item.spells, "Spells")
  end
end

function ItemExamine:ShowSpecialProperties()
  self:Add("")
  local okU, iUnique = InqInt(self.item, IntId.Unique)
  if okU then self:Add("You can only carry " .. iUnique .. " of these items.") end

  local okC, cooldown = InqFloat(self.item, FloatId.CooldownDuration)
  if okC then self:Add("Cooldown When Used: " .. DeltaTimeToString(cooldown)) end

  local okCl, cleaving = InqInt(self.item, IntId.Cleaving)
  if okCl then
    self:Add(string.format("Cleave: %d enemies in front arc.", cleaving))
    self:Add("")
  end

  local props = {}
  local okCT, creatureType = InqInt(self.item, IntId.SlayerCreatureType)
  if okCT then
    if creatureType == 31 then
      table.insert(props, "Bael'Zharon's Hate")
    else
      table.insert(props, InqCreatureDisplayName(creatureType) .. " slayer")
    end
  end

  local okAtk, attackType = InqInt(self.item, IntId.AttackType)
  if okAtk and bit.band(attackType, 0x79E0) > 0 then table.insert(props, "Multi-Strike") end

  local imbuedCheck = 0
  local function orInt(id)
    local ok, v = InqInt(self.item, id)
    if ok then imbuedCheck = bit.bor(imbuedCheck, v) end
  end
  orInt(IntId.ImbuedEffect); orInt(IntId.ImbuedEffect2); orInt(IntId.ImbuedEffect3)
  orInt(IntId.ImbuedEffect4); orInt(IntId.ImbuedEffect5)

  if imbuedCheck > 0 then
    if bit.band(imbuedCheck, 1)      > 0 then table.insert(props, "Critical Strike") end
    if bit.band(imbuedCheck, 2)      > 0 then table.insert(props, "Crippling Blow") end
    if bit.band(imbuedCheck, 4)      > 0 then table.insert(props, "Armor Rending") end
    if bit.band(imbuedCheck, 8)      > 0 then table.insert(props, "Slash Rending") end
    if bit.band(imbuedCheck, 0x10)   > 0 then table.insert(props, "Pierce Rending") end
    if bit.band(imbuedCheck, 0x20)   > 0 then table.insert(props, "Bludgeon Rending") end
    if bit.band(imbuedCheck, 0x40)   > 0 then table.insert(props, "Acid Rending") end
    if bit.band(imbuedCheck, 0x4000) > 0 then table.insert(props, "Nether Rending") end
    if bit.band(imbuedCheck, 0x80)   > 0 then table.insert(props, "Cold Rending") end
    if bit.band(imbuedCheck, 0x100)  > 0 then table.insert(props, "Lightning Rending") end
    if bit.band(imbuedCheck, 0x200)  > 0 then table.insert(props, "Fire Rending") end
    if bit.band(imbuedCheck, 0x400)  > 0 then table.insert(props, "+1 Melee Defense") end
    if bit.band(imbuedCheck, 0x800)  > 0 then table.insert(props, "+1 Missile Defense") end
    if bit.band(imbuedCheck, 0x1000) > 0 then table.insert(props, "+1 Magic Defense") end
  end

  local okAbs, _ = InqFloat(self.item, FloatId.AbsorbMagicDamage)
  if okAbs then table.insert(props, "Magic Absorbing") end

  local okMR, magicResist = InqInt(self.item, IntId.ResistMagic)
  if okMR and magicResist >= 9999 then table.insert(props, "Unenchantable") end

  local okAtt, attuned = InqInt(self.item, IntId.Attuned)
  if okAtt and attuned > 0 and attuned < 2 then table.insert(props, "Attuned") end

  local okBond, bonded = InqInt(self.item, IntId.Bonded)
  if okBond then
    if     bonded == -2 then table.insert(props, "Destroyed on Death")
    elseif bonded == -1 then table.insert(props, "Dropped on Death")
    elseif bonded == 1  then table.insert(props, "Bonded") end
  end

  local okRet, retained = InqBool(self.item, BoolId.Retained)
  if okRet and retained then table.insert(props, "Retained") end

  local okCrit, _ = InqFloat(self.item, FloatId.CriticalMultiplier)
  if okCrit then table.insert(props, "Crushing Blow") end
  okCrit, _ = InqFloat(self.item, FloatId.CriticalFrequency)
  if okCrit then table.insert(props, "Biting Strike") end
  okCrit, _ = InqFloat(self.item, FloatId.IgnoreArmor)
  if okCrit then table.insert(props, "Armor Cleaving") end

  local okRes, _ = InqFloat(self.item, FloatId.ResistanceModifier)
  local okDT, damageType = InqInt(self.item, IntId.DamageType)
  if okRes and okDT then table.insert(props, "Resistance Cleaving: " .. tostring(damageType)) end

  local okSpell, _ = InqDataID(self.item, DataId.ProcSpell)
  if okSpell then table.insert(props, "Cast on Strike") end
  local okIvory, ivoryable = InqBool(self.item, BoolId.Ivoryable)
  if okIvory and ivoryable then table.insert(props, "Ivoryable") end
  local okDye, dyeable = InqBool(self.item, BoolId.Dyable)
  if okDye and dyeable then table.insert(props, "Dyeable") end

  if #props > 0 then self:Add("Properties: " .. table.concat(props, ", ")) end
  if imbuedCheck ~= 0 then self:Add("This item cannot be further imbued.") end
  self:Add("")

  local okAuto, autoLeft = InqBool(self.item, BoolId.AutowieldLeft)
  if okAuto and autoLeft then
    self:Add("This item is tethered to the left side.")
    self:Add("")
  end
end

function ItemExamine:ShowUsage()
  local ok, strUsage = InqString(self.item, StringId.Use)
  if ok and strUsage ~= "" then self:AddLines(strUsage) end
end

function ItemExamine:ShowLevelLimitInfo()
  local _, minL = InqInt(self.item, IntId.MinLevel)
  local _, maxL = InqInt(self.item, IntId.MaxLevel)
  if minL > 0 or maxL > 0 then
    local txt
    if     maxL <= 0          then txt = string.format("Restricted to characters of Level %d or greater.", minL)
    elseif minL <= 0          then txt = string.format("Restricted to characters of Level %d or below.", maxL)
    elseif maxL == minL       then txt = string.format("Restricted to characters of Level %d.", minL)
    else txt = string.format("Restricted to characters of Levels %d to %d.", minL, maxL) end
    self:Add(txt)
  end
  local ok, portalDest = InqString(self.item, StringId.AppraisalPortalDestination)
  if ok and portalDest ~= "" then self:Add("Destination: " .. portalDest) end
end

function ItemExamine:ShowWieldRequirements()
  local ok, hasAllowed = InqBool(self.item, BoolId.AppraisalHasAllowedWielder)
  if ok and hasAllowed then
    local _, owner = InqString(self.item, StringId.CraftsmanName)
    if owner == "" then owner = "the original owner" end
    self:Add("Wield requires " .. owner)
  end

  local okAcct, acctReq = InqInt(self.item, IntId.AccountRequirements)
  if okAcct and acctReq > 0 then self:Add("Use requires Throne of Destiny.") end

  local okHer, heritage = InqInt(self.item, IntId.HeritageGroup)
  if okHer then
    local okHG, hg = InqHeritageGroupDisplayName(heritage)
    if okHG and hg ~= "" then self:Add("Wield requires " .. hg) end
  end

  local function helper(iReq, iSkill, iDiff)
    local strSkill = GetAppraisalStringFromRequirements(iReq, iSkill, iDiff)
    local txt = ""
    if iReq == 8 then
      if iDiff ~= 3 then txt = "Wield requires trained "      .. strSkill:gsub("(%l)(%u)", "%1 %2")
      else               txt = "Wield requires specialized "  .. strSkill:gsub("(%l)(%u)", "%1 %2") end
    elseif iReq == 0xB then txt = "Wield requires " .. strSkill:gsub("(%l)(%u)", "%1 %2") .. " type"
    elseif iReq == 0xC then txt = "Wield requires " .. strSkill:gsub("(%l)(%u)", "%1 %2") .. " race"
    else txt = string.format("Wield requires %s %d", strSkill:gsub("(%l)(%u)", "%1 %2"), iDiff) end
    if txt ~= "" then self:Add(txt) end
  end

  local wieldSets = {
    { IntId.WieldRequirements,  IntId.WieldSkilltype,  IntId.WieldDifficulty  },
    { IntId.WieldRequirements2, IntId.WieldSkilltype2, IntId.WieldDifficulty2 },
    { IntId.WieldRequirements3, IntId.WieldSkilltype3, IntId.WieldDifficulty3 },
    { IntId.WieldRequirements4, IntId.WieldSkilltype4, IntId.WieldDifficulty4 },
  }
  local fallbackIds = { {0x10E,0x10F,0x110},{0x111,0x112,0x113},{0x114,0x115,0x116} }

  for _, ws in ipairs(wieldSets) do
    local okR, r = InqInt(self.item, ws[1])
    local okS, s = InqInt(self.item, ws[2])
    local okD, d = InqInt(self.item, ws[3])
    if okR and okS and okD then
      helper(r, s, d)
    else
      for _, t in ipairs(fallbackIds) do
        local okRf, rf = InqInt(self.item, t[1])
        local okSf, sf = InqInt(self.item, t[2])
        local okDf, df = InqInt(self.item, t[3])
        if okRf and okSf and okDf then helper(rf, sf, df) end
      end
    end
  end
end

function ItemExamine:ShowUsageLimitInfo()
  local ok, levelReq = InqInt(self.item, IntId.UseRequiresLevel)
  if ok and levelReq > 0 then
    self:Add("")
    self:Add("Use requires level " .. levelReq .. ".")
  end

  local okSkill, skill = InqInt(self.item, IntId.UseRequiresSkillLevel)
  local okLvl, level   = InqInt(self.item, IntId.UseLevelRequirement)
  local skillAdded     = false
  if okSkill and skill > 0 and okLvl and level > 0 then
    local skillStr = InqSkillName(skill)
    if skillStr == "" then skillStr = "Unknown Skill" end
    self:Add("")
    self:Add(string.format("Use requires %s of at least %d.", skillStr:gsub("(%l)(%u)", "%1 %2"), level))
    skillAdded = true
  end

  local okS2, skill2 = InqInt(self.item, IntId.UseRequiresSkill)
  if okS2 and skill2 > 0 then
    local skillStr = InqSkillName(skill2)
    if skillStr == "" then skillStr = "Unknown Skill" end
    if not skillAdded then self:Add("") end
    self:Add("Use requires specialized " .. skillStr:gsub("(%l)(%u)", "%1 %2") .. ".")
  end
end

function ItemExamine:ShowItemLevelInfo()
  local okBase, baseXp  = InqInt64(self.item, Int64Id.ItemBaseXp)
  local okMax, maxLevel = InqInt(self.item, IntId.ItemMaxLevel)
  local okStyle, xpStyle= InqInt(self.item, IntId.ItemXpStyle)
  if okBase and baseXp > 0 and okMax and maxLevel > 0 and okStyle then
    local _, itemXp = InqInt64(self.item, Int64Id.ItemTotalXp)
    local level     = ItemTotalXPToLevel(itemXp, baseXp, maxLevel, xpStyle)
    local nextLevel = math.min(level + 1, maxLevel)
    local nextXp    = ItemLevelToTotalXP(nextLevel, baseXp, maxLevel, xpStyle)
    self:Add(string.format("Item Level: %d / %d", level, maxLevel), nil, nil, level, "ItemLevel")
    self:Add("Item XP: " .. format_int(itemXp) .. "/" .. format_int(nextXp))
    self:Add("")
    self:Add("")
  end

  local okCloak, cloakProc = InqInt(self.item, IntId.CloakWeaveProc)
  if okCloak and cloakProc == 2 then
    self:Add("This cloak has a chance to reduce an incoming attack by 200 damage.")
  end
end

function ItemExamine:ShowActivationRequirements()
  local parts = {}

  local okDiff, diff = InqInt(self.item, IntId.ItemDifficulty)
  if okDiff and diff > 0 then table.insert(parts, "Arcane Lore " .. diff) end

  local okRank, rank = InqInt(self.item, IntId.AllegianceRank)
  if okRank and rank >= 1 then table.insert(parts, "Allegiance Rank " .. rank) end

  local okHer, heritage = InqInt(self.item, IntId.HeritageGroup)
  if okHer then
    local okHG, hg = InqHeritageGroupDisplayName(heritage)
    if okHG then table.insert(parts, hg) end
  end

  local okSkillLim, skillLimit = InqInt(self.item, IntId.ItemSkillLevelLimit)
  local okAttr2, attr2         = InqInt(self.item, IntId.AppraisalItemSkill)
  if okSkillLim and skillLimit > 0 and okAttr2 then
    local name = InqSkillName(attr2)
    if name ~= "" then table.insert(parts, name:gsub("(%l)(%u)", "%1 %2") .. " " .. skillLimit) end
  end

  local okAttrLim, attrLimit = InqInt(self.item, IntId.ItemAttributeLimit)
  local okAttrId, attrId     = InqInt(self.item, IntId.WieldSkilltype)
  if okAttrLim and attrLimit > 0 and okAttrId then
    local name = InqAttributeName(attrId)
    if name ~= "" then table.insert(parts, name:gsub("(%l)(%u)", "%1 %2") .. " " .. attrLimit) end
  end

  local okAttr2Lim, attr2Lim = InqInt(self.item, IntId.ItemAttribute2ndLevelLimit)
  local okAttr2Id, attr2Id   = InqInt(self.item, IntId.WieldSkilltype2)
  if okAttr2Lim and attr2Lim > 0 and okAttr2Id then
    local name = InqAttribute2ndName(attr2Id)
    if name ~= "" then table.insert(parts, name:gsub("(%l)(%u)", "%1 %2") .. " " .. attr2Lim) end
  end

  if #parts > 0 then self:Add("Activation requires " .. table.concat(parts, ", ")) end
end

function ItemExamine:ShowCasterData()
  local ok, manaC = InqFloat(self.item, FloatId.ManaConversionMod)
  if ok and manaC ~= 0 then
    self:Add("Bonus to Mana Conversion: +" .. ModifierToString(manaC + 1.0) .. "%%.", nil, nil, manaC, "ManaConversionBonus")
  end

  local okE, elePvM = InqFloat(self.item, FloatId.ElementalDamageMod)
  if okE then
    local okDT, dmgType = InqInt(self.item, IntId.DamageType)
    if okDT then
      local elemName = ({
        [1]="Slashing",[2]="Piercing",[4]="Bludgeoning",[8]="Cold",
        [16]="Fire",[32]="Acid",[64]="Electric",[128]="Health",
        [256]="Stamina",[512]="Mana",[1024]="Nether",[2048]="Base"
      })[dmgType]
      local elePvP  = GetElementalModPKModifier(elePvM)
      self:Add("Damage bonus for " .. elemName .. " spells:")
      self:Add(" vs. Monsters: +" .. SmallModifierToString(elePvM) .. "%%.", nil, nil, elePvM, "ElemDamagePvM")
      self:Add(" vs. Players: +"  .. SmallModifierToString(elePvP) .. "%%.")
      self:Add("")
    end
  end
end

function ItemExamine:ShowBoostValue()
  local okB, boostAmount = InqInt(self.item, IntId.HealingBoostRating)
  local okA, attrib      = InqInt(self.item, IntId.BoosterEnum)
  if not okB or boostAmount == 0 or not okA then return end

  local function line(stat)
    if boostAmount < 0 then return string.format("Depletes %d %s when used.", boostAmount, stat)
    else                    return string.format("Restores %d %s when used.", boostAmount, stat) end
  end

  if     attrib == 2 then self:Add(line("Health"))
  elseif attrib == 4 then self:Add(line("Stamina"))
  elseif attrib == 6 then self:Add(line("Mana")) end
end

function ItemExamine:ShowHealKitValues()
  local okB, boost = InqInt(self.item, IntId.BoostValue)
  if okB and boost ~= 0 then self:Add("Bonus to Healing Skill: " .. boost) end
  local okM, mod = InqFloat(self.item, FloatId.HealkitMod)
  if okM then self:Add(string.format("Restoration Bonus: %.0f", mod * 100)) end
end

function ItemExamine:ShowCapacity()
  -- fill if needed
end

function ItemExamine:ShowLockAppraiseInfo()
  local okL, locked = InqBool(self.item, BoolId.Locked)
  local okR, resist = InqInt(self.item, IntId.ResistLockpick)
  if okL then
    if locked then
      self:Add("Locked")
      if okR and resist ~= 0 then
        local txt = pseudo_LockpickSuccessPercentToString(resist)
        self:Add(string.format("The lock looks %s to pick (Resistance %d).", txt, resist))
      end
    else
      self:Add("Unlocked")
    end
  elseif okR and resist ~= 0 then
    if resist > 0 then self:Add(string.format("Bonus to Lockpick Skill: +%d", resist))
    else               self:Add(string.format("Bonus to Lockpick Skill: %d",  resist)) end
  end
end

function ItemExamine:ShowManaStoneInfo()
  local okM, curMana    = InqInt(self.item, IntId.ItemCurMana)
  local okO, objectType = InqInt(self.item, IntId.ObjectType)
  if objectType == ObjectType.ManaStone and okM then
    self:Add("Stored Mana: " .. curMana)
  end
  local okE, eff = InqFloat(self.item, FloatId.ItemEfficiency)
  if okE then self:Add(string.format("Efficiency: %.0f%%%%", eff * 100)) end
  local okD, chance = InqFloat(self.item, FloatId.ManaStoneDestroyChance)
  if okD then self:Add(string.format("Chance of Destruction: %.0f%%%%", chance * 100)) end
end

function ItemExamine:ShowRemainingUses()
  local okK, keys = InqInt(self.item, IntId.NumKeys)
  if okK then
    if keys == 1 then self:Add("Contains 1 key.")
    else              self:Add(string.format("Contains %d keys.", keys)) end
  end
  local okU, unlimited = InqBool(self.item, BoolId.UnlimitedUse)
  if okU and unlimited then
    self:Add("Number of uses remaining: Unlimited")
  else
    local okS, uses = InqInt(self.item, IntId.Structure)
    if okS then self:Add("Number of uses remaining: " .. uses,nil,nil,uses,"Uses Remaining") end
  end
end

function ItemExamine:ShowCraftsman()
  local okW, allowedW = InqBool(self.item, BoolId.AppraisalHasAllowedWielder)
  local okA, allowedA = InqBool(self.item, BoolId.AppraisalHasAllowedActivator)
  if (not okW or not allowedW) and (not okA or not allowedA) then
    local okN, name = InqString(self.item, StringId.CraftsmanName)
    if okN and name ~= "" then self:Add("Created by " .. name .. ".") end
  end
end

function ItemExamine:ShowSellable()
  local okS, sellable = InqBool(self.item, BoolId.IsSellable)
  if okS and sellable == false then self:Add("This item cannot be sold.") end
end

function ItemExamine:ShowRareInfo()
  local okT, timer = InqBool(self.item, BoolId.RareUsesTimer)
  if okT and timer then
    self:Add("")
    self:Add("This rare item has a timer restriction of 3 minutes. You will not be able to use another rare item with a timer within 3 minutes of using this one.")
    self:Add("")
  end
  local okR, rareId = InqInt(self.item, IntId.RareId)
  if okR then self:Add("Rare #" .. rareId) end
end

function ItemExamine:ShowMagicInfo()
  local hasSpellbook = self.item.spells ~= nil and self.item.spells ~= ""
  if not hasSpellbook then return end

  local okSC, spellcraft = InqInt(self.item, IntId.ItemSpellcraft)
  if okSC then self:Add("Spellcraft: " .. spellcraft .. ".", nil, nil, spellcraft, "Spellcraft") end

  local okCur, curMana = InqInt(self.item, IntId.ItemCurMana)
  local okMax, maxMana = InqInt(self.item, IntId.ItemMaxMana)
  if okCur and okMax then
    self:Add(string.format("Mana: %d / %d.", curMana, maxMana), nil, nil, maxMana, "ManaMax")
  end

  local okRate, manaRate = InqFloat(self.item, FloatId.ManaRate)
  local okCost, manaCost = InqInt(self.item, IntId.ItemManaCost)
  if okRate and manaRate ~= 0 then
    local v = 1.0 / manaRate
    if v < 0 then v = -v end
    self:Add(string.format("Mana Cost: 1 point per %.0f seconds.", v))
  elseif okCost then
    if manaCost <= 0 then
      self:Add("Mana Cost: " .. manaCost .. ".")
    else
      self:Add("Mana Cost: " .. manaCost .. ". Can be reduced by the Mana Conversion skill")
    end
  end
  self:Add("")
  if self.item.spellsInfo then
    self:Add("Spell Descriptions:")
    for _, spellInfo in ipairs(self.item.spellsInfo or {}) do
      self:Add((string.format("~ %s: %s", spellInfo.name, spellInfo.desc or ""):gsub("%%", "%%%%")))
    end
  end
end

function ItemExamine:ShowDescription()
  local okLife, life = InqInt(self.item, IntId.Lifespan)
  if okLife and life > 0 then self:Add("This item expires in " .. DeltaTimeToString(life)) end

  local okLong, desc = InqString(self.item, StringId.LongDesc)
  if not okLong or desc == "" then
    local okShort, short = InqString(self.item, StringId.ShortDesc)
    desc = okShort and short or ""
  else
    local mat  = self.item.IntValues["MaterialType"]
    local work = self.item.IntValues["ItemWorkmanship"]
    if mat and work then
      local itemName           = desc
      local prependMaterial    = StringToMaterialType[mat] or ""
      local wi                 = math.max(1, math.min(work, 10))
      local craftLabels = {
        "Poorly crafted","Well-crafted","Finely crafted","Exquisitely crafted",
        "Magnificent","Nearly flawless","Flawless","Utterly flawless","Incomparable","Priceless"
      }
      local prependWorkmanship = craftLabels[wi] or ""
      local gemType  = self.item.IntValues["GemType"]
      local gemCount = self.item.IntValues["GemCount"]
      if gemType and gemCount and gemCount >= 1 then
        local modifiedGemType = StringToMaterialType[gemType] or ""
        if gemCount > 1 then
          if gemType==26 or gemType==37 or gemType==40 or gemType==46 or gemType==49 then
            modifiedGemType = modifiedGemType .. "es"
          elseif gemType == 38 then
            modifiedGemType = "Rubies"
          else
            modifiedGemType = modifiedGemType .. "s"
          end
        end
        desc = string.format("%s %s %s",--, set with %d %s",
          prependWorkmanship, prependMaterial, itemName)--, gemCount, modifiedGemType)
      else
        desc = string.format("%s %s %s", prependWorkmanship, prependMaterial, itemName)
      end
    end
  end

  if desc ~= "" then
    self:Add("")
    self:AddLines(desc)  -- was self:Add(desc)
  end

  local okB, bitfield = InqInt(self.item, IntId.PortalBitmask)
  if okB and bitfield ~= 0 then
    local lines = {}
    if bit.band(bitfield, 0x2)  ~= 0 then table.insert(lines, "Player Killers may not use this portal.") end
    if bit.band(bitfield, 0x4)  ~= 0 then table.insert(lines, "Lite Player Killers may not use this portal.") end
    if bit.band(bitfield, 0x8)  ~= 0 then table.insert(lines, "Non-Player Killers may not use this portal.") end
    if bit.band(bitfield, 0x20) ~= 0 then table.insert(lines, "This portal cannot be recalled nor linked to.") end
    if bit.band(bitfield, 0x10) ~= 0 then table.insert(lines, "This portal cannot be summoned.") end
    if #lines > 0 then
      self:Add("")
      for _, l in ipairs(lines) do self:Add(l) end
    end
  end

  local okCost, cost = InqInt64(self.item, Int64Id.AugmentationCost)
  if okCost and cost > 0 then
    self:Add(string.format("Using this gem will drain %d points of your available experience.", cost))
  end
end

----------------------------------------------------------------------
-- Creature profile
----------------------------------------------------------------------

function ItemExamine:ShowCreatureHeader()
  local genderStr = ""
  local allegianceTitle = ""
  local okCT, creatureType = InqInt(self.item, IntId.CreatureType)
  local hg
  if okCT and creatureType == 31 then
    local okGen, gender = InqInt(self.item, IntId.Gender)
    if okGen then genderStr = ({"Male ","Female "})[gender] end
    local okHer, heritage = InqInt(self.item, IntId.HeritageGroup)
    if okHer then
      local okHG, hgName = InqHeritageGroupDisplayName(heritage)
      if okHG and hgName ~= "" then
        hg = hgName
        local okAt, at = InqInt(self.item, IntId.AllegianceRank)
        if okAt then
          ---@diagnostic disable-next-line
          allegianceTitle = AllegianceTitle.GetTitle(hgName, genderStr, at)
        end
      end
    end
  end

  local _, name = InqString(self.item, StringId.Name)
  self:Add(allegianceTitle .. " " .. name, "", {centered=true, underline=true})

  local textTableByCol = {[1]={}, [2]={}}
  if okCT and creatureType == 31 then
    table.insert(textTableByCol[1], {text=genderStr .. (hg or ""), mods={centered=true}})
    table.insert(textTableByCol[1], {text=self.item.StringValues["Template"] or "", mods={centered=true}})
    local okPvp, pvp = InqInt(self.item, IntId.PlayerKillerStatus)
    if okPvp and PlayerKillerStatus.PK == pvp then
      table.insert(textTableByCol[1], {text="Player Killer", mods={centered=true}})
    elseif okPvp and PlayerKillerStatus.PKLite == pvp then
      table.insert(textTableByCol[1], {text="Player Killer Lite", mods={centered=true}})
    else
      table.insert(textTableByCol[1], {text="Non-Player Killer", mods={centered=true}})
    end
  else
    local ctName = okCT and InqCreatureDisplayName(creatureType) or ""
    table.insert(textTableByCol[1], "")
    table.insert(textTableByCol[1], {text=ctName, mods={centered=true}})
    table.insert(textTableByCol[1], "")
  end

  table.insert(textTableByCol[2], {text="Character", mods={centered=true}})
  table.insert(textTableByCol[2], {text="Level",     mods={centered=true}})
  local okLevel, level = InqInt(self.item, IntId.Level)
  table.insert(textTableByCol[2], {text=okLevel and tostring(level) or "???", mods={centered=true}})

  self:AddTable(textTableByCol)
  self:Add("$IMGUI_SEPARATOR")
end

function ItemExamine:ShowCreatureAttributes()
  local crp = self.item.CreatureProfile
  local function col(mask)
    return bit.band(crp.AttrHighlight.ToNumber(), mask) > 0
      and (bit.band(crp.AttrColor.ToNumber(), mask) > 0 and imguiGreen or imguiRed)
      or nil
  end
  local A = AttributeMask
  local textTableByCol = {[1]={}, [2]={}}
  local attrs = {
    {"Strength",     A.Strength.ToNumber(),     tostring(crp.Strength)},
    {"Endurance",    A.Endurance.ToNumber(),     tostring(crp.Endurance)},
    {"Coordination", A.Coordination.ToNumber(),  tostring(crp.Coordination)},
    {"Quickness",    A.Quickness.ToNumber(),     tostring(crp.Quickness)},
    {"Focus",        A.Focus.ToNumber(),         tostring(crp.Focus)},
    {"Self",         A.Self.ToNumber(),          tostring(crp.Self)},
    {"Health",       A.Health.ToNumber(),        string.format("%d/%d (%d%%%%)",
                                                   crp.Health, crp.HealthMax,
                                                   math.floor(crp.Health/crp.HealthMax*100+0.5))},
    {"Stamina",      A.Stamina.ToNumber(),       crp.Stamina .."/".. crp.StaminaMax},
    {"Mana",         A.Mana.ToNumber(),          crp.Mana    .."/".. crp.ManaMax},
  }
  for _, a in ipairs(attrs) do
    local c = col(a[2])
    table.insert(textTableByCol[1], {text=a[1], color=c})
    table.insert(textTableByCol[2], {text=a[3]=="0" and "???" or a[3], color=c, mods={rightAlign=true}})
  end
  self:AddTable(textTableByCol)
  self:Add("$IMGUI_SEPARATOR")
end

function ItemExamine:ShowCreatureAllegiance()
  local okCT, creatureType = InqInt(self.item, IntId.CreatureType)
  if not okCT or creatureType ~= 31 then return end

  if self.item.StringValues["AllegianceName"] then
    self:Add(self.item.StringValues["AllegianceName"], "", {centered=true})
  end

  local textTableByCol = {[1]={}, [2]={}}
  local societyStr = ""
  local okS, ribbons = InqInt(self.item, IntId.SocietyRankCelhan)
  if okS then societyStr = "Celestial Hand ~ " .. GetSocietyRank(ribbons) end
  okS, ribbons = InqInt(self.item, IntId.SocietyRankEldweb)
  if okS then societyStr = "Eldrytch Web ~ "   .. GetSocietyRank(ribbons) end
  okS, ribbons = InqInt(self.item, IntId.SocietyRankRadblo)
  if okS then societyStr = "Celestial Hand ~ " .. GetSocietyRank(ribbons) end
  if societyStr ~= "" then
    table.insert(textTableByCol[1], "Society:")
    table.insert(textTableByCol[2], {text=societyStr, mods={rightAlign=true}})
  end

  if self.item.StringValues["MonarchsTitle"] then
    if self.item.StringValues["PatronsTitle"] == self.item.StringValues["MonarchsTitle"] then
      table.insert(textTableByCol[1], "Monarch/Patron:")
      table.insert(textTableByCol[2], {text=self.item.StringValues["MonarchsTitle"], mods={rightAlign=true}})
    else
      table.insert(textTableByCol[1], "Monarch:")
      table.insert(textTableByCol[2], {text=self.item.StringValues["MonarchsTitle"], mods={rightAlign=true}})
      table.insert(textTableByCol[1], "Patron:")
      table.insert(textTableByCol[2], {text=self.item.StringValues["PatronsTitle"],  mods={rightAlign=true}})
    end
  end
  self:AddTable(textTableByCol)
  self:Add("")
end

function ItemExamine:ShowCreatureArmor()
  local okCT, creatureType = InqInt(self.item, IntId.CreatureType)
  if not okCT or creatureType ~= 31 then return end

  local textTableByCol = {[1]={}, [2]={}}
  table.insert(textTableByCol[1], "Head/Chest/Groin")
  table.insert(textTableByCol[2], "AL: "..self.item.BaseArmorHead  .."/"..self.item.BaseArmorChest .."/"..self.item.BaseArmorGroin)
  table.insert(textTableByCol[1], "Bicep/Wrist/Hand")
  table.insert(textTableByCol[2], "AL: "..self.item.BaseArmorBicep .."/"..self.item.BaseArmorWrist .."/"..self.item.BaseArmorHand)
  table.insert(textTableByCol[1], "Thigh/Shin/Foot")
  table.insert(textTableByCol[2], "AL: "..self.item.BaseArmorThigh .."/"..self.item.BaseArmorShin  .."/"..self.item.BaseArmorFoot)
  self:AddTable(textTableByCol)
  self:Add("")
end

function ItemExamine:ShowCreatureRatings()
  local okCT, creatureType = InqInt(self.item, IntId.CreatureType)
  if not okCT or creatureType ~= 31 then return end

  local _, dam     = InqInt(self.item, IntId.DamageRating)
  local _, damRes  = InqInt(self.item, IntId.DamageResistRating)
  local _, critDam = InqInt(self.item, IntId.CritDamageRating)
  local _, critRes = InqInt(self.item, IntId.CritDamageResistRating)

  local textTableByCol = {[1]={}, [2]={}}
  if dam > 0 or critDam > 0 then
    table.insert(textTableByCol[1], "Dam/CritDmg")
    table.insert(textTableByCol[2], {text="Rating: "..dam.."/"..critDam, mods={rightAlign=true}})
  end
  if damRes > 0 or critRes > 0 then
    table.insert(textTableByCol[1], "Dam/CritDmg")
    table.insert(textTableByCol[2], {text="Resist: "..damRes.."/"..critRes, mods={rightAlign=true}})
  end
  if #textTableByCol[1] > 0 then self:AddTable(textTableByCol) end
end

return ItemExamine