------------------------------------------------------------------------------
--	FILE:	 occ_core.lua
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Gameplay script - Lua Handling
-------------------------------------------------------------------------------
include "occ_StateUtils"
include "occ_UnitCommands"
include "occ_Rules"
-- ===========================================================================
--	NEW VARIABLES
-- ===========================================================================
local b_onecity = false
local ms_WallImprov :number		= GameInfo.Improvements["IMPROVEMENT_GREAT_WALL"].Index;
local ms_RallyImprov :number		= GameInfo.Improvements["IMPROVEMENT_RALLY_POINT"].Index;
local ms_ScoutWaveTurn = 5
local ms_WaveSize = 4
local ms_OnlineWaveInterval = 15
local ms_QuickWaveInterval = 25
local ms_StandardWaveInterval = 40
local ms_EpicWaveInterval = 50
local ms_MarathonWaveInterval = 66
local NO_PLAYER = -1;
local GOLD_REWARD = 600;
local CS_GOLD_REWARD = 100;

-- ===========================================================================
--	GLOBAL FLAGS
-- ===========================================================================


-- ===========================================================================
--	NEW EVENTS
-- ===========================================================================

function OnImprovementPillaged(iPlotIndex :number, eImprovement :number)
	if(iPlotIndex == NO_PLOT) then
		print("ERROR: no plot");
		return;
	end

	if(eImprovement == ms_WallImprov) then
		local improvPlot :object = Map.GetPlotByIndex(iPlotIndex);
		if(improvPlot == nil) then
			print("ERROR: improvPlot missing");
			return;
		end

		if(improvPlot:GetImprovementOwner() ~= NO_PLAYER) then
			local pOwner :object = Players[improvPlot:GetImprovementOwner()];
			if(pOwner ~= nil) then
				local pCapitalCity = pOwner:GetCities():GetCapitalCity()
				if pCapitalCity ~= nil then
					local distance = Map.GetPlotDistance(pCapitalCity:GetIndex(),improvPlot:GetIndex())
					if distance > 4 then
						improvPlot:SetOwner(NO_PLAYER)
						for i=0,5,1 do --Look at each adjacent plot
							local adjacentPlot = Map.GetAdjacentPlot(improvPlot:GetX(),improvPlot:GetY(), i);

							if (adjacentPlot ~= nil) and (adjacentPlot:IsOwned()) and (adjacentPlot:GetOwner() == improvPlot:GetImprovementOwner()) then
								local distance_adj = Map.GetPlotDistance(adjacentPlot:GetIndex(),adjacentPlot:GetIndex())
								if distance_adj > 4 then
									adjacentPlot:SetOwner(NO_PLAYER)
								end
							end
						end
					end
					ImprovementBuilder.SetImprovementType(improvPlot, -1, NO_PLAYER);
				end
			end
		end
	end
end

function OnGameTurnStarted_OneCity(turn)
	-- Cannot ever have more than one city
	local pAllPlayerIDs : table = PlayerManager.GetAliveIDs();
	for _,iPlayerID in ipairs(pAllPlayerIDs) do

		local pPlayer : object = Players[iPlayerID];
		local pPlayerCities : object = pPlayer:GetCities();
		for i, pCity in pPlayerCities:Members() do
			if pCity ~= nil then
				if pCity:GetOriginalOwner() ~= pCity:GetOwner() then
					CityManager.DestroyCity(pCity)
				end
			end
		end
	end

	-- Waves trigger
	local b_wave = false
	-- Speed = Hash / Max Turn
	-- Marathon = 137894519 / 1500
	-- Epic = 341116999 / 750
	-- Standard = 327976177 / 500
	-- Quick = -1424172973 / 330
	-- Online = -1649545904 / 250

	if GameConfiguration.GetGameSpeedType() == -1649545904 then
		if turn % ms_OnlineWaveInterval == 0 then
			b_wave = true
		end
	end

	if GameConfiguration.GetGameSpeedType() == -1424172973 then
		if turn % ms_QuickWaveInterval == 0 then
			b_wave = true
		end
	end

	if GameConfiguration.GetGameSpeedType() == 327976177 then
		if turn % ms_StandardWaveInterval == 0 then
			b_wave = true
		end
	end

	if GameConfiguration.GetGameSpeedType() == 341116999 then
		if turn % ms_EpicWaveInterval == 0 then
			b_wave = true
		end
	end

	if GameConfiguration.GetGameSpeedType() == 137894519 then
		if turn % ms_MarathonWaveInterval == 0 then
			b_wave = true
		end
	end

	if b_wave == true or turn == ms_ScoutWaveTurn then
		OnWaveTriggered(turn)
	end
