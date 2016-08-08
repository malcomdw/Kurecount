--CONSTANTS
local mill = 1/1000000
local ks = 1/1000
local TRACKED_DAMAGE = {
  SWING_DAMAGE = true,
  RANGE_DAMAGE = true,
  SPELL_DAMAGE = true,
  SPELL_PERIODIC_DAMAGE = true,
  SPELL_BUILDING_DAMAGE = true,
  DAMAGE_SHIELD = true,
  DAMAGE_SPLIT = true,
  DAMAGE_SPLIT = true,
}
local CLASS_COLORS = {
  DEATHKNIGHT = {r=0.77, g=0.12, b=0.23}, 
  DEMONHUNTER = {r=0.64, g=0.19, b=0.79}, 
  DRUID = {r=1.00, g=0.49, b=0.04}, 
  HUNTER = {r=0.67, g=0.83, b=0.45}, 
  MAGE = {r=0.41, g=0.80, b=0.94}, 
  MONK = {r=0.00, g=1.00, b=0.59}, 
  PALADIN = {r=0.96, g=0.55, b=0.73}, 
  PRIEST = {r=1.00, g=1.00, b=1.00}, 
  ROGUE = {r=1.00, g=0.96, b=0.41}, 
  SHAMAN = {r=0.00, g=0.44, b=0.87}, 
  WARLOCK = {r=0.58, g=0.51, b=0.79}, 
  WARRIOR = {r=0.78, g=0.61, b=0.43}, 
}
local DEFAULT_COLORS = {
  {r=0.2, g=0.2, b=0.2}, 
  {r=0.4, g=0.4, b=0.4}, 
}
local TRACKED_SUMMONS = {
  SPELL_SUMMON = true,
  SPELL_CREATE = true,
}

local DAMAGE = "Damage"
local TARGETS = "Targets"
local SPELLS = "Spells"
local FRIEND = "Friend Fire"

local frameRefresh = 1.0

local MAIN_PREV = "KurecountPrevButton"
local MAIN_NEXT = "KurecountNextButton"
local MAIN_CLOSE = "KurecountClose"
local MAIN_ROW = "KurecountScrollFrameChildItem"
local MAIN_MENU_TEXT = "KurecountHeaderFrameMenuText"
local MAIN_TARGET_TEXT = "KurecountHeaderFrameTargetText"

local DETAILS_PREV = "KurecountDetailsPrevButton"
local DETAILS_NEXT = "KurecountDetailsNextButton"
local DETAILS_CLOSE = "KurecountDetailsClose"
local DETAILS_ROW = "KurecountDetailsScrollFrameChildItem"
local DETAILS_MENU_TEXT = "KurecountDetailsHeaderFrameMenuText"
local DETAILS_TARGET_TEXT = "KurecountDetailsHeaderFrameTargetText"


--DATA TABLES
local player_info = {}
local pet_info = {}
local party_damage = {}
local target_damage = {}
local friend_fire = {}
local MAIN_FRAME_OPTIONS = {DAMAGE, TARGETS, FRIEND}
local MAIN_DATA_TABLES = {party_damage, target_damage, friend_fire}
local DETAILS_FRAME_OPTIONS = {SPELLS, TARGETS}


  

--VARIABLES  
local player_guid = nil
local target = nil


local combat_time = 0
local combat_start = nil
local combat_end = nil
local refresh_counter = 0
local is_on_combat = false
local is_on_encounter = false
  
  
--FRAMES
local mainOption = 0
local detailsOption = 0
local detailsName





function Kurecount_OnLoad(self)
  Kurecount_ResetValues()
  player_info = {}
  pet_info = {}
  Kurecount_UpdatePlayersInfo()
  Kurecount_UpdatePets()
  player_guid = UnitGUID("player")
  self:RegisterForDrag("LeftButton");
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("ENCOUNTER_START")
  self:RegisterEvent("ENCOUNTER_END")
  Kurecount_ResetValues()
  Kurecount_HideRows()
  
  
  getglobal(MAIN_PREV):SetScript("OnClick", Kurecount_prevMainFrame)
  getglobal(MAIN_PREV):SetScale(0.7)
  getglobal(MAIN_NEXT):SetScript("OnClick", Kurecount_nextMainFrame)
  getglobal(MAIN_NEXT):SetScale(0.7)
  getglobal(MAIN_CLOSE):SetScale(0.8)
  getglobal(MAIN_MENU_TEXT):SetText(MAIN_FRAME_OPTIONS[mainOption+1])
 
  for i = 1, 40 do
	local row = getglobal(MAIN_ROW..i)
	row:SetScript("OnMouseUp", Kurecount_OpenDetails)
  end
  
