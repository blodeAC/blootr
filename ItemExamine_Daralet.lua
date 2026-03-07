-- itemExamine_Daralet
local bit = require("bit")

local ItemExamine_Daralet = {}
ItemExamine_Daralet.__index = ItemExamine_Daralet

local ImbuedEffectType = {
  Undef                           = 0x00000000,
  CriticalStrike                  = 0x00000001,
  CripplingBlow                   = 0x00000002,
  ArmorRending                    = 0x00000004,
  SlashRending                    = 0x00000008,
  PierceRending                   = 0x00000010,
  BludgeonRending                 = 0x00000020,
  AcidRending                     = 0x00000040,
  ColdRending                     = 0x00000080,
  ElectricRending                 = 0x00000100,
  FireRending                     = 0x00000200,
  MeleeDefense                    = 0x00000400,
  MissileDefense                  = 0x00000800,
  MagicDefense                    = 0x00001000,
  Spellbook                       = 0x00002000,
  NetherRending                   = 0x00004000,
  WardRending                     = 0x00008000,
  IgnoreSomeMagicProjectileDamage = 0x20000000,
  AlwaysCritical                  = 0x40000000,
  IgnoreAllArmor                  = 0x80000000
}

local RATING_PROPERTIES = {
  "GearDamage", "GearDamageResist", "GearCrit", "GearCritResist",
  "GearCritDamage", "GearCritDamageResist", "GearHealingBoost", "GearMaxHealth",
  "GearPKDamageRating", "GearPKDamageResistRating", "WardLevel",
  "GearStrength", "GearEndurance", "GearCoordination", "GearQuickness",
  "GearFocus", "GearSelf", "GearMaxStamina", "GearMaxMana",
  "GearThreatGain", "GearThreatReduction", "GearElementalWard", "GearPhysicalWard",
  "GearMagicFind", "GearBlock", "GearItemManaUsage", "GearLifesteal",
  "GearSelfHarm", "GearThorns", "GearVitalsTransfer", "GearRedFury",
  "GearYellowFury", "GearBlueFury", "GearSelflessness", "GearVipersStrike",
  "GearFamiliarity", "GearBravado", "GearHealthToStamina", "GearHealthToMana",
  "GearExperienceGain", "GearManasteal", "GearBludgeon", "GearPierce",
  "GearSlash", "GearFire", "GearFrost", "GearAcid", "GearLightning",
  "GearHealBubble", "GearCompBurn", "GearPyrealFind", "GearNullification",
  "GearWardPen", "GearStaminasteal", "GearHardenedDefense", "GearReprisal",
  "GearElementalist", "GearToughness", "GearResistance",
  "GearSlashBane", "GearBludgeonBane", "GearPierceBane",
  "GearAcidBane", "GearFireBane", "GearFrostBane", "GearLightningBane",
}

local SKILLMOD_PROPERTIES = {
  "ArmorHealthRegenMod", "ArmorStaminaRegenMod", "ArmorManaRegenMod",
  "ArmorAttackMod", "ArmorPhysicalDefMod", "ArmorMissileDefMod", "ArmorMagicDefMod",
  "ArmorRunMod", "ArmorTwohandedCombatMod", "ArmorDualWieldMod",
  "ArmorThieveryMod", "ArmorPerceptionMod", "ArmorShieldMod", "ArmorDeceptionMod",
  "ArmorWarMagicMod", "ArmorLifeMagicMod", "WeaponWarMagicMod", "WeaponLifeMagicMod",
  "WeaponRestorationSpellsMod", "ArmorHealthMod", "ArmorStaminaMod", "ArmorManaMod",
  "ArmorResourcePenalty",
}

