-- manifest_base.lua
-- Covers ItemExamine Show* methods only.
-- propId  = standard enum (has .ToNumber())
-- propKey = nil for all base entries

local C = require("item_category").Category
local bit = require("bit")

local M = {}

-- ── Universal ─────────────────────────────────────────────────────────────────

M.universal = {
  {
    label    = "Name",
    pretext  = "Name: ",   posttext = "",
    propType = "StringValues",  propKey   = "Name",
    widget   = "string",       ops      = {"Regex ->"},
    default  = "",           categories = "*",
  },
  {
    label    = "Material",
    pretext  = "Material: ",   posttext = "",
    propType = "IntValue",  propKey   = "MaterialType",
    widget   = "enum",       ops      = {">=","<=",">","<","=="},
    enumTable = {
        [0x0000] = "Unknown",        [0x0001] = "Ceramic",        [0x0002] = "Porcelain",
        --[0x0003] = "Cloth",
        [0x0004] = "Linen",          [0x0005] = "Satin",          [0x0006] = "Silk",
        [0x0007] = "Velvet",         [0x0008] = "Wool",           --[0x0009] = "Gem",
        [0x000A] = "Agate",          [0x000B] = "Amber",          [0x000C] = "Amethyst",
        [0x000D] = "Aquamarine",     [0x000E] = "Azurite",        [0x000F] = "BlackGarnet",
        [0x0010] = "BlackOpal",      [0x0011] = "Bloodstone",     [0x0012] = "Carnelian",
        [0x0013] = "Citrine",        [0x0014] = "Diamond",        [0x0015] = "Emerald",
        [0x0016] = "FireOpal",       [0x0017] = "GreenGarnet",    [0x0018] = "GreenJade",
        [0x0019] = "Hematite",       [0x001A] = "ImperialTopaz",  [0x001B] = "Jet",
        [0x001C] = "LapisLazuli",    [0x001D] = "LavenderJade",   [0x001E] = "Malachite",
        [0x001F] = "Moonstone",      [0x0020] = "Onyx",           [0x0021] = "Opal",
        [0x0022] = "Peridot",        [0x0023] = "RedGarnet",      [0x0024] = "RedJade",
        [0x0025] = "RoseQuartz",     [0x0026] = "Ruby",           [0x0027] = "Sapphire",
        [0x0028] = "SmokeyQuartz",   [0x0029] = "Sunstone",       [0x002A] = "TigerEye",
        [0x002B] = "Tourmaline",     [0x002C] = "Turquoise",      [0x002D] = "WhiteJade",
        [0x002E] = "WhiteQuartz",    [0x002F] = "WhiteSapphire",  [0x0030] = "YellowGarnet",
        [0x0031] = "YellowTopaz",    [0x0032] = "Zircon",         [0x0033] = "Ivory",
        [0x0034] = "Leather",        [0x0035] = "ArmoredilloHide",[0x0036] = "GromnieHide",
        [0x0037] = "ReedSharkHide",  --[0x0038] = "Metal",
        [0x0039] = "Brass",          [0x003A] = "Bronze",         [0x003B] = "Copper",
        [0x003C] = "Gold",           [0x003D] = "Iron",           [0x003E] = "Pyreal",
        [0x003F] = "Silver",         [0x0040] = "Steel",          --[0x0041] = "Stone",
        [0x0042] = "Alabaster",      [0x0043] = "Granite",        [0x0044] = "Marble",
        [0x0045] = "Obsidian",       [0x0046] = "Sandstone",      [0x0047] = "Serpentine",
        --[0x0048] = "Wood",
        [0x0049] = "Ebony",          [0x004A] = "Mahogany",       [0x004B] = "Oak",
        [0x004C] = "Pine",           [0x004D] = "Teak",
    },
    default  = 1,           categories = "*",
  },
  {
    label    = "Value",
    pretext  = "Value: ",   posttext = "",
    propType = "IntValues",  propKey   = "Value",
    widget   = "int",       ops      = {">=","<=",">","<","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Burden",
    pretext  = "Burden: ",  posttext = "",
    propType = "IntValues",  propKey   = "EncumbranceVal",
    widget   = "int",       ops      = {">=","<=",">","<"},
    default  = 0,           categories = "*",
  },
  {
    label    = "Workmanship",
    pretext  = "Workmanship: ",  posttext = "",
    propType = "IntValues",       propKey   = "ItemWorkmanship",
    widget   = "enum",
    enumTable = {
      [1]="(1) Poorly crafted",[2]="(2) Well-crafted",[3]="(3) Finely crafted",
      [4]="(4) Exquisitely crafted",[5]="(5) Magnificent",[6]="(6) Nearly flawless",
      [7]="(7) Flawless",[8]="(8) Utterly flawless",[9]="(9) Incomparable",[10]="(10) Priceless",
    },
    ops      = {">=","<=","=="},
    default  = 1,           categories = "*",
  },
  {
    label    = "Times Tinkered",
    pretext  = "This item has been tinkered ",  posttext = " times.",
    propType = "IntValues",  propKey   = "NumTimesTinkered",
    widget   = "int",       ops      = {"==",">=","<="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Equipment Set",
    pretext  = "Set: ",  posttext = "",
    propType = "IntValues",  propKey = "EquipmentSetId",
    widget   = "enumset",    
    enumTable = SetNames or {},
    ops      = {"is one of"},
    default  = 1,        categories = "*",
  },

  -- Ratings (all universal, only present if > 0)
  {
    label    = "Damage Rating",
    pretext  = "Dam ",      posttext = "",
    propType = "IntValues",  propKey   = "GearDamage",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Damage Resist Rating",
    pretext  = "Dam Resist ", posttext = "",
    propType = "IntValues",  propKey   = "GearDamageResist",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Crit Rating",
    pretext  = "Crit ",     posttext = "",
    propType = "IntValues",  propKey   = "GearCrit",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Crit Damage Rating",
    pretext  = "Crit Dam ", posttext = "",
    propType = "IntValues",  propKey   = "GearCritDamage",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Crit Resist Rating",
    pretext  = "Crit Resist ", posttext = "",
    propType = "IntValues",  propKey   = "GearCritResist",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Crit Damage Resist Rating",
    pretext  = "Crit Dam Resist ", posttext = "",
    propType = "IntValues",  propKey   = "GearCritDamageResist",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Healing Boost Rating",
    pretext  = "Heal Boost ", posttext = "",
    propType = "IntValues",  propKey   = "GearHealingBoost",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Nether Resist Rating",
    pretext  = "Nether Resist ", posttext = "",
    propType = "IntValues",  propKey   = "GearNetherResist",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Life Resist Rating",
    pretext  = "Life Resist ", posttext = "",
    propType = "IntValues",  propKey   = "GearLifeResist",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Vitality",
    pretext  = "This item adds ", posttext = " Vitality.",
    propType = "IntValues",  propKey   = "GearMaxHealth",
    widget   = "int",       ops      = {">=",">","=="},
    default  = 0,           categories = "*",
  },

  -- Spells
  {
    label    = "Spell(s)",
    pretext  = "Spells contain: ", posttext = "",
    propType = "spells",  propId   = nil,
    widget   = "string",    ops      = {"Regex ->"},
    default  = "",          categories = "*",
  },
  
  -- Wield requirements
  {
    label    = "Wield Requirement",
    propType = "wieldReq",   -- synthetic, handled specially
    propKey  = nil,
    widget   = "wieldreq",
    ops      = {">=", "<=", "==", ">", "<"},
    default  = { reqType=7, skillType=0, difficulty=1 },
    categories = "*",
  },
  
  -- Level limits
  {
    label    = "Min Level",
    pretext  = "Min Level: ",  posttext = "",
    propType = "IntValues",  propKey   = "MinLevel",
    widget   = "int",       ops      = {"<=","=="},
    default  = 0,           categories = "*",
  },
  {
    label    = "Max Level",
    pretext  = "Max Level: ",  posttext = "",
    propType = "IntValues",  propKey   = "MaxLevel",
    widget   = "int",       ops      = {">=","=="},
    default  = 0,           categories = "*",
  },

  -- Special properties (booleans)
  {
    label    = "Attuned",
    pretext  = "Attuned: ",  posttext = "",
    propType = "IntValues",   propKey   = "Attuned",
    widget   = "int",        ops      = {"=="},
    default  = 1,            categories = "*",
  },
  {
    label    = "Bonded",
    pretext  = "Bonded: ",   posttext = "",
    propType = "IntValues",   propKey   = "Bonded",
    widget   = "int",        ops      = {"=="},
    default  = 1,            categories = "*",
  },
  {
    label    = "Unenchantable",
    pretext  = "Unenchantable (ResistMagic >= 9999)", posttext = "",
    propType = "IntValues",   propKey   = "ResistMagic",
    widget   = "int",        ops      = {">="},
    default  = 9999,         categories = "*",
  },
  {
    label    = "Imbued Effect",
    pretext  = "Imbued: ",   posttext = "",
    propType = "IntValues",   propKey   = "ImbuedEffect",
    widget   = "flags",
    flagTable = {
      [0x001]="Critical Strike", [0x002]="Crippling Blow",  [0x004]="Armor Rending",
      [0x008]="Slash Rending",   [0x010]="Pierce Rending",  [0x020]="Bludgeon Rending",
      [0x040]="Acid Rending",    [0x080]="Cold Rending",    [0x100]="Lightning Rending",
      [0x200]="Fire Rending",    [0x400]="Melee Def",       [0x800]="Missile Def",
      [0x1000]="Magic Def",      [0x4000]="Nether Rending", [0x8000]="Ward Rending",
    },
    ops      = {"OR","AND"},
    default  = 0,            categories = "*",
  },
}

-- ── Weapons ───────────────────────────────────────────────────────────────────

M.weapon = {
  {
    label    = "Damage",
    pretext  = "Damage: ",   posttext = "",
    propType = "IntValues",   propKey   = "Damage",
    widget   = "int",        ops      = {">=","<=",">","<","=="},
    default  = 0,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE },
  },
  {
    label    = "Damage Type",
    pretext  = "Damage Type: ",   posttext = "",
    propType = "IntValues",   propKey   = "DamageType",
    widget   = "flags",
    flagTable = {
      [DamageType.Slashing.ToNumber()]="Slashing",
      [DamageType.Piercing.ToNumber()]="Piercing",
      [DamageType.Bludgeoning.ToNumber()]="Bludgeoning",
      [DamageType.Fire.ToNumber()]="Fire",
      [DamageType.Cold.ToNumber()]="Cold",
      [DamageType.Acid.ToNumber()]="Acid",
      [DamageType.Electric.ToNumber()]="Electric",
      [0x400]="Nether",
    },
    ops      = {"OR","AND"},
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE, C.WEAPON_WAND}
  },  
  {
    label    = "Attack Bonus",
    pretext  = "Bonus to Attack Skill: ",  posttext = "%%.",
    propType = "FloatValues", propKey   = "WeaponOffense",
    widget   = "float",      ops      = {">=",">"},
    default  = 1.0,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE, C.WEAPON_WAND },
  },
  {
    label    = "Melee Defense Bonus",
    pretext  = "Bonus to Melee Defense: ", posttext = "%%.",
    propType = "FloatValues", propKey   = "WeaponDefense",
    widget   = "float",      ops      = {">=",">"},
    default  = 1.0,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE, C.WEAPON_WAND },
  },
  {
    label    = "Missile Defense Bonus",
    pretext  = "Bonus to Missile Defense: ", posttext = "%%.",
    propType = "FloatValues", propKey   = "WeaponMissileDefense",
    widget   = "float",      ops      = {">=",">"},
    default  = 1.0,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE, C.WEAPON_WAND },
  },
  {
    label    = "Magic Defense Bonus",
    pretext  = "Bonus to Magic Defense: ", posttext = "%%.",
    propType = "FloatValues", propKey   = "WeaponMagicDefense",
    widget   = "float",      ops      = {">=",">"},
    default  = 1.0,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE, C.WEAPON_WAND },
  },
  {
    label    = "Elemental Damage Bonus",
    pretext  = "Elemental Damage Bonus: ", posttext = "",
    propType = "IntValues",   propKey   = "ElementalDamageBonus",
    widget   = "int",        ops      = {">=",">","=="},
    default  = 0,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE },
  },
  {
    label    = "Damage Modifier",
    pretext  = "Damage Modifier: ",  posttext = "",
    propType = "FloatValues", propKey   = "DamageMod",
    widget   = "float",      ops      = {">=",">"},
    default  = 1.0,
    categories = { C.WEAPON_MISSILE },
  },
  {
    label    = "Weapon Speed",
    pretext  = "Speed: ",    posttext = "",
    propType = "IntValues",   propKey   = "WeaponTime",
    widget   = "int",        ops      = {"<=","<","=="},   -- lower = faster
    default  = 50,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE },
  },
  {
    label    = "Critical Multiplier",   -- Crushing Blow
    pretext  = "Critical Multiplier: ", posttext = "",
    propType = "FloatValues", propKey   = "CriticalMultiplier",
    widget   = "float",      ops      = {">=",">"},
    default  = 1.0,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE },
  },
  {
    label    = "Critical Frequency",    -- Biting Strike
    pretext  = "Critical Chance: ",     posttext = "",
    propType = "FloatValues", propKey   = "CriticalFrequency",
    widget   = "float",      ops      = {">=",">"},
    default  = 0.1,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE },
  },
  {
    label    = "Armor Cleaving",
    pretext  = "Ignore Armor: ",  posttext = "",
    propType = "FloatValues", propKey   = "IgnoreArmor",
    widget   = "float",      ops      = {"<=","<"},   -- lower = ignores more
    default  = 1.0,
    categories = { C.WEAPON_MELEE, C.WEAPON_MISSILE },
  },
}

