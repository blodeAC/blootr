-- TODO enums: SLAYER, gem type, imbued effect

local _imgui      = require("imgui")
local ImGui       = _imgui.ImGui
local views       = require("utilitybelt.views")
local io          = require("filesystem").GetScript()
local bit         = require("bit")
local ItemExamine = require("ItemExamine")
local manifest    = require("property_manifest")
local catDetect   = require("item_category")

local additionalProperties = manifest._additionalProperties or {}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local UIState = {
  mode               = "none",  -- "none" | "text" | "editor" | "rules"
  textLines          = nil,
  item               = nil,
  category           = nil,
  presentProps       = nil,
  absentProps        = nil,
  addComboIdx        = 0,
  propFilter         = "",
  filteredAbsent     = nil,
  editingRuleSet     = nil,
  editingProfileName = false,
  selectedProfile    = 1,
  importIdx          = 0,
}

local activeProfiles = {}
local importList     = {}   -- { label, server, character }
local inspectQueue   = {}
local container      = {}
AppraiseInfo         = {}

local lootSaveFile   = "loot.json"
local windowSaveFile = "window_config.json"
local windowStates   = {}

-- forward declarations
local buildItem, saveLootProfile, loadLootProfile, populateImportList

local hud = views.Huds.CreateHud("loot")

----------------------------------------------------------------------
-- Value types
----------------------------------------------------------------------

local VALUE_TYPES = {
  IntValues    = { enum = "IntId",    default = 1     },
  BoolValues   = { enum = "BoolId",   default = false },
  DataValues   = { enum = "DataId",   default = 1     },
  Int64Values  = { enum = "Int64Id",  default = 1     },
  FloatValues  = { enum = "FloatId",  default = 1.0   },
  StringValues = { enum = "StringId", default = ""    },
}

----------------------------------------------------------------------
-- JSON helper
----------------------------------------------------------------------

local function prettyPrintJSON(value, indent)
  local function escape(s)
    return '"' .. s:gsub('([\\"])', '\\%1'):gsub('\n','\\n'):gsub('\r','\\r') .. '"'
  end
  indent = indent or ""
  local ind2 = indent .. "  "
  if type(value) == "table" then
    local isArray = #value > 0
    local items = {}
    for k, v in pairs(value) do
      local prefix = isArray and "" or escape(tostring(k)) .. ": "
      table.insert(items, ind2 .. prefix .. prettyPrintJSON(v, ind2))
    end
    if #items == 0 then return isArray and "[]" or "{}" end
    return isArray
      and "[\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "]"
      or  "{\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "}"
  elseif type(value) == "string" then
    return escape(value)
  else
    return tostring(value)
  end
end

----------------------------------------------------------------------
-- Loot evaluation  (plain data — activeProfiles is deserialized JSON)
----------------------------------------------------------------------

local function evalRule(rule, item)
  local val
  local op, rv = rule.op, rule.value
  
  if rule.propType == "spells" then
    val = item.spells or ""
  elseif rule.propType == "wieldReq" then
    local suffixes = {"", "2", "3", "4"}
    for _, s in ipairs(suffixes) do 
      local rt = item.IntValues["WieldRequirements" .. s]
      local st = item.IntValues["WieldSkilltype" .. s]  
      local diff = item.IntValues["WieldDifficulty" .. s]
      if rt == rv.reqType and st == rv.skillType and diff then
        local d, target = tonumber(diff), tonumber(rv.difficulty)
        if rule.op == ">=" then return d >= target end
        if rule.op == "<=" then return d <= target end
        if rule.op == "==" then return d == target end
        if rule.op == ">"  then return d >  target end
        if rule.op == "<"  then return d <  target end
      end
    end
    return false
  else
    val = item[rule.propType] and item[rule.propType][rule.propKey]
  end
  if val == nil then return false end

  if rule.propType == "StringValues" or rule.propType == "spells" then
    local sv, rv2 = tostring(val), tostring(rv)
    if op == "Regex ->" then
      return Regex.IsMatch(sv, rv2,RegexOptions.IgnoreCase)  -- user writes the regex, IsMatch already does substring
    else
      return Regex.IsMatch(sv, "^" .. rv2 .. "$",RegexOptions.IgnoreCase)  -- == means full match
    end
  elseif rule.propType == "BoolValues" then
    return val == rv
  elseif op == "is one of" then
    if #rv==0 then return true end
    for _, accepted in ipairs(rv) do
      if tonumber(val) == tonumber(accepted) then return true end
    end
    return false
  else
    val, rv = tonumber(val), tonumber(rv)
    if not val or not rv then return false end
    local epsilon = 1e-6
    if op == "==" or op == "AND" then return math.abs(val - rv) < epsilon end
    if op == "!=" then return math.abs(val - rv) >= epsilon end
    if op == ">=" then return val >= rv - epsilon end
    if op == "<=" then return val <= rv + epsilon end
    if op == ">"  then return val > rv + epsilon end
    if op == "<"  then return val < rv - epsilon end
    if op == "OR" then
      return bit.band(tonumber(val) or 0, tonumber(rv) or 0) > 0
    end
  end
  return false
end

local function evaluateItem(item)
  for _, profile in ipairs(activeProfiles) do
    if profile.active then
      for _, ruleSet in ipairs(profile.ruleSets) do
        if ruleSet.enabled then
          local match = true
          for _, rule in ipairs(ruleSet.rules) do
            if not evalRule(rule, item) then match = false; break end
          end
          if match then return ruleSet end
        end
      end
    end
  end
  return nil
end

----------------------------------------------------------------------
-- Looting
----------------------------------------------------------------------

local lootActionOptions = ActionOptions.new() 
---@diagnostic disable-next-line
lootActionOptions.MaxRetryCount = 10
lootActionOptions.SkipChecks    = true

local function lootItem(itemData, ruleset)
  local weenie = game.World.Get(itemData.id)
  if not weenie then return end

  local queueLen = 1
  for _ in game.ActionQueue.ImmediateQueue do queueLen = queueLen + 1 end
  for _ in game.ActionQueue.Queue          do queueLen = queueLen + 1 end
  lootActionOptions.TimeoutMilliseconds = queueLen * 1000

  game.Actions.ObjectMove(itemData.id, game.CharacterId, 0, true, lootActionOptions,
    function(action)
      if action.Success then
        ruleset.totalFound = (ruleset.totalFound or 0) + 1
      else
        print(string.format("Failed to loot \"%s\": %s", weenie.Name, action.ErrorDetails))
      end
    end)
end

