local MapDims = LibStub("LibMapData-1.0")

local raid_units = {}
for i = 1, MAX_RAID_MEMBERS do
	raid_units[i] = format("raid%i", i)
end

local roster_sort = function(a, b)
	if a.invalid ~= b.invalid then
		return a.invalid < b.invalid
	else
		if a.potential ~= b.potential then
			return a.potential > b.potential
		else
			return a.unit < b.unit
		end
	end
end

local GridStatus = Grid:GetModule("GridStatus")
local GridRoster = Grid:GetModule("GridRoster")

local GridStatusHRTargets = GridStatus:NewModule("GridStatusHRTargets", "AceTimer-3.0")
GridStatusHRTargets.menuName = "GridStatusHRTargets"
GridStatusHRTargets.options = false

GridStatusHRTargets.data = {}
GridStatusHRTargets.data.roster = {}
GridStatusHRTargets.data.colors = {}

local roster = GridStatusHRTargets.data.roster
local colors = GridStatusHRTargets.data.colors
local settings

GridStatusHRTargets.defaultDB = {
	HRTargets = {
		text      = "HR Target",
		enable    = false,
		priority  = 90,
		frequency = 3,
		numToFind = 3,
		color     = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
		color2    = { r = 1.0, g = 1.0, b = 1.0, a = 0.3 },
		mst_usage = 0.7
	},
}

local HRTargets_options = {
	["frequency"] = {
		type = "range",
		name = "Refresh frequency",
		desc = "Seconds between status refreshes",
		get  = function() 
		           return GridStatusHRTargets.db.profile.HRTargets.frequency 
               end,
		set  = function(_, v)
		           GridStatusHRTargets.db.profile.HRTargets.frequency = v
		           GridStatusHRTargets:CancelTimer(GridStatusHRTargets.UpdateAllUnitsTimer, true)
		           if GridStatusHRTargets.db.profile.HRTargets.enable then
				       GridStatusHRTargets.UpdateAllUnitsTimer = GridStatusHRTargets:ScheduleRepeatingTimer("UpdateAllUnits", GridStatusHRTargets.db.profile.HRTargets.frequency)
		           end
		       end,
		min  = 0,
		max  = 5,
		step = 0.1,
		isPercent = false,
		order = -1,
	},
	["numToFind"] = {
		type = "range",
		name = "Number of targets to find",
		desc = " ",
		max  = 25,
		min  = 1,
		step = 1,
		get  = function()
		           return GridStatusHRTargets.db.profile.HRTargets.numToFind
		       end,
		set  = function(_, v)
		           GridStatusHRTargets.db.profile.HRTargets.numToFind = v
		           GridStatusHRTargets:GenerateColors()
               end,
		order = -1
	},
	["color"] = {
		type = "color",
		name = "Color 1",
		desc = "Best of the best color.",
		hasAlpha = true,
		get = function ()
			local color = GridStatusHRTargets.db.profile.HRTargets.color
			return color.r, color.g, color.b, color.a
		end,
		set = function (_, r, g, b, a)
			local color = GridStatusHRTargets.db.profile.HRTargets.color
			color.r = r
			color.g = g
			color.b = b
			color.a = a or 1
			GridStatusHRTargets:GenerateColors()
		end,
	},
	["color2"] = {
		type = "color",
		name = "Color 2",
		desc = "Worst of the best color.",
		hasAlpha = true,
		get = function ()
			local color = GridStatusHRTargets.db.profile.HRTargets.color2
			return color.r, color.g, color.b, color.a
		end,
		set = function (_, r, g, b, a)
			local color = GridStatusHRTargets.db.profile.HRTargets.color2
			color.r = r
			color.g = g
			color.b = b
			color.a = a or 1
			GridStatusHRTargets:GenerateColors()
		end,
	},
	["mst_usage"] = {
		type = "range",
		name = "Mastery usage",
		desc = "0.0 = Mastery is useless\n1.0 = Full mastery usage",
		max  = 1,
		min  = 0,
		step = 0.1,
		get  = function()
		           return GridStatusHRTargets.db.profile.HRTargets.mst_usage
		       end,
		set  = function(_, v)
		           GridStatusHRTargets.db.profile.HRTargets.mst_usage = v
               end
	},
}