function ItemExamine_Daralet.new(itemData)
  local self = setmetatable({}, ItemExamine_Daralet)
  self.item  = itemData
  self.item.WeenieType = game.World.Get(self.item.id).ObjectType
  self.item.ObjectType = game.World.Get(self.item.id).ObjectType
  self.item.Wielder    = game.World.Get(self.item.id).Wielder

  self._hasAdditionalProperties = nil
  self._hasExtraPropertiesText  = nil
  self._hasLongDescAdditions    = nil

  self._additionalPropertiesList                = {}
  self._longDescAdditions                       = nil
  self._additionalPropertiesLongDescriptionsText = nil
  self._extraPropertiesText                     = nil
  
  self.equippedItemsRatingCache = {}
  for _, property in pairs(RATING_PROPERTIES) do
    self.equippedItemsRatingCache[property] = 0
  end
  self.equippedItemsSkillModCache = {}
  for _, property in pairs(SKILLMOD_PROPERTIES) do
    self.equippedItemsSkillModCache[property] = 0
  end
  self.equippedItems = {}
  self.lines = {}

  if self.item.StringValues["Use"] and not self.item.StringValues["Use"]:match("Quality Level:") and (self.item.StringValues["Use"]:match(":") or self.item.StringValues["Use"]:match("\t"))  then
    self.item.StringValues.Use = nil
  end
  if self.item.StringValues["LongDesc"]~=nil then
    local lastLine = self.item.StringValues.LongDesc:match("[^\n]+$")  -- last non-empty line
    if lastLine and lastLine:sub(1,1) ~= "~" then
      self.item.StringValues["LongDesc"] = lastLine .. "\n"
    else
      self.item.StringValues["LongDesc"] = nil
    end
  end

  self:SetTinkeringLongText()

  if self._hasLongDescAdditions then
    self._longDescAdditions = self._longDescAdditions .. ""
    self.item.StringValues["LongDesc"] = self._longDescAdditions
  end

  local useText = self.item.StringValues["Use"]
  self._extraPropertiesText = (useText and #useText > 0) and (useText .. "\n") or ""

  self:SetProtectionLevelsUseText()
  self:SetArmorRendUseLongText()
  self:SetArmorCleavingUseLongText()
  self:SetResistanceRendLongText(ImbuedEffectType.AcidRending,      "Acid")
  self:SetResistanceRendLongText(ImbuedEffectType.BludgeonRending,  "Bludgeoning")
  self:SetResistanceRendLongText(ImbuedEffectType.ColdRending,      "Cold")
  self:SetResistanceRendLongText(ImbuedEffectType.ElectricRending,  "Lightning")
  self:SetResistanceRendLongText(ImbuedEffectType.FireRending,      "Fire")
  self:SetResistanceRendLongText(ImbuedEffectType.PierceRending,    "Pierce")
  self:SetResistanceRendLongText(ImbuedEffectType.SlashRending,     "Slash")
  self:SetResistanceCleavingUseLongText()
  self:SetCripplingBlowUseLongText()
  self:SetCrushingBlowUseLongText()
  self:SetCriticalStrikeUseLongText()
  self:SetBitingStrikeUseLongText()
  self:SetWardRendingUseLongText()
  self:SetWardCleavingUseLongText()
  self:SetStaminaReductionUseLongText()
  self:SetNoCompsRequiredSchoolUseLongText()

  self:SetGearRatingText("GearStrength",    self.item.IntValues["GearStrength"],    "Mighty Thews",     "Grants +10 to current Strength, plus an additional +1 per equipped rating (ONE) total).",    1.0, 1.0, 10)
  self:SetGearRatingText("GearEndurance",   self.item.IntValues["GearEndurance"],   "Perseverance",     "Grants +10 to current Endurance, plus an additional +1 per equipped rating (ONE) total).",   1.0, 1.0, 10)
  self:SetGearRatingText("GearCoordination",self.item.IntValues["GearCoordination"],"Dexterous Hand",   "Grants +10 to current Coordination, plus an additional +1 per equipped rating (ONE) total).", 1.0, 1.0, 10)
  self:SetGearRatingText("GearQuickness",   self.item.IntValues["GearQuickness"],   "Swift-footed",     "Grants +10 to current Quickness, plus an additional +1 per equipped rating (ONE) total).",   1.0, 1.0, 10)
  self:SetGearRatingText("GearFocus",       self.item.IntValues["GearFocus"],       "Focused Mind",     "Grants +10 to current Focus, plus an additional +1 per equipped rating (ONE) total).",       1.0, 1.0, 10)
  self:SetGearRatingText("GearSelf",        self.item.IntValues["GearSelf"],        "Erudite Mind",     "Grants +10 to current Self, plus an additional +1 per equipped rating (ONE) total).",        1.0, 1.0, 10)
  self:SetGearRatingText("GearSelfHarm",    self.item.IntValues["GearSelfHarm"],    "Blood Frenzy",     "Grants 10%% increased damage with all attacks, plus an additional 0.5%% per equipped rating (ONE) total). However, you will occasionally deal the extra damage to yourself as well.", 0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearThreatGain",  self.item.IntValues["GearThreatGain"],  "Provocation",      "Grants 10%% increased threat from your actions, plus an additional 0.5%% per equipped rating (ONE) total).",           0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearThreatReduction", self.item.IntValues["GearThreatReduction"], "Clouded Vision", "Grants 10%% reduced threat from your actions, plus an additional 0.5%% per equipped rating (ONE) total).",      0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearElementalWard",   self.item.IntValues["GearElementalWard"],   "Prismatic Ward", "Grants 10%%%% protection against Flame, Frost, Lightning, and Acid damage types, plus an additional 0.5%% per equipped rating (ONE) total).", 0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearPhysicalWard",    self.item.IntValues["GearPhysicalWard"],    "Black Bulwark",  "Grants 10%%%% protection against Slashing, Bludgeoning, and Piercing damage types, plus an additional 0.5%% per equipped rating (ONE) total).", 0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearMagicFind",   self.item.IntValues["GearMagicFind"],   "Seeker",           "Grants a 5%% bonus to monster loot quality, plus an additional 0.25%% per equipped rating (ONE) total).",             0.25, 1.0, 5,  0, true)
  self:SetGearRatingText("GearBlock",       self.item.IntValues["GearBlock"],       "Stalwart Defense", "Grants a 10%% bonus to block attacks, plus an additional 0.5%% per equipped rating (ONE) total).",                    0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearItemManaUsage",   self.item.IntValues["GearItemManaUsage"],   "Thrifty Scholar",   "Grants a 20%% cost reduction to mana consumed by equipped items, plus an additional 1%% per equipped rating (ONE) total).",  1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearThorns",      self.item.IntValues["GearThorns"],      "Swift Retribution","Deflect 10%% of a blocked attack's damage back to a close-range attacker, plus an additional 0.5%% per equipped rating (ONE) total).", 0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearVitalsTransfer",  self.item.IntValues["GearVitalsTransfer"],  "Tilted Scales",     "Grants a 10%% bonus to your Vitals Transfer spells, plus an additional 0.5%% per equipped rating (ONE) total). Receive an equivalent reduction in the effectiveness of your other Restoration spells.", 0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearRedFury",     self.item.IntValues["GearRedFury"],     "Red Fury",         "Grants increased damage as you lose health, up to a maximum bonus of 20%% at 0 health, plus an additional 1%% per equipped rating (ONE) total).",    1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearYellowFury",  self.item.IntValues["GearYellowFury"],  "Yellow Fury",      "Grants increased physical damage as you lose stamina, up to a maximum bonus of 20%% at 0 stamina, plus an additional 1%% per equipped rating (ONE) total).", 1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearBlueFury",    self.item.IntValues["GearBlueFury"],    "Blue Fury",        "Grants increased magical damage as you lose mana, up to a maximum bonus of 20%% at 0 mana, plus an additional 1%% per equipped rating (ONE) total).",    1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearSelflessness",self.item.IntValues["GearSelflessness"],"Selfless Spirit",  "Grants a 10%% bonus to your restoration spells when cast on others, plus an additional 0.5%% per equipped rating (ONE) total). Receive an equivalent reduction in their effectiveness when cast on yourself.", 0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearFamiliarity", self.item.IntValues["GearFamiliarity"], "Familiar Foe",     "Grants up to a 20%% bonus to defense skill against a target you are attacking, plus an additional 1%% per equipped rating (ONE) total). The chance builds up from 0%, based on how often you have hit the target.", 1.0, 1.0, 10, 0, true)
  self:SetGearRatingText("GearBravado",     self.item.IntValues["GearBravado"],     "Bravado",          "Grants up to a 20%% bonus to attack skill against a target you are attacking, plus an additional 1%% per equipped rating (ONE) total). The chance builds up from 0%%, based on how often you have hit the target.", 1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearHealthToStamina", self.item.IntValues["GearHealthToStamina"], "Masochist",        "Grants a 10%% chance to regain the hit damage received from an attack as stamina, plus an additional 0.5%% per equipped rating (ONE) total).", 0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearHealthToMana",    self.item.IntValues["GearHealthToMana"],    "Austere Anchorite","Grants a 10%% chance to regain the hit damage received from an attack as mana, plus an additional 0.5%% per equipped rating (ONE) total).",    0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearExperienceGain",  self.item.IntValues["GearExperienceGain"],  "Illuminated Mind", "Grants a 5%% bonus to experience gain, plus an additional 0.25%% per equipped rating (ONE) total).",                                           0.25, 1.0, 5,  0, true)
  self:SetGearRatingText("GearLifesteal",   self.item.IntValues["GearLifesteal"],   "Sanguine Thirst",  "Grants a 10%% chance on hit to gain health, plus an additional 0.5%% per equipped rating (ONE) total). Amount stolen is equal to 10%% of damage dealt.",   0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearStaminasteal",self.item.IntValues["GearStaminasteal"],"Vigor Siphon",     "Grants a 10%% chance on hit to gain stamina, plus an additional 0.5%% per equipped rating (ONE) total). Amount stolen is equal to 10%% of damage dealt.",  0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearManasteal",   self.item.IntValues["GearManasteal"],   "Ophidian",         "Grants a 10%% chance on hit to steal mana from your target, plus an additional 0.5%% per equipped rating (ONE) total). Amount stolen is equal to 10%% of damage dealt.", 0.5, 1.0, 10, 0, true)
  self:SetGearRatingText("GearBludgeon",    self.item.IntValues["GearBludgeon"],    "Skull-cracker",    "Grants up to 20%% bonus critical hit damage, plus an additional 1%% per equipped rating (ONE) total). The bonus builds up from 0%%, based on how often you have hit the target.",              1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearPierce",      self.item.IntValues["GearPierce"],      "Precision Strikes","Grants up to 20%% piercing resistance penetration, plus an additional 1%% per equipped rating (ONE) total). The bonus builds up from 0%%, based on how often you have hit the target",        1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearSlash",       self.item.IntValues["GearSlash"],       "Falcon's Gyre",    "Grants a 10%% chance to cleave an additional target, plus an additional 0.5%% per equipped rating (ONE) total).",                                                                             0.5, 0.1, 10, 2, true)
  self:SetGearRatingText("GearFire",        self.item.IntValues["GearFire"],        "Blazing Brand",    "Grants a 10%% bonus to Fire damage, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance on hit to set the ground beneath your target ablaze, plus an additional 0.1%% per equipped rating (TWO) total).",    0.5, 0.1, 10, 2, true)
  self:SetGearRatingText("GearFrost",       self.item.IntValues["GearFrost"],       "Bone-chiller",     "Grants a 10%% bonus to Cold damage, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance on hit to surround your target with chilling mist, plus an additional 0.1%% per equipped rating (TWO) total).",     0.5, 0.1, 10, 2, true)
  self:SetGearRatingText("GearAcid",        self.item.IntValues["GearAcid"],        "Devouring Mist",   "Grants a 10%% bonus to Acid damage, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance on hit to surround your target with acidic mist, plus an additional 0.1%% per equipped rating (TWO) total).",      0.5, 0.1, 10, 2, true)
  self:SetGearRatingText("GearLightning",   self.item.IntValues["GearLightning"],   "Astyrrian's Rage", "Grants a 10%% bonus to Lightning damage, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance on hit to electrify the ground beneath your target, plus an additional 0.1%% per equipped rating (TWO) total).", 0.5, 0.1, 10, 2, true)
  self:SetGearRatingText("GearHealBubble",  self.item.IntValues["GearHealBubble"],  "Purified Soul",    "Grants a 10%% bonus to your restoration spells, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance to create a sphere of healing energy on top of your target when casting a restoration spell, plus an additional 0.1%% per equipped rating (ONE) total).", 0.5, 0.1, 10, 2, true)
  self:SetGearRatingText("GearCompBurn",    self.item.IntValues["GearCompBurn"],    "Meticulous Magus", "Grants a 20%% reduction to your chance to burn spell components, plus an additional 1%% per equipped rating (ONE) total).",  1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearPyrealFind",  self.item.IntValues["GearPyrealFind"],  "Prosperity",       "Grants a 5%% chance for a monster to drop an extra item, plus an additional 0.25%% per equipped rating (ONE) total).",      0.25, 1.0, 5,  0, true)
  self:SetGearRatingText("GearNullification",   self.item.IntValues["GearNullification"],   "Nullification",      "Grants up to 20%% reduced magic damage taken, plus an additional 1%% per equipped rating (ONE) total). The amount builds up from 0%%, based on how often you have been hit with a damaging spell.",          1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearWardPen",     self.item.IntValues["GearWardPen"],     "Ruthless Discernment","Grants up to 20%% ward penetration, plus an additional 1%% per equipped rating (ONE) total). The Amount builds up from 0%%, based on how often you have hit your target.",                  1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearHardenedDefense", self.item.IntValues["GearHardenedDefense"], "Hardened Fortification","Grants up to 20%% reduced physical damage taken, plus an additional 1%% per equipped rating (ONE) total). The amount builds up from 0%%, based on how often you have been hit with a damaging physical attack.", 1.0, 10.0, 20, 0, true)
  self:SetGearRatingText("GearReprisal",    self.item.IntValues["GearReprisal"],    "Vicious Reprisal", "Grants a 5%% chance to evade an incoming critical hit, plus an additional 0.25%% per equipped rating (ONE) total). Your next attack after the evade is a guaranteed critical.",                0.25, 1.0, 5,  0, true)
  self:SetGearRatingText("GearElementalist",self.item.IntValues["GearElementalist"],"Elementalist",     "Grants up to a 20%% damage bonus to war spells, plus an additional 1%% per equipped rating (ONE) total). The amount builds up from 0%%, based on how often you have hit your target.",        1.0, 1.0, 20, 0, true)
  self:SetGearRatingText("GearToughness",   self.item.IntValues["GearToughness"],   "Toughness",        "Grants +20 physical defense, plus an additional 1 per equipped rating (ONE) total).",  1.0, 1.0, 20)
  self:SetGearRatingText("GearResistance",  self.item.IntValues["GearResistance"],  "Resistance",       "Grants +20 magic defense, plus an additional 1 per equipped rating (ONE) total).",    1.0, 1.0, 20)
  self:SetGearRatingText("GearSlashBane",    self.item.IntValues["GearSlashBane"],    "Swordsman's Bane","Grants +0.2 slashing protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",    0.01, 1.0, 0.2)
  self:SetGearRatingText("GearBludgeonBane", self.item.IntValues["GearBludgeonBane"], "Tusker's Bane",   "Grants +0.2 bludgeoning protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",  0.01, 1.0, 0.2)
  self:SetGearRatingText("GearPierceBane",   self.item.IntValues["GearPierceBane"],   "Archer's Bane",   "Grants +0.2 piercing protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",   0.01, 1.0, 0.2)
  self:SetGearRatingText("GearAcidBane",     self.item.IntValues["GearAcidBane"],     "Olthoi's Bane",   "Grants +0.2 acid protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",        0.01, 1.0, 0.2)
  self:SetGearRatingText("GearFireBane",     self.item.IntValues["GearFireBane"],     "Inferno's Bane",  "Grants +0.2 fire protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",        0.01, 1.0, 0.2)
  self:SetGearRatingText("GearFrostBane",    self.item.IntValues["GearFrostBane"],    "Gelidite's Bane", "Grants +0.2 cold protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",        0.01, 1.0, 0.2)
  self:SetGearRatingText("GearLightningBane",self.item.IntValues["GearLightningBane"],"Astyrrian's Bane","Grants +0.2 electric protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",    0.01, 1.0, 0.2)

  self:SetAdditionalPropertiesUseText()
  self:SetSpellProcRateUseText()

  self._extraPropertiesText = self._extraPropertiesText .. "\n"

  self:SetBowAttackModUseText()
  self:SetAmmoEffectUseText()
  self:SetWeaponWarMagicUseText()
  self:SetWeaponLifeMagicUseText()
  self:SetWeaponPhysicalDefenseUseText()
  self:SetWeaponMagicDefenseUseText()
  self:SetWeaponRestoModUseText()
  self:SetBowElementalWarningUseText()
  self:SetArmorWardLevelUseText()
  self:SetArmorWeightClassUseText()
  self:SetArmorResourcePenaltyUseText()
  self:SetWeaponSpellcraftText()
  self:SetJewelryManaConUseText()

  local equipped = self.item.Wielder and self.item.Wielder.Id == game.CharacterId
  local function esum(k) return equipped and self:GetEquippedItemsSkillModSum(k) or 0 end
  self:SetArmorModUseText("ArmorWarMagicMod",          self.item.FloatValues["ArmorWarMagicMod"],          "Bonus to War Magic Skill: +(ONE)%%",              esum("ArmorWarMagicMod"))
  self:SetArmorModUseText("ArmorLifeMagicMod",          self.item.FloatValues["ArmorLifeMagicMod"],          "Bonus to Life Magic Skill: +(ONE)%%",             esum("ArmorLifeMagicMod"))
  self:SetArmorModUseText("ArmorAttackMod",             self.item.FloatValues["ArmorAttackMod"],             "Bonus to Attack Skill: +(ONE)%%",                 esum("ArmorAttackMod"))
  self:SetArmorModUseText("ArmorPhysicalDefMod",        self.item.FloatValues["ArmorPhysicalDefMod"],        "Bonus to Physical Defense: +(ONE)%%",             esum("ArmorPhysicalDefMod"))
  self:SetArmorModUseText("ArmorMagicDefMod",           self.item.FloatValues["ArmorMagicDefMod"],           "Bonus to Magic Defense: +(ONE)%%",                esum("ArmorMagicDefMod"))
  self:SetArmorModUseText("ArmorDualWieldMod",          self.item.FloatValues["ArmorDualWieldMod"],          "Bonus to Dual Wield Skill: +(ONE)%%",             esum("ArmorDualWieldMod"))
  self:SetArmorModUseText("ArmorTwohandedCombatMod",    self.item.FloatValues["ArmorTwohandedCombatMod"],    "Bonus to Two-handed Combat Skill: +(ONE)%%",      esum("ArmorTwohandedCombatMod"))
  self:SetArmorModUseText("ArmorRunMod",                self.item.FloatValues["ArmorRunMod"],                "Bonus to Run Skill: +(ONE)%%",                    esum("ArmorRunMod"))
  self:SetArmorModUseText("ArmorThieveryMod",           self.item.FloatValues["ArmorThieveryMod"],           "Bonus to Thievery Skill: +(ONE)%%",               esum("ArmorThieveryMod"))
  self:SetArmorModUseText("ArmorShieldMod",             self.item.FloatValues["ArmorShieldMod"],             "Bonus to Shield Skill: +(ONE)%%",                 esum("ArmorShieldMod"))
  self:SetArmorModUseText("ArmorPerceptionMod",         self.item.FloatValues["ArmorPerceptionMod"],         "Bonus to Perception Skill: +(ONE)%%",             esum("ArmorPerceptionMod"))
  self:SetArmorModUseText("ArmorDeceptionMod",          self.item.FloatValues["ArmorDeceptionMod"],          "Bonus to Deception Skill: +(ONE)%%",              esum("ArmorDeceptionMod"))
  self:SetArmorModUseText("ArmorHealthMod",             self.item.FloatValues["ArmorHealthMod"],             "Bonus to Maximum Health: +(ONE)%%",               esum("ArmorHealthMod"))
  self:SetArmorModUseText("ArmorHealthRegenMod",        self.item.FloatValues["ArmorHealthRegenMod"],        "Bonus to Health Regen: +(ONE)%%",                 esum("ArmorHealthRegenMod"))
  self:SetArmorModUseText("ArmorStaminaMod",            self.item.FloatValues["ArmorStaminaMod"],            "Bonus to Maximum Stamina: +(ONE)%%",              esum("ArmorStaminaMod"))
  self:SetArmorModUseText("ArmorStaminaRegenMod",       self.item.FloatValues["ArmorStaminaRegenMod"],       "Bonus to Stamina Regen: +(ONE)%%",                esum("ArmorStaminaRegenMod"))
  self:SetArmorModUseText("ArmorManaMod",               self.item.FloatValues["ArmorManaMod"],               "Bonus to Maximum Mana: +(ONE)%%",                 esum("ArmorManaMod"))
  self:SetArmorModUseText("ArmorManaRegenMod",          self.item.FloatValues["ArmorManaRegenMod"],          "Bonus to Mana Regen: +(ONE)%%",                   esum("ArmorManaRegenMod"))

  self._extraPropertiesText = (self._extraPropertiesText or "") .. "\n"

  self:SetDamagePenaltyUseText()
  self:SetJewelcraftingUseText()
  self:SetSalvageBagUseText()
  self:SetSigilTrinketUseText()

  if self._hasExtraPropertiesText then
    self._extraPropertiesText = self._extraPropertiesText .. ""
    self.item.StringValues["Use"] = self._extraPropertiesText

    if self._additionalPropertiesLongDescriptionsText and #self._additionalPropertiesLongDescriptionsText > 0 then
      local longDescString = self.item.StringValues["LongDesc"]
      self._additionalPropertiesLongDescriptionsText =
        "Property Descriptions:\n" .. (self._additionalPropertiesLongDescriptionsText or "") ..
        "\n\n" .. (longDescString or "")
      self.item.StringValues["LongDesc"] =
        self._additionalPropertiesLongDescriptionsText
    end
  end

  return self