end


function KurecountDetails_OnLoad(self)
	self:RegisterForDrag("LeftButton");
	getglobal(DETAILS_PREV):SetScript("OnClick", Kurecount_prevDetailsFrame)
	getglobal(DETAILS_PREV):SetScale(0.7)
    getglobal(DETAILS_NEXT):SetScript("OnClick", Kurecount_nextDetailsFrame)
	getglobal(DETAILS_NEXT):SetScale(0.7)
    getglobal(DETAILS_CLOSE):SetScale(0.8)
    getglobal(DETAILS_MENU_TEXT):SetText(DETAILS_FRAME_OPTIONS[detailsOption+1])
	self:Hide()
end


--self = selected row
function Kurecount_OpenDetails(self)
	detailsName = self.name
	Kurecount_UpdateDetails()
	getglobal("KurecountDetails"):Show()
end



function Kurecount_ResetValues()
  party_damage = {}
  target_damage = {}
  friend_fire = {}
  target = nil
  combat_start = nil
  combat_end = nil
  combat_time = 0
  counter = 0
end



function Kurecount_OnUpdate(self, elapsed)
	if is_on_combat then
	  refresh_counter = refresh_counter + elapsed
	  if refresh_counter >= frameRefresh then
		refresh_counter = 0
		Kurecount_UpdateFrames()
	  end
	end
end

function Kurecount_OnEvent(self, event, ...)

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local srcFlags = select(6, ...)
    if bit.band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MASK) > COMBATLOG_OBJECT_AFFILIATION_RAID then
      return
    end
	Kurecount_TrackDamage(...)

  elseif event == "GROUP_ROSTER_UPDATE" then
    Kurecount_UpdatePlayersInfo()
    Kurecount_UpdatePets()

	
  elseif event == "ENCOUNTER_START" then
	Kurecount_ResetValues()
	Kurecount_HideRows()
	is_on_encounter = true
    is_on_combat = true
	combat_start = GetServerTime()
	Kurecount_UpdateTarget(select(2, ...))

	
  elseif event == "PLAYER_REGEN_DISABLED" then
    Kurecount_ResetValues()
	Kurecount_HideRows()
	combat_start = GetServerTime()
	is_on_combat = true
	
	
  elseif event == "PLAYER_REGEN_ENABLED" and not is_on_encounter then
	is_on_combat = false
	combat_time = GetServerTime() - combat_start
	Kurecount_UpdateEndCombat()
	
  elseif event == "ENCOUNTER_END" then
    is_on_encounter = false
	is_on_combat = false
	combat_time = GetServerTime() - combat_start
	Kurecount_UpdateEndCombat()
  end
end

function Kurecount_UpdatePlayersInfo()
  Kurecount_UpdatePlayerInfoUnit("player")
  for i = 1, 40 do
    Kurecount_UpdatePlayerInfoUnit("raid"..i)
  end
  for i = 1, 4 do
    Kurecount_UpdatePlayerInfoUnit("party"..i)
  end
 	
end

function Kurecount_UpdatePlayerInfoUnit(unit)
  if unit and UnitExists(unit) then
    local guid = UnitGUID(unit)
    Kurecount_UpdatePlayerInfoGuid(guid)
  end
end

function Kurecount_UpdatePlayerInfoGuid(guid)
	if player_info[guid] == nil then
		local class, classFilename, race, raceFilename, sex, name, realm = GetPlayerInfoByGUID(guid)
		player_info[guid] = {class = class, classFilename = classFilename, race = race, raceFilename = raceFilename, sex = sex, name = name, realm = realm}
	end
end 


function compareByDamage(a,b)
  return a.damage > b.damage
end


function getPetOwner(srcGUID)
	if pet_info[srcGUID] == nil then
	  Kurecount_UpdatePets()
	  Kurecount_UpdatePlayersInfo()
	  if pet_info[srcGUID] == nil then
		return
	  end
    end
    return pet_info[srcGUID].ownerGuid