function GridStatusHRTargets:GenerateColors()
	wipe(colors)
	local color1 = self.db.profile.HRTargets.color
	local color2 = self.db.profile.HRTargets.color2
	if settings.numToFind > 1 then
		for i = 1, settings.numToFind do
			local p = (i - 1) / (settings.numToFind - 1)
			colors[i] = {
				r = color1.r + p * (color2.r - color1.r),
				g = color1.g + p * (color2.g - color1.g),
				b = color1.b + p * (color2.b - color1.b),
				a = color1.a + p * (color2.a - color1.a)
			}
		end
	else
		colors[1] = {
			r = color1.r,
			g = color1.g,
			b = color1.b,
			a = color1.a
		}
	end
end

function GridStatusHRTargets:OnInitialize()
	self.super.OnInitialize(self)
	self:RegisterStatus("HRTargets", "Holy Radiance Targets", HRTargets_options, true)
	settings = self.db.profile.HRTargets
	self:GenerateColors()
end

function GridStatusHRTargets:OnEnable()
	self.super.OnEnable(self)
end

function GridStatusHRTargets:OnStatusEnable()
	self:RegisterMessage("Grid_RosterUpdated")
	self:RegisterMessage("Grid_UnitOffline")
	self:CancelTimer(self.UpdateAllUnitsTimer, true)
	self.UpdateAllUnitsTimer = self:ScheduleRepeatingTimer("UpdateAllUnits", settings.frequency)
	self:Grid_RosterUpdated()
	MapDims.RegisterCallback(self, "MapChanged")
end

function GridStatusHRTargets:OnStatusDisable()
	self.core:SendStatusLostAllUnits("HRTargets")
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()
	MapDims.UnregisterAllCallbacks(self)
	self:CancelTimer(self.UpdateAllUnitsTimer, true)
end

function GridStatusHRTargets:Reset()
	self.super.Reset(self)
	self.core:SendStatusLostAllUnits("HRTargets")
	self:UnregisterStatus("HRTargets")
	self:RegisterStatus("HRTargets", "HRTargets", nil, true)
	self:UpdateAllUnits()
end

function GridStatusHRTargets:Grid_UnitOffline(event, guid)
	self.core:SendStatusLost(guid, "HRTargets")
end

function GridStatusHRTargets:MapChanged(event, map, level, w, h)
	self.data.dimX, self.data.dimY = w, h
	if not self.data.dimX or self.data.dimX == 0 then 
		SetMapToCurrentZone()
		local map   = GetMapInfo()
		local level = GetCurrentMapDungeonLevel()
		self.data.dimX, self.data.dimY = MapDims:MapArea(map, level)
	end
end

function GridStatusHRTargets:Grid_RosterUpdated()
	if (not self) or (not self.db.profile.HRTargets.enable) then return end
	self.data.raiders = GetNumGroupMembers()
	wipe(roster)
	if self.data.raiders > 0 then
		for i = 1, self.data.raiders do
			roster[i] = {}
			roster[i].unit = raid_units[i]
			roster[i].guid = UnitGUID(raid_units[i])
		end
	end
	self:CancelTimer(self.UpdateAllUnitsTimer, true)
	if self.data.raiders > 1 and UnitInRaid("player") then
		self.UpdateAllUnitsTimer = self:ScheduleRepeatingTimer("UpdateAllUnits", self.db.profile.HRTargets.frequency)
	else
		self.core:SendStatusLostAllUnits("HRTargets")
	end
end

