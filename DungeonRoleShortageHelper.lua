
local addOnName = "DungeonRoleShortageHelper"
local addOn = LibStub("AceAddon-3.0"):NewAddon(addOnName, "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("DungeonRoleShortageHelper")

----------------------------------------------------------
--	Globals												--
----------------------------------------------------------
local healerButton = nil
local tankButton = nil
local damagerButton = nil
local updateTimer = nil

local tankShortageDungeons = nil
local healerShortageDungeons = nil
local damagerShortageDungeons = nil

local  isMainFrameDragged = false
local  isMainFrameLocked = false

----------------------------------------------------------
--	Utilities											--
----------------------------------------------------------
function Log(str, ...)
	if not DungeonRoleShortageHelperDB.isDebugging then
		return
	end
	
	if ... then str = str:format(...) end
	DEFAULT_CHAT_FRAME:AddMessage(("%s: %s"):format(addOnName,str))
end

--More functions from LFGFrame 
function GetTexCoordsForRole(role)
	local textureHeight, textureWidth = 256, 256;
	local roleHeight, roleWidth = 67, 67;
	
	if ( role == "GUIDE" ) then
		return GetTexCoordsByGrid(1, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "TANK" ) then
		return GetTexCoordsByGrid(1, 2, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "HEALER" ) then
		return GetTexCoordsByGrid(2, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "DAMAGER" ) then
		return GetTexCoordsByGrid(2, 2, textureWidth, textureHeight, roleWidth, roleHeight);
	else
		error("Unknown role: "..tostring(role));
	end
end

function GetBackgroundTexCoordsForRole(role)
	local textureHeight, textureWidth = 128, 256;
	local roleHeight, roleWidth = 75, 75;
	
	if ( role == "TANK" ) then
		return GetTexCoordsByGrid(2, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "HEALER" ) then
		return GetTexCoordsByGrid(1, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "DAMAGER" ) then
		return GetTexCoordsByGrid(3, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	else
		error("Role does not have background: "..tostring(role));
	end
end

function GetTexCoordsForRoleSmallCircle(role)
	if ( role == "TANK" ) then
		return 0, 19/64, 22/64, 41/64;
	elseif ( role == "HEALER" ) then
		return 20/64, 39/64, 1/64, 20/64;
	elseif ( role == "DAMAGER" ) then
		return 20/64, 39/64, 22/64, 41/64;
	else
		error("Unknown role: "..tostring(role));
	end
end

function GetTexCoordsForRoleSmall(role)
	if ( role == "TANK" ) then
		return 0.5, 0.75, 0, 1;
	elseif ( role == "HEALER" ) then
		return 0.75, 1, 0, 1;
	elseif ( role == "DAMAGER" ) then
		return 0.25, 0.5, 0, 1;
	else
		error("Unknown role: "..tostring(role));
	end
end

----------------------------------------------------------
--	Addon 											    --
----------------------------------------------------------
function addOn:OnInitialize()
	if not DungeonRoleShortageHelperDB then
		DungeonRoleShortageHelperDB = {}
		DungeonRoleShortageHelperDB.isDebugging = false
		DungeonRoleShortageHelperDB.mainFramePosition = {x = 0, y =0}
	end
end


function addOn:CreateUI ()
	mainFrame = CreateFrame("Frame",("%s.MainFrame"):format(addOnName),UIParent)
	mainFrame:SetWidth(125) 
	mainFrame:SetHeight(40) 
	mainFrame:SetPoint("BOTTOMLEFT",DungeonRoleShortageHelperDB.mainFramePosition.x, DungeonRoleShortageHelperDB.mainFramePosition.y)
	mainFrame:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	    tile = true, tileSize = 8, edgeSize = 8,
	    insets = { left = 1, right = 1, top = 1, bottom = 1 }
	})
	mainFrame:SetBackdropColor(0, 0, 0, 0.8)
	mainFrame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1.0);

	mainFrame:SetMovable(true)
	mainFrame:EnableMouse(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript(
		"OnDragStart", 
		function() 
			Log("OnDragStart")
			if not isMainFrameLocked then
			mainFrame:StartMoving() 
			isMainFrameDragged = true 
			end
		end
	)

	mainFrame:SetScript(
		"OnDragStop", 
		function() 
			Log("OnDragStop")
			if not isMainFrameLocked then
				mainFrame:StopMovingOrSizing() 
				isMainFrameDragged = false
				local x = mainFrame:GetLeft()
				local y = mainFrame:GetBottom()
				DungeonRoleShortageHelperDB.mainFramePosition = { x = mainFrame:GetLeft(), y = mainFrame:GetBottom()}
			end
		end
	)

	tankButton = CreateFrame("Button", nil, mainFrame)
	tankButton:SetPoint("LEFT", 10, 0)
	tankButton:SetWidth(32)
	tankButton:SetHeight(32)

	local tankIcon = tankButton:CreateTexture() 
	tankIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
	tankIcon:SetTexCoord(GetTexCoordsForRole("TANK")) 
	tankIcon:SetAllPoints()	
	tankButton:SetNormalTexture(tankIcon)
	SetDesaturation(tankButton:GetNormalTexture(), true);

	tankButton:SetScript(
		"OnEnter",
		function(widget)
			if table.maxn(tankShortageDungeons) == 0 then
				return
			end

			GameTooltip:SetOwner(tankButton, "ANCHOR_TOPRIGHT")
			GameTooltip:AddLine(L["Dungeon List For Tank:"])
			for _, dungeonName in pairs(tankShortageDungeons) do		
				GameTooltip:AddLine(dungeonName)
			end 
			GameTooltip:Show()
		end
	)

	tankButton:SetScript(
		"OnLeave",
		function(widget)
			GameTooltip:Hide()
		end
	)

	
	tankButton:SetScript(
		"OnClick",
		function(widget)
			if table.maxn(tankShortageDungeons) == 0 then
				return
			end

			ToggleLFDParentFrame()
		end
	)

	healerButton = CreateFrame("Button", nil, mainFrame)
	healerButton:SetPoint("LEFT", 45, 0)
	healerButton:SetWidth(32)
	healerButton:SetHeight(32)

	local healerIcon = healerButton:CreateTexture() 
	healerIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
	healerIcon:SetTexCoord(GetTexCoordsForRole("HEALER")) 
	healerIcon:SetAllPoints()	
	healerButton:SetNormalTexture(healerIcon)
	SetDesaturation(healerButton:GetNormalTexture(), true);

	healerButton:SetScript(
		"OnEnter",
		function(widget)
			if table.maxn(healerShortageDungeons) == 0 then
				return
			end
			GameTooltip:SetOwner(healerButton, "ANCHOR_TOPRIGHT")
			GameTooltip:AddLine(L["Dungeon List For Healer:"])
			for _, dungeonName in pairs(healerShortageDungeons) do		
				GameTooltip:AddLine(dungeonName)
			end 
			GameTooltip:Show()
		end
	)

	healerButton:SetScript(
		"OnLeave",
		function(widget)
			GameTooltip:Hide()
		end
	)

	healerButton:SetScript(
		"OnClick",
		function(widget)
			if table.maxn(healerShortageDungeons) == 0 then
				return
			end

			ToggleLFDParentFrame()
		end
	)

	damagerButton = CreateFrame("Button", nil, mainFrame)
	damagerButton:SetPoint("LEFT", 80, 0)
	damagerButton:SetWidth(32)
	damagerButton:SetHeight(32)

	local damagerIcon = damagerButton:CreateTexture() 
	damagerIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
	damagerIcon:SetTexCoord(GetTexCoordsForRole("DAMAGER")) 
	damagerIcon:SetAllPoints()	
	damagerButton:SetNormalTexture(damagerIcon)
	SetDesaturation(damagerButton:GetNormalTexture(), true);
	
	damagerButton:SetScript(
		"OnEnter",
		function(widget)
			if table.maxn(damagerShortageDungeons) == 0 then
				return
			end
			GameTooltip:SetOwner(damagerButton, "ANCHOR_TOPRIGHT")		
			GameTooltip:AddLine(L["Dungeon List For Damager:"])
			for _, dungeonName in pairs(damagerShortageDungeons) do		
				GameTooltip:AddLine(dungeonName)
			end 
			GameTooltip:Show()
		end
	)

	damagerButton:SetScript(
		"OnLeave",
		function(widget)
			GameTooltip:Hide()
		end
	)

	damagerButton:SetScript(
		"OnClick",
		function(widget)
			if table.maxn(damagerShortageDungeons) == 0 then
				return
			end

			ToggleLFDParentFrame()
		end
	)
end

function addOn:DestroyUI ()
 -- Do what here?
end

function addOn:OnEnable()
	Log("OnEnable")

	self:RegisterEvent("LFG_UPDATE_RANDOM_INFO", "OnLFGUpdateRandomInfo")

	updateTimer = self:ScheduleRepeatingTimer("OnUpdate", 10)
	
	self:CreateUI()

	-- Call update manually.
	self:OnUpdate()
    
end

function addOn:OnDisable()
	if updateTimer then
		self:CancelTimer(updateTimer, true)
		updateTimer = nil
	end

	self:DestroyUI()
end

function addOn:CheckDungeonAvaliable(dungeonID)
	local _, _, _, minLevel, maxLevel, _, _, _, expansionLevel, _, _, _, _, _, _, _, _, _, _, minGearLevel = GetLFGDungeonInfo(dungeonID);

	local hasSufficientExpansionLevel = EXPANSION_LEVEL >= expansionLevel
	if not hasSufficientExpansionLevel then
		return false
	end

	local palyerLevel = UnitLevel("player")
	local hasSufficientPlayerLevel = palyerLevel >= minLevel and palyerLevel <= maxLevel
	if not hasSufficientPlayerLevel then
		return false
	end

	local overallAverageItemLevel, _, _ =  GetAverageItemLevel()
	local hasSufficientItemLevel = overallAverageItemLevel >= minGearLevel
	if not hasSufficientItemLevel then
		return false
	end

	return true
end

function addOn:CheckShortageReward()
	tankShortageDungeons = {}
	healerShortageDungeons = {}
	damagerShortageDungeons = {}
	
	-- There is no API for finding avaliable rondom dungeons, so just iterate all，
	-- so I just iterate all random dungeons.
	for randomDungeonIndex = 1, GetNumRandomDungeons() do
		local dungeonID, dungeonName = GetLFGRandomDungeonInfo(randomDungeonIndex)
		if self:CheckDungeonAvaliable(dungeonID) then
			for shortageServerity=1, LFG_ROLE_NUM_SHORTAGE_TYPES do
				local eligible, forTank, forHealer, forDamage, itemCount, money, xp = GetLFGRoleShortageRewards(dungeonID, shortageServerity)
				local shortageRoles = {} 
				local hasRewards = ((0 ~= itemCount) or (0 ~= money) or (0 ~= xp))
				if eligible and hasRewards then
					if forTank then
						table.insert(tankShortageDungeons, dungeonName)
					end
					if forHealer then
						table.insert(healerShortageDungeons, dungeonName)
					end
					if forDamage then
						table.insert(damagerShortageDungeons, dungeonName)
					end
				end
			end
		end
	end
end

function addOn:UpdateUI()
	if table.maxn(tankShortageDungeons) > 0 then
		SetDesaturation(tankButton:GetNormalTexture(), false);
	else 
		SetDesaturation(tankButton:GetNormalTexture(), true);
	end
	
	if table.maxn(healerShortageDungeons) > 0 then
		SetDesaturation(healerButton:GetNormalTexture(), false);
	else 
		SetDesaturation(healerButton:GetNormalTexture(), true);
	end
	
	if table.maxn(damagerShortageDungeons) > 0 then
		SetDesaturation(damagerButton:GetNormalTexture(), false);
	else 
		SetDesaturation(damagerButton:GetNormalTexture(), true);
	end
end

function addOn:OnUpdate()
	self:CheckShortageReward()
	self:UpdateUI()
end

function addOn:OnLFGUpdateRandomInfo()
	-- Call update manually.
	self:OnUpdate()
end