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
  {r=0.5, g=0.5, b=0.5}, 
  {r=0.7, g=0.7, b=0.7}, 
}
local TRACKED_SUMMONS = {
  SPELL_SUMMON = true,
  SPELL_CREATE = true,
}

local DAMAGE = "Damage"
local TARGETS = "Targets"
local SPELLS = "Spells"
local FRIEND = "Friend Fire"

local MAIN_FRAME_OPTIONS = {DAMAGE, TARGETS}
local DETAILS_FRAME_OPTIONS = {SPELLS, TARGETS}
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
  

--VARIABLES  
local player_guid = nil
local total_damage = 0
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


local zero_mt = {
    __index = function(tbl, key)
      return 0
    end,
  }

function Kurecount_ResetValues()
  combat_time = 0
  total_damage = 0
  party_damage = newTable()
  target_damage = newTable()
  target = nil
  combat_start = nil
  combat_end = nil
  counter = 0
end


function newTable()
	local new = {}
	setmetatable(new, zero_mt)
	return new
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

function compareByTotalDamage(a,b)
  return a.totalDamage > b.totalDamage
end

function compareByDamage(a,b)
  return a.damage > b.damage
end

function Kurecount_UpdateDamageAmount(srcGUID, srcName, srcFlags, amount, destGUID, destName, destFlags, spellName)
  -- if guardian, object or pet: change guid to owner's
  if bit.band(srcFlags, bit.bor(COMBATLOG_OBJECT_TYPE_GUARDIAN, COMBATLOG_OBJECT_TYPE_OBJECT, COMBATLOG_OBJECT_TYPE_PET)) ~=0 then
    if pet_info[srcGUID] == nil then
	  Kurecount_UpdatePets()
	  Kurecount_UpdatePlayersInfo()
	  if pet_info[srcGUID] == nil then
		return
	  end
    end
    srcGUID = pet_info[srcGUID].ownerGuid
	if spellName then
		spellName = "<PET="..srcName..">"..spellName
	end
  end
  
  if srcGUID == nil then
    return
  end

  total_damage = total_damage + amount
  
  local damageUpdated = false
  
  for i,elem in ipairs(party_damage) do
    if elem.guid == srcGUID then
      
	  --total
	  party_damage[i].totalDamage = party_damage[i].totalDamage + amount
      
	  --damage by target
	  damageUpdated = false
	  for j,elem in ipairs(party_damage[i].damageByTarget) do
        if elem.target == destName then
          party_damage[i].damageByTarget[j].damage = party_damage[i].damageByTarget[j].damage + amount
          damageUpdated = true
        end
      end
      if not damageUpdated then
        table.insert(party_damage[i].damageByTarget, {target = destName, damage = amount})
      end
      table.sort(party_damage[i].damageByTarget, compareByDamage)
      
	  --damage by spell
	  damageUpdated = false
	  for j,elem in ipairs(party_damage[i].damageBySpell) do
        if elem.spell == spellName then
		  party_damage[i].damageBySpell[j].count = party_damage[i].damageBySpell[j].count + 1
          party_damage[i].damageBySpell[j].damage = party_damage[i].damageBySpell[j].damage + amount
          damageUpdated = true
        end
      end
      if not damageUpdated then
        table.insert(party_damage[i].damageBySpell, {spell = spellName, damage = amount, count = 1})
      end
      table.sort(party_damage[i].damageBySpell, compareByDamage)
      
	  damageUpdated = true
    end
  end

  if not damageUpdated then table.insert(party_damage, {guid = srcGUID, totalDamage = amount, damageByTarget = {{target = destName, damage = amount}}, damageBySpell = {{spell = spellName, damage = amount, count = 1}}}) end
  table.sort(party_damage, compareByTotalDamage)

  
  damageUpdated = false
  --target pov
  for i,elem in ipairs(target_damage) do
    if elem.target == destName then
      --total
	  target_damage[i].totalDamage = target_damage[i].totalDamage + amount
      
	  --damage by target
	  for j,elem in ipairs(target_damage[i].damageByPlayer) do
        if elem.player == srcGUID then
          target_damage[i].damageByPlayer[j].damage = target_damage[i].damageByPlayer[j].damage + amount
          damageUpdated = true
        end
      end
      if not damageUpdated then
        table.insert(target_damage[i].damageByPlayer, {player = srcGUID, damage = amount})
      end
      table.sort(target_damage[i].damageByPlayer, compareByDamage)
      damageUpdated = true
	end
  end
  if not damageUpdated then 
	table.insert(target_damage, {target = destName, totalDamage = amount, damageByPlayer = {{player = srcGUID, damage = amount}}}) 
  end
  table.sort(target_damage, compareByTotalDamage)
  

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
	
	-- if the target is a player ignore it (friend fire)
	if player_info[destGUID] then
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
  if MAIN_FRAME_OPTIONS[mainOption + 1] == DAMAGE then 
	  for i, v in ipairs(party_damage) do
		Kurecount_UpdatePlayerInfoGuid(v.guid)
		Kurecount_UpdateMainFrameRaidDamage(i)
	  end
	  Kurecount_HideRowsMainFrame(#party_damage+1, 40)		
  end
  if MAIN_FRAME_OPTIONS[mainOption + 1] == TARGETS then 
	  for i, v in ipairs(target_damage) do
		Kurecount_UpdateMainFrameTargets(i)
	  end
	  Kurecount_HideRowsMainFrame(#target_damage+1, 40)
  end	  
  
  Kurecount_UpdateDetails()
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


function Kurecount_UpdateDetailsSpells()
	for i, v in ipairs(party_damage) do
		if v.guid == detailsName then
			local maxDamage = 0
			for j, w in ipairs(v.damageBySpell) do
				if j==1 then maxDamage = w.damage end
				local percentRowLength = w.damage / maxDamage
				local percenttext = PercentageNum(w.damage / v.totalDamage)
				local textName = string.format("%d. %s (%d)", j, w.spell, w.count)
				local textDamage = string.format("%s (%s)", ShortNum(w.damage), percenttext)
				local color = DEFAULT_COLORS[1 + j%(#DEFAULT_COLORS)]
				Kurecount_FillRowFrame(DETAILS_ROW..j, textName, textDamage, color, percentRowLength)
			end
			Kurecount_HideRowsDetailsFrame(#v.damageBySpell+1, 40)
		end
	end
end

function Kurecount_UpdateDetailsTargets()
	for i, v in ipairs(party_damage) do
		if v.guid == detailsName then
			local maxDamage = 0
			for j, w in ipairs(v.damageByTarget) do
				if j==1 then maxDamage = w.damage end
				local percentRowLength = w.damage / maxDamage
				local percenttext = PercentageNum(w.damage / v.totalDamage)
				local textName = string.format("%d. %s", j, w.target)
				local textDamage = string.format("%s (%s)", ShortNum(w.damage), percenttext)
				local color = DEFAULT_COLORS[1 + j%(#DEFAULT_COLORS)]
				Kurecount_FillRowFrame(DETAILS_ROW..j, textName, textDamage, color, percentRowLength)
			end
			Kurecount_HideRowsDetailsFrame(#v.damageByTarget+1, 40)
		end
	end
end

function Kurecount_UpdateDetailsTargetPlayers()
	for i, v in ipairs(target_damage) do
		if v.target == detailsName then
			local maxDamage = 0
			for j, w in ipairs(v.damageByPlayer) do
				if j==1 then maxDamage = w.damage end
				local percentRowLength = w.damage / maxDamage
				local percenttext = PercentageNum(w.damage / v.totalDamage)
				local textName = string.format("%d. %s", j, player_info[w.player].name)
				local textDamage = string.format("%s (%s)", ShortNum(w.damage), percenttext)
				local color = CLASS_COLORS[player_info[w.player].classFilename]
				Kurecount_FillRowFrame(DETAILS_ROW..j, textName, textDamage, color, percentRowLength)
			end
			Kurecount_HideRowsDetailsFrame(#v.damageByPlayer+1, 40)
		end
	end
end

function Kurecount_UpdateMainFrameRaidDamage(i)
	
	local guid = party_damage[i].guid
	local damage = party_damage[i].totalDamage
	local damagetext = ShortNum(damage)
	local percenttext = PercentageNum(damage/total_damage)
	
	local totalTime
	if is_on_combat then
		totalTime = GetServerTime() - combat_start
	else
		totalTime = combat_time
	end
	local dpstext = ShortNum(damage/totalTime)
	local color = CLASS_COLORS[player_info[guid].classFilename]
	if not color then
		color={r=0, g=0, b=0}
	end
	local percentRowLength = party_damage[i].totalDamage / party_damage[1].totalDamage
	local textName = string.format("%d. %s", i, player_info[guid].name)
	local textDamage = string.format("%s (%s, %s)", damagetext, dpstext, percenttext)
	
	Kurecount_FillRowFrame(MAIN_ROW..i, textName, textDamage, color, percentRowLength)
	getglobal(MAIN_ROW..i).name = guid

end


function Kurecount_UpdateMainFrameTargets(i)
	
	local target = target_damage[i].target
	local damage = target_damage[i].totalDamage
	local damagetext = ShortNum(damage)
	local percenttext = PercentageNum(damage/total_damage)
	
	local totalTime
	if is_on_combat then
		totalTime = GetServerTime() - combat_start
	else
		totalTime = combat_time
	end
	local dpstext = ShortNum(damage/totalTime)
	local color = DEFAULT_COLORS[1 + i%(#DEFAULT_COLORS)]
	local percentRowLength = target_damage[i].totalDamage / target_damage[1].totalDamage
	local textName = string.format("%d. %s", i, target)
	local textDamage = string.format("%s (%s, %s)", damagetext, dpstext, percenttext)
	
	Kurecount_FillRowFrame(MAIN_ROW..i, textName, textDamage, color, percentRowLength)
	getglobal(MAIN_ROW..i).name = target
end


function Kurecount_FillRowFrame(frameName, textLeft, textRight, color, colorPercent)
	local row = getglobal(frameName)
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