function GridStatusHRTargets:UpdateAllUnits()
	if self.data.raiders > 1 then
		if not self:GetBestTargets() then return end
		local num = self.data.raiders > settings.numToFind and settings.numToFind or self.data.raiders
		for guid, unitid in GridRoster:IterateRoster() do
			for i = 1, num do
				if roster[i] and UnitIsUnit(roster[i].unit, unitid) then
					if roster[i].invalid == 0 then
						local amt = roster[i].potential
						self.core:SendStatusGained(guid, "HRTargets",
							settings.priority,
							40,
							colors[i],
							amt > 0 and tostring(math.floor(amt)) or nil
						)
						break
					end
				end
				if i == num then
					self.core:SendStatusLost(guid, "HRTargets")
				end
			end
		end
	else
		self.core:SendStatusLostAllUnits("HRTargets")
	end
end

function GridStatusHRTargets:GetBestTargets()
	if not IsPlayerSpell(82327) then return false end
	
	-- Update Raid Locations
	if not self.data.dimX or self.data.dimX == 0 then
		self:MapChanged()
		if not self.data.dimX or self.data.dimX == 0 then
			--print("Error: No map loaded.")
			self.core:SendStatusLostAllUnits("HRTargets")
			return false
		end
	end
	
	for i = 1, #roster do
		local unit = roster[i].unit
		local x, y
		roster[i].healthDeficit = UnitHealthMax(unit) - UnitHealth(unit)
		if UnitIsDeadOrGhost(unit) or (not UnitIsConnected(unit)) or (not UnitIsVisible(unit)) then
			roster[i].invalid = 1
			x, y = 0, 0
		else
			roster[i].invalid = 0
			x, y = GetPlayerMapPosition(unit)
			if x <= 0 and y <= 0 then
				if not WorldMapFrame:IsShown() then
					SetMapToCurrentZone()
					x, y = GetPlayerMapPosition(unit)
				end
			end
		end
		roster[i].location = roster[i].location or { x = 0, y = 0 }
		roster[i].location.x, roster[i].location.y = x * self.data.dimX, y * self.data.dimY
		roster[i].inRange = roster[i].inRange or {}
		wipe(roster[i].inRange)
	end
	
	-- Update Distances
	for i = 1, (#roster - 1) do
		if roster[i].invalid == 0 then
			local x1, y1 = roster[i].location.x, roster[i].location.y
			for j = (i + 1), #roster do
				if roster[j].invalid == 0 then
					local x2, y2 = roster[j].location.x, roster[j].location.y
					local dx = x2 - x1
					local dy = y2 - y1
					
					local distance = dx*dx + dy*dy
					
					-- 100 = 10^2 (radiance range)
					if distance <= 100 then
						table.insert(roster[i].inRange, roster[j])
						table.insert(roster[j].inRange, roster[i])
					end
				end
			end
		end
	end
	
	-- Compute potential healing
	-- 5098 to 6230 (+ 67.5% of SpellPower) + 5% SoI + 25% Passive
	local base_healing = (GetSpellBonusHealing() * 0.675 + 5664) * 1.3125
	local splash_healing = base_healing * 0.5
	local mst_usageonus = (GetMasteryEffect() / 100) * settings.mst_usage
	for i = 1, #roster do
		local t = roster[i]
		local p = 0
		-- Direct healing
		p = p + (t.healthDeficit > base_healing and base_healing or t.healthDeficit) -- Direct healing
		p = p + (mst_usageonus * base_healing) -- Direct mastery
		-- Splash healing
		local splash_targets = #t.inRange
		local splash_amount = splash_healing * (splash_targets > 5 and 5 or splash_targets)
		local splash_per_target = splash_amount / splash_targets
		for j = 1, splash_targets do
			local st = t.inRange[j]
			p = p + (st.healthDeficit > splash_per_target and splash_per_target or st.healthDeficit) -- Direct splash
			p = p + (mst_usageonus * splash_per_target) -- Splash mastery
		end
		--print(GetUnitName(t.unit) .. " potential is " .. p)
		t.potential = p
	end
	
	sort(roster, roster_sort)
	return true
end
