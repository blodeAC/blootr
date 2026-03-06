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
-- Rating Properties Mapping (PropertyInt -> WorldObject property)
local RATING_PROPERTIES = {
  "GearDamage",
  "GearDamageResist",
  "GearCrit",
  "GearCritResist",
  "GearCritDamage",
  "GearCritDamageResist",
  "GearHealingBoost",
  "GearMaxHealth",
  "GearPKDamageRating",
  "GearPKDamageResistRating",
  "WardLevel",
  "GearStrength",
  "GearEndurance",
  "GearCoordination",
  "GearQuickness",
  "GearFocus",
  "GearSelf",
  "GearMaxStamina",
  "GearMaxMana",
  "GearThreatGain",
  "GearThreatReduction",
  "GearElementalWard",
  "GearPhysicalWard",
  "GearMagicFind",
  "GearBlock",
  "GearItemManaUsage",
  "GearLifesteal",
  "GearSelfHarm",
  "GearThorns",
  "GearVitalsTransfer",
  "GearRedFury",
  "GearYellowFury",
  "GearBlueFury",
  "GearSelflessness",
  "GearVipersStrike",
  "GearFamiliarity",
  "GearBravado",
  "GearHealthToStamina",
  "GearHealthToMana",
  "GearExperienceGain",
  "GearManasteal",
  "GearBludgeon",
  "GearPierce",
  "GearSlash",
  "GearFire",
  "GearFrost",
  "GearAcid",
  "GearLightning",
  "GearHealBubble",
  "GearCompBurn",
  "GearPyrealFind",
  "GearNullification",
  "GearWardPen",
  "GearStaminasteal",
  "GearHardenedDefense",
  "GearReprisal",
  "GearElementalist",
  "GearToughness",
  "GearResistance",
  "GearSlashBane",
  "GearBludgeonBane",
  "GearPierceBane",
  "GearAcidBane",
  "GearFireBane",
  "GearFrostBane",
  "GearLightningBane"
}

-- Skill Mod Properties Mapping (PropertyFloat -> WorldObject property)
local SKILLMOD_PROPERTIES = {
  "ArmorHealthRegenMod",
  "ArmorStaminaRegenMod",
  "ArmorManaRegenMod",
  "ArmorAttackMod",
  "ArmorPhysicalDefMod",
  "ArmorMissileDefMod",
  "ArmorMagicDefMod",
  "ArmorRunMod",
  "ArmorTwohandedCombatMod",
  "ArmorDualWieldMod",
  "ArmorThieveryMod",
  "ArmorPerceptionMod",
  "ArmorShieldMod",
  "ArmorDeceptionMod",
  "ArmorWarMagicMod",
  "ArmorLifeMagicMod",
  "WeaponWarMagicMod",
  "WeaponLifeMagicMod",
  "WeaponRestorationSpellsMod",
  "ArmorHealthMod",
  "ArmorStaminaMod",
  "ArmorManaMod",
  "ArmorResourcePenalty"
}