local function processItem(itemData)
  for l = #inspectQueue, 1, -1 do
    if inspectQueue[l] == itemData.id then
      local matched = evaluateItem(itemData)
      if matched then lootItem(itemData, matched) end
      table.remove(inspectQueue, l)
      break
    end
  end
end

game.World.OnContainerOpened.Add(function(msg)
  local c = msg.Container
  if c.ObjectClass ~= ObjectClass.Corpse
  and not Regex.IsMatch(c.Name, "Corpse")
  and not Regex.IsMatch(c.Name, "Chest") then
    return
  end

  local cid = c.Id
  if container[cid] ~= nil then
    -- re-open: trim items already looted into inventory
    local remaining = {}
    for _, itemId in ipairs(container[cid]) do
      local wo = game.World.Get(itemId)
      if wo and wo.Container ~= game.CharacterId then
        table.insert(remaining, itemId)
      end
    end
    container[cid] = remaining
  else
    container[cid] = c.AllItemIds
    game.World.Get(cid).OnDestroyed.Add(function()
      container[cid] = nil
    end)
  end

  for _, itemId in ipairs(container[cid]) do
    table.insert(inspectQueue, itemId)
    if AppraiseInfo[itemId] then
      processItem(AppraiseInfo[itemId])
    else
      await(game.Actions.ObjectAppraise(itemId))
      buildItem(itemId)
      -- buildItem → Item_SetAppraiseInfo hook → buildItem → processItem
    end
  end
end)

----------------------------------------------------------------------
-- Item building
----------------------------------------------------------------------

local function scanInventory()
  for _, invItem in ipairs(game.Character.Equipment) do
    print(tostring(invItem==nil))
    await(game.Actions.ObjectAppraise(invItem.Id))
    print(_)
  end
  
end

buildItem = function(e)
  local objectId = type(e) ~= "number" and e.Data.ObjectId or e
  local weenie   = game.World.Get(objectId)
  if not weenie then return end

  local itemData = {
    id   = objectId,
    name = weenie.Name,
    lootCriteria = {
      IntValues={}, BoolValues={}, DataValues={},
      Int64Values={}, FloatValues={}, StringValues={},
    },
  }

  -- spells
  for _, spellId in ipairs(weenie.SpellIds) do
    itemData.spells = (itemData.spells or "") .. game.Character.SpellBook.Get(spellId.Id).Name .. ", "
  end
  if itemData.spells and #itemData.spells > 0 then
    itemData.spells = itemData.spells:sub(1, -3)
  end

  -- value tables
  for typeName in pairs(VALUE_TYPES) do
    itemData[typeName] = {}
    for k, v in pairs(weenie[typeName]) do
      local nk     = tonumber(tostring(k))
      local mapped = nk and additionalProperties[typeName] and additionalProperties[typeName][nk]
      itemData[typeName][mapped or tostring(k)] = v
    end
    local keys = {}
    for n in pairs(itemData[typeName]) do table.insert(keys, n) end
    itemData.sorted = itemData.sorted or {}
    itemData.sorted[typeName] = table.sort(keys, function(a, b) return a > b end)
  end
  itemData.StringValues["HeritageGroup"] = nil

  -- armor resist profile
  if type(e) ~= "number" and e.Data and e.Data.ArmorProfile then
    local ap  = e.Data.ArmorProfile
    local map = {
      ProtAcid        = "ArmorModVsAcid",
      ProtBludgeoning = "ArmorModVsBludgeon",
      ProtCold        = "ArmorModVsCold",
      ProtFire        = "ArmorModVsFire",
      ProtLightning   = "ArmorModVsElectric",
      ProtNether      = "ArmorModVsNether",
      ProtPiercing    = "ArmorModVsPierce",
      ProtSlashing    = "ArmorModVsSlash",
    }
    for src, dst in pairs(map) do
      if ap[src] then itemData.FloatValues[dst] = ap[src] end
    end
  end

  -- weapon profile
  if type(e) ~= "number" and e.Data and e.Data.WeaponProfile then
    local wp = e.Data.WeaponProfile
    if wp["SkillBonus"] then itemData.FloatValues["WeaponOffense"] = wp["SkillBonus"] end
    if wp["Speed"]      then itemData.IntValues["Speed"]           = wp["Speed"]      end
  end

  -- buff highlight bitmasks
  if type(e) ~= "number" and e.Data and e.Data.ProtHighlight then
    itemData.IntValues["ProtHighlight"] = e.Data.ProtHighlight.ToNumber()
    itemData.IntValues["ProtColor"]     = e.Data.ProtColor.ToNumber()
  end
  if type(e) ~= "number" and e.Data and e.Data.WeapHighlight then
    itemData.IntValues["WeapHighlight"] = e.Data.WeapHighlight.ToNumber()
    itemData.IntValues["WeapColor"]     = e.Data.WeapColor.ToNumber()
  end

  AppraiseInfo[objectId] = itemData

  local ex = ItemExamine.new(itemData)
  if not ex then print("niled out"); return end

  local category = catDetect.detect(itemData)

  local presentProps, absentProps = {}, {}
  for _, entry in ipairs(manifest.forCategory(category)) do
    if entry.widget == "wieldreq" then
      local suffixes = {"", "2", "3", "4"}
      local anyFound = false
      for _, s in ipairs(suffixes) do
        local rt = itemData.IntValues and itemData.IntValues["WieldRequirements" .. s]
        if not rt then break end
        local st   = itemData.IntValues["WieldSkilltype" .. s] or 0
        local diff = itemData.IntValues["WieldDifficulty" .. s] or 1
        table.insert(presentProps, { entry=entry, value={reqType=rt, skillType=st, difficulty=diff}, op=entry.ops[1] })
        anyFound = true
      end
      if not anyFound then
        table.insert(absentProps, entry)
      end
    else
      local has, val = manifest.probeEntry(entry, itemData)
      if has then
        if entry.widget == "enumset" and type(val) ~= "table" then
          val = { val }
        end
        table.insert(presentProps, { entry=entry, value=val, op=entry.ops[1] })
      else
        table.insert(absentProps, entry)
      end
    end
  end

  if game.World.Selected and game.World.Selected.Id == objectId then
    UIState.textLines    = ex.lines
    UIState.item         = itemData
    UIState.category     = category
    UIState.presentProps = presentProps
    UIState.absentProps  = absentProps
    UIState.addComboIdx  = 0
    if UIState.mode ~= "test" then
      UIState.mode = "text"
    end
  end

  processItem(itemData)
end

game.Messages.Incoming.Item_SetAppraiseInfo.Add(buildItem)