end

function OnGameTurnStarted_CheckBorder(turn)
	-- Cannot ever have improvement or tile of a dead major player on the map
	local pAllEverPlayerIDs : table = PlayerManager.GetWasEverAliveMajorIDs();
	for _,iPlayerID in ipairs(pAllEverPlayerIDs) do

		local pPlayer : object = Players[iPlayerID];

		if pPlayer ~= nil then
			if pPlayer:IsAlive() == false and pPlayer:IsMajor() == true then
				for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
					local pPlot = Map.GetPlotByIndex(iPlotIndex)
					if pPlot ~= nil then

						local pPlot_Owner = pPlot:GetOwner()
						if (pPlot_Owner ~=nil ) then
							if pPlot_Owner == iPlayerID then
								pPlot:SetOwner(NO_PLAYER)
								ImprovementBuilder.SetImprovementType(pPlot, -1, NO_PLAYER);
							end
						end
					end
				end
			end
		end
	end

	-- Cannot have ghost rally point

	for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
		local pPlot = Map.GetPlotByIndex(iPlotIndex)
		if pPlot ~= nil then
			local pPlot_Owner = pPlot:GetOwner()
			if (pPlot_Owner == NO_PLAYER ) and (pPlot:GetImprovementType() == ms_RallyImprov) then
				ImprovementBuilder.SetImprovementType(pPlot, -1, NO_PLAYER);
			end
		end
	end


end

-- DESTROY SPAWNED SETTLERS
-- function OnPlayerTurnActivated_OneCity(playerID:number)
-- 	local pAllPlayerIDs : table = PlayerManager.GetAliveIDs();
-- 	for _,iPlayerID in ipairs(pAllPlayerIDs) do

-- 		local pPlayer : object = Players[iPlayerID];
-- 		if pPlayer ~= nil then
-- 		local pPlayerUnits : object = pPlayer:GetUnits();
-- 		local pPlayerCities = pPlayer:GetCities();


-- 		if pPlayerCities:GetCount() > 0 and pPlayer:IsMajor() then
-- 			for k, pUnit in pPlayerUnits:Members() do
-- 				if pUnit:GetName() == "LOC_UNIT_SETTLER_NAME" then
-- 					print("One City Challenge: Destroy Setter",iPlayerID)
-- 					pPlayerUnits:Destroy(pUnit)
-- 				end
-- 			end
-- 		end
-- 		end
-- 	end
-- end

function OnUnitInitialized(iPlayerID : number, iUnitID : number)
	if iPlayerID == -1 or iPlayerID == nil or iUnitID == nil then
		return
	end
	local pUnit : object = UnitManager.GetUnit(iPlayerID, iUnitID);
	if (pUnit == nil) then
		return;
	end
	local pPlayer : object = Players[iPlayerID];

	-- Init Charges properties for units it is relevant to
	local eUnitType = pUnit:GetTypeHash();
	for eType, pChargesData in pairs(RULES.UnitCharges) do
		if (eUnitType == eType and GetObjectState(pUnit, g_PropertyKeys.Charges) == nil) then
			SetObjectState(pUnit, g_PropertyKeys.Charges, 0);

			local iMaxCharges : number = pChargesData.Base;
			SetObjectState(pUnit, g_PropertyKeys.MaxCharges, iMaxCharges);
		end
	end
