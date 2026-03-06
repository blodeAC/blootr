-- item_category.lua
local bit = require("bit")

local Category = {
  WEAPON_MELEE   = "weapon_melee",
  WEAPON_MISSILE = "weapon_missile",
  WEAPON_WAND    = "weapon_wand",
  ARMOR          = "armor",
  CLOTHING       = "clothing",
  JEWELRY        = "jewelry",
  CONSUMABLE     = "consumable",
  CONTAINER      = "container",
  MISC           = "misc",
}

local function detect(itemData)
  local _, validLoc = InqInt(itemData, IntId.ValidLocations)
  local _, objType  = InqInt(itemData, IntId.ObjectType)
  local _, ammoType = InqInt(itemData, IntId.AmmoType)
  local _, al       = InqInt(itemData, IntId.ArmorLevel)
  local _, priority = InqInt(itemData, IntId.ClothingPriority)

  -- wand/caster: magic weapon slot (0x800000 ish) but no ammo
  if bit.band(validLoc, EquipMask.Wand.ToNumber()) > 0 then
    return Category.WEAPON_WAND
  end
  -- missile launcher
  if bit.band(validLoc, EquipMask.MissileWeapon.ToNumber()) > 0 and ammoType > 0 then
    return Category.WEAPON_MISSILE
  end
  -- melee/two-handed
  if bit.band(validLoc, EquipMask.MeleeWeapon.ToNumber()) > 0 then
    return Category.WEAPON_MELEE
  end
  -- armor (has AL)
  if al and al > 0 then
    return Category.ARMOR
  end
  -- jewelry slots
  if bit.band(validLoc, EquipMask.LeftRing.ToNumber() +  EquipMask.LeftBracelet.ToNumber() + 
                        EquipMask.RightRing.ToNumber() + EquipMask.RightBracelet.ToNumber() + 
                        EquipMask.Necklace.ToNumber()) > 0 then
    return Category.JEWELRY
  end
  -- clothing (has clothing priority but no AL)
  if priority and priority > 0 then
    return Category.CLOTHING
  end
  --[[
  -- containers
  if objType == ObjectType.Container then
    return Category.CONTAINER
  end
  -- consumables (food, potions etc)
  if objType == 32 or objType == 64 then
    return Category.CONSUMABLE
  end]]

  return Category.MISC
end

return { Category = Category, detect = detect }