end 


function Kurecount_UpdateDamageTable(tableVar, subTableName, name, subName, amount)
	if not tableVar then
		tableVar = {}
	end
	if not tableVar.damage then
		tableVar.damage = 0
	end
	tableVar.damage = tableVar.damage + amount
	
	local updated = false
	
	for i,elem in ipairs(tableVar) do
		if elem.name == name then
			if not elem[subTableName] then
				elem[subTableName] = {}
				elem.damage = 0
			end
			elem.damage = elem.damage + amount
			for j,subelem in ipairs(elem[subTableName]) do
				if subelem.name == subName then
					subelem.damage = subelem.damage + amount
					subelem.count = subelem.count + 1
					table.sort(elem[subTableName], compareByDamage)
					updated = true
					break
				end
			end
			if not updated then
				table.insert(elem[subTableName], {name = subName, damage = amount, count = 1})
				updated = true
			end
			break
		end
    end
	if not updated then
		table.insert(tableVar,{name = name, totalDamage = amount, subTableName = {name = subName, damage = amount, count = 1}})
	end
end


function Kurecount_UpdateDamageAmount(srcGUID, srcName, srcFlags, amount, destGUID, destName, destFlags, spellName)
  -- if source is guardian, object or pet: change guid to owner's
  if bit.band(srcFlags, bit.bor(COMBATLOG_OBJECT_TYPE_GUARDIAN, COMBATLOG_OBJECT_TYPE_OBJECT, COMBATLOG_OBJECT_TYPE_PET)) ~=0 then
    srcGUID = getPetOwner(srcGUID)
	if spellName then
		spellName = spellName.." <"..srcName..">"
	end
  end
  
  if player_info[destGUID] then
	-- friend fire
	Kurecount_UpdateDamageTable(friend_fire, "damageByTarget", srcGUID, destName, amount)
	Kurecount_UpdateDamageTable(friend_fire, "damageBySpell", srcGUID, spellName, amount)
  else
	-- damage
	Kurecount_UpdateDamageTable(party_damage, "damageByTarget", srcGUID, destName, amount)
	Kurecount_UpdateDamageTable(party_damage, "damageBySpell", srcGUID, spellName, amount)
	Kurecount_UpdateDamageTable(target_damage, "damageByPlayer", destName, srcGUID, amount)
  end
end

function Kurecount_UpdatePets()
  Kurecount_UpdatePetUnit("pet", "player")
  for i = 1, 40 do
    Kurecount_UpdatePetUnit("raidpet"..i, "raid"..i)
  end
  for i = 1, 4 do
    Kurecount_UpdatePetUnit("partypet"..i, "party"..i)
  end
end

function Kurecount_UpdatePetUnit(petUnit, ownerUnit)
  if petUnit and UnitExists(petUnit) then
    local guid = UnitGUID(ownerUnit)
    local petGUID = UnitGUID(petUnit)
    local petName = GetUnitName(petUnit, false)
    pet_info[petGUID] = {name = petName, ownerGuid = guid}
  end
end

function Kurecount_TrackDamage(timestamp, combatEvent, hideCaster, srcGUID, srcName, srcFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, ...)
  
  if TRACKED_SUMMONS[combatEvent] then
    pet_info[destGUID] = {name = destName, ownerGuid = srcGUID}
  elseif TRACKED_DAMAGE[combatEvent] then
    if srcGUID == "" then
		return
	end
	-- if the target is a pet ignore it (for mages)
	if pet_info[destGUID] then
		return
	end
	
	local offset = 4
	local spellName
    if (combatEvent == "SWING_DAMAGE") then
      offset = 1
	  spellName = "Melee"
    else
      spellName = select(2, ...)
    end

	
	
    local amount, overkill, school, resisted, blocked, absorbed = select(offset, ...)
    Kurecount_UpdateDamageAmount(srcGUID, srcName, srcFlags, amount, destGUID, destName, destFlags, spellName)
    
	if target == nil then
      Kurecount_UpdateTarget(destName)
    end
  end
end


function Kurecount_prevMainFrame()
	mainOption = (mainOption - 1) % #MAIN_FRAME_OPTIONS
	local text = getglobal(MAIN_MENU_TEXT)
	text:SetText(MAIN_FRAME_OPTIONS[mainOption + 1])	
	Kurecount_UpdateFrames()