end

function OnCityConquered(capturerID,  ownerID, cityID , cityX, cityY)

	if capturerID == nil then
		return
	end

	local pPlayer = Players[capturerID]
	local capturedCityPlayer = Players[ownerID]

	-- Taking a city from major civilization
	if pPlayer ~= nil and capturedCityPlayer ~= nil and capturedCityPlayer:IsMajor() == true then
		local pGold:table = pPlayer:GetTreasury();
		print("Award Gold to",capturerID)
		pGold:ChangeGoldBalance(GOLD_REWARD);
	end
	-- Taking a city from city state
	if pPlayer ~= nil and capturedCityPlayer ~= nil and capturedCityPlayer:IsMajor() == false then
		local pGold:table = pPlayer:GetTreasury();
		print("Award Gold to",capturerID)
		pGold:ChangeGoldBalance(CS_GOLD_REWARD);
	end

end

-- ===========================================================================
--	One City Challenge
-- ===========================================================================

function AddSettlers(plot, playerUnits)
	local lastPlot = plot;
	local startPlot = plot;
	local numberOf = 0;
	local iSettler = GameInfo.Units["UNIT_SETTLER"].Index
		
	if GameConfiguration.GetValue("TCC_SettlerCount") and GameConfiguration.GetValue("TCC_SettlerCount") >= 0 then 
		numberOf = GameConfiguration.GetValue("TCC_SettlerCount")
	end
	
	if numberOf > 0 then
		local direction = 0
		for i = 2, numberOf do	
			for j = 1, 6 do
			-- for direction = lastDirection, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			-- adjacentPlot = lastPlot;
				direction = direction + 1
				if direction == DirectionTypes.NUM_DIRECTION_TYPES then
					direction = 0
				end
				adjacentPlot = Map.GetAdjacentPlot(lastPlot:GetX(), lastPlot:GetY(), direction);
				if (adjacentPlot ~= nil) and not (adjacentPlot:IsWater() or adjacentPlot:IsImpassable()) then
					break
				end
			end
			pUnit = playerUnits:Create(iSettler, adjacentPlot:GetX(), adjacentPlot:GetY())	
			lastPlot = startPlot
		end	
	end
	return lastPlot;
end

function OneCity_Init()
	local pAllPlayerIDs : table = PlayerManager.GetAliveIDs();
	for _,iPlayerID in ipairs(pAllPlayerIDs) do

		local pPlayer : object = Players[iPlayerID];
		if pPlayer ~= nil then
			local pPlayerUnits : object = pPlayer:GetUnits();
			if pPlayer:IsMajor() or pPlayer:IsHuman() then
				local settlerCount = 0;
				local targetSettlerCount = 1;
				if GameConfiguration.GetValue("TCC_SettlerCount") and GameConfiguration.GetValue("TCC_SettlerCount") >= 0 then 
					targetSettlerCount = GameConfiguration.GetValue("TCC_SettlerCount");
				end
				for i, unit in pPlayerUnits:Members() do
					local unitTypeName = UnitManager.GetTypeName(unit);
					if "LOC_UNIT_SETTLER_NAME" == unitTypeName then
						settlerCount = settlerCount + 1;
						SpawnTurn = 1;
						unitPlot = Map.GetPlot(unit:GetX(), unit:GetY());		
					end
				end

				if unitPlot ~= nil and settlerCount ~= targetSettlerCount then
					local lastPlot = unitPlot;
					lastPlot = AddSettlers(lastPlot, pPlayerUnits);
				end
			end
			local pPlayerGovernors = pPlayer:GetGovernors();
			-- Disable Settler builds
			pPlayerUnits:SetBuildDisabled(GameInfo.Units["UNIT_SETTLER"].Index, true);
			if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() and pPlayerGovernors ~= nil and pPlayerGovernors:GetGovernorPoints() ~= 1 then
				pPlayerGovernors:ChangeGovernorPoints(1)
			end
			if pPlayer:IsHuman() == false then
				pPlayerUnits:SetBuildDisabled(GameInfo.Units["UNIT_EXPANSIONIST"].Index, true);
			else
				pPlayerUnits:SetBuildDisabled(GameInfo.Units["UNIT_EXPANSIONIST"].Index, false);
			end
		end
	end