local lastInventoryCount = 0
game.OnRender3D.Add(function()
  if #game.Character.Inventory ~= lastInventoryCount then
    lastInventoryCount = #game.Character.Inventory
    scanInventory()
  end
end)

----------------------------------------------------------------------
-- Rule commit (new ruleset from editor → active profile)
----------------------------------------------------------------------

local function commitRuleToProfile(uiState)
  local profile
  for _, p in ipairs(activeProfiles) do
    if p.active then profile = p; break end
  end
  if not profile then
    profile = { name="Default", active=true, ruleSets={} }
    table.insert(activeProfiles, profile)
  end

  local ruleSet = { name=uiState.item.name, enabled=true, rules={}, category=uiState.category }
  for _, row in ipairs(uiState.presentProps) do
    table.insert(ruleSet.rules, {
      propType  = row.entry.propType,
      propIdNum = row.entry.propId or nil,
      propKey   = row.entry.propKey,
      op        = row.op,
      value     = row.value,
    })
  end
  table.insert(profile.ruleSets, ruleSet)
  saveLootProfile()
end

----------------------------------------------------------------------
-- Persistence — loot profiles
----------------------------------------------------------------------

function saveLootProfile()
  local data = {}
  if io.FileExists(lootSaveFile) then
    data = json.parse(io.ReadText(lootSaveFile)) or {}
  end
  local server    = game.ServerName
  local character = game.Character.Weenie.Name
  data[server] = data[server] or {}

  -- strip transient UI flags before serializing
  for _, profile in ipairs(activeProfiles) do
    for _, ruleSet in ipairs(profile.ruleSets) do
      ruleSet.editingName = nil
    end
  end

  data[server][character] = activeProfiles
  io.WriteText(lootSaveFile, prettyPrintJSON(data))
end

function loadLootProfile(server, character, merge)
  server    = server    or game.ServerName
  character = character or game.Character.Weenie.Name
  if not io.FileExists(lootSaveFile) then return end
  local data = json.parse(io.ReadText(lootSaveFile)) or {}
  if not (data[server] and data[server][character]) then return end

  if not merge then
    activeProfiles = data[server][character]
    return
  end

  -- merge: append rulesets from imported profiles into matching local profiles
  local imported = data[server][character]
  for _, srcProfile in ipairs(imported) do
    -- find matching local profile by name, or create it
    local dstProfile
    for _, p in ipairs(activeProfiles) do
      if p.name == srcProfile.name then dstProfile = p; break end
    end
    if not dstProfile then
      dstProfile = { name=srcProfile.name, active=false, ruleSets={} }
      table.insert(activeProfiles, dstProfile)
    end

    -- append rulesets that don't already exist by name
    local existing = {}
    for _, rs in ipairs(dstProfile.ruleSets) do
      existing[rs.name] = true
    end
    for _, rs in ipairs(srcProfile.ruleSets) do
      if not existing[rs.name] then
        table.insert(dstProfile.ruleSets, rs)
      end
    end
  end
end

function populateImportList()
  importList = {}
  if not io.FileExists(lootSaveFile) then return end
  local data = json.parse(io.ReadText(lootSaveFile)) or {}
  for server, chars in pairs(data) do
    for character in pairs(chars) do
      table.insert(importList, {
        label     = server .. " > " .. character,
        server    = server,
        character = character,
      })
    end
  end
end

loadLootProfile()
populateImportList()

----------------------------------------------------------------------
-- Persistence — window position/size
----------------------------------------------------------------------

local function saveWindowStates()
  io.WriteText(windowSaveFile, prettyPrintJSON(windowStates))
end

local function loadWindowStates()
  if not io.FileExists(windowSaveFile) then return end
  windowStates = json.parse(io.ReadText(windowSaveFile)) or {}
  local s = windowStates.hud
  if not s then return end
  hud.Visible = s.visible ~= false
  hud.OnPreRender.Once(function()
    ImGui.SetNextWindowPos(Vector2.new(s.posX, s.posY))
    ImGui.SetNextWindowSize(Vector2.new(s.sizeX, s.sizeY))
  end)
end

local lastTickState = {}
game.OnTick.Add(function()
  local s = windowStates.hud
  if not s then return end
  local l = lastTickState
  if not l.posX
  or l.posX ~= s.posX or l.posY ~= s.posY
  or l.sizeX ~= s.sizeX or l.sizeY ~= s.sizeY
  or l.visible ~= s.visible then
    saveWindowStates()
    lastTickState = { posX=s.posX, posY=s.posY, sizeX=s.sizeX, sizeY=s.sizeY, visible=s.visible }
  end
end)

loadWindowStates()

----------------------------------------------------------------------
-- ImGui helpers
----------------------------------------------------------------------

local COL_OP     = 55
local COL_VALUE  = 90
local COL_REMOVE = 20

local function navButton(label, dark)
  local w = ImGui.GetContentRegionMax().X / 3 - ImGui.GetStyle().ItemSpacing.X
  if dark then
    ImGui.PushStyleColor(_imgui.ImGuiCol.Button,        Vector4.new(0.1, 0.1, 0.1, 1.0))
    ImGui.PushStyleColor(_imgui.ImGuiCol.ButtonHovered, Vector4.new(0.2, 0.2, 0.2, 1.0))
    ImGui.PushStyleColor(_imgui.ImGuiCol.Text,          Vector4.new(1.0, 1.0, 1.0, 1.0))
  end
  local clicked = ImGui.Button(label, Vector2.new(w, 0))
  if dark then ImGui.PopStyleColor(3) end
  return clicked
end