end

function ItemExamine_Daralet:SetTrophyQualityLevelText()
  local trophyQuality = self.item.IntValues["TrophyQuality"]
  if not trophyQuality or trophyQuality <= 0 then return end
  local trophyQualityTable = setmetatable({
    [2]="Inferior",[3]="Poor",[4]="Crude",[5]="Ordinary",
    [6]="Good",[7]="Great",[8]="Excellent",[9]="Superb",[10]="Peerless"
  }, { __index = function() return "Damaged" end })
  self._extraPropertiesText = "Quality Level: " .. trophyQuality
  self.item.StringValues["Use"] = self._extraPropertiesText
end

function ItemExamine_Daralet:SetCustomDecorationLongText()
  if self.item.IntValues["MaterialType"] == nil or self.item.IntValues["ItemWorkmanship"] == nil then return end
  local prependMaterial = "" .. StringToMaterialType[self.item.IntValues["MaterialType"]]
  local wi = math.max(1, math.min(self.item.IntValues["ItemWorkmanship"] or 1, 10))
  local craftLabels = {
    "Poorly crafted","Well-crafted","Finely crafted","Exquisitely crafted",
    "Magnificent","Nearly flawless","Flawless","Utterly flawless","Incomparable","Priceless"
  }
  local prependWorkmanship = craftLabels[wi]
  local modifiedGemType = StringToMaterialType[self.item.IntValues["GemType"]]
  if self.item.IntValues["GemType"] ~= nil and self.item.IntValues["GemCount"] ~= nil and self.item.IntValues["GemCount"] >= 1 then
    if self.item.IntValues["GemCount"] > 1 then
      local g = self.item.IntValues["GemType"]
      if g==26 or g==37 or g==40 or g==46 or g==49 then
        modifiedGemType = modifiedGemType .. "es"
      elseif g == 38 then
        modifiedGemType = "Rubies"
      else
        modifiedGemType = modifiedGemType .. "s"
      end
    end
    self._longDescAdditions = string.format("%s %s %s, set with %d %s",
      prependWorkmanship, prependMaterial, self.item.StringValues["Name"],
      self.item.IntValues["GemCount"], modifiedGemType)
  else
    self._longDescAdditions = string.format("%s %s %s",
      prependWorkmanship, prependMaterial, self.item.StringValues["Name"])
  end
  self._hasLongDescAdditions = true
end

function ItemExamine_Daralet:SetTinkeringLongText()
  if (self.item.IntValues["NumTimesTinkered"] or 0) < 1 then return end
  if self.item.StringValues["TinkerLog"] == nil then return end

  local tinkerLogArray = {}
  for s in string.gmatch(self.item.StringValues["TinkerLog"], "([^,]+)") do
    table.insert(tinkerLogArray, s)
  end

  local tinkeringTypes = {}
  for i = 0, 79 do tinkeringTypes[i] = 0 end

  self._hasLongDescAdditions = true
  self._longDescAdditions = (self._longDescAdditions or "") .. "This item has been tinkered with:\n"

  for _, s in ipairs(tinkerLogArray) do
    local index = tonumber(s)
    if index and index >= 0 and index < 80 then
      tinkeringTypes[index] = tinkeringTypes[index] + 1
    end
  end

  local sumofTinksinLog = 0
  for index = 0, 79 do
    local value = tinkeringTypes[index]
    if value > 0 then
      if MaterialType[index] ~= nil then
        self._longDescAdditions = self._longDescAdditions ..
          string.format("    \n  %s:  %d", tostring(self.item.IntValues["MaterialType"]), value)
      else
        print(string.format("Unknown variable at index %d: %d", index, value))
      end
      sumofTinksinLog = sumofTinksinLog + value
    end
  end

  if sumofTinksinLog == 0 and self.item.IntValues["NumTimesTinkered"] >= 1 then
    self._longDescAdditions = self._longDescAdditions ..
      string.format("\n        \n  Failures:    %d", self.item.IntValues["NumTimesTinkered"])
  else
    local diff = sumofTinksinLog - self.item.IntValues["NumTimesTinkered"]
    if diff < 0 then
      self._longDescAdditions = self._longDescAdditions ..
        string.format("\n           \n  Failures:  %d", math.abs(diff))
    end
  end
end