end

function OnWaveTriggered(turn)

	local pAllPlayerIDs : table = PlayerManager.GetAliveIDs();
	for _,iPlayerID in ipairs(pAllPlayerIDs) do

		local pPlayer : object = Players[iPlayerID];
		local pPlayerCities : object = pPlayer:GetCities();
		local playerUnits = pPlayer:GetUnits()
		if pPlayer:IsMajor() == true and pPlayerCities ~= nil then

			local unitType = "UNIT_SCOUT"
			local unitNumber = ms_WaveSize
			if turn == ms_ScoutWaveTurn then
				unitType = "UNIT_SCOUT"
				unitNumber = 2
				else -- Normal Wave
				unitType, unitNumber = GetWaveUnit(iPlayerID)
			end
			print("OnWaveTriggered",iPlayerID,unitType,unitNumber)
			local unitIndex = GameInfo.Units[unitType].Index

			if unitIndex == nil then
				print("Invalid Unit",unitType)
				return
			end

			-- Has a rally point ?
			local rally_plot = nil
			for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
				local pPlot = Map.GetPlotByIndex(iPlotIndex)
				if pPlot ~= nil then
					local pPlot_Owner = pPlot:GetOwner()
					if (pPlot_Owner ~=nil ) then
						if pPlot_Owner == iPlayerID then
							if pPlot:GetImprovementType() == ms_RallyImprov then
								rally_plot = pPlot
								for i = 1, unitNumber, 1 do
									playerUnits:Create(unitIndex, rally_plot:GetX(), rally_plot:GetY())
								end
								break
							end
						end
					end
				end
			end
			if rally_plot == nil then
				-- No rally point so spawn in Capital City
				local capitalCity = pPlayerCities:GetCapitalCity();
				if capitalCity ~= nil then
					for i = 1, unitNumber, 1 do
						playerUnits:Create(unitIndex, capitalCity:GetX(), capitalCity:GetY())
					end
				end
			end
		end
	end
end

function GetWaveUnit(iPlayerID)
	local unitType = "UNIT_SCOUT"
	local unitNumber = ms_WaveSize

	local pPlayer : object = Players[iPlayerID];

	if pPlayer == nil then
		print("GetWaveUnit",iPlayerID,"Invalid Player")
		return unitType, unitNumber
	end

	local era = pPlayer:GetEra()
	local leader = PlayerConfigurations[iPlayerID]:GetLeaderTypeName()