function ItemExamine_Daralet.new(itemData)
  local self = setmetatable({}, ItemExamine_Daralet)
  self.item  = itemData
  self.item.WeenieType = game.World.Get(self.item.id).ObjectType
  self.item.ObjectType = game.World.Get(self.item.id).ObjectType
  self.item.Wielder = game.World.Get(self.item.id).Wielder
  
  self._hasAdditionalProperties = nil
  self._hasExtraPropertiesText = nil
  self._hasLongDescAdditions = nil
  
  self._additionalPropertiesList = {}
  self._longDescAdditions = nil
  self._additionalPropertiesLongDescriptionsText = nil
  self._extraPropertiesText = nil
  
  self.equippedItemsRatingCache = {}
  for _,property in pairs(RATING_PROPERTIES) do
    self.equippedItemsRatingCache[property]=0
  end
  self.equippedItemsSkillModCache = {}
  for _,property in pairs(SKILLMOD_PROPERTIES) do
    self.equippedItemsSkillModCache[property]=0
  end
  self.equippedItems = {}
  
  --self.itemWo= game.World.Get(itemData.id)
  self.lines = {}
  
  self:SetCustomDecorationLongText()
  self:SetTinkeringLongText()
  
  if self._hasLongDescAdditions then
    self._longDescAdditions = self._longDescAdditions .. ""
    self.item.StringValues["LongDesc"] = self._longDescAdditions
  end
  
  -- USE
  local useText = self.item.StringValues["Use"]
  if useText and #useText > 0 then
    self._extraPropertiesText = useText .. "\n"
  else
    self._extraPropertiesText = ""
  end
  
  -- Trophy Quality Level
  self:SetTrophyQualityLevelText()
  
  -- Protection Levels ('Use' text)
  self:SetProtectionLevelsUseText()
  
  -- Retail Imbues ('Use' and 'LongDesc' text)
  self:SetArmorRendUseLongText()
  self:SetArmorCleavingUseLongText()
  
  self:SetResistanceRendLongText(ImbuedEffectType.AcidRending, "Acid")
  self:SetResistanceRendLongText(ImbuedEffectType.BludgeonRending, "Bludgeoning")
  self:SetResistanceRendLongText(ImbuedEffectType.ColdRending, "Cold")
  self:SetResistanceRendLongText(ImbuedEffectType.ElectricRending, "Lightning")
  self:SetResistanceRendLongText(ImbuedEffectType.FireRending, "Fire")
  self:SetResistanceRendLongText(ImbuedEffectType.PierceRending, "Pierce")
  self:SetResistanceRendLongText(ImbuedEffectType.SlashRending, "Slash")
  
  self:SetResistanceCleavingUseLongText()
  
  self:SetCripplingBlowUseLongText()
  self:SetCrushingBlowUseLongText()
  
  self:SetCriticalStrikeUseLongText()
  self:SetBitingStrikeUseLongText()
  
  -- Additional Properties
  self:SetWardRendingUseLongText()
  self:SetWardCleavingUseLongText()
  
  self:SetStaminaReductionUseLongText()
  self:SetNoCompsRequiredSchoolUseLongText()
  
  -- Gear Ratings
  self:SetGearRatingText("GearStrength",self.item.IntValues["GearStrength"], "Mighty Thews",
  "Grants +10 to current Strength, plus an additional +1 per equipped rating (ONE) total).",
  1.0, 1.0, 10)
  
  self:SetGearRatingText("GearEndurance", self.item.IntValues["GearEndurance"], "Perseverance",
  "Grants +10 to current Endurance, plus an additional +1 per equipped rating (ONE) total).",
  1.0, 1.0, 10)
  
  self:SetGearRatingText("GearCoordination", self.item.IntValues["GearCoordination"], "Dexterous Hand",
  "Grants +10 to current Coordination, plus an additional +1 per equipped rating (ONE) total).",
  1.0, 1.0, 10)
  
  self:SetGearRatingText("GearQuickness", self.item.IntValues["GearQuickness"], "Swift-footed",
  "Grants +10 to current Quickness, plus an additional +1 per equipped rating (ONE) total).",
  1.0, 1.0, 10)
  
  self:SetGearRatingText("GearFocus", self.item.IntValues["GearFocus"], "Focused Mind",
  "Grants +10 to current Focus, plus an additional +1 per equipped rating (ONE) total).",
  1.0, 1.0, 10)
  
  self:SetGearRatingText("GearSelf", self.item.IntValues["GearSelf"], "Erudite Mind",
  "Grants +10 to current Self, plus an additional +1 per equipped rating (ONE) total).",
  1.0, 1.0, 10)
  
  self:SetGearRatingText("GearSelfHarm", self.item.IntValues["GearSelfHarm"], "Blood Frenzy",
  "Grants 10%% increased damage with all attacks, plus an additional 0.5%% per equipped rating (ONE) total). However, you will occasionally deal the extra damage to yourself as well.",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearThreatGain", self.item.IntValues["GearThreatGain"], "Provocation",
  "Grants 10%% increased threat from your actions, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearThreatReduction", self.item.IntValues["GearThreatReduction"], "Clouded Vision",
  "Grants 10%% reduced threat from your actions, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearElementalWard", self.item.IntValues["GearElementalWard"], "Prismatic Ward",
  "Grants 10%%%% protection against Flame, Frost, Lightning, and Acid damage types, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearPhysicalWard", self.item.IntValues["GearPhysicalWard"], "Black Bulwark",
  "Grants 10%%%% protection against Slashing, Bludgeoning, and Piercing damage types, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearMagicFind", self.item.IntValues["GearMagicFind"], "Seeker",
  "Grants a 5%% bonus to monster loot quality, plus an additional 0.25%% per equipped rating (ONE) total).",
  0.25, 1.0, 5, 0, true)
  
  self:SetGearRatingText("GearBlock", self.item.IntValues["GearBlock"], "Stalwart Defense",
  "Grants a 10%% bonus to block attacks, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearItemManaUsage", self.item.IntValues["GearItemManaUsage"], "Thrifty Scholar",
  "Grants a 20%% cost reduction to mana consumed by equipped items, plus an additional 1%% per equipped rating (ONE) total).",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearThorns", self.item.IntValues["GearThorns"], "Swift Retribution",
  "Deflect 10%% of a blocked attack's damage back to a close-range attacker, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearVitalsTransfer", self.item.IntValues["GearVitalsTransfer"], "Tilted Scales",
  "Grants a 10%% bonus to your Vitals Transfer spells, plus an additional 0.5%% per equipped rating (ONE) total). Receive an equivalent reduction in the effectiveness of your other Restoration spells.",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearRedFury", self.item.IntValues["GearRedFury"], "Red Fury",
  "Grants increased damage as you lose health, up to a maximum bonus of 20%% at 0 health, plus an additional 1%% per equipped rating (ONE) total).",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearYellowFury", self.item.IntValues["GearYellowFury"], "Yellow Fury",
  "Grants increased physical damage as you lose stamina, up to a maximum bonus of 20%% at 0 stamina, plus an additional 1%% per equipped rating (ONE) total).",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearBlueFury", self.item.IntValues["GearBlueFury"], "Blue Fury",
  "Grants increased magical damage as you lose mana, up to a maximum bonus of 20%% at 0 mana, plus an additional 1%% per equipped rating (ONE) total).",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearSelflessness", self.item.IntValues["GearSelflessness"], "Selfless Spirit",
  "Grants a 10%% bonus to your restoration spells when cast on others, plus an additional 0.5%% per equipped rating (ONE) total). Receive an equivalent reduction in their effectiveness when cast on yourself.",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearFamiliarity", self.item.IntValues["GearFamiliarity"], "Familiar Foe",
  "Grants up to a 20%% bonus to defense skill against a target you are attacking, plus an additional 1%% per equipped rating (ONE) total). The chance builds up from 0%, based on how often you have hit the target.",
  1.0, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearBravado", self.item.IntValues["GearBravado"], "Bravado",
  "Grants up to a 20%% bonus to attack skill against a target you are attacking, plus an additional 1%% per equipped rating (ONE) total). The chance builds up from 0%%, based on how often you have hit the target.",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearHealthToStamina", self.item.IntValues["GearHealthToStamina"], "Masochist",
  "Grants a 10%% chance to regain the hit damage received from an attack as stamina, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearHealthToMana", self.item.IntValues["GearHealthToMana"], "Austere Anchorite",
  "Grants a 10%% chance to regain the hit damage received from an attack as mana, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearExperienceGain", self.item.IntValues["GearExperienceGain"], "Illuminated Mind",
  "Grants a 5%% bonus to experience gain, plus an additional 0.25%% per equipped rating (ONE) total).",
  0.25, 1.0, 5, 0, true)
  
  self:SetGearRatingText("GearLifesteal", self.item.IntValues["GearLifesteal"], "Sanguine Thirst",
  "Grants a 10%% chance on hit to gain health, plus an additional 0.5%% per equipped rating (ONE) total). Amount stolen is equal to 10%% of damage dealt.",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearStaminasteal", self.item.IntValues["GearStaminasteal"], "Vigor Siphon",
  "Grants a 10%% chance on hit to gain stamina, plus an additional 0.5%% per equipped rating (ONE) total). Amount stolen is equal to 10%% of damage dealt.",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearManasteal", self.item.IntValues["GearManasteal"], "Ophidian",
  "Grants a 10%% chance on hit to steal mana from your target, plus an additional 0.5%% per equipped rating (ONE) total). Amount stolen is equal to 10%% of damage dealt.",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearBludgeon", self.item.IntValues["GearBludgeon"], "Skull-cracker",
  "Grants up to 20%% bonus critical hit damage, plus an additional 1%% per equipped rating (ONE) total). The bonus builds up from 0%%, based on how often you have hit the target.",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearPierce", self.item.IntValues["GearPierce"], "Precision Strikes",
  "Grants up to 20%% piercing resistance penetration, plus an additional 1%% per equipped rating (ONE) total). The bonus builds up from 0%%, based on how often you have hit the target",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearSlash", self.item.IntValues["GearSlash"], "Falcon's Gyre",
  "Grants a 10%% chance to cleave an additional target, plus an additional 0.5%% per equipped rating (ONE) total).",
  0.5, 1.0, 10, 0, true)
  
  self:SetGearRatingText("GearFire", self.item.IntValues["GearFire"], "Blazing Brand",
  "Grants a 10%% bonus to Fire damage, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance on hit to set the ground beneath your target ablaze, plus an additional 0.1%% per equipped rating (TWO) total).",
  0.5, 0.1, 10, 2, true)
  
  self:SetGearRatingText("GearFrost", self.item.IntValues["GearFrost"], "Bone-chiller",
  "Grants a 10%% bonus to Cold damage, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance on hit to surround your target with chilling mist, plus an additional 0.1%% per equipped rating (TWO) total).",
  0.5, 0.1, 10, 2, true)
  
  self:SetGearRatingText("GearAcid", self.item.IntValues["GearAcid"], "Devouring Mist",
  "Grants a 10%% bonus to Acid damage, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance on hit to surround your target with acidic mist, plus an additional 0.1%% per equipped rating (TWO) total).",
  0.5, 0.1, 10, 2, true)
  
  self:SetGearRatingText("GearLightning", self.item.IntValues["GearLightning"], "Astyrrian's Rage",
  "Grants a 10%% bonus to Lightning damage, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance on hit to electrify the ground beneath your target, plus an additional 0.1%% per equipped rating (TWO) total).",
  0.5, 0.1, 10, 2, true)
  
  self:SetGearRatingText("GearHealBubble", self.item.IntValues["GearHealBubble"], "Purified Soul",
  "Grants a 10%% bonus to your restoration spells, plus an additional 0.5%% per equipped rating (ONE) total). Also grants a 2%% chance to create a sphere of healing energy on top of your target when casting a restoration spell, plus an additional 0.1%% per equipped rating (ONE) total).",
  0.5, 0.1, 10, 2, true)
  
  self:SetGearRatingText("GearCompBurn", self.item.IntValues["GearCompBurn"], "Meticulous Magus",
  "Grants a 20%% reduction to your chance to burn spell components, plus an additional 1%% per equipped rating (ONE) total).",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearPyrealFind", self.item.IntValues["GearPyrealFind"], "Prosperity",
  "Grants a 5%% chance for a monster to drop an extra item, plus an additional 0.25%% per equipped rating (ONE) total).",
  0.25, 1.0, 5, 0, true)
  
  self:SetGearRatingText("GearNullification", self.item.IntValues["GearNullification"], "Nullification",
  "Grants up to 20%% reduced magic damage taken, plus an additional 1%% per equipped rating (ONE) total). The amount builds up from 0%%, based on how often you have been hit with a damaging spell.",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearWardPen", self.item.IntValues["GearWardPen"], "Ruthless Discernment",
  "Grants up to 20%% ward penetration, plus an additional 1%% per equipped rating (ONE) total). The Amount builds up from 0%%, based on how often you have hit your target.",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearHardenedDefense", self.item.IntValues["GearHardenedDefense"], "Hardened Fortification",
  "Grants up to 20%% reduced physical damage taken, plus an additional 1%% per equipped rating (ONE) total). The amount builds up from 0%%, based on how often you have been hit with a damaging physical attack.",
  1.0, 10.0, 20, 0, true)
  
  self:SetGearRatingText("GearReprisal", self.item.IntValues["GearReprisal"], "Vicious Reprisal",
  "Grants a 5%% chance to evade an incoming critical hit, plus an additional 0.25%% per equipped rating (ONE) total). Your next attack after the evade is a guaranteed critical.",
  0.25, 1.0, 5, 0, true)
  
  self:SetGearRatingText("GearElementalist", self.item.IntValues["GearElementalist"], "Elementalist",
  "Grants up to a 20%% damage bonus to war spells, plus an additional 1%% per equipped rating (ONE) total). The amount builds up from 0%%, based on how often you have hit your target.",
  1.0, 1.0, 20, 0, true)
  
  self:SetGearRatingText("GearToughness", self.item.IntValues["GearToughness"], "Toughness",
  "Grants +20 physical defense, plus an additional 1 per equipped rating (ONE) total).",
  1.0, 1.0, 20)
  
  self:SetGearRatingText("GearResistance", self.item.IntValues["GearResistance"], "Resistance",
  "Grants +20 magic defense, plus an additional 1 per equipped rating (ONE) total).",
  1.0, 1.0, 20)
  
  self:SetGearRatingText("GearSlashBane", self.item.IntValues["GearSlashBane"], "Swordsman's Bane",
  "Grants +0.2 slashing protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",
  0.01, 1.0, 0.2)
  
  self:SetGearRatingText("GearBludgeonBane", self.item.IntValues["GearBludgeonBane"], "Tusker's Bane",
  "Grants +0.2 bludgeoning protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",
  0.01, 1.0, 0.2)
  
  self:SetGearRatingText("GearPierceBane", self.item.IntValues["GearPierceBane"], "Archer's Bane",
  "Grants +0.2 piercing protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",
  0.01, 1.0, 0.2)
  
  self:SetGearRatingText("GearAcidBane", self.item.IntValues["GearAcidBane"], "Olthoi's Bane",
  "Grants +0.2 acid protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",
  0.01, 1.0, 0.2)
  
  self:SetGearRatingText("GearFireBane", self.item.IntValues["GearFireBane"], "Inferno's Bane",
  "Grants +0.2 fire protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",
  0.01, 1.0, 0.2)
  
  self:SetGearRatingText("GearFrostBane", self.item.IntValues["GearFrostBane"], "Gelidite's Bane",
  "Grants +0.2 cold protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",
  0.01, 1.0, 0.2)
  
  self:SetGearRatingText("GearLightningBane", self.item.IntValues["GearLightningBane"], "Astyrrian's Bane",
  "Grants +0.2 electric protection to all equipped armor, plus an additional 0.01 per equipped rating (ONE) total). The protection level cannot be increased beyond 1.0 (average), from this effect.",
  0.01, 1.0, 0.2)
  
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
  
  local equipped = false
  if self.item.Wielder and self.item.Wielder.Id == game.CharacterId then
    equipped = true
  end
  self:SetArmorModUseText("ArmorWarMagicMod", self.item.FloatValues["ArmorWarMagicMod"], "Bonus to War Magic Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorWarMagicMod") or 0))
  self:SetArmorModUseText("ArmorLifeMagicMod", self.item.FloatValues["ArmorLifeMagicMod"], "Bonus to Life Magic Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorLifeMagicMod") or 0))    
  self:SetArmorModUseText("ArmorAttackMod", self.item.FloatValues["ArmorAttackMod"], "Bonus to Attack Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorAttackMod") or 0))
  self:SetArmorModUseText("ArmorPhysicalDefMod", self.item.FloatValues["ArmorPhysicalDefMod"], "Bonus to Physical Defense: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorPhysicalDefMod") or 0))
  self:SetArmorModUseText("ArmorMagicDefMod", self.item.FloatValues["ArmorMagicDefMod"], "Bonus to Magic Defense: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorMagicDefMod") or 0))
  self:SetArmorModUseText("ArmorDualWieldMod", self.item.FloatValues["ArmorDualWieldMod"], "Bonus to Dual Wield Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorDualWieldMod") or 0))
  self:SetArmorModUseText("ArmorTwohandedCombatMod", self.item.FloatValues["ArmorTwohandedCombatMod"], "Bonus to Two-handed Combat Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorTwohandedCombatMod") or 0))
  self:SetArmorModUseText("ArmorRunMod", self.item.FloatValues["ArmorRunMod"], "Bonus to Run Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorRunMod") or 0))
  self:SetArmorModUseText("ArmorThieveryMod", self.item.FloatValues["ArmorThieveryMod"], "Bonus to Thievery Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorThieveryMod") or 0))
  self:SetArmorModUseText("ArmorShieldMod", self.item.FloatValues["ArmorShieldMod"], "Bonus to Shield Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorShieldMod") or 0))
  self:SetArmorModUseText("ArmorPerceptionMod", self.item.FloatValues["ArmorPerceptionMod"], "Bonus to Perception Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorPerceptionMod") or 0))
  self:SetArmorModUseText("ArmorDeceptionMod", self.item.FloatValues["ArmorDeceptionMod"], "Bonus to Deception Skill: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorDeceptionMod") or 0))
  self:SetArmorModUseText("ArmorHealthMod", self.item.FloatValues["ArmorHealthMod"], "Bonus to Maximum Health: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorHealthMod") or 0))
  self:SetArmorModUseText("ArmorHealthRegenMod", self.item.FloatValues["ArmorHealthRegenMod"], "Bonus to Health Regen: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorHealthRegenMod") or 0))
  self:SetArmorModUseText("ArmorStaminaMod", self.item.FloatValues["ArmorStaminaMod"], "Bonus to Maximum Stamina: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorStaminaMod") or 0))
  self:SetArmorModUseText("ArmorStaminaRegenMod", self.item.FloatValues["ArmorStaminaRegenMod"], "Bonus to Stamina Regen: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorStaminaRegenMod") or 0))
  self:SetArmorModUseText("ArmorManaMod", self.item.FloatValues["ArmorManaMod"], "Bonus to Maximum Mana: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorManaMod") or 0))
  self:SetArmorModUseText("ArmorManaRegenMod",self.item.FloatValues["ArmorManaRegenMod"], "Bonus to Mana Regen: +(ONE)%%", (equipped and self:GetEquippedItemsSkillModSum("ArmorManaRegenMod") or 0))
  
  
  self:SetDamagePenaltyUseText()
  self:SetJewelcraftingUseText()
  self:SetSalvageBagUseText()
  
  self:SetSigilTrinketUseText()
  
  if (self._hasExtraPropertiesText) then
    self._extraPropertiesText = self._extraPropertiesText .. ""
    --print(self._extraPropertiesText)
    self.item.StringValues["Use"] = self._extraPropertiesText
    
    if (self._additionalPropertiesLongDescriptionsText and #(self._additionalPropertiesLongDescriptionsText) > 0) then
      local longDescString = self.item.StringValues["LongDesc"]
      
      self._additionalPropertiesLongDescriptionsText =
      "Property Descriptions:\n" .. (self._additionalPropertiesLongDescriptionsText or "") .. "\n\n" .. (longDescString or "")
      self.item.StringValues["LongDesc"] = self._additionalPropertiesLongDescriptionsText
      --print(self.item.StringValues.LongDesc)
    end
  end
  return self
end

function ItemExamine_Daralet:SetTrophyQualityLevelText()
  local trophyQuality = self.item.IntValues["TrophyQuality"]
  if trophyQuality ~= nil and trophyQuality > 0 then
    local trophyQualityTable = setmetatable({
      [2] = "Inferior",
      [3] = "Poor",
      [4] = "Crude",
      [5] = "Ordinary",
      [6] = "Good",
      [7] = "Great",
      [8] = "Excellent",
      [9] = "Superb",
      [10]= "Peerless"
    },{
      __index = function(src, key)
        return "Damaged"
      end})
      local qualityName = trophyQualityTable[trophyQuality]
      
      self._extraPropertiesText = "Quality Level: " .. trophyQuality
      self.item.StringValues["Use"] = self._extraPropertiesText
    end
  end
  
  function ItemExamine_Daralet:SetCustomDecorationLongText()
    if self.item.IntValues["MaterialType"] ~= nil and self.item.IntValues["ItemWorkmanship"] ~= nil then
      local prependMaterial = "" .. StringToMaterialType[self.item.IntValues["MaterialType"]]
      local workmanshipIndex = math.max(1, math.min((self.item.IntValues["ItemWorkmanship"] or 1), 10))
      local prependWorkmanship = ""
      if workmanshipIndex==1 then
        prependWorkmanship = "Poorly crafted"
      elseif workmanshipIndex==2 then
        prependWorkmanship = "Well-crafted"
      elseif workmanshipIndex==3 then
        prependWorkmanship = "Finely crafted"
      elseif workmanshipIndex==4 then
        prependWorkmanship = "Exquisitely crafted"
      elseif workmanshipIndex==5 then
        prependWorkmanship = "Magnificent"
      elseif workmanshipIndex==6 then
        prependWorkmanship = "Nearly flawless"
      elseif workmanshipIndex==7 then
        prependWorkmanship = "Flawless"
      elseif workmanshipIndex==8 then
        prependWorkmanship = "Utterly flawless"
      elseif workmanshipIndex==9 then
        prependWorkmanship = "Incomparable"
      elseif workmanshipIndex==10 then
        prependWorkmanship = "Priceless"
      end
      local modifiedGemType = StringToMaterialType[self.item.IntValues["GemType"]]
      
      if self.item.IntValues["GemType"] ~= nil and self.item.IntValues["GemCount"] ~= nil and self.item.IntValues["GemCount"] >= 1 then
        if self.item.IntValues["GemCount"] > 1 then
          local gemTypeInt = self.item.IntValues["GemType"]
          if gemTypeInt == 26 or gemTypeInt == 37 or gemTypeInt == 40 or gemTypeInt == 46 or gemTypeInt == 49 then
            modifiedGemType = modifiedGemType .. "es"
          elseif gemTypeInt == 38 then
            modifiedGemType = "Rubies"
          else
            modifiedGemType = modifiedGemType .. "s"
          end
        end
        
        self._longDescAdditions =
        string.format("%s %s %s, set with %d %s",
        prependWorkmanship, prependMaterial, self.item.StringValues["Name"], self.item.IntValues["GemCount"], modifiedGemType)
      else
        self._longDescAdditions =
        string.format("%s %s %s", prependWorkmanship, prependMaterial, self.item.StringValues["Name"])
      end
      
      self._hasLongDescAdditions = true
    end
  end
  
  -- tinkerlog is server only
  function ItemExamine_Daralet:SetTinkeringLongText()
    if (self.item.IntValues["NumTimesTinkered"] or 0) < 1 then
      return
    end
    if self.item.IntValues["NumTimesTinkered"] <= 0 or self.item.StringValues["TinkerLog"] == nil then
      return
    end
    
    local tinkerLogArray = {}
    for s in string.gmatch( self.item.StringValues["TinkerLog"], "([^,]+)") do
      table.insert(tinkerLogArray, s)
    end
    
    
    local tinkeringTypes = {}
    for i = 0, 79 do
      tinkeringTypes[i] = 0
    end
    
    self._hasLongDescAdditions = true
    self._longDescAdditions = (self._longDescAdditions or "") .. [[This item has been tinkered with:
]]
    
    for _, s in ipairs(tinkerLogArray) do
      local index = tonumber(s)
      if index ~= nil and index >= 0 and index < 80 then
        tinkeringTypes[index] = tinkeringTypes[index] + 1
      end
    end
    
    local sumofTinksinLog = 0
    
    for index = 0, 79 do
      local value = tinkeringTypes[index]
      if value > 0 then
        if MaterialType[index] ~= nil then
          local materialType = index
          self._longDescAdditions = self._longDescAdditions .. string.format([[    
  %s:  %d]], tostring(self.item.IntValues["MaterialType"]), value)
        else
          print(string.format("Unknown variable at index %d: %d", index, value))
        end
        sumofTinksinLog = sumofTinksinLog + value
      end
    end
    
    if sumofTinksinLog == 0 and self.item.IntValues["NumTimesTinkered"] >= 1 then
      self._longDescAdditions = self._longDescAdditions .. string.format([[
        
  Failures:    %d]], self.item.IntValues["NumTimesTinkered"])
    else
      sumofTinksinLog = sumofTinksinLog - self.item.IntValues["NumTimesTinkered"]
      if sumofTinksinLog < 0 then
        self._longDescAdditions = self._longDescAdditions .. string.format([[
           
  Failures:  %d]], math.abs(sumofTinksinLog))
      end
    end
  end
  
  function ItemExamine_Daralet:SetSigilTrinketUseText()
    local sigilTrinket = self.item  -- assuming checked/cast elsewhere
    
    -- Proc Chance
    local sigilTrinketTriggerChance = sigilTrinket.FloatValues["SigilTrinketTriggerChance"]
    if sigilTrinketTriggerChance ~= nil and sigilTrinketTriggerChance > 0.01 then
      self._extraPropertiesText = (self._extraPropertiesText or "") ..
      string.format([[Proc Chance: %.0f%%%%
]], math.floor(sigilTrinketTriggerChance * 100 + 0.5))
      self._hasExtraPropertiesText = true
    end
    
    -- Frequency
    local cooldownDuration = sigilTrinket.FloatValues["CooldownDuration"]
    if cooldownDuration ~= nil and cooldownDuration > 0.01 then
      self._extraPropertiesText = self._extraPropertiesText ..
      string.format([[Cooldown: %.1f seconds
]], cooldownDuration)
      self._hasExtraPropertiesText = true
    end
    
    -- Max Level
    local maxStructure = sigilTrinket.IntValues["MaxStructure"]
    if maxStructure ~= nil and maxStructure > 0 then
      self._extraPropertiesText = self._extraPropertiesText ..
      string.format([[Max Number of Uses: %d
]], maxStructure)
      self._hasExtraPropertiesText = true
    end
    
    -- Intensity
    local sigilTrinketIntensity = sigilTrinket.FloatValues["SigilTrinketIntensity"]
    if sigilTrinketIntensity ~= nil and sigilTrinketIntensity > 0.01 then
      self._extraPropertiesText = self._extraPropertiesText ..
      string.format([[Bonus Intensity: %.1f%%%%
]], sigilTrinketIntensity * 100)
      self._hasExtraPropertiesText = true
    end
    
    -- Mana Reduction
    local sigilTrinketReductionAmount = sigilTrinket.FloatValues["SigilTrinketReductionAmount"]
    if sigilTrinketReductionAmount ~= nil and sigilTrinketReductionAmount > 0.01 then
      self._extraPropertiesText = self._extraPropertiesText ..
      string.format([[Mana Cost Reduction: %.1f%%%%
]], sigilTrinketReductionAmount * 100)
      self._hasExtraPropertiesText = true
    end
    
    -- Reserved Health
    local sigilTrinketHealthReserved = sigilTrinket.FloatValues["SigilTrinketHealthReserved"]
    if sigilTrinketHealthReserved ~= nil and sigilTrinketHealthReserved > 0 then
      local wielder = (self.item.Wielder and self.item.Wielder.Id == game.CharacterId) or nil
      if wielder ~= nil then
        local totalReservedHealth = 0.0
        
        for _,gear in pairs(game.Character.Equipment) do
          if bit.band(gear.ValidWieldedLocations,EquipMask.RedAetheria.ToNumber() + EquipMask.YellowAetheria.ToNumber() + EquipMask.BlueAetheria.ToNumber())>0 then
            totalReservedHealth = totalReservedHealth + (gear.IntValues["SigilTrinketHealthReserved"] or 0)
          end
        end
        self._extraPropertiesText = self._extraPropertiesText .. string.format([[Health Reservation: %.1f%%%% (%.1f%%%%)
]], sigilTrinketHealthReserved * 100, totalReservedHealth * 100)
      else
        self._extraPropertiesText = self._extraPropertiesText .. string.format([[Health Reservation: %.1f%%%%
]], sigilTrinketHealthReserved * 100)
      end
      self._hasExtraPropertiesText = true
    end
    
    -- Reserved Stamina
    local sigilTrinketStaminaReserved = sigilTrinket.FloatValues["SigilTrinketStaminaReserved"]
    if sigilTrinketStaminaReserved ~= nil and sigilTrinketStaminaReserved > 0 then
      local wielder = (self.item.Wielder and self.item.Wielder.Id == game.CharacterId) or nil
      if wielder ~= nil then
        local totalReservedStamina = 0.0
        
        for _,gear in pairs(game.Character.Equipment) do
          if bit.band(gear.ValidWieldedLocations,EquipMask.RedAetheria)>0 or bit.band(gear.ValidWieldedLocations,EquipMask.YellowAetheria)>0 or bit.band(gear.ValidWieldedLocations,EquipMask.BlueAetheria)>0 then
            totalReservedStamina = totalReservedStamina + (gear.IntValues["SigilTrinketStaminaReserved"] or 0)
          end
        end
        self._extraPropertiesText = self._extraPropertiesText .. string.format([[Stamina Reservation: %.1f%%%% (%.1f%%%%)
]], sigilTrinketStaminaReserved * 100, totalReservedStamina * 100)
      else
        self._extraPropertiesText = self._extraPropertiesText .. string.format([[Stamina Reservation: %.1f%%%%
]], sigilTrinketStaminaReserved * 100)
      end
      self._hasExtraPropertiesText = true
    end
    
    -- Reserved Mana
    local sigilTrinketManaReserved = sigilTrinket.FloatValues["SigilTrinketManaReserved"]
    if sigilTrinketManaReserved ~= nil and sigilTrinketManaReserved > 0 then
      local wielder = (self.item.Wielder and self.item.Wielder.Id == game.CharacterId) or nil
      if wielder ~= nil then
        local totalReservedMana = 0.0
        
        for _,gear in pairs(game.Character.Equipment) do
          if bit.band(gear.ValidWieldedLocations,EquipMask.RedAetheria)>0 or bit.band(gear.ValidWieldedLocations,EquipMask.YellowAetheria)>0 or bit.band(gear.ValidWieldedLocations,EquipMask.BlueAetheria)>0 then
            totalReservedMana = totalReservedMana + (gear.IntValues["SigilTrinketManaReserved"] or 0)
          end
        end
        self._extraPropertiesText = self._extraPropertiesText .. string.format([[Mana Reservation: %.1f%%%% (%.1f%%%%)
]], sigilTrinketManaReserved * 100, totalReservedMana * 100)
      else
        self._extraPropertiesText = self._extraPropertiesText .. string.format([[Mana Reservation: %.1f%%%%
]], sigilTrinketManaReserved * 100)
      end
      self._hasExtraPropertiesText = true
    end
    
    -- Wield Skill Req
    if sigilTrinket.AllowedSpecializedSkills ~= nil then
      local skills = sigilTrinket.AllowedSpecializedSkills
      if #skills > 0 then
        local ok, err = pcall(function()
          local names = {}
          for i = 1, #skills do
            local sk = skills[i]
            local name
            local ok2, _ = pcall(function()
              name = sk --NewSkillNames.ToSentence(sk)
            end)
            if not ok2 or name == nil then
              name = tostring( sk ) --NewSkillNames[sk] or sk)
            end
            table.insert(names, name)
          end
          
          local unique = {}
          local seen = {}
          for _, n in ipairs(names) do
            if not seen[n] then
              seen[n] = true
              table.insert(unique, n)
            end
          end
          
          local wieldReqStr
          if #unique == 1 then
            wieldReqStr = "Wield requires specialized " .. unique[1]
          else
            wieldReqStr = "Wield requires specialized " .. table.concat(unique, " or ")
          end
          
          self._extraPropertiesText = (self._extraPropertiesText or "") .. wieldReqStr .. [[
]]
          self._hasExtraPropertiesText = true
        end)
        -- ignore error if not ok
      end
    end
  end
  
  function ItemExamine_Daralet:SetSalvageBagUseText()
    local structure = self.item.IntValues["Structure"]
    if structure == nil or structure < 0 then
      return
    end
    
    if self.item.WeenieType ~= WeenieType.CombatPet+5 then
      return
    end
    
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format([[
This bag contains %d units of salvage.
]], structure)
    self._hasExtraPropertiesText = true
  end
  
  -- assumes:
  --  jewel.JewelQuality (number or nil)
  --  jewel.JewelMaterialType (enum-like value or nil)
  --  jewel.JewelSocket1 (string or nil)
  --  StringToMaterialType[string] = materialType
  --  JewelQualityStringToValue[string] = quality number
  --  JewelEffectInfoMain[materialType] = { Name=..., Slot=..., BasePrimary=..., BonusPrimary=..., BaseSecondary=..., BonusSecondary=... }
  --  JewelEffectInfoAlternate[materialType] = same shape as above
  --  JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary?, nameAlternate?)
  --  ACE.Entity.Enum.MaterialType.<Name> mapped to some constants (or replace with your own enum table)
  local function JewelType(primary, alternate)
    return setmetatable({
      PrimaryRating = primary,
      AlternateRating = alternate,
    }, {
      __tostring = function(t)
        return t.PrimaryRating
      end,
      __call = function(t)
        return t.PrimaryRating
      end,
    })
  end
  ItemExamine_Daralet.JewelMaterialToType = setmetatable({
    [MaterialType.Agate] = JewelType( "GearThreatGain", "Undef" ),
    [MaterialType.Amber] = JewelType( "GearYellowFury", "GearHealthToStamina" ),
    [MaterialType.Amethyst] = JewelType( "GearNullification", "GearResistance" ),
    [MaterialType.Aquamarine] = JewelType( "GearFrost", "GearFrostBane" ),
    [MaterialType.Azurite] = JewelType( "GearSelf", "Undef" ),
    [MaterialType.BlackGarnet] = JewelType( "GearPierce", "GearPierceBane" ),
    [MaterialType.BlackOpal] = JewelType( "GearReprisal", "Undef" ),
    [MaterialType.Bloodstone] = JewelType( "GearLifesteal", "Undef" ),
    [MaterialType.Carnelian] = JewelType( "GearStrength", "Undef" ),
    [MaterialType.Citrine] = JewelType( "GearStaminasteal", "Undef" ),
    [MaterialType.Diamond] = JewelType( "GearHardenedDefense", "GearToughness" ),
    [MaterialType.Emerald] = JewelType( "GearAcid", "GearAcidBane" ),
    [MaterialType.FireOpal] = JewelType( "GearFamiliarity", "Undef" ),
    [MaterialType.GreenGarnet] = JewelType( "GearElementalist", "Undef" ),
    [MaterialType.GreenJade] = JewelType( "GearPyrealFind", "Undef" ),
    [MaterialType.Hematite] = JewelType( "GearSelfHarm", "Undef" ),
    [MaterialType.ImperialTopaz] = JewelType( "GearSlash", "GearSlashBane" ),
    [MaterialType.Jet] = JewelType( "GearLightning", "GearLightningBane" ),
    [MaterialType.LapisLazuli] = JewelType( "GearBlueFury", "GearHealthToMana" ),
    [MaterialType.LavenderJade] = JewelType( "GearSelflessness", "Undef" ),
    [MaterialType.Malachite] = JewelType( "GearCompBurn", "Undef" ),
    [MaterialType.Moonstone] = JewelType( "GearItemManaUsage", "Undef" ),
    [MaterialType.Onyx] = JewelType( "GearPhysicalWard", "Undef" ),
    [MaterialType.Opal] = JewelType( "GearManasteal", "Undef" ),
    [MaterialType.Peridot] = JewelType( "GearQuickness", "Undef" ),
    [MaterialType.RedGarnet] = JewelType( "GearFire", "GearFireBane" ),
    [MaterialType.RedJade] = JewelType( "GearFocus", "Undef" ),
    [MaterialType.RoseQuartz] = JewelType( "GearVitalsTransfer", "Undef" ),
    [MaterialType.Ruby] = JewelType( "GearRedFury", "Undef" ),
    [MaterialType.Sapphire] = JewelType( "GearMagicFind", "Undef" ),
    [MaterialType.SmokeyQuartz] = JewelType( "GearThreatReduction", "Undef" ),
    [MaterialType.Sunstone] = JewelType( "GearExperienceGain", "Undef" ),
    [MaterialType.TigerEye] = JewelType( "GearCoordination", "Undef" ),
    [MaterialType.Tourmaline] = JewelType( "GearWardPen", "Undef" ),
    [MaterialType.Turquoise] = JewelType( "GearBlock", "Undef" ),
    [MaterialType.WhiteJade] = JewelType( "GearHealBubble", "Undef" ),
    [MaterialType.WhiteQuartz] = JewelType( "GearThorns", "Undef" ),
    [MaterialType.WhiteSapphire] = JewelType( "GearBludgeon", "GearBludgeonBane" ),
    [MaterialType.YellowGarnet] = JewelType( "GearBravado", "Undef" ),
    [MaterialType.YellowTopaz] = JewelType( "GearEndurance", "Undef" ),
    [MaterialType.Zircon] = JewelType( "GearElementalWard", "Undef" )
  },{
    __index = function(t, key)
      local entry = rawget(t, key)
      return entry and entry.PrimaryRating or nil
    end
  })
  ItemExamine_Daralet.JewelTypeToMaterial = {
    ["GearThreatGain"] = MaterialType.Agate,
    ["GearYellowFury"] = MaterialType.Amber,
    ["GearNullification"] = MaterialType.Amethyst,
    ["GearFrost"] = MaterialType.Aquamarine,
    ["GearSelf"] = MaterialType.Azurite,
    ["GearPierce"] = MaterialType.BlackGarnet,
    ["GearReprisal"] = MaterialType.BlackOpal,
    ["GearLifesteal"] = MaterialType.Bloodstone,
    ["GearStrength"] = MaterialType.Carnelian,
    ["GearStaminasteal"] = MaterialType.Citrine,
    ["GearHardenedDefense"] = MaterialType.Diamond,
    ["GearAcid"] = MaterialType.Emerald,
    ["GearFamiliarity"] = MaterialType.FireOpal,
    ["GearElementalist"] = MaterialType.GreenGarnet,
    ["GearPyrealFind"] = MaterialType.GreenJade,
    ["GearSelfHarm"] = MaterialType.Hematite,
    ["GearSlash"] = MaterialType.ImperialTopaz,
    ["GearLightning"] = MaterialType.Jet,
    ["GearBlueFury"] = MaterialType.LapisLazuli,
    ["GearSelflessness"] = MaterialType.LavenderJade,
    ["GearCompBurn"] = MaterialType.Malachite,
    ["GearItemManaUsage"] = MaterialType.Moonstone,
    ["GearPhysicalWard"] = MaterialType.Onyx,
    ["GearManasteal"] = MaterialType.Opal,
    ["GearQuickness"] = MaterialType.Peridot,
    ["GearFire"] = MaterialType.RedGarnet,
    ["GearFocus"] = MaterialType.RedJade,
    ["GearVitalsTransfer"] = MaterialType.RoseQuartz,
    ["GearRedFury"] = MaterialType.Ruby,
    ["GearMagicFind"] = MaterialType.Sapphire,
    ["GearThreatReduction"] = MaterialType.SmokeyQuartz,
    ["GearExperienceGain"] = MaterialType.Sunstone,
    ["GearCoordination"] = MaterialType.TigerEye,
    ["GearWardPen"] = MaterialType.Tourmaline,
    ["GearBlock"] = MaterialType.Turquoise,
    ["GearHealBubble"] = MaterialType.WhiteJade,
    ["GearThorns"] = MaterialType.WhiteQuartz,
    ["GearBludgeon"] = MaterialType.WhiteSapphire,
    ["GearBravado"] = MaterialType.YellowGarnet,
    ["GearEndurance"] = MaterialType.YellowTopaz,
    ["GearElementalWard"] = MaterialType.Zircon,
    
    ["GearToughness"] = MaterialType.Diamond,
    ["GearResistance"] = MaterialType.Amethyst,
    ["GearHealthToStamina"] = MaterialType.Amber,
    ["GearHealthToMana"] = MaterialType.LapisLazuli,
    ["GearSlashBane"] = MaterialType.ImperialTopaz,
    ["GearBludgeonBane"] = MaterialType.WhiteSapphire,
    ["GearPierceBane"] = MaterialType.BlackGarnet,
    ["GearAcidBane"] = MaterialType.Emerald,
    ["GearFireBane"] = MaterialType.RedGarnet,
    ["GearFrostBane"] = MaterialType.Aquamarine,
    ["GearLightningBane"] = MaterialType.Jet,
  };
  
  local JewelEffectInfoAlternate = {
    -- armor
    [MaterialType.Diamond] = {
      PropertyName = "GearToughness",
      Name = "Toughness",
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Amethyst] = {
      PropertyName = "GearResistance",
      Name = "Resistance", 
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    [MaterialType.Jet] = {
      PropertyName = "GearLightningBane",
      Name = "Astyrrian's Bane",
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.RedGarnet] = {
      PropertyName = "GearFireBane",
      Name = "Inferno's Bane",
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Aquamarine] = {
      PropertyName = "GearFrostBane",
      Name = "Gelidite's Bane",
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Emerald] = {
      PropertyName = "GearAcidBane",
      Name = "Olthoi's Bane",
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.ImperialTopaz] = {
      PropertyName = "GearSlashBane",
      Name = "Swordsman's Bane",
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.BlackGarnet] = {
      PropertyName = "GearPierceBane",
      Name = "Archer's Bane",
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.WhiteSapphire] = {
      PropertyName = "GearBludgeonBane",
      Name = "Tusker's Bane",
      Slot = "piece of armor",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    [MaterialType.LapisLazuli] = {
      PropertyName = "GearHealthToMana",
      Name = "Austere Anchorite",
      Slot = "piece of armor",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Amber] = {
      PropertyName = "GearHealthToStamina",
      Name = "Masochist",
      Slot = "piece of armor",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
  }
  local JewelQuality = {
    [1] = "Scuffed",
    [2] = "Flawed", 
    [3] = "Mediocre",
    [4] = "Fine",
    [5] = "Admirable",
    [6] = "Superior",
    [7] = "Excellent",
    [8] = "Magnificent",
    [9] = "Peerless",
    [10] = "Flawless"
  }
  local JewelQualityStringToValue = {
    ["Scuffed"] = 1,
    ["Flawed"] = 2,
    ["Mediocre"] = 3,
    ["Fine"] = 4,
    ["Admirable"] = 5,
    ["Superior"] = 6,
    ["Excellent"] = 7,
    ["Magnificent"] = 8,
    ["Peerless"] = 9,
    ["Flawless"] = 10
  }
  
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
        -- reverse: name -> id
        for k, v in pairs(src) do
          if v == key then
            return k
          end
        end
      elseif type(key) == "key" then
        -- direct: id -> name
        return rawget(src, key)
      end
      return nil
    end
  })
  
  local JewelEffectInfoMain = {
    -- neck
    [MaterialType.Sunstone] = {
      PropertyName = "GearExperienceGain",
      Name = "Illuminated Mind",
      Slot = "necklace",
      BasePrimary = 5,
      BonusPrimary = 0.25,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Sapphire] = {
      PropertyName = "GearMagicFind",
      Name = "Seeker",
      Slot = "necklace",
      BasePrimary = 5,
      BonusPrimary = 0.25,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.GreenJade] = {
      PropertyName = "GearPyrealFind",
      Name = "Prosperity",
      Slot = "necklace",
      BasePrimary = 5,
      BonusPrimary = 0.25,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    -- ring
    [MaterialType.Carnelian] = {
      PropertyName = "GearStrength",
      Name = "Mighty Thews",
      Slot = "ring",
      BasePrimary = 10,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Azurite] = {
      PropertyName = "GearSelf",
      Name = "Erudite Mind",
      Slot = "ring",
      BasePrimary = 10,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.TigerEye] = {
      PropertyName = "GearCoordination",
      Name = "Dexterous Hand",
      Slot = "ring",
      BasePrimary = 10,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.RedJade] = {
      PropertyName = "GearFocus",
      Name = "Focused Mind",
      Slot = "ring",
      BasePrimary = 10,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.YellowTopaz] = {
      PropertyName = "GearEndurance",
      Name = "Perserverence",
      Slot = "ring",
      BasePrimary = 10,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Peridot] = {
      PropertyName = "GearQuickness",
      Name = "Swift-footed",
      Slot = "ring",
      BasePrimary = 10,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    -- bracelet
    [MaterialType.Agate] = {
      PropertyName = "GearThreatGain",
      Name = "Provocation",
      Slot = "bracelet",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.SmokeyQuartz] = {
      PropertyName = "GearThreatReduction",
      Name = "Clouded Vision",
      Slot = "bracelet",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Moonstone] = {
      PropertyName = "GearItemManaUsage",
      Name = "Meticulous Magus",
      Slot = "bracelet",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Malachite] = {
      PropertyName = "GearCompBurn",
      Name = "Thrifty Scholar",
      Slot = "bracelet",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Onyx] = {
      PropertyName = "GearPhysicalWard",
      Name = "Black Bulwark",
      Slot = "bracelet",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Zircon] = {
      PropertyName = "GearElementalWard",
      Name = "Prismatic Ward",
      Slot = "bracelet",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    -- bracelet (or armor)
    [MaterialType.Diamond] = {
      PropertyName = "GearHardenedDefense",
      Name = "Hardened Fortification",
      Slot = "bracelet",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Amethyst] = {
      PropertyName = "GearNullification",
      Name = "Nullification",
      Slot = "bracelet",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    -- shield
    [MaterialType.Turquoise] = {
      PropertyName = "GearBlock",
      Name = "Stalwart Defense",
      Slot = "shield",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.WhiteQuartz] = {
      PropertyName = "GearThorns",
      Name = "Swift Retrbution",
      Slot = "shield",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    -- weapon
    [MaterialType.Hematite] = {
      PropertyName = "GearSelfHarm",
      Name = "Blood Frenzy",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Bloodstone] = {
      PropertyName = "GearLifesteal",
      Name = "Sanguine Thirst",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Citrine] = {
      PropertyName = "GearStaminasteal",
      Name = "Vigor Siphon",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Opal] = {
      PropertyName = "GearManasteal",
      Name = "Ophidian",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.WhiteJade] = {
      PropertyName = "GearHealBubble",
      Name = "Purified Soul",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 2,
      BonusSecondary = 0.1
    },
    [MaterialType.RoseQuartz] = {
      PropertyName = "GearVitalsTransfer",
      Name = "Tilted-scales",
      Slot = "weapon",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Ruby] = {
      PropertyName = "GearRedFury",
      Name = "Red Fury",
      Slot = "weapon",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    -- weapon (or armor)
    [MaterialType.Jet] = {
      PropertyName = "GearLightning",
      Name = "Astyrrian Rage",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 2,
      BonusSecondary = 0.1
    },
    [MaterialType.RedGarnet] = {
      PropertyName = "GearFire",
      Name = "Blazing Brand",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 2,
      BonusSecondary = 0.1
    },
    [MaterialType.Aquamarine] = {
      PropertyName = "GearFrost",
      Name = "Bone-chiller",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 2,
      BonusSecondary = 0.1
    },
    [MaterialType.Emerald] = {
      PropertyName = "GearAcid",
      Name = "Devouring Mist",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 2,
      BonusSecondary = 0.1
    },
    [MaterialType.ImperialTopaz] = {
      PropertyName = "GearSlash",
      Name = "Falcon's Gyre",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.BlackGarnet] = {
      PropertyName = "GearPierce",
      Name = "Precision Strikes",
      Slot = "weapon",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.WhiteSapphire] = {
      PropertyName = "GearBludgeon",
      Name = "Skull-cracker",
      Slot = "weapon",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.LapisLazuli] = {
      PropertyName = "GearBlueFury",
      Name = "Blue Fury",
      Slot = "weapon",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Amber] = {
      PropertyName = "GearYellowFury",
      Name = "Yellow Fury",
      Slot = "weapon",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    -- weapon or shield
    [MaterialType.YellowGarnet] = {
      PropertyName = "GearBravado",
      Name = "Bravado",
      Slot = "weapon or shield",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.FireOpal] = {
      PropertyName = "GearFamiliarity",
      Name = "Familiar Foe",
      Slot = "weapon or shield",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.BlackOpal] = {
      PropertyName = "GearReprisal",
      Name = "Vicious Reprisal",
      Slot = "weapon or shield",
      BasePrimary = 5,
      BonusPrimary = 0.25,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    
    -- wand
    [MaterialType.GreenGarnet] = {
      PropertyName = "GearElementalist",
      Name = "Elementalist",
      Slot = "wand",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.Tourmaline] = {
      PropertyName = "GearWardPen",
      Name = "Ruthless Discernment",
      Slot = "wand",
      BasePrimary = 20,
      BonusPrimary = 1.0,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
    [MaterialType.LavenderJade] = {
      PropertyName = "GearSelflessness",
      Name = "Selfless Spirit",
      Slot = "wand",
      BasePrimary = 10,
      BonusPrimary = 0.5,
      BaseSecondary = 0,
      BonusSecondary = 0.0
    },
  }
  
  
  local function JewelStatsDescription(baseRating, amount, bonusPerQuality, name, bonusPerQualitySecondary, altName)
    altName = altName or ""
    
    local secondaryBonus = ""
    if bonusPerQualitySecondary then
      secondaryBonus = string.format([[
Secondary Bonus Rating: %.2f (%.2f x Quality)]], bonusPerQualitySecondary * amount, bonusPerQualitySecondary)
    end
    
    local altAdditionalSources = altName ~= "" and " or " .. altName or ""
    
    return string.format([[
Quality: %d (%s)
Bonus Rating: %.2f (%.2f x Quality)%s
    
    
Additional sources of %s%s will only add the bonus rating.]],
    amount, JewelQuality[amount] or "Unknown",
    bonusPerQuality * amount, bonusPerQuality,
    secondaryBonus, name, altAdditionalSources)
  end
  
  function ItemExamine_Daralet:GetJewelDescription(jewel)
    jewel = self.item
    local quality = jewel.IntValues["JewelQuality"] or 1
    local materialType = jewel.IntValues["JewelMaterialType"]
    
    -- legacy support
    if jewel.StringValues["LegacyJewelSocketString1"] ~= nil and jewel.StringValues["LegacyJewelSocketString1"] ~= "Empty" then
      local jewelString = {}
      -- split by '/' into jewelString[1], jewelString[2], ...
      for part in string.gmatch(jewel.StringValues["LegacyJewelSocketString1"], "[^/]+") do
        table.insert(jewelString, part)
      end
      
      -- jewelString[1] = quality string
      -- jewelString[2] = material string
      local matStr = jewelString[2]
      if matStr and StringToMaterialType[matStr] then
        local jewelMaterial = StringToMaterialType[matStr]
        materialType = jewelMaterial
        jewel.IntValues["JewelMaterialType"] = jewelMaterial
      end
      
      local qualStr = jewelString[1]
      if qualStr and JewelQualityStringToValue[qualStr] then
        local jewelQuality = JewelQualityStringToValue[qualStr]
        quality = jewelQuality
        jewel.IntValues["JewelQuality"] = jewelQuality
      end
      
      jewel.JewelSocket1 = nil
    end
    
    if materialType == nil then
      return ""
    end
    
    local name = ""
    local equipmentType = ""
    local baseRating = 0
    local bonusPerQuality = 0.0
    local baseRatingSecondary = 0
    local bonusPerQualitySecondary = 0.0
    
    local jewelEffectInfoMain = JewelEffectInfoMain[materialType]
    if jewelEffectInfoMain then
      name = jewelEffectInfoMain.Name
      equipmentType = jewelEffectInfoMain.Slot
      baseRating = jewelEffectInfoMain.BasePrimary
      bonusPerQuality = jewelEffectInfoMain.BonusPrimary
      baseRatingSecondary = jewelEffectInfoMain.BaseSecondary
      bonusPerQualitySecondary = jewelEffectInfoMain.BonusSecondary
    end
    
    local nameAlternate = ""
    local equipmentTypeAlternate = ""
    local baseRatingAlternate = 0
    local bonusPerQualityAlternate = 0.0
    local baseRatingSecondaryAlternate = 0
    local bonusPerQualitySecondaryAlternate = 0.0
    
    local jewelEffectInfoAlternate = JewelEffectInfoAlternate[materialType]
    if jewelEffectInfoAlternate then
      nameAlternate = jewelEffectInfoAlternate.Name
      equipmentTypeAlternate = jewelEffectInfoAlternate.Slot
      baseRatingAlternate = jewelEffectInfoAlternate.BasePrimary
      bonusPerQualityAlternate = jewelEffectInfoAlternate.BonusPrimary
      baseRatingSecondaryAlternate = jewelEffectInfoAlternate.BaseSecondary
      bonusPerQualitySecondaryAlternate = jewelEffectInfoAlternate.BonusSecondary
    end
    
    local alternateText = ""
    if nameAlternate ~= "" then
      alternateText = string.format(" OR in a %s to gain %s", equipmentTypeAlternate, nameAlternate)
    end
    
    local description = string.format(
    [[Socket this jewel in a %s to gain %s%s, while equipped. The target must be workmanship %d or greater.
    
]],
    equipmentType, name, alternateText, quality
  )
  
  -- alias for enum to shorten
  local MT = MaterialType
  
  if materialType == MT.Sunstone then
    description = description ..
    string.format([[~ %s: Gain %d%%%% increased experience from monster kills (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Sapphire then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% bonus to loot quality from monster kills (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.GreenJade then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% chance to receive an extra item from monster kills (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
    -- ring right
  elseif materialType == MT.Carnelian then
    description = description ..
    string.format([[~ %s: Gain %d Strength (+%.2f%%%% per equipped rating). Once socketed, the %s can only be worn on the right finger.
    
]],
    name, baseRating, bonusPerQuality, equipmentType) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Azurite then
    description = description ..
    string.format([[~ %s: Gain %d Self (+%.2f%%%% per equipped rating). Once socketed, the %s can only be worn on the right finger.
    
]],
    name, baseRating, bonusPerQuality, equipmentType) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.TigerEye then
    description = description ..
    string.format([[~ %s: Gain %d Coordination (+%.2f%%%% per equipped rating). Once socketed, the %s can only be worn on the right finger.
    
]],
    name, baseRating, bonusPerQuality, equipmentType) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
    -- ring left
  elseif materialType == MT.RedJade then
    description = description ..
    string.format([[~ %s: Gain %d Focus (+%.2f%%%% per equipped rating). Once socketed, the %s can only be worn on the left finger.
    
]],
    name, baseRating, bonusPerQuality, equipmentType) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.YellowTopaz then
    description = description ..
    string.format([[~ %s: Gain %d Endurance (+%.2f%%%% per equipped rating). Once socketed, the %s can only be worn on the left finger.
    
]],
    name, baseRating, bonusPerQuality, equipmentType) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Peridot then
    description = description ..
    string.format([[~ %s: Gain %d Quickness (+%.2f%%%% per equipped rating). Once socketed, the %s can only be worn on the left finger.
    
]],
    name, baseRating, bonusPerQuality, equipmentType) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
    -- bracelet left
  elseif materialType == MT.Agate then
    description = description ..
    string.format([[~ %s: Gain %d increased threat from your actions (+%.2f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the left wrist.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.SmokeyQuartz then
    description = description ..
    string.format([[~ %s: Gain %d reduced threat from your actions (+%.2f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the left wrist.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Moonstone then
    description = description ..
    string.format([[~ %s: Gain %d%%%% reduced mana consumed by items (+%.2f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the left wrist.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Malachite then
    description = description ..
    string.format([[~ %s: Gain %d%%%% reduced chance to burn spell components (+%.2f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the left wrist.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
    -- bracelet right
  elseif materialType == MT.Onyx then
    description = description ..
    string.format([[~ %s: Gain %d%%%% reduced damage taken from slashing, bludgeoning, and piercing damage types (+%.2f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the right wrist.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Zircon then
    description = description ..
    string.format([[~ %s: Gain %d%%%% reduced damage taken from acid, fire, cold, and electric damage types (+%.2f%%%% per equipped rating). Once socketed, the bracelet can only be worn on the right wrist.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
    -- bracelet right or armor
  elseif materialType == MT.Amethyst then
    description = description ..
    string.format([[~ %s: Gain up to %d%%%% reduced magic damage taken (+%.2f%%%% per equipped rating). The amount builds up from 0%%, based on how often you have recently been hit with a damaging spell. Once socketed, the bracelet can only be worn on the right wrist.
    
]],
    name, baseRating, bonusPerQuality) ..
    string.format([[~ %s: Gain +%d Physical Defense (+%.2f per equipped rating).
    
]],
    nameAlternate, baseRatingAlternate, bonusPerQualityAlternate) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. [[
    
]]
    
  elseif materialType == MT.Diamond then
    description = description ..
    string.format([[~ %s: Gain up to %d%%%% reduced physical damage taken (+%.2f%%%% per equipped rating). The amount builds up from 0%%, based on how often you have recently been hit with a damaging physical attack. Once socketed, the bracelet can only be worn on the right wrist.
    
]],
    name, baseRating, bonusPerQuality) ..
    string.format([[~ %s: Gain +%d Physical Defense (+%.2f per equipped rating).
    
]],
    nameAlternate, baseRatingAlternate, bonusPerQualityAlternate) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. [[
    
]]
    
    -- shield
  elseif materialType == MT.Turquoise then
    description = description ..
    string.format([[~ %s: Gain %d%%%% increased block chance (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.WhiteQuartz then
    description = description ..
    string.format([[~ %s: Deflect %d%% damage from a blocked attack back to a close-range attacker (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
    -- weapon + shield
  elseif materialType == MT.BlackOpal then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% chance to evade a critical attack (+%.2f%%%% per equipped rating). Your next attack after a the evade is a guaranteed critical.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.FireOpal then
    description = description ..
    string.format([[~ %s: Gain up to %d%%%% increased evade and resist chances, against the target you are attacking (+%.2f%%%% per equipped rating). The amount builds up from 0%%, based on how often you have recently hit the target.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.YellowGarnet then
    description = description ..
    string.format([[~ %s: Gain up to %d%%%% increased physical attack skill (+%.2f%%%% per equipped rating). The amount builds up from 0%%, based on how often you have recently hit the target.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
    -- weapon or armor
  elseif materialType == MT.Ruby then
    description = description ..
    string.format([[~ %s: Gain up to %d%%%% increased damage as your health approaches 0 (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Amber then
    description = description ..
    string.format([[~ %s: Gain up to %d%%%% increased damage as your stamina approaches 0 (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    string.format([[~ %s: Gain a %d%%%% chance after taking damage to gain the same amount as stamina (+%.2f per equipped rating).
    
]],
    nameAlternate, baseRatingAlternate, bonusPerQualityAlternate) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.LapisLazuli then
    description = description ..
    string.format([[~ %s: Gain up to %d%%%% increased damage as your mana approaches 0 (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    string.format([[~ %s: Gain a %d%%%% chance after taking damage to gain the same amount as mana (+%.2f per equipped rating).
    
]],
    nameAlternate, baseRatingAlternate, bonusPerQualityAlternate) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
    -- weapon only
  elseif materialType == MT.Bloodstone then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% chance on hit to gain health (+%.2f%%%% per equipped rating). Amount stolen is equal to 10%%%% of damage dealt.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Citrine then
    description = description ..
    string.format([[~ %s: Gain %d%%%% chance on hit to gain stamina (+%.2f%%%% per equipped rating). Amount stolen is equal to 10%%%% of damage dealt.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Opal then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% chance on hit to gain mana (+%.2f%%%% per equipped rating). Amount stolen is equal to 10%%%% of damage dealt.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Hematite then
    description = description ..
    string.format([[~ %s: Gain %d%%%% increased damage with all attacks (+%.2f%%%% per equipped rating). However, 10%%%% of your attacks will deal the extra damage to yourself as well.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.RoseQuartz then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% bonus to your transfer spells (+%.2f%%%% per equipped rating). Receive an equivalent reduction in the effectiveness of your other restoration spells.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.LavenderJade then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% bonus to your restoration spells on others (+%.2f%%%% per equipped rating). Receive an equivalent reduction in the effectiveness when cast on yourself.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.GreenGarnet then
    description = description ..
    string.format([[~ %s: Gain up to %d%%%% increased war magic damage (+%.2f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Tourmaline then
    description = description ..
    string.format([[~ %s: Gain up to %d%% ward cleaving (+%.2f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.
    
]],
    name, baseRating, bonusPerQuality) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.WhiteJade then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% bonus to your restoration spells (+%.2f%%%% per equipped rating). Also grants a %d%%%% chance to create a sphere of healing energy on top of your target when casting a restoration spell (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name) .. [[
    
]]
    
  elseif materialType == MT.Aquamarine then
    description = description ..
    string.format([[~ %s: Gain %d%%%% increased cold damage (+%.2f%%%% per equipped rating). Also grants a %d%%%% chance to surround your target with chilling mist (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) ..
    string.format([[~ %s: Gain +%.2f Frost Protection to all equipped armor (+%.2f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).
    
]],
    nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary, nameAlternate) .. [[
    
]]
    
  elseif materialType == MT.BlackGarnet then
    description = description ..
    string.format([[~ %s: Gain %d%%%% piercing resistance penetration (+%.2f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.
    
]],
    name, baseRating, bonusPerQuality) ..
    string.format([[~ %s: Gain +%.2f Piercing Protection to all equipped armor (+%.2f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).
    
]],
    nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. [[
    
]]
    
  elseif materialType == MT.Emerald then
    description = description ..
    string.format([[~ %s: Gain %d%%%% increased acid damage (+%.2f%%%% per equipped rating). Also grants a %d%%%% chance to surround your target with acidic mist (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) ..
    string.format([[~ %s: Gain +%.2f Acid Protection to all equipped armor (+%.2f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).
    
]],
    nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary, nameAlternate) .. [[
    
]]
    
  elseif materialType == MT.ImperialTopaz then
    description = description ..
    string.format([[~ %s: Gain a %d%%%% chance to cleave an additional target (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality) ..
    string.format([[~ %s: Gain +%.2f Slashing Protection to all equipped armor (+%.2f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).
    
]],
    nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. [[
    
]]
    
  elseif materialType == MT.Jet then
    description = description ..
    string.format([[~ %s: Gain %d%%%% increased electric damage (+%.2f%%%% per equipped rating). Also grants a %d%%%% chance to electrify the ground beneath your target (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) ..
    string.format([[~ %s: Gain +%.2f Lightning Protection to all equipped armor (+%.2f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).
    
]],
    nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary, nameAlternate) .. [[
    
]]
    
  elseif materialType == MT.RedGarnet then
    description = description ..
    string.format([[~ %s: Gain %d%%%% increased fire damage (+%.2f%%%% per equipped rating). Also grants a %d%%%% chance to set the ground beneath your target ablaze (+%.2f%%%% per equipped rating).
    
]],
    name, baseRating, bonusPerQuality, baseRatingSecondary, bonusPerQualitySecondary) ..
    string.format([[~ %s: Gain +%.2f Flame Protection to all equipped armor (+%.2f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).
    
]],
    nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, bonusPerQualitySecondary, nameAlternate) .. [[
    
]]
    
  elseif materialType == MT.WhiteSapphire then
    description = description ..
    string.format([[~ %s: Gain %d%%%% bludgeon critical damage (+%.2f%%%% per equipped rating). The amount builds up from 0%%%%, based on how often you have recently hit the target.
    
]],
    name, baseRating, bonusPerQuality) ..
    string.format([[~ %s: Gain +%.2f Bludgeoning Protection to all equipped armor (+%.2f per equipped rating). This bonus caps at a protection level rating of 1.2 (Above Average).
    
]],
    nameAlternate, baseRatingAlternate * 0.01, bonusPerQualityAlternate * 0.01) ..
    JewelStatsDescription(baseRating, quality, bonusPerQuality, name, nil, nameAlternate) .. [[
    
]]
  end
  
  return description
end

local function GetSocketDescription(materialType, quality)
  local materialString = StringToMaterialType[materialType]
  return string.format([[
  Socket: %s (%d)
]], materialString, quality)
end

function ItemExamine_Daralet:SetJewelcraftingUseText()
  self._hasExtraPropertiesText = true
  
  if self.item.WeenieType == WeenieType.CombatPet+4 then -- jewel
    self._extraPropertiesText = (self._extraPropertiesText or "") .. self.item:GetJewelDescription()
  else
    local sockets = self.item.IntValues["JewelSockets"] or 0
    for i = 1, sockets do
      --local detail = SocketedJewelDetails[i]  -- Lua arrays are 1-based; adjust if needed
      local currentSocketMaterialTypeId = self.item.IntValues["JewelSocket"..i.."Material"]
      local currentSocketQualityLevel = self.item.IntValues["JewelSocket"..i.."Quality"]
      
      if i == 1 and self.item.StringValues.LegacyJewelSocketString1 ~= "Empty" and self.item.StringValues.LegacyJewelSocketString1 ~= nil then
        local jewelString = {}
        for part in string.gmatch(self.item.StringValues.LegacyJewelSocketString1, "([^/]+)") do
          table.insert(jewelString, part)
        end
        
        local mt = StringToMaterialType[jewelString[2] ]
        if mt ~= nil then
          currentSocketMaterialTypeId = mt
        end
        
        local q = JewelQualityStringToValue[jewelString[1] ]
        if q ~= nil then
          currentSocketQualityLevel = q
        end
      end
      
      if i == 1 and self.item.StringValues.LegacyJewelSocketString2 ~= "Empty" and self.item.StringValues.LegacyJewelSocketString2 ~= nil then
        local jewelString = {}
        for part in string.gmatch(self.item.StringValues.LegacyJewelSocketString2, "([^/]+)") do
          table.insert(jewelString, part)
        end
        
        local mt = StringToMaterialType[jewelString[2] ]
        if mt ~= nil then
          currentSocketMaterialTypeId = mt
        end
        
        local q = JewelQualityStringToValue[jewelString[1] ]
        if q ~= nil then
          currentSocketQualityLevel = q
        end
      end
      
      --print(currentSocketMaterialTypeId==nil)
      if currentSocketMaterialTypeId == nil or currentSocketMaterialTypeId < 1 or
      currentSocketQualityLevel == nil or currentSocketQualityLevel < 1 then
        self._extraPropertiesText = (self._extraPropertiesText or "") .. [[
    Empty Jewel Socket
]]
        --print("----------" .. self._extraPropertiesText)
      else
        self._extraPropertiesText = (self._extraPropertiesText or "") ..
        GetSocketDescription(currentSocketMaterialTypeId, currentSocketQualityLevel)
      end
    end
  end
end

function ItemExamine_Daralet:SetDamagePenaltyUseText()
  local damageRating = self.item.IntValues["DamageRating"]
  if damageRating == nil or damageRating >= 0 then
    return
  end
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format([[Damage Penalty: %d%%
]], damageRating)
  self._hasExtraPropertiesText = true
end
function ItemExamine_Daralet:GetEquippedItemsSkillModSum(skillMod)
  if self.equippedItemsSkillModCache == nil then
    return 0
  end
  
  local value = self.equippedItemsSkillModCache[skillMod]
  if value ~= nil then
    return value
  end
  
  if self._log and self._log.Error then
    self._log:Error(string.format("Creature_Equipment.GetEquippedItemsSkillModSum() does not support %s", skillMod))
  end
  
  return 0
end

function ItemExamine_Daralet:SetArmorModUseText(floatString,floatVal, text, totalMod, multiplierOne, multiplierTwo)
  multiplierOne = multiplierOne or 100.0
  multiplierTwo = multiplierTwo or 100.0
  
  local armorMod = floatVal
  if armorMod == nil or armorMod < 0.001 then
    return
  end
  
  local wielder = (self.item.Wielder and self.item.Wielder.Id==game.CharacterId) or nil
  
  local mod = math.floor(armorMod * multiplierOne * 10 + 0.5) / 10
  local finalText = string.gsub(text, "%(ONE%)", tostring(mod))
  
  if wielder ~= nil and totalMod ~= 0.0 and totalMod ~= nil then
    totalMod = math.floor(totalMod * multiplierTwo * 100 + 0.5) / 100
    finalText = finalText .. string.format("  (%.2f%%%%)", totalMod)
    self._extraPropertiesText = (self._extraPropertiesText or "") .. finalText .. [[ 
]]
  else
    self._extraPropertiesText = (self._extraPropertiesText or "") .. finalText .. [[ 
]]
  end
  
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetJewelryManaConUseText()
  local manaConversionMod = self.item.FloatValues["ManaConversionMod"]
  if manaConversionMod == nil or manaConversionMod < 0.001 then
    return
  end
  
  if self.item.ObjectType == ObjectType.Jewelry or self.item.ObjectType == ObjectType.Armor or self.item.ObjectType == ObjectType.Clothing then
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format([[Bonus to Mana Conversion Skill: +%.1f%%%%
]], manaConversionMod * 100)
  end
  
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetArmorResourcePenaltyUseText()
  local armoResourcePenalty = self.item.FloatValues["ArmorResourcePenalty"]
  if armoResourcePenalty == nil or armoResourcePenalty < 0.001 then
    return
  end
  
  local wielder = (self.item.Wielder and self.item.Wielder.Id==game.CharacterId) or nil
  
  if wielder ~= nil then
    local totalArmorResourcePenalty =  self:GetEquippedItemsSkillModSum("ArmorResourcePenalty")
    --print(totalArmorResourcePenalty)
    self._extraPropertiesText = (self._extraPropertiesText or "") .. string.format(
[[Penalty to Stamina/Mana usage: %.1f%%%%  (%.2f%%%%)
]], armoResourcePenalty * 100, totalArmorResourcePenalty * 100)
  else
    self._extraPropertiesText = (self._extraPropertiesText or "") .. string.format(
[[Penalty to Stamina/Mana usage: %.1f%%%%
]], armoResourcePenalty * 100)
  end
  
  self._hasExtraPropertiesText = true
  --]]
end

function ItemExamine_Daralet:SetArmorWardLevelUseText()
  local wardLevel = self.item.IntValues["WardLevel"]
  if wardLevel == nil or wardLevel == 0 then
    return
  end
  
  local wielder = (self.item.Wielder and self.item.Wielder.Id==game.CharacterId) or nil
  
  if wielder ~= nil then
    local totalWardLevel = self:GetEquippedItemsWardSum("WardLevel")
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format([[Ward Level: %d  (%d)
]], wardLevel, totalWardLevel)
  else
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format([[Ward Level: %d
]], wardLevel)
  end
  
  self._hasExtraPropertiesText = true
end

local ArmorWeightClass ={
  None = 0,
  Cloth = 1,
  Light = 2,
  Heavy = 4
}

function ItemExamine_Daralet:SetArmorWeightClassUseText()
  local armorWeightClass = self.item.IntValues["ArmorWeightClass"]
  if armorWeightClass == nil or armorWeightClass <= 0 then
    return
  end
  
  local weightClassText = ""
  if armorWeightClass == ArmorWeightClass.Cloth then
    weightClassText = "Cloth"
  elseif armorWeightClass == ArmorWeightClass.Light then
    weightClassText = "Light"
  elseif armorWeightClass == ArmorWeightClass.Heavy then
    weightClassText = "Heavy"
  end
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format([[Weight Class: %s
]], weightClassText)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetBowElementalWarningUseText()
  local damageType = self.item.IntValues["DamageType"]
  if damageType == nil or damageType == DamageType.Slashing-1 then
    return
  end
  
  if not (self.item.IntValues["DefaultCombatStyle"]==0x00010 or self.item.IntValues["DefaultCombatStyle"]==0x00020 or self.item.IntValues["DefaultCombatStyle"]==0x00400) then
    return
  end
  
  local element = ""
  if damageType == DamageType.Slashing then
    element = "slashing"
  elseif damageType == DamageType.Piercing then
    element = "piercing"
  elseif damageType == DamageType.Bludgeoning then
    element = "bludgeoning"
  elseif damageType == DamageType.Acid then
    element = "acid"
  elseif damageType == DamageType.Fire then
    element = "fire"
  elseif damageType == DamageType.Cold then
    element = "cold"
  elseif damageType == DamageType.Electric then
    element = "electric"
  end
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format([[
The Damage Modifier on this weapon only applies to %s damage.
]], element)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponRestoModUseText()
  local weaponLifeMagicVitalMod = self.item.FloatValues["WeaponRestorationSpellsMod"]
  if weaponLifeMagicVitalMod == nil or weaponLifeMagicVitalMod < 1.001 then
    return
  end
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format(
  [[Healing Bonus for Restoration Spells: +%.1f%%%%
]],
  (weaponLifeMagicVitalMod - 1) * 100
)
self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponMagicDefenseUseText()
  local weaponMagicalDefense = self.item.FloatValues["WeaponMagicalDefense"]
  if weaponMagicalDefense == nil or weaponMagicalDefense <= 1.001 then
    return
  end
  
  local weaponMod = (weaponMagicalDefense - 1) * 100
  --+self.item.FloatValues["WeaponMagicalDefense"]
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format([[Bonus to Magic Defense: +%.1f%%%%
]], weaponMod)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponPhysicalDefenseUseText()
  local weaponPhysicalDefense = self.item.FloatValues["WeaponPhysicalDefense"]
  if weaponPhysicalDefense == nil or weaponPhysicalDefense <= 1.001 then
    return
  end
  
  local weaponMod = (weaponPhysicalDefense - 1) * 100
  -- + self.item.FloatValues["WeaponPhysicalDefense"] 
  
  self._extraPropertiesText = (self._extraPropertiesText or "") .. string.format([[Bonus to Physical Defense: +%.1f%%%%
]], weaponMod)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponLifeMagicUseText()
  local weaponLifeMagicMod = self.item.FloatValues["WeaponLifeMagicMod"]
  if weaponLifeMagicMod == nil or weaponLifeMagicMod < 0.001 then
    return
  end
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format([[Bonus to Life Magic Skill: +%.1f%%%%
]], weaponLifeMagicMod * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetWeaponWarMagicUseText()
  local weaponWarMagicMod = self.item.FloatValues["WeaponWarMagicMod"]
  if weaponWarMagicMod == nil or weaponWarMagicMod < 0.001 then
    return
  end
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format([[Bonus to War Magic Skill: +%.1f%%%%
]], weaponWarMagicMod * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetBowAttackModUseText()
  local weaponOffense = self.item.FloatValues["WeaponOffense"]
  if weaponOffense == nil or weaponOffense <= 1.001 then
    return
  end
  
  local weaponMod = (weaponOffense - 1) * 100
  if self.item.IntValues["WeaponSkill"] == SkillId.Bow or
  self.item.IntValues["WeaponSkill"] == SkillId.Crossbow or
  self.item.IntValues["WeaponSkill"] == SkillId.MissleWeapons then
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format([[Bonus to Attack Skill: +%.1f%%%%
]], weaponMod)
  end
  
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetAmmoEffectUseText()
  local ammoEffectUsesRemaining = self.item.IntValues["AmmoEffectUsesRemaining"]
  if ammoEffectUsesRemaining == nil or ammoEffectUsesRemaining <= 0 then
    return
  end
  
  local ammoEffect = self.item.IntValues["AmmoEffect"]
  if ammoEffect == nil or ammoEffect < 0 then
    return
  end
  
  local ammoEffectString = tostring(ammoEffect==0 and "Sharpened" or ammoEffect)
  ammoEffectString = ammoEffectString:gsub("(%u)", " %1"):gsub("^ ", "")
  
  if self.item.WeenieType == WeenieType.Ammunition then
    self._extraPropertiesText = (self._extraPropertiesText or "") ..
    string.format([[Ammo Effect: %s
]], ammoEffectString)
    self._extraPropertiesText = self._extraPropertiesText ..
    string.format([[Effect Uses Remaining: %d
]], ammoEffectUsesRemaining)
    
    local propertyDescription = ""
    
    if ammoEffect == 0 then
      propertyDescription = "~Sharpened: Increases damage by 10%%."
    end
    
    self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") .. propertyDescription
    self._hasExtraPropertiesText = true
  end
end

function ItemExamine_Daralet:SetSpellProcRateUseText()
  local procSpellRate = self.item.FloatValues["ProcSpellRate"]
  if procSpellRate == nil or procSpellRate <= 0.0 then
    return
  end
  
  if self.item.DataValues["ProcSpell"] == nil then
    return
  end
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format([[Cast on strike chance: %.1f%%%%
]], procSpellRate * 100)
  self._hasExtraPropertiesText = true
end

function ItemExamine_Daralet:SetAdditionalPropertiesUseText(itemData)
  if not self._hasAdditionalProperties then
    return
  end
  
  local additionaPropertiesString = ""
  for _, property in ipairs(self._additionalPropertiesList) do
    additionaPropertiesString = additionaPropertiesString .. property .. ", "
  end
  
  additionaPropertiesString = additionaPropertiesString:gsub("%s+$", "")
  additionaPropertiesString = additionaPropertiesString:gsub(",%s*$", "")
  
  local oomText = (self.item.IntValues["ItemWorkmanship"] ~= nil) and "" or "This item's properties will not activate if it is out of mana"
  
  self._extraPropertiesText = (self._extraPropertiesText or "") ..
  string.format([[Additional Properties: %s.
  
%s
  
]], additionaPropertiesString, oomText)
  self._hasExtraPropertiesText = true
end
local function GetTierFromWieldDifficulty(wieldDifficulty)
  local tiers = {
    [50] = 1,
    [125] = 2,
    [175] = 3,
    [200] = 4,
    [215] = 5,
    [230] = 6,
    [250] = 7,
    [270] = 8
  }
  
  -- Return the matching tier, or 1 by default if not found
  return tiers[wieldDifficulty] or 1
end
local StaminaCostReductionPerTier = {0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.075, 0.1}
local BonusCritChancePerTier = {0.0, 0.01, 0.015, 0.02, 0.025, 0.03, 0.4, 0.05}
local BonusCritMultiplierPerTier = {0.0, 0.01, 0.015, 0.02, 0.025, 0.03, 0.4, 0.05}

function ItemExamine_Daralet:SetStaminaReductionUseLongText()
  local staminaCostReductionMod = self.item.FloatValues["StaminaCostReductionMod"]
  if staminaCostReductionMod == nil or staminaCostReductionMod <= 0.001 then
    return
  end
  
  table.insert(self._additionalPropertiesList, "Stamina Cost Reduction")
  
  local ratingAmount = math.floor(staminaCostReductionMod * 100 + 0.5)
  
  local itemTier = GetTierFromWieldDifficulty(self.item.IntValues["WieldDifficulty"] or 1)
  local rangeMinAtTier = math.floor(StaminaCostReductionPerTier[itemTier] * 100 + 0.5)
  
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") .. string.format("~ Stamina Cost Reduction: Reduces stamina cost of attack by %d%%%%. " ..
  [[Roll range is based on item tier (%d%%%% to %d%%%%).
]], ratingAmount, rangeMinAtTier, rangeMinAtTier + 10)
end

function ItemExamine_Daralet:SetBitingStrikeUseLongText()
  local critFrequency = self.item.FloatValues["CriticalFrequency"]
  if critFrequency == nil or critFrequency <= 0.0 then
    return
  end
  
  local ratingAmount = math.floor((critFrequency - 0.1) * 100 + 0.5)
  
  local itemTier = GetTierFromWieldDifficulty(self.item.IntValues.WieldDifficulty or 1)
  local rangeMinAtTier = math.floor(BonusCritChancePerTier[itemTier] * 100 + 0.5)
  
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format("~ Biting Strike: Increases critical chance by +%d%%%%, additively. " ..
  [[Roll range is based on item tier (%d%%%% to %d%%%%).
]], ratingAmount, rangeMinAtTier, rangeMinAtTier + 5)
end

function ItemExamine_Daralet:SetCriticalStrikeUseLongText()
  local imbuedEffectCriticalStrike = self.item.IntValues["ImbuedEffect"]
  if imbuedEffectCriticalStrike ~= ImbuedEffectType.CriticalStrike then
    return
  end
  --print("Critical strike - depends on wielder etc. TODO")
  --[[ 
  local wielder = self.item.Wielder
  if itemData.OwnerId == nil and wielder == nil then
    return
  end
  
  local owner = wielder
  if owner == nil then
    owner = PlayerManager.GetOnlinePlayer(itemData.OwnerId)
  end
  if owner == nil then
    return
  end
  
  local criticalStrikeAmount = WorldObject.GetCriticalStrikeMod(owner:GetCreatureSkill(itemData.WeaponSkill), owner)
  local amountFormatted = math.floor(criticalStrikeAmount * 100 + 0.5)
  ]]
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format("~ Critical Strike: Increases critical chance by 5%%%% to 10%%%%), additively. " ..
  [[Value is based on wielder attack skill, up to 500 base.
]])
end

function ItemExamine_Daralet:SetCrushingBlowUseLongText()
  local critMultiplier = self.item.FloatValues["CriticalMultiplier"]
  if critMultiplier == nil or critMultiplier <= 1 then
    return
  end
  
  local ratingAmount = math.floor((critMultiplier - 1) * 100 + 0.5)
  
  local itemTier = GetTierFromWieldDifficulty(self.item.IntValues["WieldDifficulty"] or 1)
  local rangeMinAtTier = math.floor(BonusCritMultiplierPerTier[itemTier] * 100 + 0.5)
  
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format("~ Crushing Blow: Increases critical damage by +%d%%%%, additively. " ..
  [[Roll range is based on item tier (%d%%%% to %d%%%%).
]],
  ratingAmount, rangeMinAtTier, rangeMinAtTier + 50)
end

function ItemExamine_Daralet:SetCripplingBlowUseLongText()
  local imbuedEffectCripplingBlow = self.item.IntValues["ImbuedEffect"]
  if imbuedEffectCripplingBlow ~= ImbuedEffectType.CripplingBlow then
    return
  end
  --print("Crippling blow - depends on wielder etc. TODO")
  --[[
  local wielder = itemData.Wielder
  if itemData.OwnerId == nil and wielder == nil then
    return
  end
  
  local owner = wielder
  if owner == nil then
    owner = PlayerManager.GetOnlinePlayer(itemData.OwnerId)
  end
  if owner == nil then
    return
  end
  
  local cripplingBlowAmount = WorldObject.GetCripplingBlowMod(owner:GetCreatureSkill(itemData.WeaponSkill), owner)
  local amountFormatted = math.floor(cripplingBlowAmount * 100 + 0.5)
  ]]
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format("~ Crippling Blow: Increases critical damage by 50%%%% to 100%%%%, additively. " ..
  [[Value is based on wielder attack skill, up to 500 base.
]])
  
end

local BonusIgnoreArmorPerTier = {0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.075, 0.1}
function ItemExamine_Daralet:SetArmorCleavingUseLongText()
  local ignoreArmor = self.item.FloatValues["IgnoreArmor"]
  if ignoreArmor == nil or ignoreArmor == 0 then
    return
  end
  
  local ratingAmount = 100 - math.floor(ignoreArmor * 100 + 0.5)
  
  local itemTier = GetTierFromWieldDifficulty(self.item.IntValues["WieldDifficulty"] or 1)
  local rangeMinAtTier = 10 + math.floor(BonusIgnoreArmorPerTier[itemTier] * 100 + 0.5)
  
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format("~ Armor Cleaving: Increases armor ignored by %d%%%%, additively. " ..
  [[Roll range is based on item tier (%d%%%% to %d%%%%)
]],
  ratingAmount, rangeMinAtTier, rangeMinAtTier + 10)
end

function ItemExamine_Daralet:SetArmorRendUseLongText()
  local imbuedEffectArmorRend = self.item.IntValues["ImbuedEffect"]
  if imbuedEffectArmorRend ~= ImbuedEffectType.ArmorRending then
    return
  end
  --print("Armor rend - depends on wielder etc. TODO")
  --[[
  local wielder = self.item.Wielder
  if itemData.OwnerId == nil and wielder == nil then
    return
  end
  
  local owner = wielder
  if owner == nil then
    owner = PlayerManager.GetOnlinePlayer(itemData.OwnerId)
  end
  if owner == nil then
    return
  end
  
  local rendingAmount = WorldObject.GetArmorRendingMod(owner:GetCreatureSkill(itemData.WeaponSkill), owner)
  local amountFormatted = math.floor(rendingAmount * 100 + 0.5)
  ]]
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format("~ Armor Rending: Increases armor ignored by 10%%%% to 20%%%%, additively. " ..
  [[Value is based on wielder attack skill, up to 500 base.
]])
  
end

function ItemExamine_Daralet:SetResistanceCleavingUseLongText()
  local resistanceModifier = self.item.FloatValues["ResistanceModifier"]
  if resistanceModifier == nil or resistanceModifier == 0 then
    return
  end
  
  local ratingAmount = math.floor(resistanceModifier * 100 + 0.5)
  
  local element = ""
  if self.item.IntValues["ResistanceModifierType"] == DamageType.Acid then
    element = "Acid"
  elseif self.item.IntValues["ResistanceModifierType"] == DamageType.Bludgeoning then
    element = "Bludgeoning"
  elseif self.item.IntValues["ResistanceModifierType"] == DamageType.Cold then
    element = "Cold"
  elseif self.item.IntValues["ResistanceModifierType"] == DamageType.Electric then
    element = "Lightning"
  elseif self.item.IntValues["ResistanceModifierType"] == DamageType.Fire then
    element = "Fire"
  elseif self.item.IntValues["ResistanceModifierType"] == DamageType.Piercing then
    element = "Piercing"
  elseif self.item.IntValues["ResistanceModifierType"] == DamageType.Slashing then
    element = "Slashing"
  end
  
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format([[~ Resistance Cleaving (%s): Increases %s damage by +%d%%%%, additively.
]],
  element, string.lower(element), ratingAmount)
end

function ItemExamine_Daralet:SetResistanceRendLongText(itemData, imbuedEffectType, elementName)
  local imbuedEffect = self.item.IntValues["ImbuedEffect"]
  if imbuedEffect ~= imbuedEffectType then
    return
  end
  --[[
  local wielder = itemData.Wielder
  if itemData.OwnerId == nil and wielder == nil then
    return
  end
  
  local owner = wielder
  if owner == nil then
    owner = PlayerManager.GetOnlinePlayer(itemData.OwnerId)
  end
  if owner == nil then
    return
  end
  
  local rendingAmount = WorldObject.GetRendingMod(owner:GetCreatureSkill(itemData.WeaponSkill), owner)
  local amountFormatted = math.floor(rendingAmount * 100 + 0.5)
  ]]
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format("~ %s Rending: Increases %s damage by 15%%%% to 30%%%%, additively. " ..
  [[Value is based on wielder attack skill, up to 500 base.
]],
  elementName, string.lower(elementName))
end
local BonusIgnoreWardPerTier = {0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.075, 0.1}
function ItemExamine_Daralet:SetWardCleavingUseLongText()
  local ignoreWard = self.item.FloatValues["IgnoreWard"]
  if ignoreWard ~= nil and ignoreWard ~= 0 then
    table.insert(self._additionalPropertiesList, "Ward Cleaving")
    
    local ratingAmount = 100 - math.floor(ignoreWard * 100 + 0.5)
    
    local itemTier = GetTierFromWieldDifficulty(self.item.IntValues["WieldDifficulty"] or 1)
    local rangeMinAtTier = 10 + math.floor(BonusIgnoreWardPerTier[itemTier] * 100 + 0.5)
    
    self._hasExtraPropertiesText = true
    
    self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    string.format("~ Ward Cleaving: Increases ward ignored by %d%%%%, additively. " ..
    [[Roll range is based on item tier (%d%%%% to %d%%%%).
]],
    ratingAmount, rangeMinAtTier, rangeMinAtTier + 10)
  end
end

function ItemExamine_Daralet:SetWardRendingUseLongText()
  local imbuedEffect = self.item.IntValues["ImbuedEffect"]
  if imbuedEffect ~= 0x8000 then
    return
  end
  
  table.insert(self._additionalPropertiesList, "Ward Rending")
  
  --print("Resistance rend - depends on wielder etc. TODO")
  --[[
  local wielder = itemData.Wielder
  if itemData.OwnerId == nil and wielder == nil then
    return
  end
  
  local owner = wielder
  if owner == nil then
    owner = PlayerManager.GetOnlinePlayer(itemData.OwnerId)
  end
  if owner == nil then
    return
  end
  
  local rendingAmount = WorldObject.GetWardRendingMod(owner:GetCreatureSkill(itemData.WeaponSkill))
  local amountFormatted = math.floor(rendingAmount * 100 + 0.5)
  ]]
  self._hasExtraPropertiesText = true
  
  self._additionalPropertiesLongDescriptionsText =
  (self._additionalPropertiesLongDescriptionsText or "") ..
  string.format("~ Ward Rending: Increases ward ignored by 10%%%% to 20%%%%, additively. " ..
  [[Value is based on wielder attack skill, up to 500 base.
]])
end

function ItemExamine_Daralet:SetNoCompsRequiredSchoolUseLongText()
  local noCompsForPortalSpells = self.item.IntValues["NoCompsRequiredForMagicSchool"]
  if noCompsForPortalSpells == nil or noCompsForPortalSpells == 0 then
    return
  end
  
  if noCompsForPortalSpells == MagicSchool.WarMagic then
    table.insert(self._additionalPropertiesList, "War Primacy")
    self._additionalPropertiesLongDescriptionsText =
    (self._additionalPropertiesLongDescriptionsText or "") ..
    "~ War Primacy: War Magic spells cast do not require or consume components. Spells from other schools cannot be cast."
    elseif noCompsForPortalSpells == MagicSchool.LifeMagic then
      table.insert(self._additionalPropertiesList, "Life Primacy")
      self._additionalPropertiesLongDescriptionsText =
      (self._additionalPropertiesLongDescriptionsText or "") ..
      "~ Life Primacy: Life Magic spells cast do not require or consume components. Spells from other schools cannot be cast."
      elseif noCompsForPortalSpells == MagicSchool.ItemEnchantment then
        table.insert(self._additionalPropertiesList, "Portal Primacy")
        self._additionalPropertiesLongDescriptionsText =
        (self._additionalPropertiesLongDescriptionsText or "") ..
        "~ Portal Primacy: Portal Magic spells cast do not require or consume components. Spells from other schools cannot be cast."
        end
        
        self._hasExtraPropertiesText = true
        self._hasAdditionalProperties = true
      end
      
      local function GetProtectionLevelText(protectionMod)
        if protectionMod <= 0.39 then
          return "Poor"
        elseif protectionMod <= 0.79 then
          return "Below Average"
        elseif protectionMod <= 1.19 then
          return "Average"
        elseif protectionMod <= 1.59 then
          return "Above Average"
        else
          return "Unparalleled"
        end
      end
      
      function ItemExamine_Daralet:SetProtectionLevelsUseText()
        local armorLevel = self.item.IntValues["ArmorLevel"]
        if armorLevel ~= nil and armorLevel == 0 and self.item.IntValues["ArmorWeightClass"] == ArmorWeightClass.Cloth then
          local slashingMod = self.item.FloatValues["ArmorModVsSlash"] or 1.0
          local piercingMod = self.item.FloatValues["ArmorModVsPierce"] or 1.0
          local bludgeoningMod = self.item.FloatValues["ArmorModVsBludgeon"] or 1.0
          local fireMod = self.item.FloatValues["ArmorModVsFire"] or 1.0
          local coldMod = self.item.FloatValues["ArmorModVsCold"] or 1.0
          local acidMod = self.item.FloatValues["ArmorModVsAcid"] or 1.0
          local electricMod = self.item.FloatValues["ArmorModVsElectric"] or 1.0
          
          local function fmt(v) return string.format("%0.2f", v) end
          
          self._extraPropertiesText = (self._extraPropertiesText or "") ..
          string.format([[Slashing: %s (%s) 
]],  GetProtectionLevelText(slashingMod), fmt(slashingMod))
          self._extraPropertiesText = self._extraPropertiesText ..
          string.format([[Piercing: %s (%s) 
]], GetProtectionLevelText(piercingMod), fmt(piercingMod))
          self._extraPropertiesText = self._extraPropertiesText ..
          string.format([[Bludgeoning: %s (%s) 
]], GetProtectionLevelText(bludgeoningMod), fmt(bludgeoningMod))
          self._extraPropertiesText = self._extraPropertiesText ..
          string.format([[Fire: %s (%s) 
]], GetProtectionLevelText(fireMod), fmt(fireMod))
          self._extraPropertiesText = self._extraPropertiesText ..
          string.format([[Cold: %s (%s) 
]], GetProtectionLevelText(coldMod), fmt(coldMod))
          self._extraPropertiesText = self._extraPropertiesText ..
          string.format([[Acid: %s (%s) 
]], GetProtectionLevelText(acidMod), fmt(acidMod))
          self._extraPropertiesText = self._extraPropertiesText ..
          string.format([[Electric: %s (%s)
          
]], GetProtectionLevelText(electricMod), fmt(electricMod))
          
          self._hasExtraPropertiesText = true
        end
      end
      function ItemExamine_Daralet:GetJewelRating(intStringName)
        local total = 0
        local sockets = self.item.IntValues["JewelSockets"] or 0
        for i = 1, sockets do
          --local detail = SocketedJewelDetails[i]  -- Lua arrays are 1-based; adjust if needed
          local jewelMaterial = self.item.IntValues["JewelSocket"..i.."Material"]
          local jewelQuality = self.item.IntValues["JewelSocket"..i.."Quality"]
          local jewelAlternate = self.item.BoolValues["JewelSocket"..i.."AlternateEffect"]
          
          -- Skip if any property is nil
          if jewelMaterial ~= nil and jewelQuality ~= nil and jewelAlternate ~= nil then
            local materialType = self.JewelMaterialToType[jewelMaterial]
            
            -- Check alternate effect
            if (jewelAlternate ~= true and materialType.PrimaryRating ~= intStringName) or 
            (jewelAlternate == true and materialType.AlternateRating ~= intStringName) then
              
            else
              total = total + jewelQuality
            end
            
          end
        end
        
        return total
      end
      
      function ItemExamine_Daralet:SetGearRatingText(intStringName, intVal, name, description, multiplierOne, multiplierTwo, baseOne, baseTwo, percent)
        multiplierOne = multiplierOne or 1.0
        multiplierTwo = multiplierTwo or 1.0
        baseOne = baseOne or 0.0
        baseTwo = baseTwo or 0.0
        percent = percent or false
        
        local itemGearRating = intVal or 0
        local jewelGearRating = self:GetJewelRating(intStringName)
        local totalRatingOnItem = itemGearRating + jewelGearRating
        
        if totalRatingOnItem < 1 then
          return
        end
        
        local ratingRomanNumeral = "" .. totalRatingOnItem
        
        table.insert(self._additionalPropertiesList, string.format("%s %s", name, ratingRomanNumeral))
        self._hasAdditionalProperties = true
        
        local ratingFromAllEquippedItems = self:GetEquippedAndActivatedItemRatingSum("IntValues",intStringName)
        --local wielder = self.item.Wielder
        --if wielder ~= nil and wielder.IsPlayer then
        --        ratingFromAllEquippedItems = 0
        --end
                
        local percentSign = percent and "%%%%" or ""
        local amountOne = math.floor((baseOne + ratingFromAllEquippedItems * multiplierOne) * 100 + 0.5) / 100
        local amountTwo = math.floor((baseTwo + ratingFromAllEquippedItems * multiplierTwo) * 100 + 0.5) / 100

        local desc = description
        
        desc = string.gsub(desc, "(ONE)",  tostring(amountOne) .. percentSign )
        desc = string.gsub(desc, "(TWO)",  tostring(amountTwo) .. percentSign )
        
        self._additionalPropertiesLongDescriptionsText = (self._additionalPropertiesLongDescriptionsText or "") .. string.format([[~ %s: %s
]], name, desc)
      end
      function ItemExamine_Daralet:SetWeaponSpellcraftText()
        if (self.item.IntValues["ItemCurMana"] ~= nil) then
          return
        end
        
        local itemSpellCraft = self.item.IntValues["ItemSpellcraft"]
        if itemSpellCraft ~= nil then
          self._extraPropertiesText = self._extraPropertiesText .. "Spellcraft: " .. itemSpellCraft .. "." .. [[ 
]]
          self.item.StringValues["Use"] = self._extraPropertiesText;
        end
        
      end
      
      ------------------------------------------------
      --------------- formerly equipmentFunctions.lua
      ------------------------------------------------
      
      local MaterialValidLocations = {
        -- wand only
        [MaterialType.Tourmaline] = 0x01000000,
        [MaterialType.GreenGarnet] = 0x01000000,
        [MaterialType.LavenderJade] = 0x01000000,
        
        -- any weapon 
        [MaterialType.Opal] = 0x03500000,
        [MaterialType.RoseQuartz] = 0x03500000,
        [MaterialType.Hematite] = 0x03500000,
        [MaterialType.Bloodstone] = 0x03500000,
        [MaterialType.WhiteJade] = 0x03500000,
        
        -- weapon or armor
        [MaterialType.ImperialTopaz] = 0x03507F21,
        [MaterialType.BlackGarnet] = 0x03507F21 ,
        [MaterialType.Jet] = 0x03507F21,
        [MaterialType.RedGarnet] = 0x03507F21,
        [MaterialType.Aquamarine] = 0x03507F21,
        [MaterialType.WhiteSapphire] = 0x03507F21,
        [MaterialType.Emerald] = 0x03507F21,
        [MaterialType.Amber] = 0x03507F21,
        [MaterialType.LapisLazuli] = 0x03507F21,
        -- shield only
        [MaterialType.WhiteQuartz] = 0x00200000,
        [MaterialType.Turquoise] = 0x00200000,
        -- shield or melee weapon
        [MaterialType.Ruby] = 0x03700000,
        [MaterialType.BlackOpal] = 0x03700000,
        [MaterialType.FireOpal] = 0x03700000,
        [MaterialType.YellowGarnet] = 0x03700000,
        -- bracelet only (left rest)
        [MaterialType.SmokeyQuartz] = 0x00030000,
        [MaterialType.Agate] = 0x00030000,
        [MaterialType.Moonstone] = 0x00030000,
        [MaterialType.Citrine] = 0x00030000,
        [MaterialType.Malachite] = 0x00030000,
        -- bracelet only (right rest)
        [MaterialType.Onyx] = 0x00030000,
        [MaterialType.Zircon] = 0x00030000,
        -- bracelet only OR armor
        [MaterialType.Diamond] = 0x00037F21,
        [MaterialType.Amethyst] = 0x00037F21,
        -- ring only (left rest)
        [MaterialType.Peridot] = 0x000C0000,
        [MaterialType.RedJade] = 0x000C0000,
        [MaterialType.YellowTopaz] = 0x000C0000,
        -- ring only (right rest)
        [MaterialType.Carnelian] = 0x000C0000,
        [MaterialType.Azurite] = 0x000C0000,
        [MaterialType.TigerEye] = 0x000C0000,
        -- necklace only
        [MaterialType.Sapphire] = 0x00008000,
        [MaterialType.Sunstone] = 0x00008000,
        [MaterialType.GreenJade] = 0x00008000,
      }
      
      
      
      function ItemExamine_Daralet:AddItemToCaches(wo)
        local item = AppraiseInfo[wo.Id]
        if not item then return end
        if self.equippedItems[wo.Id] then
          self:RemoveItemFromEquippedItemsRatingCache(wo)
          self:RemoveItemFromEquippedItemsSkillModCache(wo)
          self.equippedItems[wo.Id] = false
        end
        for _, propName in pairs(RATING_PROPERTIES) do
          self.equippedItemsRatingCache[propName] = (self.equippedItemsRatingCache[propName] or 0) + (item["IntValues"][propName] or 0)
        end
        for _, propFloat in pairs(SKILLMOD_PROPERTIES) do
          self.equippedItemsSkillModCache[propFloat] = (self.equippedItemsSkillModCache[propFloat] or 0.0) + (item["FloatValues"][propFloat] or 0.0)
        end
        self.equippedItems[wo.Id] = true
      end
      function ItemExamine_Daralet:RemoveItemFromEquippedItemsSkillModCache(wo)
        local item = AppraiseInfo[wo.Id]
        if not self.equippedItems[wo.Id] then
          return
        end
        for _, propFloat in pairs(SKILLMOD_PROPERTIES) do
          self.equippedItemsSkillModCache[propFloat] = (self.equippedItemsSkillModCache[propFloat] or 0.0) - (item["FloatValues"][propFloat] or 0.0)
        end
      end
      function ItemExamine_Daralet:RemoveItemFromEquippedItemsRatingCache(wo)
        local item = AppraiseInfo[wo.Id]
        if not item then
          return
        end
        if not self.equippedItems[wo.Id] then
          return
        end
        
        for _, propString in pairs(RATING_PROPERTIES) do
          local value = (item["IntValues"][propString] or 0)
          self.equippedItemsRatingCache[propString] = (self.equippedItemsRatingCache[propString] or 0) - value
        end
      end
      
      function ItemExamine_Daralet:GetEquippedItemsWardSum(wardLevel)
        return self:GetEquippedItemsRatingSum(wardLevel)
      end
      function ItemExamine_Daralet:GetEquippedItemsRatingSum(propString)
        for _,gear in pairs(game.Character.Equipment) do
          if self.equippedItems[gear.Id]==nil and AppraiseInfo[gear.Id]~=nil then
            self:AddItemToCaches(gear)
          end
        end
        
        local value = self.equippedItemsRatingCache[propString]
        if value ~= nil then 
          return value 
        end
        if self._log and self._log.Error then
          self._log:Error(string.format("self.GetEquippedItemsRatingSum() does not support %s", propString))
        end
        return 0
      end
      function ItemExamine_Daralet:GetEquippedAndActivatedItemRatingSum(propertyType,propertyString)
        local ratingAmount = 0
        for _, wo in pairs(game.Character.Equipment) do
          local item = AppraiseInfo[wo.Id]
          
          -- Skip items that require mana but have none
          if item~=nil and item.BoolValues~=nil and item.IntValues~=nil and 
              (not item.BoolValues["SpecialPropertiesRequireMana"] or 
              (item.IntValues["ItemCurMana"]~=nil and (item.IntValues["ItemCurMana"] > 0))) then
            ratingAmount = ratingAmount + (item[propertyType][propertyString] or 0)
            
            -- Add socketed jewels
            ratingAmount = ratingAmount + self:GetRatingFromSocketedJewels(propertyString, item)
            
          end
        end
        return ratingAmount
      end
      function ItemExamine_Daralet:GetRatingFromSocketedJewels(propertyString, item)
        local jewelRating = 0
        local sockets = item.IntValues["JewelSockets"] or 0
        
        for i = 1, sockets do
          --local detail = SocketedJewelDetails[i]  -- Lua arrays are 1-based; adjust if needed
          local jewelMaterial = item.IntValues["JewelSocket"..i.."Material"]
          local jewelQuality = item.IntValues["JewelSocket"..i.."Quality"]
          local jewelAlternate = item.BoolValues["JewelSocket"..i.."AlternateEffect"]
          local itemLocation = item.IntValues["ValidLocations"]
          
          -- Skip if any property is nil
          if jewelMaterial ~= nil and jewelQuality ~= nil and jewelAlternate ~= nil then
            local materialType = self.JewelMaterialToType[jewelMaterial]
            jewelRating = jewelRating + self:GetRatingFromJewel(propertyString, itemLocation, materialType, jewelQuality)
          end
        end
        return jewelRating
      end
      
      
      function ItemExamine_Daralet:GetRatingFromJewel(propertyString, equipMask, jewelMaterialType, jewelQuality)
        -- Check material type match
        if not self.JewelTypeToMaterial[propertyString] or self.JewelTypeToMaterial[propertyString] ~= jewelMaterialType then
          return 0
          
          -- Check equip location compatibility
        elseif (bit.band(MaterialValidLocations[jewelMaterialType],equipMask)) ~= equipMask then
          return 0
          
          -- Armor uses alternate rating, weapons use primary
        elseif (bit.band(0x00007F21,equipMask)) == 0x00007F21 and self.JewelMaterialToType[jewelMaterialType].AlternateRating ~= propertyString then
          return 0
        elseif self.JewelMaterialToType[jewelMaterialType].PrimaryRating ~= propertyString then
          return 0
        end
        
        return jewelQuality
      end
      
      return ItemExamine_Daralet