local function renderValueWidget(row)
  local entry = row.entry
  
  if entry.widget == "int" then
    local ch; ch, row.value = ImGui.InputInt("##v", row.value, 1, 10)
  elseif entry.widget == "float" then
    local ch; ch, row.value = ImGui.InputFloat("##v", row.value, 0.01, 0.1, "%.4f")
  elseif entry.widget == "bool" then
    local ch; ch, row.value = ImGui.Checkbox("##v", row.value)
  elseif entry.widget == "string" then
    local ch; ch, row.value = ImGui.InputText("##v", row.value, 256)
    if ImGui.IsItemHovered() and row.value and #row.value > 0 then
      ImGui.SetTooltip(row.value)
    end
    
  elseif entry.widget == "enum" then
    local keys, labels = {}, {}
    for k, v in pairs(entry.enumTable) do
      table.insert(keys, k); table.insert(labels, v)
    end
    local currentIdx = 1
    for i, k in ipairs(keys) do
      if k == row.value then currentIdx = i end
    end
    local ch ---@diagnostic disable-next-line
    ch, currentIdx = ImGui.Combo("##v", currentIdx - 1, labels, #labels)
    if ch then row.value = keys[currentIdx + 1] end
  elseif entry.widget == "enumset" then
    local current = type(row.value) == "table" and row.value or {}
    local parts = {}
    for _, v in ipairs(current) do
      table.insert(parts, tostring(entry.enumTable[v] or v))
    end
    local buttonLabel = #parts > 0 and table.concat(parts, "|") or "none"
    local popupId = "##enumset" .. tostring(entry.propKey or entry.label)
    if ImGui.Button(buttonLabel .. "##esb") then
      ImGui.OpenPopup(popupId)
    end
    if ImGui.BeginPopup(popupId) then
      for k, v in pairs(entry.enumTable) do
        local isSelected = false
        local selectedIdx = nil
        for i, sv in ipairs(current) do
          if sv == k then isSelected = true; selectedIdx = i; break end
        end
        local fch, newIsSet = ImGui.Checkbox(v, isSelected)
        if fch then
          if newIsSet then
            table.insert(current, k)
          elseif selectedIdx then
            table.remove(current, selectedIdx)
          end
        end
      end
      ImGui.EndPopup()
    end
    row.value = current --[[@as any]]
  elseif entry.widget == "flags" then
    local current = tonumber(row.value) or 0    
    local parts = {}
    for mask, flaglabel in pairs(entry.flagTable) do
      if bit.band(current, mask) ~= 0 then
        table.insert(parts, flaglabel)
      end
    end
    local sep = row.op == "AND" and "&" or "|"
    
    local buttonLabel = #parts > 0 and table.concat(parts, sep) or "none"
    local popupId = "##flags" .. tostring(entry.propKey or entry.label)
    if ImGui.Button(buttonLabel .. "##fb") then
      ImGui.OpenPopup(popupId)
    end
    if ImGui.BeginPopup(popupId) then
      for mask, flaglabel in pairs(entry.flagTable) do
        local isSet = bit.band(current, mask) ~= 0
        local fch, newIsSet = ImGui.Checkbox(flaglabel, isSet)
        if fch then
          isSet = newIsSet == true
          current = isSet and bit.bor(current, mask) or bit.band(current, bit.bnot(mask))
        end
      end
      ImGui.EndPopup()
    end
    row.value = current
  elseif entry.widget == "wieldreq" then
    local v = row.value
    if type(v) ~= "table" then
      v = { reqType=7, skillType=0, difficulty=1 }
    end

    -- first combo: requirement type
    local reqLabels = { "Skill", "Base Skill", "Attribute", "Base Attribute", "Vital", "Base Vital", "Level", "Training","DONTUSE","DONTUSE","Creature Type", "Heritage" }
        local reqIdx = 7
    for i=1,#reqLabels do
      if i == v.reqType then 
        reqIdx = i
      end 
    end
    ImGui.SetNextItemWidth(COL_VALUE)
    local ch, ni = ImGui.Combo("##wreqtype", reqIdx-1, reqLabels, #reqLabels)
    if ch then v.reqType = ni+1; v.skillType = 0 end

    -- second combo: options depend on reqType
    if v.reqType == 7 then
      -- level: just a number, no second combo
    elseif v.reqType == 8 or v.reqType == 1 or v.reqType == 2 then
      -- skill — pull from SkillId enum
      local skillLabels, skillValues = {}, {}
      ---@diagnostic disable-next-line
      for _, sk in ipairs(SkillId.GetValues()) do
        table.insert(skillLabels, tostring(sk)); table.insert(skillValues, sk.ToNumber())
      end
      local si = 1
      ImGui.SetNextItemWidth(COL_VALUE)
      for i, sv in ipairs(skillValues) do if sv == v.skillType then si = i end end
      local sch, sni = ImGui.Combo("##wreqskill", si-1, skillLabels, #skillLabels)
      if sch then v.skillType = skillValues[sni+1] end
    elseif v.reqType == 3 or v.reqType == 4 then
      local attrLabels = {"Strength","Endurance","Quickness","Coordination","Focus","Self"}
      local si = math.max(1, v.skillType)
      ImGui.SetNextItemWidth(COL_VALUE)
      local ach, ani = ImGui.Combo("##wreqattr", si-1, attrLabels, #attrLabels)
      if ach then v.skillType = ani+1 end
    elseif v.reqType == 5 or v.reqType == 6 then
      local vitalLabels = {"Health","Mana","Stamina"}
      local si = math.max(1, v.skillType)
      ImGui.SetNextItemWidth(COL_VALUE)
      local vch, vni = ImGui.Combo("##wreqvitals", si-1, vitalLabels, #vitalLabels)
      if vch then v.skillType = vni+1 end
    elseif v.reqType == 12 then
      local heritageLabels = {"Aluvian","Gharu'ndim","Sho","Viamontian","Umbraen","Gearknight","Tumerok","Lugian","Empyrean","Penumbraen","Undead"}
      local si = math.max(1, v.skillType)
      ImGui.SetNextItemWidth(COL_VALUE)
      local hch, hni = ImGui.Combo("##wreqher", si-1, heritageLabels, #heritageLabels)
      if hch then v.skillType = hni+1 end
    end

    if v.reqType == 8 then
      local trainingLevels = {"Untrained","Trained","Specialized"}
      local si = math.max(1, v.difficulty)
      ImGui.SetNextItemWidth(COL_VALUE)
      local tch, tni = ImGui.Combo("##wreqdiff", si-1, trainingLevels, #trainingLevels)
      if tch then v.difficulty = tni+1 end
      row.value = v
    else
      local diff = v.difficulty or 1
      ImGui.SetNextItemWidth(COL_VALUE)
      local dch, newDiff = ImGui.InputInt("##wreqdiff", diff, 1, 10)
      if dch and newDiff then v.difficulty = newDiff end
      row.value = v
    end
    
  end
end

local function setupRuleColumns()
  ImGui.TableSetupColumn("##label",  _imgui.ImGuiTableColumnFlags.WidthStretch)
  ImGui.TableSetupColumn("##op",     _imgui.ImGuiTableColumnFlags.WidthFixed, COL_OP)
  ImGui.TableSetupColumn("##value",  _imgui.ImGuiTableColumnFlags.WidthFixed, COL_VALUE)
  ImGui.TableSetupColumn("##remove", _imgui.ImGuiTableColumnFlags.WidthFixed, COL_REMOVE)
end

local function renderInlineRow(row, i)
  ImGui.PushID(i)
  ImGui.TableNextRow()

  ImGui.TableSetColumnIndex(0)
  ImGui.Text(row.entry.label)

  ImGui.TableSetColumnIndex(1)
  ImGui.SetNextItemWidth(COL_OP)
  local opIdx = 1
  for j, op in ipairs(row.entry.ops) do
    if op == row.op then opIdx = j end
  end
  
  if #row.entry.ops==1 then
    row.op = row.entry.ops[1]
    ImGui.Text(row.op)  
  else
    local ch, newOpIdx = ImGui.Combo("##op", opIdx - 1, row.entry.ops, #row.entry.ops)
    if ch then row.op = row.entry.ops[newOpIdx + 1] end
  end
  
  ImGui.TableSetColumnIndex(2)
  ImGui.SetNextItemWidth(COL_VALUE)
  renderValueWidget(row)

  ImGui.TableSetColumnIndex(3)
  
  ImGui.PushStyleColor(_imgui.ImGuiCol.Button,        Vector4.new(0.6, 0.1, 0.1, 1))
  ImGui.PushStyleColor(_imgui.ImGuiCol.ButtonHovered, Vector4.new(0.8, 0.2, 0.2, 1))
  if ImGui.SmallButton("x") then row._remove = true end
  ImGui.PopStyleColor(2)
  
  ImGui.PopID()
end
hud.WindowSettings = _imgui.ImGuiWindowFlags.NoScrollbar
----------------------------------------------------------------------
-- Main render
----------------------------------------------------------------------

hud.OnRender.Add(function()
  -- cache window geometry every frame; OnTick writes to disk on change
  windowStates.hud = {
    posX    = ImGui.GetWindowPos().X,
    posY    = ImGui.GetWindowPos().Y,
    sizeX   = ImGui.GetWindowSize().X,
    sizeY   = ImGui.GetWindowSize().Y,
    visible = hud.Visible,
  }

  if UIState.mode == "none" then
    if UIState.item and game.World.Selected and UIState.item.id==game.World.Selected.Id then
      ImGui.PushStyleColor(_imgui.ImGuiCol.Button,        Vector4.new(0.1, 0.6, 0.2, 0.5))
      ImGui.PushStyleColor(_imgui.ImGuiCol.ButtonHovered, Vector4.new(0.2, 0.8, 0.2, 0.75))
      if navButton("+ Add Rule") then
        UIState.editorReturnMode = UIState.mode
        UIState.mode           = "editor"
        UIState.propFilter     = ""
        UIState.filteredAbsent = nil
        UIState.editingRuleSet = nil
      end
      ImGui.PopStyleColor(2)
    else
      ImGui.BeginDisabled(true)
      navButton("+ Add Rule")
      ImGui.EndDisabled()
    end

    ImGui.SameLine()
    if navButton("Rules") then 
      UIState.rulesReturnMode = UIState.mode
      UIState.mode = "rules"
    end


    ImGui.SameLine()
    ImGui.PushStyleColor(_imgui.ImGuiCol.Button,        Vector4.new(0.6, 0.6, 0.3, 0.5))
    ImGui.PushStyleColor(_imgui.ImGuiCol.ButtonHovered, Vector4.new(0.8, 0.8, 0.6, 0.8))
    if navButton("Test") then 
      UIState.rulesReturnMode = UIState.mode
      UIState.mode = "test"
    end
    ImGui.PopStyleColor(2)
    
    ImGui.Separator()
    ImGui.TextDisabled("No item inspected.")

  ---------------------------------------------------------------------------
  -- Text mode
  ---------------------------------------------------------------------------
  elseif UIState.mode == "text" then
    if UIState.item and game.World.Selected and UIState.item.id==game.World.Selected.Id then
      ImGui.PushStyleColor(_imgui.ImGuiCol.Button,        Vector4.new(0.1, 0.6, 0.2, 0.5))
      ImGui.PushStyleColor(_imgui.ImGuiCol.ButtonHovered, Vector4.new(0.2, 0.8, 0.2, 0.75))
      if navButton("+ Add Rule") then
        UIState.editorReturnMode = UIState.mode
        UIState.mode           = "editor"
        UIState.propFilter     = ""
        UIState.filteredAbsent = nil
        UIState.editingRuleSet = nil
      end
      ImGui.PopStyleColor(2)
    else
      ImGui.BeginDisabled(true)
      navButton("+ Add Rule")
      ImGui.EndDisabled()
    end
    ImGui.SameLine()
    if navButton("Rules") then 
      UIState.rulesReturnMode = UIState.mode
      UIState.mode = "rules" 
    end

    ImGui.SameLine()
    ImGui.PushStyleColor(_imgui.ImGuiCol.Button,        Vector4.new(0.6, 0.6, 0.3, 0.5))
    ImGui.PushStyleColor(_imgui.ImGuiCol.ButtonHovered, Vector4.new(0.8, 0.8, 0.6, 0.8))
    if navButton("Test") then
      UIState.rulesReturnMode = UIState.mode
      UIState.mode = "test" 
    end
    ImGui.PopStyleColor(2)

    ImGui.Separator()
    if ImGui.BeginChild("##properties") then
      for _, line in ipairs(UIState.textLines or {}) do
        if line.color then
          ImGui.PushStyleColor(_imgui.ImGuiCol.Text, line.color)
          ImGui.TextWrapped(line.text)
          ImGui.PopStyleColor()
        else
          ImGui.TextWrapped(line.text)
        end
      end
    end
    ImGui.EndChild()

---------------------------------------------------------------------------
  -- Rules mode
  ---------------------------------------------------------------------------
  elseif UIState.mode == "rules" then
    if navButton("Back", true) then
      UIState.mode = UIState.rulesReturnMode or "none"
    end
    ImGui.SameLine()
    if #importList > 0 then
      local addW    = ImGui.CalcTextSize("Add").X + ImGui.GetStyle().FramePadding.X * 2
      local spacing = ImGui.GetStyle().ItemSpacing.X
      ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail().X - addW - spacing)
      local importLabels = {}
      for _, e in ipairs(importList) do table.insert(importLabels, e.label) end
      local iCh, iIdx = ImGui.Combo("##import", UIState.importIdx, importLabels, #importLabels)
      if iCh then UIState.importIdx = iIdx end
      ImGui.SameLine()
      if ImGui.Button("Add") then
        local entry = importList[UIState.importIdx + 1]
        if entry then
          loadLootProfile(entry.server, entry.character, true)
          saveLootProfile()
          populateImportList()
        end
      end
    else
      ImGui.TextDisabled("No other characters in save file.")
    end
    ImGui.Separator()

    -- ── profile selector ──────────────────────────────────────────────────
    if #activeProfiles == 0 then
      ImGui.TextDisabled("No profiles yet.")
      if ImGui.Button("New") then
        table.insert(activeProfiles, { name="New Profile", active=true, ruleSets={} })
        UIState.selectedProfile = #activeProfiles
        saveLootProfile()
      end
    else
      local profile = activeProfiles[UIState.selectedProfile]

      if UIState.editingProfileName and profile then
        ImGui.SetNextItemWidth(180)
        local rnCh, rnVal = ImGui.InputText("##pname", profile.name, 64,
          _imgui.ImGuiInputTextFlags.EnterReturnsTrue)
        if rnCh then
          profile.name = rnVal
          saveLootProfile()
          UIState.editingProfileName = false
        end
        ImGui.SameLine()
        if ImGui.SmallButton("Cancel") then UIState.editingProfileName = false end
      else
        -- + new
        if ImGui.Button(" + ") then
          table.insert(activeProfiles, { name="New Profile", active=true, ruleSets={} })
          UIState.selectedProfile = #activeProfiles
          saveLootProfile()
        end
        ImGui.SameLine()

        -- profile combo
        local profileLabels = {}
        for _, p in ipairs(activeProfiles) do
          table.insert(profileLabels, (p.active and "* " or "  ") .. p.name)
        end
        ImGui.SetNextItemWidth(
          ImGui.GetContentRegionAvail().X
          - ImGui.GetFrameHeight() * 2        -- _ and x buttons
          - ImGui.GetStyle().ItemSpacing.X * 2
        )
        local pCh, pIdx = ImGui.Combo("##profile", UIState.selectedProfile - 1, profileLabels, #profileLabels)
        if pCh then
          UIState.selectedProfile = pIdx + 1
          for _, p in ipairs(activeProfiles) do p.active = false end
          activeProfiles[UIState.selectedProfile].active = true
          saveLootProfile()
        end
        ImGui.SameLine()

        -- rename
        if ImGui.SmallButton("[ _ ]") then
          UIState.editingProfileName = true
          UIState.wantProfileNameFocus = true
        end
        ImGui.SameLine()

        -- delete
        ImGui.PushStyleColor(_imgui.ImGuiCol.Button,        Vector4.new(0.6, 0.1, 0.1, 1))
        ImGui.PushStyleColor(_imgui.ImGuiCol.ButtonHovered, Vector4.new(0.8, 0.2, 0.2, 1))
        if ImGui.SmallButton("x") then
          table.remove(activeProfiles, UIState.selectedProfile)
          UIState.selectedProfile = math.max(1, UIState.selectedProfile - 1)
          if #activeProfiles > 0 then
            activeProfiles[UIState.selectedProfile].active = true
          end
          saveLootProfile()
        end
        ImGui.PopStyleColor(2)
      end

      ImGui.Separator()
      ImGui.TextDisabled("Rules (double click to edit name)")

      if not profile then
        ImGui.TextDisabled("Select a profile.")
      else
        -- ── ruleset list ──────────────────────────────────────────────────
        if ImGui.BeginChild("##rulesetlist", Vector2.new(0, ImGui.GetContentRegionAvail().Y), false) then
          local style    = ImGui.GetStyle()
          local frameH   = ImGui.GetFrameHeight()
          local fixedW   = frameH * 3 + style.ItemSpacing.X * 2
          local drawList = ImGui.GetWindowDrawList()
          local pad      = style.FramePadding
          
          local deletedRi = nil
          for ri, ruleSet in ipairs(profile.ruleSets) do
            ImGui.PushID(ri)
            ImGui.BeginGroup()
            
            if ImGui.BeginTable("##rsrow", 2, _imgui.ImGuiTableFlags.SizingFixedFit) then
              ImGui.TableSetupColumn("##rsleft",  _imgui.ImGuiTableColumnFlags.WidthStretch)
              ImGui.TableSetupColumn("##rsright", _imgui.ImGuiTableColumnFlags.WidthFixed, fixedW)
              ImGui.TableNextRow()
              
              -- left: checkbox + selectable (click=open, dblclick=rename) or input
              ImGui.TableSetColumnIndex(0)
              local enCh, enVal = ImGui.Checkbox("##rse", ruleSet.enabled)
              if enCh then ruleSet.enabled = enVal; saveLootProfile() end
              ImGui.SameLine()
              
              if ruleSet.editingName then
                if ruleSet.wantFocus then
                  ImGui.SetKeyboardFocusHere()
                  ruleSet.wantFocus = false
                end
                local rsCh, rsVal = ImGui.InputText("##rsname", ruleSet.name, 64,
                _imgui.ImGuiInputTextFlags.EnterReturnsTrue)
                if rsCh then
                  ruleSet.name        = rsVal
                  ruleSet.editingName = false
                  saveLootProfile()
                end
                if ImGui.IsItemDeactivated() then ruleSet.editingName = false end
              else
                local label = ruleSet.name
                ImGui.Selectable(label .. "###rssel",
                ruleSet.open or false,
                _imgui.ImGuiSelectableFlags.AllowDoubleClick)
                if ImGui.IsItemClicked(_imgui.ImGuiMouseButton.Left) then
                  if ImGui.IsMouseDoubleClicked(_imgui.ImGuiMouseButton.Left) then
                    ruleSet.wantFocus   = true
                    ruleSet.editingName = true
                  else
                    ruleSet.open = not (ruleSet.open or false)
                  end
                end
              end
              
              -- right: up + dn + x
              ImGui.TableSetColumnIndex(1)
              ImGui.BeginDisabled(ri == 1)
              if ImGui.ArrowButton("##up", _imgui.ImGuiDir.Up) then
                profile.ruleSets[ri], profile.ruleSets[ri-1] = profile.ruleSets[ri-1], profile.ruleSets[ri]
                saveLootProfile()
              end
              ImGui.EndDisabled()
              ImGui.SameLine()
              ImGui.BeginDisabled(ri == #profile.ruleSets)
              if ImGui.ArrowButton("##dn", _imgui.ImGuiDir.Down) then
                profile.ruleSets[ri], profile.ruleSets[ri+1] = profile.ruleSets[ri+1], profile.ruleSets[ri]
                saveLootProfile()
              end
              ImGui.EndDisabled()
              ImGui.SameLine()
              ImGui.PushStyleColor(_imgui.ImGuiCol.Button,        Vector4.new(0.6, 0.1, 0.1, 1))
              ImGui.PushStyleColor(_imgui.ImGuiCol.ButtonHovered, Vector4.new(0.8, 0.2, 0.2, 1))
              if ImGui.SmallButton("x") then deletedRi = ri end
              ImGui.PopStyleColor(2)
              
              ImGui.EndTable()
            end
            
            -- expanded content
            if ruleSet.open and not ruleSet.editingName then
              ImGui.Indent()
              
              if ImGui.Button("Edit Rule", Vector2.new(ImGui.GetContentRegionAvail().X-frameH, frameH)) then
                UIState.editorReturnMode = "rules"
                UIState.mode           = "editor"
                UIState.category       = ruleSet.category
                UIState.presentProps   = {}
                UIState.absentProps    = {}
                UIState.propFilter     = ""
                UIState.filteredAbsent = nil
                UIState.editingRuleSet = { profile=profile, rs=ruleSet }
                local inRuleset = {}
                
                for _, rule in ipairs(ruleSet.rules) do
                  local ruleKey = rule.propKey or rule.propType
                  inRuleset[ruleKey] = rule
                end
                for _, entry in ipairs(manifest.forCategory(ruleSet.category)) do
                  local entryKey = entry.propKey or entry.propType
                  local rule = inRuleset[entryKey]
                  if rule then
                    table.insert(UIState.presentProps, { entry=entry, value=rule.value, op=rule.op })
                  else
                    table.insert(UIState.absentProps, entry)
                  end
                end
              end
              
              -- read-only rule summary
              if ImGui.BeginTable("##ruleview", 3, _imgui.ImGuiTableFlags.SizingFixedFit) then
                ImGui.TableSetupColumn("##rl", _imgui.ImGuiTableColumnFlags.WidthFixed, 130)
                ImGui.TableSetupColumn("##ro", _imgui.ImGuiTableColumnFlags.WidthFixed, 50)
                ImGui.TableSetupColumn("##rv", _imgui.ImGuiTableColumnFlags.WidthFixed, 90)
                for ki, rule in ipairs(ruleSet.rules) do
                  ImGui.PushID(ki)
                  ImGui.TableNextRow()
                  ImGui.TableSetColumnIndex(0)
                  local label
                  if rule.propType == "wieldReq" and type(rule.value) == "table" then
                    local rv = rule.value
                    label = string.format("Wield: %s[%d]", ({"Skill","Base Skill","Attribute","Base Attribute","Vital","Base Vital","Level","DONTUSE","DONTUSE","Training","Creature Type","Heritage" })[rv.reqType], rv.skillType)
                  elseif rule.propType == "spells" then
                    label = "Spell(s)"
                  elseif rule.propKey then
                    -- existing manifest label lookup
                    label = rule.propKey or tostring(rule.propIdNum)
                    for _, entry in ipairs(manifest.Manifest) do
                      if rule.propKey and entry.propKey == rule.propKey then
                        label = entry.label; break
                      elseif rule.propIdNum and entry.propId then
                        local n = type(entry.propId) == "number" and entry.propId
                        or entry.propId.ToNumber and entry.propId:ToNumber()
                        if n == rule.propIdNum then label = entry.label; break end
                      end
                    end
                  else
                    label = tostring(rule.propIdNum)
                  end
                  ImGui.Text(label)
                  ImGui.TableSetColumnIndex(1); ImGui.Text(rule.op)
                  local valueStr
                  if rule.propType == "wieldReq" and type(rule.value) == "table" then
                    valueStr = tostring(rule.value.difficulty)
                  elseif type(rule.value) == "table" then
                    local parts = {}
                    local manifestEntry
                    for _, e in ipairs(manifest.Manifest) do
                      if e.propKey == rule.propKey then manifestEntry = e; break end
                    end
                    for _, v in ipairs(rule.value) do
                      local label = manifestEntry and manifestEntry.enumTable and manifestEntry.enumTable[v] or tostring(v)
                      table.insert(parts, tostring(label))
                    end
                    valueStr = table.concat(parts, " | ")
                  else
                    -- try to get human label for enum/flags values
                    local manifestEntry
                    for _, e in ipairs(manifest.Manifest) do
                      if e.propKey == rule.propKey then manifestEntry = e; break end
                    end
                    if manifestEntry and manifestEntry.widget == "enum" and manifestEntry.enumTable then
                      valueStr = tostring(manifestEntry.enumTable[tonumber(rule.value)] or rule.value)
                    elseif manifestEntry and manifestEntry.widget == "flags" and manifestEntry.flagTable then
                      local parts = {}
                      local v = tonumber(rule.value) or 0
                      for mask, label in pairs(manifestEntry.flagTable) do
                        if bit.band(v, mask) ~= 0 then table.insert(parts, label) end
                      end
                      local sep = rule.op == "all" and " & " or " | "
                      valueStr = #parts > 0 and table.concat(parts, sep) or "0"
                    else
                      local numVal = tonumber(rule.value)
                      if numVal and math.floor(numVal) ~= numVal then
                        valueStr = string.format("%.3f", numVal)
                      else
                        valueStr = tostring(rule.value)
                      end
                    end
                  end
                  ImGui.TableSetColumnIndex(2); ImGui.Text(valueStr)
                  ImGui.PopID()
                end
                ImGui.EndTable()
              end
              
              ImGui.Unindent()
            end
            
            ImGui.EndGroup()
            
            -- border around the whole group
            local rmin = ImGui.GetItemRectMin()
            local rmax = ImGui.GetItemRectMax()
            drawList.AddRect(
            Vector2.new(ImGui.GetWindowPos().X - style.WindowPadding.X - pad.X, rmin.Y - pad.Y),
            Vector2.new(ImGui.GetWindowPos().X + ImGui.GetWindowSize().X + pad.X, rmax.Y + pad.Y),
            0x44FFFFFF, 3)
            
            ImGui.Spacing()
            ImGui.PopID()
          end
          
          if deletedRi then
            table.remove(profile.ruleSets, deletedRi)
            saveLootProfile()
          end
          
          ImGui.Spacing()
        end
        ImGui.EndChild()
      end
    end

  ---------------------------------------------------------------------------
  -- Editor mode
  ---------------------------------------------------------------------------
  elseif UIState.mode == "editor" then

    -- ── top bar ────────────────────────────────────────────────────────────
    if navButton("Cancel", true) then
      UIState.editingRuleSet = nil
      UIState.mode           = UIState.editorReturnMode or "text"
    end
    ImGui.SameLine()
    if navButton("Save Rule") then
      if UIState.editingRuleSet then
        -- overwrite existing ruleset in place
        local rs = UIState.editingRuleSet.rs
        rs.rules = {}
        for _, row in ipairs(UIState.presentProps) do
          table.insert(rs.rules, {
            propType  = row.entry.propType,
            propIdNum = row.entry.propId or nil,
            propKey   = row.entry.propKey,
            op        = row.op,
            value     = row.value,
          })
        end
        saveLootProfile()
        UIState.editingRuleSet = nil
      else
        commitRuleToProfile(UIState)
      end
      UIState.mode = UIState.rulesReturnMode or "text"
    end
    ImGui.Separator()
    
    local displayName = UIState.editingRuleSet and UIState.editingRuleSet.rs.name or UIState.item and UIState.item.name or ""
    ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail().X)
    local nameCh, nameVal = ImGui.InputText("##rulename", displayName, 128)
    if nameCh then
      if UIState.editingRuleSet then
        UIState.editingRuleSet.rs.name = nameVal
      elseif UIState.item then
        UIState.item.name = nameVal
      end
    end
    ImGui.Spacing()

    -- ── editable rule rows ────────────────────────────────────────────────
    if ImGui.BeginChild("##ruleTable") then
      local toRemove = nil
      if ImGui.BeginTable("##rules", 4, _imgui.ImGuiTableFlags.SizingFixedFit) then
        setupRuleColumns()
        for i, row in ipairs(UIState.presentProps) do
          renderInlineRow(row, i)
          if row._remove then toRemove = i end
        end
        ImGui.EndTable()
      end

      if toRemove then
        local row = table.remove(UIState.presentProps, toRemove)
        row._remove            = nil
        UIState.filteredAbsent = nil  -- removed prop reappears in picker
        table.insert(UIState.absentProps, row.entry)
      end

      -- ── add-property picker with search filter ────────────────────────────
      ImGui.Spacing()
      if #UIState.absentProps > 0 then
        local fCh, fVal = ImGui.InputText("##propfilter", UIState.propFilter or "", 64)
        if fCh then
          UIState.propFilter     = fVal
          UIState.filteredAbsent = nil
        end

        if UIState.filteredAbsent == nil then
          UIState.filteredAbsent = {}
          local filter = (UIState.propFilter or ""):lower()
          for i, entry in ipairs(UIState.absentProps) do
            if filter == "" or entry.label:lower():find(filter, 1, true) then
              table.insert(UIState.filteredAbsent, { entry=entry, origIdx=i })
            end
          end
          UIState.addComboIdx = 0
        end

        if #UIState.filteredAbsent > 0 then
          local filteredLabels = {}
          for _, item in ipairs(UIState.filteredAbsent) do
            table.insert(filteredLabels, item.entry.label)
          end
          ImGui.SetNextItemWidth(200)
          local ch, idx = ImGui.Combo("##addprop", UIState.addComboIdx, filteredLabels, #filteredLabels)
          if ch then UIState.addComboIdx = idx end
          ImGui.SameLine()
          if ImGui.Button("+ Add") then
            local selected = UIState.filteredAbsent[UIState.addComboIdx + 1]
            if selected then
              table.remove(UIState.absentProps, selected.origIdx)
              table.insert(UIState.presentProps, {
                entry = selected.entry,
                value = selected.entry.default,
                op    = selected.entry.ops[1],
              })
              UIState.addComboIdx    = 0
              UIState.propFilter     = ""
              UIState.filteredAbsent = nil
            end
          end
        else
          ImGui.TextDisabled("No properties match filter.")
        end
      end
    end
    ImGui.EndChild()
  elseif UIState.mode == "test" then
    if navButton("Back", true) then 
      UIState.mode = UIState.rulesReturnMode or "none"
    end
    ImGui.Separator()

    if not UIState.item then
      ImGui.TextDisabled("No item inspected.")
    else
      ImGui.Text(UIState.item.name .. "  [" .. UIState.category .. "]")
      ImGui.Spacing()

      local matched = false
      for _, profile in ipairs(activeProfiles) do
        local profileLabel = (profile.active and "* " or "  ") .. profile.name
        if ImGui.CollapsingHeader(profileLabel) then
          if ImGui.BeginTable("##testresults", 2, _imgui.ImGuiTableFlags.SizingFixedFit) then
            ImGui.TableSetupColumn("##rsname", _imgui.ImGuiTableColumnFlags.WidthStretch)
            ImGui.TableSetupColumn("##rsresult", _imgui.ImGuiTableColumnFlags.WidthFixed, 200)
            for _, ruleSet in ipairs(profile.ruleSets) do
              ImGui.TableNextRow()
              ImGui.TableSetColumnIndex(0)
              ImGui.Text(ruleSet.name or "?")
              ImGui.TableSetColumnIndex(1)
              if not ruleSet.enabled then
                ImGui.TextDisabled("off")
              else
                local pass = true
                local failRule = nil
                for _, rule in ipairs(ruleSet.rules) do
                  if not evalRule(rule, UIState.item) then
                    pass = false
                    failRule = rule
                    break
                  end
                end

                if pass then
                  ImGui.PushStyleColor(_imgui.ImGuiCol.Text, Vector4.new(0.3, 1.0, 0.3, 1.0))
                  ImGui.Text("MATCH")
                  ImGui.PopStyleColor()
                  matched = true
                else
                  ImGui.PushStyleColor(_imgui.ImGuiCol.Text, Vector4.new(1.0, 0.4, 0.4, 1.0))
                  ImGui.Text("no")
                  ImGui.PopStyleColor()
                  if failRule then
                    local failLabel = failRule.propKey or failRule.propType or "?"
                    -- try to get the human label from manifest
                    for _, entry in ipairs(manifest.Manifest) do
                      if entry.propKey and entry.propKey == failRule.propKey then
                        failLabel = entry.label; break
                      end
                    end
                    ImGui.SameLine()
                    ImGui.PushStyleColor(_imgui.ImGuiCol.Text, Vector4.new(1.0, 0.7, 0.3, 1.0))
                    ImGui.TextWrapped(failLabel .. " " .. tostring(failRule.op) .. " " .. tostring(failRule.value))
                    ImGui.PopStyleColor()
                  end
                end
              end
            end
            ImGui.EndTable()
          end
        end
      end

      ImGui.Spacing()
      ImGui.Separator()
      if matched then
        ImGui.PushStyleColor(_imgui.ImGuiCol.Text, Vector4.new(0.3, 1.0, 0.3, 1.0))
        ImGui.Text("Would be looted.")
        ImGui.PopStyleColor()
      else
        ImGui.PushStyleColor(_imgui.ImGuiCol.Text, Vector4.new(1.0, 0.4, 0.4, 1.0))
        ImGui.Text("Would NOT be looted.")
        ImGui.PopStyleColor()
      end
    end
  end
end)