-- 40 Aluminium
-- 41 Coal
-- 42 Horse
-- 43 Iron if pPlayer:GetResources():HasResource(43) == true then
-- 44 Niter
-- 45 Oil
-- 46 Uranium
	local playerTechs	:table	= pPlayer:GetTechs();
	local playerCulture	= pPlayer:GetCulture();



	-- Information --

		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ROBOTICS"].Index) then
			unitNumber = 1
			return "UNIT_GIANT_DEATH_ROBOT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_COMPOSITES"].Index) then
			return "UNIT_MODERN_ARMOR", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_SATELLITES"].Index) then
			return "UNIT_MECHANIZED_INFANTRY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_GUIDANCE_SYSTEMS"].Index) then
			return "UNIT_ROCKET_ARTILLERY", unitNumber
		end

	-- Atomic --

		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_SYNTHETIC_MATERIALS"].Index) then
			return "UNIT_HELICOPTER", unitNumber
		end

	-- Modern --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_REPLACEABLE_PARTS"].Index) and leader == "LEADER_JOHN_CURTIN" then
			unitNumber = unitNumber + 2
			return "UNIT_DIGGER", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_COMBUSTION"].Index) then
			return "UNIT_TANK", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STEEL"].Index) then
			return "UNIT_ARTILLERY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_REPLACEABLE_PARTS"].Index) then
			return "UNIT_INFANTRY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CHEMISTRY"].Index) then
			return "UNIT_AT_CREW", unitNumber
		end


	-- Industrial --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BALLISTICS"].Index) and (leader == "LEADER_T_ROOSEVELT_ROUGHRIDER") then
			unitNumber = unitNumber + 1
			return "UNIT_AMERICAN_ROUGH_RIDER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_RIFLING"].Index) and (leader == "LEADER_ROBERT_THE_BRUCE") then
			unitNumber = unitNumber + 2
			return "UNIT_SCOTTISH_HIGHLANDER", unitNumber
		end
		if playerCulture:HasCivic(GameInfo.Civics["CIVIC_REFORMED_CHURCH"].Index) and (leader == "LEADER_JADWIGA") then
			unitNumber = unitNumber + 1
			return "UNIT_POLISH_HUSSAR", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) and (leader == "LEADER_VICTORIA") then
			unitNumber = unitNumber + 2
			return "UNIT_ENGLISH_REDCOAT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) and (leader == "LEADER_PETER_GREAT") then
			unitNumber = unitNumber + 1
			return "UNIT_RUSSIAN_COSSACK", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) and (leader == "LEADER_CATHERINE_DE_MEDICI" or leader == "LEADER_CATHERINE_DE_MEDICI_ALT" or leader == "LEADER_ELEANOR_FRANCE") then
			unitNumber = unitNumber + 2
			return "UNIT_FRENCH_GARDE_IMPERIALE", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) and (leader == "LEADER_SIMON_BOLIVAR") then
			unitNumber = unitNumber + 1
			return "UNIT_COLOMBIAN_LLANERO", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) and (leader == "LEADER_MATTHIAS_CORVINUS") then
			unitNumber = unitNumber + 1
			return "UNIT_HUNGARY_HUSZAR", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BALLISTICS"].Index) then
			return "UNIT_CUIRASSIER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) then
			return "UNIT_CAVALRY", unitNumber
		end


	-- Renaissance --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_METAL_CASTING"].Index) and leader == "LEADER_KRISTINA"  then
			unitNumber = unitNumber + 1
			return "UNIT_SWEDEN_CAROLEAN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_GUNPOWDER"].Index) and (leader == "LEADER_SEONDEOK" or leader == "LEADER_SEJONG") then
			unitNumber = unitNumber + 1
			return "UNIT_KOREAN_HWACHA", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_GUNPOWDER"].Index) and leader == "LEADER_PHILIP_II"  then
			unitNumber = unitNumber + 2
			return "UNIT_SPANISH_CONQUISTADOR", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_GUNPOWDER"].Index) and leader == "LEADER_SULEIMAN"  then
			unitNumber = unitNumber + 2
			return "UNIT_SULEIMAN_JANISSARY", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_METAL_CASTING"].Index) then
			return "UNIT_BOMBARD", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_GUNPOWDER"].Index) then
			return "UNIT_MUSKETMAN", unitNumber
		end



	-- Medieval --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MACHINERY"].Index) and leader == "LEADER_PACHACUTI" then
			unitNumber = unitNumber + 2
			return "UNIT_INCA_WARAKAQ", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MACHINERY"].Index) and leader == "LEADER_LADY_TRIEU" then
			unitNumber = unitNumber + 1
			return "UNIT_VIETNAMESE_VOI_CHIEN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MACHINERY"].Index) and (leader == "LEADER_KUBLAI_KHAN_CHINA" or leader == "LEADER_QIN" or leader == "LEADER_QIN_ALT" or leader == "LEADER_WU_ZETIAN" or leader == "LEADER_YONGLE") then
			unitNumber = unitNumber + 1
			return "UNIT_CHINESE_CROUCHING_TIGER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_ENGINEERING"].Index) and leader == "LEADER_JAYAVARMAN" then
			unitNumber = unitNumber + 1
			return "UNIT_KHMER_DOMREY", unitNumber
		end
		if playerCulture:HasCivic(GameInfo.Civics["CIVIC_DIVINE_RIGHT"].Index) and leader == "LEADER_BASIL" then
			unitNumber = unitNumber + 1
			return "UNIT_BYZANTINE_TAGMA", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STIRRUPS"].Index) and (leader == "LEADER_GENGHIS_KHAN" or leader == "LEADER_KUBLAI_KHAN_MONGOLIA") then
			unitNumber = unitNumber + 1
			return "UNIT_MONGOLIAN_KESHIG", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STIRRUPS"].Index) and (leader == "LEADER_SALADIN" or leader == "LEADER_SALADIN_ALT") then
			unitNumber = unitNumber + 1
			return "UNIT_ARABIAN_MAMLUK", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STIRRUPS"].Index) and (leader == "LEADER_MANSA_MUSA" or leader == "LEADER_SUNDIATA_KEITA") then
			unitNumber = unitNumber + 1
			return "UNIT_MALI_MANDEKALU_CAVALRY", unitNumber
		end
		if playerCulture:HasCivic(GameInfo.Civics["CIVIC_FEUDALISM"].Index) and (leader == "LEADER_HOJO" or leader == "LEADER_TOKUGAWA") then
			unitNumber = unitNumber + 2
			return "UNIT_JAPANESE_SAMURAI", unitNumber
		end
		if playerCulture:HasCivic(GameInfo.Civics["CIVIC_FEUDALISM"].Index) and (leader == "LEADER_HARDRADA" or leader == "LEADER_HARALD_ALT") then
			unitNumber = unitNumber + 2
			return "UNIT_NORWEGIAN_BERSERKER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CASTLES"].Index) and leader == "LEADER_MATTHIAS_CORVINUS" then
			unitNumber = unitNumber + 1
			return "UNIT_HUNGARY_BLACK_ARMY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CASTLES"].Index) and leader == "LEADER_MENELIK" then
			unitNumber = unitNumber + 1
			return "UNIT_ETHIOPIAN_OROMO_CAVALRY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CASTLES"].Index) and leader == "LEADER_LAUTARO" then
			unitNumber = unitNumber + 1
			return "UNIT_MAPUCHE_MALON_RAIDER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_TACTICS"].Index) and leader == "LEADER_SHAKA" then
			unitNumber = unitNumber + 2
			return "UNIT_ZULU_IMPI", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_TACTICS"].Index) and leader == "LEADER_TAMAR" then
			unitNumber = unitNumber + 2
			return "UNIT_GEORGIAN_KHEVSURETI", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STIRRUPS"].Index) then
			return "UNIT_KNIGHT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CASTLES"].Index) then
			return "UNIT_COURSER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_TACTICS"].Index) then
			return "UNIT_MAN_AT_ARMS", unitNumber
		end

	-- Classical --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and (leader == "LEADER_TRAJAN" or leader == "LEADER_JULIUS_CAESAR") then
			unitNumber = unitNumber + 2
			return "UNIT_ROMAN_LEGION", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and (leader == "LEADER_MVEMBA" or leader == "LEADER_NZINGA_MBANDE") then
			unitNumber = unitNumber + 2
			return "UNIT_KONGO_SHIELD_BEARER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_HORSEBACK_RIDING"].Index) and leader == "LEADER_ALEXANDER" then
			unitNumber = unitNumber + 1
			return "UNIT_MACEDONIAN_HETAIROI", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_HORSEBACK_RIDING"].Index) and leader == "LEADER_TOMYRIS" then
			unitNumber = unitNumber + 1
			return "UNIT_SCYTHIAN_HORSE_ARCHER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_HORSEBACK_RIDING"].Index) and (leader == "LEADER_GANDHI" or leader == "LEADER_CHANDRAGUPTA") then
			unitNumber = unitNumber + 1
			return "UNIT_INDIAN_VARU", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and leader == "LEADER_ALEXANDER" then
			unitNumber = unitNumber + 2
			return "UNIT_MACEDONIAN_HYPASPIST", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and (leader == "LEADER_CYRUS" or leader == "LEADER_NADER_SHAH") then
			unitNumber = unitNumber + 2
			return "UNIT_PERSIAN_IMMORTAL", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CONSTRUCTION"].Index) and leader == "LEADER_KUPE" then
			unitNumber = unitNumber + 2
			return "UNIT_MAORI_TOA", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_HORSEBACK_RIDING"].Index) then
			return "UNIT_HORSEMAN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) then
			return "UNIT_SWORDSMAN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ENGINEERING"].Index) then
			unitNumber = unitNumber + 1
			return "UNIT_CATAPULT", unitNumber
		end

	-- Ancient --

		-- UU --
		if leader == "LEADER_POUNDMAKER" then
			unitNumber = unitNumber + 1
			return "UNIT_CREE_OKIHTCITAW", unitNumber
		end
		if leader == "LEADER_GILGAMESH" then
			unitNumber = unitNumber + 1
			return "UNIT_SUMERIAN_WAR_CART", unitNumber
		end
		if leader == "LEADER_HAMMURABI" then
			unitNumber = unitNumber + 1
			return "UNIT_BABYLONIAN_SABUM_KIBITTUM", unitNumber
		end
		if leader == "LEADER_MONTEZUMA" then
			unitNumber = unitNumber + 2
			return "UNIT_AZTEC_EAGLE_WARRIOR", unitNumber
		end
		if leader == "LEADER_AMBIORIX" then
			unitNumber = unitNumber + 2
			return "UNIT_GAUL_GAESATAE", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_THE_WHEEL"].Index) and (leader == "LEADER_CLEOPATRA" or leader == "LEADER_CLEOPATRA_ALT" or leader == "LEADER_RAMSES") then
			unitNumber = unitNumber + 1
			return "UNIT_EGYPTIAN_CHARIOT_ARCHER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BRONZE_WORKING"].Index) and (leader == "LEADER_GORGO" or leader == "LEADER_PERICLES") then
			unitNumber = unitNumber + 2
			return "UNIT_GREEK_HOPLITE", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ARCHERY"].Index) and leader == "LEADER_LADY_SIX_SKY" then
			unitNumber = unitNumber + 1
			return "UNIT_MAYAN_HULCHE", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ARCHERY"].Index) and leader == "LEADER_AMANITORE" then
			unitNumber = unitNumber + 1
			return "UNIT_NUBIAN_PITATI", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_THE_WHEEL"].Index) then
			return "UNIT_HEAVY_CHARIOT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BRONZE_WORKING"].Index) then
			return "UNIT_SPEARMAN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ARCHERY"].Index) then
			return "UNIT_ARCHER", unitNumber
		end

		print("No pre-exiting scenario",iPlayerID)

		return "UNIT_SCOUT", unitNumber


end


-------------------------------------------------------

function Initialize()
	print("-- OCC ON --");

	if GameConfiguration.GetValue("GAMEMODE_ONECITY") == true then
		OneCity_Init()
		b_onecity = true
		GameEvents.PlayerTurnStarted.Add(OnPlayerTurnActivated_OneCity);
		GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted_OneCity);
		GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted_CheckBorder);
		GameEvents.OnImprovementPillaged.Add(OnImprovementPillaged);
		GameEvents.CityConquered.Add(OnCityConquered);
		GameEvents.UnitInitialized.Add(OnUnitInitialized);

		-- Do NEW GAME INIT (if applicable)
		local bInited : boolean = GetObjectState(Game, g_PropertyKeys.Initialized);
		if (bInited == nil or bInited == false) then
			SetObjectState(Game, g_PropertyKeys.Initialized, true);
		end
	end
end


Initialize();