-- ── Wand ──────────────────────────────────────────────────────────────────────

M.wand = {
  {
    label    = "Mana Conversion Bonus",
    pretext  = "Bonus to Mana Conversion: ", posttext = "%%.",
    propType = "FloatValues", propKey   = "ManaConversionMod",
    widget   = "float",      ops      = {">=",">"},
    default  = 0.0,
    categories = { C.WEAPON_WAND },
  },
  {
    label    = "Elemental Damage Mod",
    pretext  = "Elemental Damage Mod: ",    posttext = "",
    propType = "FloatValues", propKey   = "ElementalDamageMod",
    widget   = "float",      ops      = {">=",">"},
    default  = 0.0,
    categories = { C.WEAPON_WAND },
  },
}

-- ── Armor ─────────────────────────────────────────────────────────────────────

M.armor = {
  {
    label    = "Armor Level",
    pretext  = "Armor Level: ",  posttext = "",
    propType = "IntValues",   propKey   = "ArmorLevel",
    widget   = "int",        ops      = {">=","<=",">","<","=="},
    default  = 0,
    categories = { C.ARMOR },
  },
  {
    label    = "AL vs Slash",
    pretext  = "Slashing: ",     posttext = "",
    propType = "FloatValues", propKey  = "ArmorModVsSlash",
    widget   = "float",      ops      = {">=",">","=="},
    default  = 0.0,
    categories = { C.ARMOR },
  },
  {
    label    = "AL vs Pierce",
    pretext  = "Piercing: ",     posttext = "",
    propType = "FloatValues", propKey   = "ArmorModVsPierce",
    widget   = "float",      ops      = {">=",">","=="},
    default  = 0.0,
    categories = { C.ARMOR },
  },
  {
    label    = "AL vs Bludgeon",
    pretext  = "Bludgeoning: ",  posttext = "",
    propType = "FloatValues", propKey   = "ArmorModVsBludgeon",
    widget   = "float",      ops      = {">=",">","=="},
    default  = 0.0,
    categories = { C.ARMOR },
  },
  {
    label    = "AL vs Fire",
    pretext  = "Fire: ",         posttext = "",
    propType = "FloatValues", propKey   = "ArmorModVsFire",
    widget   = "float",      ops      = {">=",">","=="},
    default  = 0.0,
    categories = { C.ARMOR },
  },
  {
    label    = "AL vs Cold",
    pretext  = "Cold: ",         posttext = "",
    propType = "FloatValues", propKey   = "ArmorModVsCold",
    widget   = "float",      ops      = {">=",">","=="},
    default  = 0.0,
    categories = { C.ARMOR },
  },
  {
    label    = "AL vs Acid",
    pretext  = "Acid: ",         posttext = "",
    propType = "FloatValues", propKey   = "ArmorModVsAcid",
    widget   = "float",      ops      = {">=",">","=="},
    default  = 0.0,
    categories = { C.ARMOR },
  },
  {
    label    = "AL vs Electric",
    pretext  = "Electric: ",     posttext = "",
    propType = "FloatValues", propKey   = "ArmorModVsElectric",
    widget   = "float",      ops      = {">=",">","=="},
    default  = 0.0,
    categories = { C.ARMOR },
  },
  {
    label    = "AL vs Nether",
    pretext  = "Nether: ",       posttext = "",
    propType = "FloatValues", propKey   = "ArmorModVsNether",
    widget   = "float",      ops      = {">=",">","=="},
    default  = 0.0,
    categories = { C.ARMOR },
  },
}

-- ── Magic items ───────────────────────────────────────────────────────────────

M.magic = {
  {
    label    = "Spellcraft",
    pretext  = "Spellcraft: ",   posttext = ".",
    propType = "IntValues",   propKey   = "ItemSpellcraft",
    widget   = "int",        ops      = {">=","<=",">","<","=="},
    default  = 0,            categories = "*",
    -- Only relevant if item has spells; probeEntry handles this naturally
  },
  {
    label    = "Max Mana",
    pretext  = "Mana: ",         posttext = " / max",
    propType = "IntValues",   propKey   = "ItemMaxMana",
    widget   = "int",        ops      = {">=","<=","=="},
    default  = 0,            categories = "*",
  },
}

return M