function ItemExamine_Daralet:SetSigilTrinketUseText()
  local s = self.item

  local triggerChance = s.FloatValues["SigilTrinketTriggerChance"]
  if triggerChance and triggerChance > 0.01 then
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("Proc Chance: %.0f%%%%\n", math.floor(triggerChance * 100 + 0.5))
    self._hasExtraPropertiesText = true
  end

  local cooldown = s.FloatValues["CooldownDuration"]
  if cooldown and cooldown > 0.01 then
    self._extraPropertiesText = self._extraPropertiesText ..
      string.format("Cooldown: %.1f seconds\n", cooldown)
    self._hasExtraPropertiesText = true
  end

  local maxStructure = s.IntValues["MaxStructure"]
  if maxStructure and maxStructure > 0 then
    self._extraPropertiesText = self._extraPropertiesText ..
      string.format("Max Number of Uses: %d\n", maxStructure)
    self._hasExtraPropertiesText = true
  end

  local intensity = s.FloatValues["SigilTrinketIntensity"]
  if intensity and intensity > 0.01 then
    self._extraPropertiesText = self._extraPropertiesText ..
      string.format("Bonus Intensity: %.1f%%%%\n", intensity * 100)
    self._hasExtraPropertiesText = true
  end

  local reduction = s.FloatValues["SigilTrinketReductionAmount"]
  if reduction and reduction > 0.01 then
    self._extraPropertiesText = self._extraPropertiesText ..
      string.format("Mana Cost Reduction: %.1f%%%%\n", reduction * 100)
    self._hasExtraPropertiesText = true
  end

  local aetherMask = EquipMask.RedAetheria.ToNumber() + EquipMask.YellowAetheria.ToNumber() + EquipMask.BlueAetheria.ToNumber()
  local wielded = self.item.Wielder and self.item.Wielder.Id == game.CharacterId

  local healthRes = s.FloatValues["SigilTrinketHealthReserved"]
  if healthRes and healthRes > 0 then
    if wielded then
      local total = 0.0
      for _, gear in pairs(game.Character.Equipment) do
        if bit.band(gear.ValidWieldedLocations, aetherMask) > 0 then
          total = total + (gear.IntValues["SigilTrinketHealthReserved"] or 0)
        end
      end
      self._extraPropertiesText = self._extraPropertiesText ..
        string.format("Health Reservation: %.1f%%%% (%.1f%%%%)\n", healthRes * 100, total * 100)
    else
      self._extraPropertiesText = self._extraPropertiesText ..
        string.format("Health Reservation: %.1f%%%%\n", healthRes * 100)
    end
    self._hasExtraPropertiesText = true
  end

  local stamRes = s.FloatValues["SigilTrinketStaminaReserved"]
  if stamRes and stamRes > 0 then
    if wielded then
      local total = 0.0
      for _, gear in pairs(game.Character.Equipment) do
        if bit.band(gear.ValidWieldedLocations, aetherMask) > 0 then
          total = total + (gear.IntValues["SigilTrinketStaminaReserved"] or 0)
        end
      end
      self._extraPropertiesText = self._extraPropertiesText ..
        string.format("Stamina Reservation: %.1f%%%% (%.1f%%%%)\n", stamRes * 100, total * 100)
    else
      self._extraPropertiesText = self._extraPropertiesText ..
        string.format("Stamina Reservation: %.1f%%%%\n", stamRes * 100)
    end
    self._hasExtraPropertiesText = true
  end

  local manaRes = s.FloatValues["SigilTrinketManaReserved"]
  if manaRes and manaRes > 0 then
    if wielded then
      local total = 0.0
      for _, gear in pairs(game.Character.Equipment) do
        if bit.band(gear.ValidWieldedLocations, aetherMask) > 0 then
          total = total + (gear.IntValues["SigilTrinketManaReserved"] or 0)
        end
      end
      self._extraPropertiesText = self._extraPropertiesText ..
        string.format("Mana Reservation: %.1f%%%% (%.1f%%%%)\n", manaRes * 100, total * 100)
    else
      self._extraPropertiesText = self._extraPropertiesText ..
        string.format("Mana Reservation: %.1f%%%%\n", manaRes * 100)
    end
    self._hasExtraPropertiesText = true
  end

  if s.AllowedSpecializedSkills then
    local skills = s.AllowedSpecializedSkills
    if #skills > 0 then
      pcall(function()
        local names = {}
        for i = 1, #skills do
          local ok2, name = pcall(function() return tostring(skills[i]) end)
          table.insert(names, ok2 and name or tostring(skills[i]))
        end
        local seen, unique = {}, {}
        for _, n in ipairs(names) do
          if not seen[n] then seen[n] = true; table.insert(unique, n) end
        end
        local wieldReqStr = "Wield requires specialized " ..
          (#unique == 1 and unique[1] or table.concat(unique, " or "))
        self._extraPropertiesText = (self._extraPropertiesText or "") .. wieldReqStr .. "\n"
        self._hasExtraPropertiesText = true
      end)
    end
  end
end

function ItemExamine_Daralet:SetSalvageBagUseText()
  local structure = self.item.IntValues["Structure"]
  if not structure or structure < 0 then return end
  if self.item.WeenieType ~= WeenieType.CombatPet + 5 then return end
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("\nThis bag contains %d units of salvage.\n", structure)
  self._hasExtraPropertiesText = true
end

local function JewelType(primary, alternate)
  return setmetatable({ PrimaryRating=primary, AlternateRating=alternate }, {
    __tostring = function(t) return t.PrimaryRating end,
    __call    = function(t) return t.PrimaryRating end,
  })
end

ItemExamine_Daralet.JewelMaterialToType = setmetatable({
  [MaterialType.Agate.ToNumber()]       = JewelType("GearThreatGain",    "Undef"),
  [MaterialType.Amber.ToNumber()]       = JewelType("GearYellowFury",    "GearHealthToStamina"),
  [MaterialType.Amethyst.ToNumber()]    = JewelType("GearNullification", "GearResistance"),
  [MaterialType.Aquamarine.ToNumber()]  = JewelType("GearFrost",         "GearFrostBane"),
  [MaterialType.Azurite.ToNumber()]     = JewelType("GearSelf",          "Undef"),
  [MaterialType.BlackGarnet.ToNumber()] = JewelType("GearPierce",        "GearPierceBane"),
  [MaterialType.BlackOpal.ToNumber()]   = JewelType("GearReprisal",      "Undef"),
  [MaterialType.Bloodstone.ToNumber()]  = JewelType("GearLifesteal",     "Undef"),
  [MaterialType.Carnelian.ToNumber()]   = JewelType("GearStrength",      "Undef"),
  [MaterialType.Citrine.ToNumber()]     = JewelType("GearStaminasteal",  "Undef"),
  [MaterialType.Diamond.ToNumber()]     = JewelType("GearHardenedDefense","GearToughness"),
  [MaterialType.Emerald.ToNumber()]     = JewelType("GearAcid",          "GearAcidBane"),
  [MaterialType.FireOpal.ToNumber()]    = JewelType("GearFamiliarity",   "Undef"),
  [MaterialType.GreenGarnet.ToNumber()] = JewelType("GearElementalist",  "Undef"),
  [MaterialType.GreenJade.ToNumber()]   = JewelType("GearPyrealFind",    "Undef"),
  [MaterialType.Hematite.ToNumber()]    = JewelType("GearSelfHarm",      "Undef"),
  [MaterialType.ImperialTopaz.ToNumber()]= JewelType("GearSlash",         "GearSlashBane"),
  [MaterialType.Jet.ToNumber()]         = JewelType("GearLightning",     "GearLightningBane"),
  [MaterialType.LapisLazuli.ToNumber()] = JewelType("GearBlueFury",      "GearHealthToMana"),
  [MaterialType.LavenderJade.ToNumber()] = JewelType("GearSelflessness",  "Undef"),
  [MaterialType.Malachite.ToNumber()]   = JewelType("GearCompBurn",      "Undef"),
  [MaterialType.Moonstone.ToNumber()]   = JewelType("GearItemManaUsage", "Undef"),
  [MaterialType.Onyx.ToNumber()]        = JewelType("GearPhysicalWard",  "Undef"),
  [MaterialType.Opal.ToNumber()]        = JewelType("GearManasteal",     "Undef"),
  [MaterialType.Peridot.ToNumber()]     = JewelType("GearQuickness",     "Undef"),
  [MaterialType.RedGarnet.ToNumber()]   = JewelType("GearFire",          "GearFireBane"),
  [MaterialType.RedJade.ToNumber()]     = JewelType("GearFocus",         "Undef"),
  [MaterialType.RoseQuartz.ToNumber()]  = JewelType("GearVitalsTransfer","Undef"),
  [MaterialType.Ruby.ToNumber()]        = JewelType("GearRedFury",       "Undef"),
  [MaterialType.Sapphire.ToNumber()]    = JewelType("GearMagicFind",     "Undef"),
  [MaterialType.SmokeyQuartz.ToNumber()] = JewelType("GearThreatReduction","Undef"),
  [MaterialType.Sunstone.ToNumber()]    = JewelType("GearExperienceGain","Undef"),
  [MaterialType.TigerEye.ToNumber()]    = JewelType("GearCoordination",  "Undef"),
  [MaterialType.Tourmaline.ToNumber()]  = JewelType("GearWardPen",       "Undef"),
  [MaterialType.Turquoise.ToNumber()]   = JewelType("GearBlock",         "Undef"),
  [MaterialType.WhiteJade.ToNumber()]   = JewelType("GearHealBubble",    "Undef"),
  [MaterialType.WhiteQuartz.ToNumber()] = JewelType("GearThorns",        "Undef"),
  [MaterialType.WhiteSapphire.ToNumber()]= JewelType("GearBludgeon",      "GearBludgeonBane"),
  [MaterialType.YellowGarnet.ToNumber()] = JewelType("GearBravado",       "Undef"),
  [MaterialType.YellowTopaz.ToNumber()] = JewelType("GearEndurance",     "Undef"),
  [MaterialType.Zircon.ToNumber()]      = JewelType("GearElementalWard", "Undef"),
}, { __index = function(t, k) local e = rawget(t,k); return e and e.PrimaryRating or nil end })

ItemExamine_Daralet.JewelTypeToMaterial = {
  ["GearThreatGain"]="Agate", ["GearYellowFury"]=MaterialType.Amber,
  ["GearNullification"]=MaterialType.Amethyst, ["GearFrost"]=MaterialType.Aquamarine,
  ["GearSelf"]=MaterialType.Azurite, ["GearPierce"]=MaterialType.BlackGarnet,
  ["GearReprisal"]=MaterialType.BlackOpal, ["GearLifesteal"]=MaterialType.Bloodstone,
  ["GearStrength"]=MaterialType.Carnelian, ["GearStaminasteal"]=MaterialType.Citrine,
  ["GearHardenedDefense"]=MaterialType.Diamond, ["GearAcid"]=MaterialType.Emerald,
  ["GearFamiliarity"]=MaterialType.FireOpal, ["GearElementalist"]=MaterialType.GreenGarnet,
  ["GearPyrealFind"]=MaterialType.GreenJade, ["GearSelfHarm"]=MaterialType.Hematite,
  ["GearSlash"]=MaterialType.ImperialTopaz, ["GearLightning"]=MaterialType.Jet,
  ["GearBlueFury"]=MaterialType.LapisLazuli, ["GearSelflessness"]=MaterialType.LavenderJade,
  ["GearCompBurn"]=MaterialType.Malachite, ["GearItemManaUsage"]=MaterialType.Moonstone,
  ["GearPhysicalWard"]=MaterialType.Onyx, ["GearManasteal"]=MaterialType.Opal,
  ["GearQuickness"]=MaterialType.Peridot, ["GearFire"]=MaterialType.RedGarnet,
  ["GearFocus"]=MaterialType.RedJade, ["GearVitalsTransfer"]=MaterialType.RoseQuartz,
  ["GearRedFury"]=MaterialType.Ruby, ["GearMagicFind"]=MaterialType.Sapphire,
  ["GearThreatReduction"]=MaterialType.SmokeyQuartz, ["GearExperienceGain"]=MaterialType.Sunstone,
  ["GearCoordination"]=MaterialType.TigerEye, ["GearWardPen"]=MaterialType.Tourmaline,
  ["GearBlock"]=MaterialType.Turquoise, ["GearHealBubble"]=MaterialType.WhiteJade,
  ["GearThorns"]=MaterialType.WhiteQuartz, ["GearBludgeon"]=MaterialType.WhiteSapphire,
  ["GearBravado"]=MaterialType.YellowGarnet, ["GearEndurance"]=MaterialType.YellowTopaz,
  ["GearElementalWard"]=MaterialType.Zircon,
  ["GearToughness"]=MaterialType.Diamond, ["GearResistance"]=MaterialType.Amethyst,
  ["GearHealthToStamina"]=MaterialType.Amber, ["GearHealthToMana"]=MaterialType.LapisLazuli,
  ["GearSlashBane"]=MaterialType.ImperialTopaz, ["GearBludgeonBane"]=MaterialType.WhiteSapphire,
  ["GearPierceBane"]=MaterialType.BlackGarnet, ["GearAcidBane"]=MaterialType.Emerald,
  ["GearFireBane"]=MaterialType.RedGarnet, ["GearFrostBane"]=MaterialType.Aquamarine,
  ["GearLightningBane"]=MaterialType.Jet,
}

local JewelQuality = {
  [1]="Scuffed",[2]="Flawed",[3]="Mediocre",[4]="Fine",[5]="Admirable",
  [6]="Superior",[7]="Excellent",[8]="Magnificent",[9]="Peerless",[10]="Flawless"
}
local JewelQualityStringToValue = {
  Scuffed=1,Flawed=2,Mediocre=3,Fine=4,Admirable=5,
  Superior=6,Excellent=7,Magnificent=8,Peerless=9,Flawless=10
}

local function JewelStatsDescription(baseRating, amount, bonusPerQuality, name, bonusPerQualitySecondary, altName)
  altName = altName or ""
  local secondaryBonus = bonusPerQualitySecondary and
    string.format("\nSecondary Bonus Rating: %.1f (%.1f x Quality)", bonusPerQualitySecondary * amount, bonusPerQualitySecondary) or ""
  local altSources = altName ~= "" and (" or " .. altName) or ""
  return string.format(
    "\nQuality: %d (%s)\nBonus Rating: %.1f (%.1f x Quality)%s\n\n\nAdditional sources of %s%s will only add the bonus rating.",
    amount, JewelQuality[amount] or "Unknown",
    bonusPerQuality * amount, bonusPerQuality,
    secondaryBonus, name, altSources)
end

local JewelEffectInfoAlternate = {
  [MaterialType.Diamond.ToNumber()]      = { PropertyName="GearToughness",    Name="Toughness",          Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Amethyst.ToNumber()]     = { PropertyName="GearResistance",   Name="Resistance",         Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Jet.ToNumber()]          = { PropertyName="GearLightningBane",Name="Astyrrian's Bane",   Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.RedGarnet.ToNumber()]    = { PropertyName="GearFireBane",     Name="Inferno's Bane",     Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Aquamarine.ToNumber()]   = { PropertyName="GearFrostBane",    Name="Gelidite's Bane",    Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Emerald.ToNumber()]      = { PropertyName="GearAcidBane",     Name="Olthoi's Bane",      Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.ImperialTopaz.ToNumber()]= { PropertyName="GearSlashBane",    Name="Swordsman's Bane",   Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.BlackGarnet.ToNumber()]  = { PropertyName="GearPierceBane",   Name="Archer's Bane",      Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.WhiteSapphire.ToNumber()]= { PropertyName="GearBludgeonBane", Name="Tusker's Bane",      Slot="piece of armor", BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.LapisLazuli.ToNumber()]  = { PropertyName="GearHealthToMana", Name="Austere Anchorite",  Slot="piece of armor", BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Amber.ToNumber()]        = { PropertyName="GearHealthToStamina",Name="Masochist",        Slot="piece of armor", BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
}

local JewelEffectInfoMain = {
  [MaterialType.Sunstone.ToNumber()]     = { PropertyName="GearExperienceGain",  Name="Illuminated Mind",      Slot="necklace",        BasePrimary=5,   BonusPrimary=0.25, BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Sapphire.ToNumber()]     = { PropertyName="GearMagicFind",       Name="Seeker",                Slot="necklace",        BasePrimary=5,   BonusPrimary=0.25, BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.GreenJade.ToNumber()]    = { PropertyName="GearPyrealFind",      Name="Prosperity",            Slot="necklace",        BasePrimary=5,   BonusPrimary=0.25, BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Carnelian.ToNumber()]    = { PropertyName="GearStrength",        Name="Mighty Thews",          Slot="ring",            BasePrimary=10,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Azurite.ToNumber()]      = { PropertyName="GearSelf",            Name="Erudite Mind",          Slot="ring",            BasePrimary=10,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.TigerEye.ToNumber()]     = { PropertyName="GearCoordination",    Name="Dexterous Hand",        Slot="ring",            BasePrimary=10,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.RedJade.ToNumber()]      = { PropertyName="GearFocus",           Name="Focused Mind",          Slot="ring",            BasePrimary=10,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.YellowTopaz.ToNumber()]  = { PropertyName="GearEndurance",       Name="Perserverence",         Slot="ring",            BasePrimary=10,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Peridot.ToNumber()]      = { PropertyName="GearQuickness",       Name="Swift-footed",          Slot="ring",            BasePrimary=10,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Agate.ToNumber()]        = { PropertyName="GearThreatGain",      Name="Provocation",           Slot="bracelet",        BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.SmokeyQuartz.ToNumber()] = { PropertyName="GearThreatReduction", Name="Clouded Vision",        Slot="bracelet",        BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Moonstone.ToNumber()]    = { PropertyName="GearItemManaUsage",   Name="Meticulous Magus",      Slot="bracelet",        BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Malachite.ToNumber()]    = { PropertyName="GearCompBurn",        Name="Thrifty Scholar",       Slot="bracelet",        BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Onyx.ToNumber()]         = { PropertyName="GearPhysicalWard",    Name="Black Bulwark",         Slot="bracelet",        BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Zircon.ToNumber()]       = { PropertyName="GearElementalWard",   Name="Prismatic Ward",        Slot="bracelet",        BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Diamond.ToNumber()]      = { PropertyName="GearHardenedDefense", Name="Hardened Fortification",Slot="bracelet",        BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Amethyst.ToNumber()]     = { PropertyName="GearNullification",   Name="Nullification",         Slot="bracelet",        BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Turquoise.ToNumber()]    = { PropertyName="GearBlock",           Name="Stalwart Defense",      Slot="shield",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.WhiteQuartz.ToNumber()]  = { PropertyName="GearThorns",          Name="Swift Retribution",     Slot="shield",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Hematite.ToNumber()]     = { PropertyName="GearSelfHarm",        Name="Blood Frenzy",          Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Bloodstone.ToNumber()]   = { PropertyName="GearLifesteal",       Name="Sanguine Thirst",       Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Citrine.ToNumber()]      = { PropertyName="GearStaminasteal",    Name="Vigor Siphon",          Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Opal.ToNumber()]         = { PropertyName="GearManasteal",       Name="Ophidian",              Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.WhiteJade.ToNumber()]    = { PropertyName="GearHealBubble",      Name="Purified Soul",         Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=2, BonusSecondary=0.1 },
  [MaterialType.RoseQuartz.ToNumber()]   = { PropertyName="GearVitalsTransfer",  Name="Tilted-scales",         Slot="weapon",          BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Ruby.ToNumber()]         = { PropertyName="GearRedFury",         Name="Red Fury",              Slot="weapon",          BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Jet.ToNumber()]          = { PropertyName="GearLightning",       Name="Astyrrian Rage",        Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=2, BonusSecondary=0.1 },
  [MaterialType.RedGarnet.ToNumber()]    = { PropertyName="GearFire",            Name="Blazing Brand",         Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=2, BonusSecondary=0.1 },
  [MaterialType.Aquamarine.ToNumber()]   = { PropertyName="GearFrost",           Name="Bone-chiller",          Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=2, BonusSecondary=0.1 },
  [MaterialType.Emerald.ToNumber()]      = { PropertyName="GearAcid",            Name="Devouring Mist",        Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=2, BonusSecondary=0.1 },
  [MaterialType.ImperialTopaz.ToNumber()]= { PropertyName="GearSlash",           Name="Falcon's Gyre",         Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.BlackGarnet.ToNumber()]  = { PropertyName="GearPierce",          Name="Precision Strikes",     Slot="weapon",          BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.WhiteSapphire.ToNumber()]= { PropertyName="GearBludgeon",        Name="Skull-cracker",         Slot="weapon",          BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.LapisLazuli.ToNumber()]  = { PropertyName="GearBlueFury",        Name="Blue Fury",             Slot="weapon",          BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Amber.ToNumber()]        = { PropertyName="GearYellowFury",      Name="Yellow Fury",           Slot="weapon",          BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.YellowGarnet.ToNumber()] = { PropertyName="GearBravado",         Name="Bravado",               Slot="weapon or shield", BasePrimary=20, BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.FireOpal.ToNumber()]     = { PropertyName="GearFamiliarity",     Name="Familiar Foe",          Slot="weapon or shield", BasePrimary=20, BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.BlackOpal.ToNumber()]    = { PropertyName="GearReprisal",        Name="Vicious Reprisal",      Slot="weapon or shield", BasePrimary=5,  BonusPrimary=0.25, BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.GreenGarnet.ToNumber()]  = { PropertyName="GearElementalist",    Name="Elementalist",          Slot="wand",            BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.Tourmaline.ToNumber()]   = { PropertyName="GearWardPen",         Name="Ruthless Discernment",  Slot="wand",            BasePrimary=20,  BonusPrimary=1.0,  BaseSecondary=0, BonusSecondary=0.0 },
  [MaterialType.LavenderJade.ToNumber()] = { PropertyName="GearSelflessness",    Name="Selfless Spirit",       Slot="wand",            BasePrimary=10,  BonusPrimary=0.5,  BaseSecondary=0, BonusSecondary=0.0 },
}

function ItemExamine_Daralet:GetJewelDescription(jewel)
  jewel = self.item
  local quality     = jewel.IntValues["JewelQuality"] or 1
  local materialType = jewel.IntValues["JewelMaterialType"]

  if jewel.StringValues["LegacyJewelSocketString1"] ~= nil and
     jewel.StringValues["LegacyJewelSocketString1"] ~= "Empty" then
    local parts = {}
    for p in string.gmatch(jewel.StringValues["LegacyJewelSocketString1"], "[^/]+") do
      table.insert(parts, p)
    end
    local mt = parts[2] and StringToMaterialType[parts[2]]
    if mt then materialType = mt; jewel.IntValues["JewelMaterialType"] = mt end
    local q  = parts[1] and JewelQualityStringToValue[parts[1]]
    if q  then quality     = q;  jewel.IntValues["JewelQuality"]      = q  end
    jewel.JewelSocket1 = nil
  end

  if materialType == nil then return "" end

  local name, equipmentType, baseRating, bonusPerQuality = "", "", 0, 0.0
  local baseRatingSecondary, bonusPerQualitySecondary    = 0, 0.0
  local mi = JewelEffectInfoMain[materialType]
  if mi then
    name, equipmentType = mi.Name, mi.Slot
    baseRating, bonusPerQuality = mi.BasePrimary, mi.BonusPrimary
    baseRatingSecondary, bonusPerQualitySecondary = mi.BaseSecondary, mi.BonusSecondary
  end

  local nameAlternate, equipmentTypeAlternate = "", ""
  local baseRatingAlternate, bonusPerQualityAlternate = 0, 0.0
  local ai = JewelEffectInfoAlternate[materialType]
  if ai then
    nameAlternate, equipmentTypeAlternate = ai.Name, ai.Slot
    baseRatingAlternate, bonusPerQualityAlternate = ai.BasePrimary, ai.BonusPrimary
  end

  local alternateText = nameAlternate ~= "" and
    string.format(" OR in a %s to gain %s", equipmentTypeAlternate, nameAlternate) or ""

  local description = string.format(
    "Socket this jewel in a %s to gain %s%s, while equipped. The target must be workmanship %d or greater.\n\n",
    equipmentType, name, alternateText, quality)

  local MT = MaterialType

  local function fmt1(n, b, m) return string.format("~ %s: Gain %d%%%% increased experience from monster kills (+%.2f%%%% per equipped rating).\n\n", n, b, m) end

  if     materialType == MT.Sunstone    then description = description .. string.format("~ %s: Gain %d%%%% increased experience from monster kills (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Sapphire    then description = description .. string.format("~ %s: Gain a %d%%%% bonus to loot quality from monster kills (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.GreenJade   then description = description .. string.format("~ %s: Gain a %d%%%% chance to receive an extra item from monster kills (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Carnelian   then description = description .. string.format("~ %s: Gain %d Strength (+%.0f%%%% per equipped rating). Once socketed, the %s can only be worn on the right finger.\n\n", name, baseRating, bonusPerQuality, equipmentType) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Azurite     then description = description .. string.format("~ %s: Gain %d Self (+%.0f%%%% per equipped rating). Once socketed, the %s can only be worn on the right finger.\n\n", name, baseRating, bonusPerQuality, equipmentType) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.TigerEye    then description = description .. string.format("~ %s: Gain %d Coordination (+%.0f%%%% per equipped rating). Once socketed, the %s can only be worn on the right finger.\n\n", name, baseRating, bonusPerQuality, equipmentType) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.RedJade     then description = description .. string.format("~ %s: Gain %d Focus (+%.0f%%%% per equipped rating). Once socketed, the %s can only be worn on the left finger.\n\n", name, baseRating, bonusPerQuality, equipmentType) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.YellowTopaz then description = description .. string.format("~ %s: Gain %d Endurance (+%.0f%%%% per equipped rating). Once socketed, the %s can only be worn on the left finger.\n\n", name, baseRating, bonusPerQuality, equipmentType) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Peridot     then description = description .. string.format("~ %s: Gain %d Quickness (+%.0f%%%% per equipped rating). Once socketed, the %s can only be worn on the left finger.\n\n", name, baseRating, bonusPerQuality, equipmentType) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Agate       then description = description .. string.format("~ %s: Gain %d increased threat from your actions (+%.0f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the left wrist.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.SmokeyQuartz then description = description .. string.format("~ %s: Gain %d reduced threat from your actions (+%.0f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the left wrist.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Moonstone   then description = description .. string.format("~ %s: Gain %d%%%% reduced mana consumed by items (+%.0f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the left wrist.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Malachite   then description = description .. string.format("~ %s: Gain %d%%%% reduced chance to burn spell components (+%.0f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the left wrist.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Onyx        then description = description .. string.format("~ %s: Gain %d%%%% reduced damage taken from slashing, bludgeoning, and piercing damage types (+%.0f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the right wrist.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Zircon      then description = description .. string.format("~ %s: Gain %d%%%% reduced damage taken from acid, fire, cold, and electric damage types (+%.0f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the right wrist.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Amethyst    then description = description .. string.format("~ %s: Gain up to %d%%%% reduced magic damage taken (+%.0f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently been hit with a damaging spell. Once socketed, the bracelet can only be worn on the right wrist.\n\n", name, baseRating, bonusPerQuality) .. string.format("~ %s: Gain +%d Physical Defense (+%.0f per equipped rating).\n\n", nameAlternate, baseRatingAlternate, bonusPerQualityAlternate) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. "\n\n"
  elseif materialType == MT.Diamond     then description = description .. string.format("~ %s: Gain up to %d%%%% reduced physical damage taken (+%.0f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently been hit with a damaging physical attack. Once socketed, the bracelet can only be worn on the right wrist.\n\n", name, baseRating, bonusPerQuality) .. string.format("~ %s: Gain +%d Physical Defense (+%.0f per equipped rating).\n\n", nameAlternate, baseRatingAlternate, bonusPerQualityAlternate) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. "\n\n"
  elseif materialType == MT.Turquoise   then description = description .. string.format("~ %s: Gain %d%%%% increased block chance (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.WhiteQuartz then description = description .. string.format("~ %s: Deflect %d%%%% damage from a blocked attack back to a close-range attacker (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.BlackOpal   then description = description .. string.format("~ %s: Gain a %d%%%% chance to evade a critical attack (+%.0f%%%% per equipped rating). Your next attack after a the evade is a guaranteed critical.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.FireOpal    then description = description .. string.format("~ %s: Gain up to %d%%%% increased evade and resist chances, against the target you are attacking (+%.0f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.YellowGarnet then description = description .. string.format("~ %s: Gain up to %d%%%% increased physical attack skill (+%.0f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Ruby        then description = description .. string.format("~ %s: Gain up to %d%%%% increased damage as your health approaches 0 (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Amber       then description = description .. string.format("~ %s: Gain up to %d%%%% increased damage as your stamina approaches 0 (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. string.format("~ %s: Gain a %d%%%% chance after taking damage to gain the same amount as stamina (+%.0f per equipped rating).\n\n", nameAlternate, baseRatingAlternate, bonusPerQualityAlternate) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.LapisLazuli then description = description .. string.format("~ %s: Gain up to %d%%%% increased damage as your mana approaches 0 (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. string.format("~ %s: Gain a %d%%%% chance after taking damage to gain the same amount as mana (+%.0f per equipped rating).\n\n", nameAlternate, baseRatingAlternate, bonusPerQualityAlternate) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Bloodstone  then description = description .. string.format("~ %s: Gain a %d%%%% chance on hit to gain health (+%.0f%%%% per equipped rating). Amount stolen is equal to 10%%%% of damage dealt.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Citrine     then description = description .. string.format("~ %s: Gain %d%%%% chance on hit to gain stamina (+%.0f%%%% per equipped rating). Amount stolen is equal to 10%%%% of damage dealt.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Opal        then description = description .. string.format("~ %s: Gain a %d%%%% chance on hit to gain mana (+%.0f%%%% per equipped rating). Amount stolen is equal to 10%%%% of damage dealt.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Hematite    then description = description .. string.format("~ %s: Gain %d%%%% increased damage with all attacks (+%.0f%%%% per equipped rating). However, 10%%%% of your attacks will deal the extra damage to yourself as well.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.RoseQuartz  then description = description .. string.format("~ %s: Gain a %d%%%% bonus to your transfer spells (+%.0f%%%% per equipped rating). Receive an equivalent reduction in the effectiveness of your other restoration spells.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.LavenderJade then description = description .. string.format("~ %s: Gain a %d%%%% bonus to your restoration spells on others (+%.0f%%%% per equipped rating). Receive an equivalent reduction in the effectiveness when cast on yourself.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.GreenGarnet then description = description .. string.format("~ %s: Gain up to %d%%%% increased war magic damage (+%.0f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Tourmaline  then description = description .. string.format("~ %s: Gain up to %d%%%% ward cleaving (+%.0f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.\n\n", name, baseRating, bonusPerQuality) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.WhiteJade   then description = description .. string.format("~ %s: Gain a %d%%%% bonus to your restoration spells (+%.0f%%%% per equipped rating). Also grants a %d%%%% chance to create a sphere of healing energy on top of your target when casting a restoration spell (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. "\n\n"
  elseif materialType == MT.Aquamarine  then description = description .. string.format("~ %s: Gain %d%%%% increased cold damage (+%.0f%%%% per equipped rating). Also grants a %d%%%% chance to surround your target with chilling mist (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) .. string.format("~ %s: Gain +%.0f Frost Protection to all equipped armor (+%.0f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).\n\n", nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary, nameAlternate) .. "\n\n"
  elseif materialType == MT.BlackGarnet then description = description .. string.format("~ %s: Gain %d%%%% piercing resistance penetration (+%.0f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.\n\n", name, baseRating, bonusPerQuality) .. string.format("~ %s: Gain +%.0f Piercing Protection to all equipped armor (+%.0f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).\n\n", nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. "\n\n"
  elseif materialType == MT.Emerald     then description = description .. string.format("~ %s: Gain %d%%%% increased acid damage (+%.0f%%%% per equipped rating). Also grants a %d%%%% chance to surround your target with acidic mist (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) .. string.format("~ %s: Gain +%.0f Acid Protection to all equipped armor (+%.0f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).\n\n", nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary, nameAlternate) .. "\n\n"
  elseif materialType == MT.ImperialTopaz then description = description .. string.format("~ %s: Gain a %d%%%% chance to cleave an additional target (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality) .. string.format("~ %s: Gain +%.0f Slashing Protection to all equipped armor (+%.0f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).\n\n", nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. "\n\n"
  elseif materialType == MT.Jet         then description = description .. string.format("~ %s: Gain %d%%%% increased electric damage (+%.0f%%%% per equipped rating). Also grants a %d%%%% chance to electrify the ground beneath your target (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) .. string.format("~ %s: Gain +%.0f Lightning Protection to all equipped armor (+%.0f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).\n\n", nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary, nameAlternate) .. "\n\n"
  elseif materialType == MT.RedGarnet   then description = description .. string.format("~ %s: Gain %d%%%% increased fire damage (+%.0f%%%% per equipped rating). Also grants a %d%%%% chance to set the ground beneath your target ablaze (+%.0f%%%% per equipped rating).\n\n", name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) .. string.format("~ %s: Gain +%.0f Flame Protection to all equipped armor (+%.0f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).\n\n", nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary, nameAlternate) .. "\n\n"
  elseif materialType == MT.WhiteSapphire then description = description .. string.format("~ %s: Gain %d%%%% bludgeon critical damage (+%.0f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.\n\n", name, baseRating, bonusPerQuality) .. string.format("~ %s: Gain +%.0f Bludgeoning Protection to all equipped armor (+%.0f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).\n\n", nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) .. JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. "\n\n"
  end

  return description
end

local function GetSocketDescription(materialType, quality)
  return string.format("\n  Socket: %s (%d)\n", StringToMaterialType[materialType], quality)
end

function ItemExamine_Daralet:SetJewelcraftingUseText()
  self._hasExtraPropertiesText = true
  if self.item.IntValues["JewelQuality"] ~= nil then -- is jewel
    self._extraPropertiesText = (self._extraPropertiesText or "") .. self:GetJewelDescription()
  else
    local sockets = self.item.IntValues["JewelSockets"] or 0
    for i = 1, sockets do
      local mat = self.item.IntValues["JewelSocket"..i.."Material"]
      local q   = self.item.IntValues["JewelSocket"..i.."Quality"]

      if i == 1 then
        for _, key in ipairs({"LegacyJewelSocketString1","LegacyJewelSocketString2"}) do
          local s = self.item.StringValues[key]
          if s and s ~= "Empty" then
            local parts = {}
            for p in string.gmatch(s, "([^/]+)") do table.insert(parts, p) end
            local mt2 = parts[2] and StringToMaterialType[parts[2]]
            local q2  = parts[1] and JewelQualityStringToValue[parts[1]]
            if mt2 then mat = mt2 end
            if q2  then q   = q2  end
          end
        end
      end

      if not mat or mat < 1 or not q or q < 1 then
        self._extraPropertiesText = (self._extraPropertiesText or "") .. "\n    Empty Jewel Socket\n\n"
      else
        self._extraPropertiesText = (self._extraPropertiesText or "") .. GetSocketDescription(mat, q)
      end
    end
  end
end

function ItemExamine_Daralet:SetDamagePenaltyUseText()
  local dr = self.item.IntValues["DamageRating"]
  if not dr or dr >= 0 then return end
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Damage Penalty: %d%%\n", dr)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:GetEquippedItemsSkillModSum(skillMod)
  local v = self.equippedItemsSkillModCache and self.equippedItemsSkillModCache[skillMod]
  if v ~= nil then return v end
  return 0
end

function ItemExamine_Daralet:SetArmorModUseText(floatString, floatVal, text, totalMod, multiplierOne, multiplierTwo)
  multiplierOne = multiplierOne or 100.0
  multiplierTwo = multiplierTwo or 100.0
  if not floatVal or floatVal < 0.001 then return end
  local wielder = self.item.Wielder and self.item.Wielder.Id == game.CharacterId
  local mod = math.floor(floatVal * multiplierOne * 10 + 0.5) / 10
  local finalText = string.gsub(text, "%(ONE%)", tostring(mod))
  if wielder and totalMod and totalMod ~= 0.0 then
    totalMod = math.floor(totalMod * multiplierTwo * 100 + 0.5) / 100
    finalText = finalText .. string.format("  (%.2f%%%%)", totalMod)
  end
  self._extraPropertiesText = (self._extraPropertiesText or "") .. finalText .. "\n"
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetJewelryManaConUseText()
  local v = self.item.FloatValues["ManaConversionMod"]
  if not v or v < 0.001 then return end
  if self.item.ObjectType == ObjectType.Jewelry or
     self.item.ObjectType == ObjectType.Armor   or
     self.item.ObjectType == ObjectType.Clothing then
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("Bonus to Mana Conversion Skill: +%.1f%%%%\n", v * 100)
  end
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetArmorResourcePenaltyUseText()
  local v = self.item.FloatValues["ArmorResourcePenalty"]
  if not v or v < 0.001 then return end
  local wielder = self.item.Wielder and self.item.Wielder.Id == game.CharacterId
  if wielder then
    local total = self:GetEquippedItemsSkillModSum("ArmorResourcePenalty")
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("Penalty to Stamina/Mana usage: %.1f%%%%  (%.2f%%%%)\n", v * 100, total * 100)
  else
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("Penalty to Stamina/Mana usage: %.1f%%%%\n", v * 100)
  end
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetArmorWardLevelUseText()
  local wl = self.item.IntValues["WardLevel"]
  if not wl or wl == 0 then return end
  local wielder = self.item.Wielder and self.item.Wielder.Id == game.CharacterId
  if wielder then
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("Ward Level: %d  (%d)\n", wl, self:GetEquippedItemsWardSum("WardLevel"))
  else
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("Ward Level: %d\n", wl)
  end
  self._hasExtraPropertiesText = true
end

local ArmorWeightClass = { None=0, Cloth=1, Light=2, Heavy=4 }

function ItemExamine_Daralet:SetArmorWeightClassUseText()
  local wc = self.item.IntValues["ArmorWeightClass"]
  if not wc or wc <= 0 then return end
  local labels = { [1]="Cloth", [2]="Light", [4]="Heavy" }
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Weight Class: %s\n", labels[wc] or "Unknown")
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetBowElementalWarningUseText()
  local dt = self.item.IntValues["DamageType"]
  if not dt or dt == DamageType.Slashing - 1 then return end
  local cs = self.item.IntValues["DefaultCombatStyle"]
  if not (cs == 0x00010 or cs == 0x00020 or cs == 0x00400) then return end
  local elements = {
    [DamageType.Slashing]    = "slashing",
    [DamageType.Piercing]    = "piercing",
    [DamageType.Bludgeoning] = "bludgeoning",
    [DamageType.Acid]        = "acid",
    [DamageType.Fire]        = "fire",
    [DamageType.Cold]        = "cold",
    [DamageType.Electric]    = "electric",
  }
  local element = elements[dt] or ""
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("\nThe Damage Modifier on this weapon only applies to %s damage.\n", element)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponRestoModUseText()
  local v = self.item.FloatValues["WeaponRestorationSpellsMod"]
  if not v or v < 1.001 then return end
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Healing Bonus for Restoration Spells: +%.1f%%%%\n", (v - 1) * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponMagicDefenseUseText()
  local v = self.item.FloatValues["WeaponMagicalDefense"]
  if not v or v <= 1.001 then return end
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Bonus to Magic Defense: +%.1f%%%%\n", (v - 1) * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponPhysicalDefenseUseText()
  local v = self.item.FloatValues["WeaponPhysicalDefense"]
  if not v or v <= 1.001 then return end
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Bonus to Physical Defense: +%.1f%%%%\n", (v - 1) * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponLifeMagicUseText()
  local v = self.item.FloatValues["WeaponLifeMagicMod"]
  if not v or v < 0.001 then return end
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Bonus to Life Magic Skill: +%.1f%%%%\n", v * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponWarMagicUseText()
  local v = self.item.FloatValues["WeaponWarMagicMod"]
  if not v or v < 0.001 then return end
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Bonus to War Magic Skill: +%.1f%%%%\n", v * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetBowAttackModUseText()
  local v = self.item.FloatValues["WeaponOffense"]
  if not v or v <= 1.001 then return end
  local ws = self.item.IntValues["WeaponSkill"]
  if ws == SkillId.Bow or ws == SkillId.Crossbow or ws == SkillId.MissleWeapons then
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("Bonus to Attack Skill: +%.1f%%%%\n", (v - 1) * 100)
  end
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetAmmoEffectUseText()
  local uses = self.item.IntValues["AmmoEffectUsesRemaining"]
  if not uses or uses <= 0 then return end
  local effect = self.item.IntValues["AmmoEffect"]
  if not effect or effect < 0 then return end
  local effectStr = tostring(effect == 0 and "Sharpened" or effect)
  effectStr = effectStr:gsub("(%u)", " %1"):gsub("^ ", "")
  if self.item.WeenieType == WeenieType.Ammunition then
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("Ammo Effect: %s\nEffect Uses Remaining: %d\n", effectStr, uses)
    if effect == 0 then
      self._additionalPropertiesLongDescriptionsText =
        (self._additionalPropertiesLongDescriptionsText or "") .. "~Sharpened: Increases damage by 10%%."
    end
    self._hasExtraPropertiesText = true
  end
end

function ItemExamine_Daralet:SetSpellProcRateUseText()
  local v = self.item.FloatValues["ProcSpellRate"]
  if not v or v <= 0.0 then return end
  if not self.item.DataValues["ProcSpell"] then return end
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Cast on strike chance: %.1f%%%%\n", v * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetAdditionalPropertiesUseText()
  if not self._hasAdditionalProperties then return end
  local s = table.concat(self._additionalPropertiesList, ", ")
  local oomText = self.item.IntValues["ItemWorkmanship"] ~= nil and "" or
    "This item's properties will not activate if it is out of mana"
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format("Additional Properties: %s.\n\n%s\n\n", s, oomText)
  self._hasExtraPropertiesText = true
end

local function GetTierFromWieldDifficulty(wd)
  return ({ [50]=1,[125]=2,[175]=3,[200]=4,[215]=5,[230]=6,[250]=7,[270]=8 })[wd] or 1
end
local StaminaCostReductionPerTier  = {0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.075, 0.1}
local BonusCritChancePerTier       = {0.0, 0.01, 0.015, 0.02, 0.025, 0.03, 0.4, 0.05}
local BonusCritMultiplierPerTier   = {0.0, 0.01, 0.015, 0.02, 0.025, 0.03, 0.4, 0.05}

function ItemExamine_Daralet:SetStaminaReductionUseLongText()
  local v = self.item.FloatValues["StaminaCostReductionMod"]
  if not v or v <= 0.001 then return end
  table.insert(self._additionalPropertiesList, "Stamina Cost Reduction")
  local rating  = math.floor(v * 100 + 0.5)
  local tier    = GetTierFromWieldDifficulty(self.item.IntValues["WieldDifficulty"] or 1)
  local rangeMin = math.floor(StaminaCostReductionPerTier[tier] * 100 + 0.5)
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ Stamina Cost Reduction: Reduces stamina cost of attack by %d%%%%. Roll range is based on item tier (%d%%%% to %d%%%%).\n",
      rating, rangeMin, rangeMin + 10)
end

function ItemExamine_Daralet:SetBitingStrikeUseLongText()
  local v = self.item.FloatValues["CriticalFrequency"]
  if not v or v <= 0.0 then return end
  local rating   = math.floor((v - 0.1) * 100 + 0.5)
  local tier     = GetTierFromWieldDifficulty(self.item.IntValues.WieldDifficulty or 1)
  local rangeMin = math.floor(BonusCritChancePerTier[tier] * 100 + 0.5)
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ Biting Strike: Increases critical chance by +%d%%%%, additively. Roll range is based on item tier (%d%%%% to %d%%%%).\n",
      rating, rangeMin, rangeMin + 5)
end

function ItemExamine_Daralet:SetCriticalStrikeUseLongText()
  if self.item.IntValues["ImbuedEffect"] ~= ImbuedEffectType.CriticalStrike then return end
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    "~ Critical Strike: Increases critical chance by 5%%%% to 10%%%%)), additively.\nValue is based on wielder attack skill, up to 500 base.\n"
end

function ItemExamine_Daralet:SetCrushingBlowUseLongText()
  local v = self.item.FloatValues["CriticalMultiplier"]
  if not v or v <= 1 then return end
  local rating   = math.floor((v - 1) * 100 + 0.5)
  local tier     = GetTierFromWieldDifficulty(self.item.IntValues["WieldDifficulty"] or 1)
  local rangeMin = math.floor(BonusCritMultiplierPerTier[tier] * 100 + 0.5)
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ Crushing Blow: Increases critical damage by +%d%%%%, additively. Roll range is based on item tier (%d%%%% to %d%%%%).\n",
      rating, rangeMin, rangeMin + 50)
end

function ItemExamine_Daralet:SetCripplingBlowUseLongText()
  if self.item.IntValues["ImbuedEffect"] ~= ImbuedEffectType.CripplingBlow then return end
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    "~ Crippling Blow: Increases critical damage by 50%%%% to 100%%%%)), additively.\nValue is based on wielder attack skill, up to 500 base.\n"
end

local BonusIgnoreArmorPerTier = {0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.075, 0.1}
function ItemExamine_Daralet:SetArmorCleavingUseLongText()
  local v = self.item.FloatValues["IgnoreArmor"]
  if not v or v == 0 then return end
  local rating   = 100 - math.floor(v * 100 + 0.5)
  local tier     = GetTierFromWieldDifficulty(self.item.IntValues["WieldDifficulty"] or 1)
  local rangeMin = 10 + math.floor(BonusIgnoreArmorPerTier[tier] * 100 + 0.5)
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ Armor Cleaving: Increases armor ignored by %d%%%%, additively. Roll range is based on item tier (%d%%%% to %d%%%%)\n",
      rating, rangeMin, rangeMin + 10)
end

function ItemExamine_Daralet:SetArmorRendUseLongText()
  if self.item.IntValues["ImbuedEffect"] ~= ImbuedEffectType.ArmorRending then return end
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    "~ Armor Rending: Increases armor ignored by 10%%%% to 20%%%%)), additively.\nValue is based on wielder attack skill, up to 500 base.\n"
end

function ItemExamine_Daralet:SetResistanceCleavingUseLongText()
  local v = self.item.FloatValues["ResistanceModifier"]
  if not v or v == 0 then return end
  local rating = math.floor(v * 100 + 0.5)
  local elementMap = {
    [DamageType.Acid]        = "Acid",
    [DamageType.Bludgeoning] = "Bludgeoning",
    [DamageType.Cold]        = "Cold",
    [DamageType.Electric]    = "Lightning",
    [DamageType.Fire]        = "Fire",
    [DamageType.Piercing]    = "Piercing",
    [DamageType.Slashing]    = "Slashing",
  }
  local element = elementMap[self.item.IntValues["ResistanceModifierType"]] or ""
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ Resistance Cleaving (%s): Increases %s damage by +%d%%%%, additively.\n",
      element, string.lower(element), rating)
end

function ItemExamine_Daralet:SetResistanceRendLongText(imbuedEffectType, elementName)
  if self.item.IntValues["ImbuedEffect"] ~= imbuedEffectType then return end
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ %s Rending: Increases %s damage by 15%%%% to 30%%%%)), additively.\nValue is based on wielder attack skill, up to 500 base.\n",
      elementName, string.lower(elementName))
end

local BonusIgnoreWardPerTier = {0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.075, 0.1}
function ItemExamine_Daralet:SetWardCleavingUseLongText()
  local v = self.item.FloatValues["IgnoreWard"]
  if not v or v == 0 then return end
  table.insert(self._additionalPropertiesList, "Ward Cleaving")
  local rating   = 100 - math.floor(v * 100 + 0.5)
  local tier     = GetTierFromWieldDifficulty(self.item.IntValues["WieldDifficulty"] or 1)
  local rangeMin = 10 + math.floor(BonusIgnoreWardPerTier[tier] * 100 + 0.5)
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ Ward Cleaving: Increases ward ignored by %d%%%%, additively. Roll range is based on item tier (%d%%%% to %d%%%%).\n",
      rating, rangeMin, rangeMin + 10)
end

function ItemExamine_Daralet:SetWardRendingUseLongText()
  if self.item.IntValues["ImbuedEffect"] ~= 0x8000 then return end
  table.insert(self._additionalPropertiesList, "Ward Rending")
  self._hasExtraPropertiesText = true
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    "~ Ward Rending: Increases ward ignored by 10%%%% to 20%%%%)), additively.\nValue is based on wielder attack skill, up to 500 base.\n"
end

function ItemExamine_Daralet:SetNoCompsRequiredSchoolUseLongText()
  local v = self.item.IntValues["NoCompsRequiredForMagicSchool"]
  if not v or v == 0 then return end
  local entries = {
    [MagicSchool.WarMagic]      = { "War Primacy",    "War Magic spells cast do not require or consume components. Spells from other schools cannot be cast."    },
    [MagicSchool.LifeMagic]     = { "Life Primacy",   "Life Magic spells cast do not require or consume components. Spells from other schools cannot be cast."   },
    [MagicSchool.ItemEnchantment]={ "Portal Primacy", "Portal Magic spells cast do not require or consume components. Spells from other schools cannot be cast." },
  }
  local entry = entries[v]
  if not entry then return end
  table.insert(self._additionalPropertiesList, entry[1])
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") .. "~ " .. entry[1] .. ": " .. entry[2]
  self._hasExtraPropertiesText  = true
  self._hasAdditionalProperties = true
end

local function GetProtectionLevelText(v)
  if     v <= 0.39 then return "Poor"
  elseif v <= 0.79 then return "Below Average"
  elseif v <= 1.19 then return "Average"
  elseif v <= 1.59 then return "Above Average"
  else                   return "Unparalleled"
  end
end

function ItemExamine_Daralet:SetProtectionLevelsUseText()
  local al = self.item.IntValues["ArmorLevel"]
  if not al or al ~= 0 or self.item.IntValues["ArmorWeightClass"] ~= ArmorWeightClass.Cloth then return end
  local function get(k) return self.item.FloatValues[k] or 1.0 end
  local function fmt(v) return string.format("%0.2f", v) end
  local resists = {
    {"Slashing",    get("ArmorModVsSlash")},
    {"Piercing",    get("ArmorModVsPierce")},
    {"Bludgeoning", get("ArmorModVsBludgeon")},
    {"Fire",        get("ArmorModVsFire")},
    {"Cold",        get("ArmorModVsCold")},
    {"Acid",        get("ArmorModVsAcid")},
    {"Electric",    get("ArmorModVsElectric")},
  }
  for _, r in ipairs(resists) do
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format("%s: %s (%s)\n", r[1], GetProtectionLevelText(r[2]), fmt(r[2]))
  end
  self._extraPropertiesText = self._extraPropertiesText .. "\n"
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:GetJewelRating(intStringName)
  local total   = 0
  local sockets = self.item.IntValues["JewelSockets"] or 0
  for i = 1, sockets do
    local mat  = self.item.IntValues["JewelSocket"..i.."Material"]
    local q    = self.item.IntValues["JewelSocket"..i.."Quality"]
    local alt  = self.item.BoolValues["JewelSocket"..i.."AlternateEffect"]
    if mat and q and alt ~= nil then
      local mt = self.JewelMaterialToType[mat]
      if not (alt ~= true and mt.PrimaryRating ~= intStringName) and
         not (alt == true and mt.AlternateRating ~= intStringName) then
        total = total + q
      end
    end
  end
  return total
end

function ItemExamine_Daralet:SetGearRatingText(intStringName, intVal, name, description, multiplierOne, multiplierTwo, baseOne, baseTwo, percent)
  multiplierOne = multiplierOne or 1.0
  multiplierTwo = multiplierTwo or 1.0
  baseOne       = baseOne or 0.0
  baseTwo       = baseTwo or 0.0
  percent       = percent or false

  local itemRating  = intVal or 0
  local jewelRating = self:GetJewelRating(intStringName)
  local total       = itemRating + jewelRating
  if total < 1 then return end

  table.insert(self._additionalPropertiesList, string.format("%s %s", name, tostring(total)))
  self._hasAdditionalProperties = true

  local allEquipped  = self:GetEquippedAndActivatedItemRatingSum("IntValues", intStringName)
  local percentSign  = percent and "%%%%" or ""
  local amountOne    = math.floor((baseOne + allEquipped * multiplierOne) * 100 + 0.5) / 100
  local amountTwo    = math.floor((baseTwo + allEquipped * multiplierTwo) * 100 + 0.5) / 100
  local desc         = description
  desc = string.gsub(desc, "ONE%)", tostring(amountOne) .. percentSign)
  desc = string.gsub(desc, "TWO%)", tostring(amountTwo) .. percentSign)
  self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ %s: %s\n", name, desc)
end

function ItemExamine_Daralet:SetWeaponSpellcraftText()
  if self.item.IntValues["ItemCurMana"] ~= nil then return end
  local sc = self.item.IntValues["ItemSpellcraft"]
  if not sc then return end
  self._extraPropertiesText = self._extraPropertiesText .. "\nSpellcraft: " .. sc .. "."
  self.item.StringValues["Use"] = self._extraPropertiesText
end

local MaterialValidLocations = {
  [MaterialType.Tourmaline.ToNumber()]=0x01000000, [MaterialType.GreenGarnet.ToNumber()]=0x01000000, [MaterialType.LavenderJade.ToNumber()]=0x01000000,
  [MaterialType.Opal.ToNumber()]=0x03500000, [MaterialType.RoseQuartz.ToNumber()]=0x03500000, [MaterialType.Hematite.ToNumber()]=0x03500000,
  [MaterialType.Bloodstone.ToNumber()]=0x03500000, [MaterialType.WhiteJade.ToNumber()]=0x03500000,
  [MaterialType.ImperialTopaz.ToNumber()]=0x03507F21, [MaterialType.BlackGarnet.ToNumber()]=0x03507F21, [MaterialType.Jet.ToNumber()]=0x03507F21,
  [MaterialType.RedGarnet.ToNumber()]=0x03507F21, [MaterialType.Aquamarine.ToNumber()]=0x03507F21, [MaterialType.WhiteSapphire.ToNumber()]=0x03507F21,
  [MaterialType.Emerald.ToNumber()]=0x03507F21, [MaterialType.Amber.ToNumber()]=0x03507F21, [MaterialType.LapisLazuli.ToNumber()]=0x03507F21,
  [MaterialType.WhiteQuartz.ToNumber()]=0x00200000, [MaterialType.Turquoise.ToNumber()]=0x00200000,
  [MaterialType.Ruby.ToNumber()]=0x03700000, [MaterialType.BlackOpal.ToNumber()]=0x03700000, [MaterialType.FireOpal.ToNumber()]=0x03700000,
  [MaterialType.YellowGarnet.ToNumber()]=0x03700000,
  [MaterialType.SmokeyQuartz.ToNumber()]=0x00030000, [MaterialType.Agate.ToNumber()]=0x00030000, [MaterialType.Moonstone.ToNumber()]=0x00030000,
  [MaterialType.Citrine.ToNumber()]=0x00030000, [MaterialType.Malachite.ToNumber()]=0x00030000,
  [MaterialType.Onyx.ToNumber()]=0x00030000, [MaterialType.Zircon.ToNumber()]=0x00030000,
  [MaterialType.Diamond.ToNumber()]=0x00037F21, [MaterialType.Amethyst.ToNumber()]=0x00037F21,
  [MaterialType.Peridot.ToNumber()]=0x000C0000, [MaterialType.RedJade.ToNumber()]=0x000C0000, [MaterialType.YellowTopaz.ToNumber()]=0x000C0000,
  [MaterialType.Carnelian.ToNumber()]=0x000C0000, [MaterialType.Azurite.ToNumber()]=0x000C0000, [MaterialType.TigerEye.ToNumber()]=0x000C0000,
  [MaterialType.Sapphire.ToNumber()]=0x00008000, [MaterialType.Sunstone.ToNumber()]=0x00008000, [MaterialType.GreenJade.ToNumber()]=0x00008000,
}

function ItemExamine_Daralet:AddItemToCaches(wo)
  local item = AppraiseInfo[wo.Id]
  if not item then return end
  if self.equippedItems[wo.Id] then
    self:RemoveItemFromEquippedItemsRatingCache(wo)
    self:RemoveItemFromEquippedItemsSkillModCache(wo)
    self.equippedItems[wo.Id] = false
  end
  for _, p in pairs(RATING_PROPERTIES) do
    self.equippedItemsRatingCache[p] = (self.equippedItemsRatingCache[p] or 0) + (item.IntValues[p] or 0)
  end
  for _, p in pairs(SKILLMOD_PROPERTIES) do
    self.equippedItemsSkillModCache[p] = (self.equippedItemsSkillModCache[p] or 0.0) + (item.FloatValues[p] or 0.0)
  end
  self.equippedItems[wo.Id] = true
end

function ItemExamine_Daralet:RemoveItemFromEquippedItemsSkillModCache(wo)
  local item = AppraiseInfo[wo.Id]
  if not self.equippedItems[wo.Id] then return end
  for _, p in pairs(SKILLMOD_PROPERTIES) do
    self.equippedItemsSkillModCache[p] = (self.equippedItemsSkillModCache[p] or 0.0) - (item.FloatValues[p] or 0.0)
  end
end

function ItemExamine_Daralet:RemoveItemFromEquippedItemsRatingCache(wo)
  local item = AppraiseInfo[wo.Id]
  if not item or not self.equippedItems[wo.Id] then return end
  for _, p in pairs(RATING_PROPERTIES) do
    self.equippedItemsRatingCache[p] = (self.equippedItemsRatingCache[p] or 0) - (item.IntValues[p] or 0)
  end
end

function ItemExamine_Daralet:GetEquippedItemsWardSum(wardLevel)
  return self:GetEquippedItemsRatingSum(wardLevel)
end

function ItemExamine_Daralet:GetEquippedItemsRatingSum(propString)
  for _, gear in pairs(game.Character.Equipment) do
    if self.equippedItems[gear.Id] == nil and AppraiseInfo[gear.Id] ~= nil then
      self:AddItemToCaches(gear)
    end
  end
  local v = self.equippedItemsRatingCache[propString]
  return v ~= nil and v or 0
end

function ItemExamine_Daralet:GetEquippedAndActivatedItemRatingSum(propertyType, propertyString)
  local total = 0
  for _, wo in pairs(game.Character.Equipment) do
    local item = AppraiseInfo[wo.Id]
    if item and item.BoolValues and item.IntValues and
       (not item.BoolValues["SpecialPropertiesRequireMana"] or
        (item.IntValues["ItemCurMana"] and item.IntValues["ItemCurMana"] > 0)) then
      total = total + (item[propertyType][propertyString] or 0)
      total = total + self:GetRatingFromSocketedJewels(propertyString, item)
    end
  end
  return total
end

function ItemExamine_Daralet:GetRatingFromSocketedJewels(propertyString, item)
  local total   = 0
  local sockets = item.IntValues["JewelSockets"] or 0
  for i = 1, sockets do
    local mat  = item.IntValues["JewelSocket"..i.."Material"]
    local q    = item.IntValues["JewelSocket"..i.."Quality"]
    local alt  = item.BoolValues["JewelSocket"..i.."AlternateEffect"]
    local loc  = item.IntValues["ValidLocations"]
    if mat and q and alt ~= nil then
      local mt = self.JewelMaterialToType[mat]
      total = total + self:GetRatingFromJewel(propertyString, loc, mt, q)
    end
  end
  return total
end

function ItemExamine_Daralet:GetRatingFromJewel(propertyString, equipMask, jewelMaterialType, jewelQuality)
  if not self.JewelTypeToMaterial[propertyString] or
     self.JewelTypeToMaterial[propertyString] ~= jewelMaterialType then
    return 0
  elseif bit.band(MaterialValidLocations[jewelMaterialType], equipMask) ~= equipMask then
    return 0
  elseif bit.band(0x00007F21, equipMask) == 0x00007F21 and
         self.JewelMaterialToType[jewelMaterialType].AlternateRating ~= propertyString then
    return 0
  elseif self.JewelMaterialToType[jewelMaterialType].PrimaryRating ~= propertyString then
    return 0
  end
  return jewelQuality
end

return ItemExamine_Daralet