end

function Kurecount_nextMainFrame()
	mainOption = (mainOption + 1) % #MAIN_FRAME_OPTIONS
	local text = getglobal(MAIN_MENU_TEXT)
	text:SetText(MAIN_FRAME_OPTIONS[mainOption + 1])
	Kurecount_UpdateFrames()	
end

function Kurecount_prevDetailsFrame()
	detailsOption = (detailsOption - 1) % #DETAILS_FRAME_OPTIONS
	local text = getglobal(DETAILS_MENU_TEXT)
	text:SetText(DETAILS_FRAME_OPTIONS[detailsOption + 1])	
	Kurecount_UpdateFrames()
end

function Kurecount_nextDetailsFrame()
	detailsOption = (detailsOption + 1) % #DETAILS_FRAME_OPTIONS
	local text = getglobal(DETAILS_MENU_TEXT)
	text:SetText(DETAILS_FRAME_OPTIONS[detailsOption + 1])	
	Kurecount_UpdateFrames()
end

function Kurecount_UpdateFrames()
  if #party_damage == 0 then 
    return
  end
  Kurecount_UpdateMain()
  Kurecount_UpdateDetails()
end

function Kurecount_UpdateMain()
	tableVar = MAIN_DATA_TABLES[mainOption + 1]
	for i, v in ipairs(tableVar) do
		--Kurecount_UpdatePlayerInfoGuid(v.name)
		Kurecount_UpdateMainFrame(tableVar, i)
	end
	Kurecount_HideRowsMainFrame(#tableVar + 1, 40)		
end


function Kurecount_HideRowsMainFrame(init_idx, end_idx)
	for i = init_idx, end_idx do
		local row = getglobal(MAIN_ROW..i)
		row:Hide()
	end
end

function Kurecount_HideRowsDetailsFrame(init_idx, end_idx)
	for i = init_idx, end_idx do
		local row = getglobal(DETAILS_ROW..i)
		row:Hide()
	end
end

function Kurecount_UpdateDetails()
	if detailsName and MAIN_FRAME_OPTIONS[mainOption + 1] == DAMAGE then
		if not player_info[detailsName] then return end
		getglobal(DETAILS_TARGET_TEXT):SetFormattedText("Details: %s", player_info[detailsName].name)
		Kurecount_ShowDetailsFrameButtons()
		if DETAILS_FRAME_OPTIONS[detailsOption + 1] == SPELLS then
			Kurecount_UpdateDetailsSpells()
		end
		if DETAILS_FRAME_OPTIONS[detailsOption + 1] == TARGETS then
			Kurecount_UpdateDetailsTargets()
		end
	end
	if detailsName and MAIN_FRAME_OPTIONS[mainOption + 1] == TARGETS then
		getglobal(DETAILS_TARGET_TEXT):SetFormattedText("Details: %s", detailsName)
		Kurecount_HideDetailsFrameButtons()
		Kurecount_UpdateDetailsTargetPlayers()
	end
end

function Kurecount_ShowDetailsFrameButtons()
	getglobal(DETAILS_MENU_TEXT):Show()
	getglobal(DETAILS_PREV):Show()
	getglobal(DETAILS_NEXT):Show()
end

function Kurecount_HideDetailsFrameButtons()
	getglobal(DETAILS_MENU_TEXT):Hide()
	getglobal(DETAILS_PREV):Hide()
	getglobal(DETAILS_NEXT):Hide()		
end


function Kurecount_UpdateDetailsDamage(damageTable, totalDamage)
	local maxDamage = 0
	for j, w in ipairs(damageTable) do
		if j==1 then maxDamage = w.damage end
		local percentRowLength = w.damage / maxDamage
		local percenttext = PercentageNum(w.damage / totalDamage)
		local textName = string.format("%d. %s (%d)", j, w.name, w.count)
		local textDamage = string.format("%s (%s)", ShortNum(w.damage), percenttext)
		local color = DEFAULT_COLORS[1 + j%(#DEFAULT_COLORS)]
		Kurecount_FillRowFrame(DETAILS_ROW..j, textName, textDamage, color, percentRowLength)
	end
	Kurecount_HideRowsDetailsFrame(#damageTable + 1, 40)
end


function Kurecount_UpdateDetailsSpells()
	for i, v in ipairs(party_damage) do
		if v.name == detailsName then
			Kurecount_UpdateDetailsDamage(v.damageBySpell, v.damage)
		end
	end
end

function Kurecount_UpdateDetailsTargets()
	for i, v in ipairs(party_damage) do
		if v.name == detailsName then
			Kurecount_UpdateDetailsDamage(v.damageByTarget, v.damage)
		end
	end
end

function Kurecount_UpdateDetailsTargetPlayers()
	for i, v in ipairs(target_damage) do
		if v.name == detailsName then
			Kurecount_UpdateDetailsDamage(v.damageByPlayer, v.damage)
		end
	end
end

function Kurecount_UpdateMainFrame(tableVar, i)
	print ("Kurecount_UpdateMainFrame")
	local name, textName, textDamage, color, colorPercent = Kurecount_GetRowParamsFromTable(tableVar, i)
	Kurecount_FillRowFrame(MAIN_ROW..i, name, textName, textDamage, color, colorPercent)
end


function Kurecount_GetRowParamsFromTable(tableVar, i)
	local color, name
	if player_info[tableVar[i].name] then
		color = CLASS_COLORS[player_info[tableVar[i].name].classFilename]
		name = player_info[tableVar[i].name].name
	else
		color = DEFAULT_COLORS[1 + i%(#DEFAULT_COLORS)]
		name = tableVar[i].name
	end

	local maxDamage = tableVar[1].damage
	local damagetext = ShortNum(tableVar[i].damage)
	local percenttext = PercentageNum(tableVar[i].damage/tableVar.damage)
	
	local totalTime
	if is_on_combat then
		totalTime = GetServerTime() - combat_start
	else
		totalTime = combat_time
	end
	local dpstext = ShortNum(0)
	if totalTime > 0 then 
		dpstext = ShortNum(tableVar[i].damage/totalTime)
	end
	local percentRowLength = tableVar[i].damage / maxDamage
	local textName = string.format("%d. %s", i, name)
	local textDamage = string.format("%s (%s, %s)", damagetext, dpstext, percenttext)
	
	return name, textName, textDamage, color, percentRowLength
end 

function Kurecount_FillRowFrame(frameName, name, textLeft, textRight, color, colorPercent)
	local row = getglobal(frameName)
	row.name = name
	local texture = getglobal(frameName.."Bar")
	texture:SetColorTexture(color.r, color.g, color.b, 1)
	texture:SetWidth(row:GetWidth() * colorPercent)
	local textLeftFrame = getglobal(frameName.."TextLeft")
	textLeftFrame:SetFormattedText("%s", textLeft)
	local textRightFrame = getglobal(frameName.."TextRight")
	textRightFrame:SetFormattedText("%s", textRight)
	row:Show()
end



function Kurecount_HideRows()
	local scrollFrame = getglobal("KurecountScrollFrameChild")
	for i=1,40 do
		local row = getglobal(MAIN_ROW..i)
		row:SetWidth(scrollFrame:GetWidth())
		row:Hide()
	end
end

function Kurecount_UpdateTarget(newTarget)
	target = newTarget
	local targetText = getglobal(MAIN_TARGET_TEXT)
	combat_start = GetServerTime()
	targetText:SetText(newTarget.." ("..date("!%X",combat_start)..")")
end

function Kurecount_UpdateEndCombat()
	local targetText = getglobal(MAIN_TARGET_TEXT)
	combat_end = GetServerTime()
	if target then 
		targetText:SetText(target.." ("..date("!%X",combat_start).." - "..date("!%X",combat_end)..")")
	end
end

function ShortNum(num)
  if num > 1000000 then
    return string.format("%.2f%s", num * mill, "M")
  elseif num > 1000 then
    return string.format("%.2f%s", num * ks, "k")
  else
    return string.format("%.2f", num)
  end
end

function PercentageNum(num)
  if num > 0 then
    return string.format("%.2f%s", num * 100, "%")
  else
    return "0.0%"
  end
end

function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end



------------------------------------------------------------------------------
------------------------------------------------------------------------------

SLASH_KURECOUNT1 = "/kurecount"
SlashCmdList["KURECOUNT"] = function()
	getglobal("Kurecount"):Show()
end








