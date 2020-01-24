WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * AI-Uveso: offset platoon.lua' )
--6615

local UUtils = import('/mods/AI-Uveso/lua/AI/uvesoutilities.lua')

OldPlatoonClass = Platoon
Platoon = Class(OldPlatoonClass) {

-- For AI Patch V4 (patched). Return/exit the function on platoon disband
    EngineerBuildAI = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = self:GetPlatoonUnits()
        local armyIndex = aiBrain:GetArmyIndex()
        local x,z = aiBrain:GetArmyStartPos()
        local cons = self.PlatoonData.Construction
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile

        -- Old version of delaying the build of an experimental.
        -- This was implemended but a depricated function from sorian AI. 
        -- makes the same as the new DelayEqualBuildPlattons. Can be deleted if all platoons are rewritten to DelayEqualBuildPlattons
        -- (This is also the wrong place to do it. Should be called from Buildermanager BEFORE the builder is selected)
        if cons.T4 then
            if not aiBrain.T4Building then
                --LOG('EngineerBuildAI'..repr(cons))
                aiBrain.T4Building = true
                ForkThread(SUtils.T4Timeout, aiBrain)
                --LOG('Building T4 uinit, delaytime started')
            else
                --LOG('BLOCK building T4 unit; aiBrain.T4Building = TRUE')
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
        end

        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.ENGINEER, v) then --DUNCAN - was construction
                IssueClearCommands({v})
                if not eng then
                    eng = v
                else
                    IssueGuard({v}, eng)
                end
            end
        end

        if not eng or eng.Dead then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end

        --DUNCAN - added
        if eng:IsUnitState('Building') or eng:IsUnitState('Upgrading') or eng:IsUnitState("Enhancing") then
           return
        end

        local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
        local factionIndex = cons.FactionIndex or FactionToIndex[eng.factionCategory]

        buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
        buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
        baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]

        --LOG('*AI DEBUG: EngineerBuild AI ' .. eng.Sync.id)

        if self.PlatoonData.NeedGuard then
            eng.NeedGuard = true
        end

        -------- CHOOSE APPROPRIATE BUILD FUNCTION AND SETUP BUILD VARIABLES --------
        local reference = false
        local refName = false
        local buildFunction
        local closeToBuilder
        local relative
        local baseTmplList = {}

        -- if we have nothing to build, disband!
        if not cons.BuildStructures then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end
        if cons.NearUnitCategory then
            self:SetPrioritizedTargetList('support', {ParseEntityCategory(cons.NearUnitCategory)})
            local unitNearBy = self:FindPrioritizedUnit('support', 'Ally', false, self:GetPlatoonPosition(), cons.NearUnitRadius or 50)
            --LOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." attempt near: ", cons.NearUnitCategory)
            if unitNearBy then
                reference = table.copy(unitNearBy:GetPosition())
                -- get commander home position
                --LOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." Near unit: ", cons.NearUnitCategory)
                if cons.NearUnitCategory == 'COMMAND' and unitNearBy.CDRHome then
                    reference = unitNearBy.CDRHome
                end
            else
                reference = table.copy(eng:GetPosition())
            end
            relative = false
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
        elseif cons.Wall then
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or self:GetPlatoonPosition()
            local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100
            relative = false
            reference = AIUtils.GetLocationNeedingWalls(aiBrain, 200, 4, 'STRUCTURE - WALLS', cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            table.insert(baseTmplList, 'Blank')
            buildFunction = AIBuildStructures.WallBuilder
        elseif cons.NearBasePatrolPoints then
            relative = false
            reference = AIUtils.GetBasePatrolPoints(aiBrain, cons.Location or 'MAIN', cons.Radius or 100)
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, v))
            end
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
        elseif cons.FireBase and cons.FireBaseRange then
            --DUNCAN - pulled out and uses alt finder
            reference, refName = AIUtils.AIFindFirebaseLocation(aiBrain, cons.LocationType, cons.FireBaseRange, cons.NearMarkerType,
                                                cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType,
                                                cons.MarkerUnitCount, cons.MarkerUnitCategory, cons.MarkerRadius)
            if not reference or not refName then
                self:PlatoonDisband()
                return
            end

        elseif cons.NearMarkerType and cons.ExpansionBase then
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or self:GetPlatoonPosition()
            local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100

            if cons.NearMarkerType == 'Expansion Area' then
                reference, refName = AIUtils.AIFindExpansionAreaNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Naval Area' then
                reference, refName = AIUtils.AIFindNavalAreaNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            else
                --DUNCAN - use my alternative expansion finder on large maps below a certain time
                local mapSizeX, mapSizeZ = GetMapSize()
                if GetGameTimeSeconds() <= 780 and mapSizeX > 512 and mapSizeZ > 512 then
                    reference, refName = AIUtils.AIFindFurthestStartLocationNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                    if not reference or not refName then
                        reference, refName = AIUtils.AIFindStartLocationNeedsEngineer(aiBrain, cons.LocationType,
                            (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                    end
                else
                    reference, refName = AIUtils.AIFindStartLocationNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                end
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            end

            -- If moving far from base, tell the assisting platoons to not go with
            if cons.FireBase or cons.ExpansionBase then
                local guards = eng:GetGuards()
                for k,v in guards do
                    if not v.Dead and v.PlatoonHandle then
                        v.PlatoonHandle:PlatoonDisband()
                    end
                end
            end

            if not cons.BaseTemplate and (cons.NearMarkerType == 'Naval Area' or cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            if cons.ExpansionBase and refName then
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, eng, cons)
            end
            relative = false
            if reference and aiBrain:GetThreatAtPosition(reference , 1, true, 'AntiSurface') > 0 then
                --aiBrain:ExpansionHelp(eng, reference)
            end
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            --buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
            buildFunction = AIBuildStructures.AIBuildBaseTemplate
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIFindDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Naval Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIFindNavalDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType and (cons.NearMarkerType == 'Rally Point' or cons.NearMarkerType == 'Protected Experimental Construction') then
            --DUNCAN - add so experimentals build on maps with no markers.
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if not reference then
                reference = pos
            end
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType then
            --WARN('*Data weird for builder named - ' .. self.BuilderName)
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            if not cons.BaseTemplate and (cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if cons.ExpansionBase and refName then
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, (cons.ExpansionRadius or 100), cons.ExpansionTypes, nil, cons)
            end
            if reference and aiBrain:GetThreatAtPosition(reference, 1, true) > 0 then
                --aiBrain:ExpansionHelp(eng, reference)
            end
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.AvoidCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager:GetLocationCoords()
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local avoidCat = cons.AvoidCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(avoidCat) == 'string' then
                avoidCat = ParseEntityCategory(avoidCat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.FindUnclutteredArea(aiBrain, cat, pos, radius, cons.maxUnits, cons.maxRadius, avoidCat)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            table.insert(baseTmplList, baseTmpl)
        elseif cons.AdjacencyCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager:GetLocationCoords()
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.GetOwnUnitsAroundPoint(aiBrain, cat, pos, radius, cons.ThreatMin,
                                                        cons.ThreatMax, cons.ThreatRings)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            table.insert(baseTmplList, baseTmpl)
        else
            table.insert(baseTmplList, baseTmpl)
            relative = true
            reference = true
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        end
        if cons.BuildClose then
            closeToBuilder = eng
        end
        if cons.BuildStructures[1] == 'T1Resource' or cons.BuildStructures[1] == 'T2Resource' or cons.BuildStructures[1] == 'T3Resource' then
            relative = true
            closeToBuilder = eng
            local guards = eng:GetGuards()
            for k,v in guards do
                if not v.Dead and v.PlatoonHandle and aiBrain:PlatoonExists(v.PlatoonHandle) then
                    v.PlatoonHandle:PlatoonDisband()
                end
            end
        end

        --LOG("*AI DEBUG: Setting up Callbacks for " .. eng.Sync.id)
        self.SetupEngineerCallbacks(eng)

        -------- BUILD BUILDINGS HERE --------
        for baseNum, baseListData in baseTmplList do
            for k, v in cons.BuildStructures do
                if aiBrain:PlatoonExists(self) then
                    if not eng.Dead then
                        local faction = SUtils.GetEngineerFaction(eng)
                        if aiBrain.CustomUnits[v] and aiBrain.CustomUnits[v][faction] then
                            local replacement = SUtils.GetTemplateReplacement(aiBrain, v, faction, buildingTmpl)
                            if replacement then
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, replacement, baseListData, reference, cons.NearMarkerType)
                            else
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons.NearMarkerType)
                            end
                        else
                            buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons.NearMarkerType)
                        end
                    else
                        if aiBrain:PlatoonExists(self) then
                            WaitTicks(1)
                            self:PlatoonDisband()
                            return
                        end
                    end
                end
            end
        end

        -- wait in case we're still on a base
        if not eng.Dead then
            local count = 0
            while eng:IsUnitState('Attached') and count < 2 do
                WaitSeconds(6)
                count = count + 1
            end
        end

        if not eng:IsUnitState('Building') then
            return self.ProcessBuildCommand(eng, false)
        end
    end,


-- For AI Patch V8 (patched). remove ReclaimInProgress and CaptureInProgress flag on platoon disband
    PlatoonDisband = function(self)
        local aiBrain = self:GetBrain()
--        LOG('* AI-Uveso: PlatoonDisband = '..repr(self.PlatoonData.Construction.BuildStructures))
--        LOG('* AI-Uveso: PlatoonDisband = '..repr(self.PlatoonData.Construction))
        if self.PlatoonData.Construction.RepeatBuild then
--            LOG('* AI-Uveso: Repeat build = '..repr(self.PlatoonData.Construction.BuildStructures[1]))
            self:SetAIPlan('EngineerBuildAI')
            return
        end

--        if self.BuilderName then
--            LOG('Disband platoon '..self.BuilderName)
--            if self.BuilderName == 'BuildOnMassAIPlatoon' then
--                error('BuildOnMassAIPlatoon disbanded',2)
--            end
--        end
        if self.BuilderHandle then
            self.BuilderHandle:RemoveHandle(self)
        end
        for k,v in self:GetPlatoonUnits() do
            v.PlatoonHandle = nil
            v.AssistSet = nil
            v.AssistPlatoon = nil
            v.UnitBeingAssist = nil
            v.UnitBeingBuilt = nil
            v.ReclaimInProgress = nil
            v.CaptureInProgress = nil
            if v:IsPaused() then
                v:SetPaused( false )
            end
            if not v.Dead and v.BuilderManagerData then
                if self.CreationTime == GetGameTimeSeconds() and v.BuilderManagerData.EngineerManager then
                    if self.BuilderName then
                        --LOG('*PlatoonDisband: ERROR - Platoon disbanded same tick as created - ' .. self.BuilderName .. ' - Army: ' .. aiBrain:GetArmyIndex() .. ' - Location: ' .. repr(v.BuilderManagerData.LocationType))
                        v.BuilderManagerData.EngineerManager:AssignTimeout(v, self.BuilderName)
                    else
                        --LOG('*PlatoonDisband: ERROR - Platoon disbanded same tick as created - Army: ' .. aiBrain:GetArmyIndex() .. ' - Location: ' .. repr(v.BuilderManagerData.LocationType))
                    end
                    v.BuilderManagerData.EngineerManager:DelayAssign(v)
                elseif v.BuilderManagerData.EngineerManager then
                    v.BuilderManagerData.EngineerManager:TaskFinished(v)
                end
            end
            if not v.Dead then
                IssueStop({v})
                IssueClearCommands({v})
            end
        end
        if self.AIThread then
            self.AIThread:Destroy()
        end
        aiBrain:DisbandPlatoon(self)
    end,

-- For AI Patch V4 (patched). Exit with return after platoondisband
    EconUnfinishedBody = function(self)
        local aiBrain = self:GetBrain()
        local eng = self:GetPlatoonUnits()[1]
        if not eng then
            self:PlatoonDisband()
            return
        end
        local assistData = self.PlatoonData.Assist
        local assistee = false

        eng.AssistPlatoon = self

        if not assistData.AssistLocation then
            WARN('*AI WARNING: Disbanding EconUnfinishedBody platoon that does not AssistLocation')
            self:PlatoonDisband()
            return
        end

        local beingBuilt = assistData.BeingBuiltCategories or { 'ALLUNITS' }

        -- loop through different categories we are looking for
        for _,catString in beingBuilt do

            local category = ParseEntityCategory(catString)

            local assistList = SUtils.FindUnfinishedUnits(aiBrain, assistData.AssistLocation, category)

            if assistList then
                assistee = assistList
                break
            end
        end
        -- assist unit
        if assistee then
            self:Stop()
            eng.AssistSet = true
            eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
            --LOG('* EconUnfinishedBody: Assisting now: ['..eng.UnitBeingBuilt:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingBuilt:GetBlueprint().Description..')')
            IssueGuard({eng}, assistee)
        else
            self.AssistPlatoon = nil
            eng.UnitBeingAssist = nil
            -- stop the platoon from endless assisting
            self:PlatoonDisband()
        end
    end,

-- For AI Patch V4 (patched). exit with return on platoon disband
    RepairAI = function(self)
        local aiBrain = self:GetBrain()
        if not self.PlatoonData or not self.PlatoonData.LocationType then
            self:PlatoonDisband()
            return
        end
        local eng = self:GetPlatoonUnits()[1]
        local engineerManager = aiBrain.BuilderManagers[self.PlatoonData.LocationType].EngineerManager
        local Structures = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.STRUCTURE - (categories.TECH1 - categories.FACTORY), engineerManager:GetLocationCoords(), engineerManager:GetLocationRadius())
        for k,v in Structures do
            -- prevent repairing a unit while reclaim is in progress (see ReclaimStructuresAI)
            if not v.Dead and not v.ReclaimInProgress and v:GetHealthPercent() < .8 then
                self:Stop()
                IssueRepair(self:GetPlatoonUnits(), v)
                break
            end
        end
        local count = 0
        repeat
            WaitSeconds(2)
            if not aiBrain:PlatoonExists(self) then
                return
            end
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 30
        self:PlatoonDisband()
    end,

-- For AI Patch V4 (patched). exit with return on disband, set ReclaimInProgress flag before start reclaiming
    ReclaimStructuresAI = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local data = self.PlatoonData
        local radius = aiBrain:PBMGetLocationRadius(data.Location)
        local categories = data.Reclaim
        local counter = 0
        local reclaimcat
        local reclaimables
        local unitPos
        local reclaimunit
        local distance
        local allIdle
        while aiBrain:PlatoonExists(self) do
            unitPos = self:GetPlatoonPosition()
            reclaimunit = false
            distance = false
            for num,cat in categories do
                if type(cat) == 'string' then
                    reclaimcat = ParseEntityCategory(cat)
                else
                    reclaimcat = cat
                end
                reclaimables = aiBrain:GetListOfUnits(reclaimcat, false)
                for k,v in reclaimables do
                    if not v.Dead and (not reclaimunit or VDist3(unitPos, v:GetPosition()) < distance) and unitPos then
                        reclaimunit = v
                        distance = VDist3(unitPos, v:GetPosition())
                    end
                end
                if reclaimunit then break end
            end
            if reclaimunit and not reclaimunit.Dead then
                counter = 0
                -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                reclaimunit.ReclaimInProgress = true
                IssueReclaim(self:GetPlatoonUnits(), reclaimunit)
                repeat
                    WaitSeconds(2)
                    if not aiBrain:PlatoonExists(self) then
                        return
                    end
                    allIdle = true
                    for k,v in self:GetPlatoonUnits() do
                        if not v.Dead and not v:IsIdleState() then
                            allIdle = false
                            break
                        end
                    end
                until allIdle
            elseif not reclaimunit or counter >= 5 then
                self:PlatoonDisband()
                return
            else
                counter = counter + 1
                WaitSeconds(5)
            end
        end
    end,

-- For AI Patch V4 (patched). Set CaptureInProgress before start capturing
    CaptureAI = function(self)
        local engineers = {}
        local notEngineers = {}

        for k, unit in self:GetPlatoonUnits() do
            if EntityCategoryContains(categories.ENGINEER, unit) then
                table.insert(engineers, unit)
            else
                table.insert(notEngineers, unit)
            end
        end

        self:Stop()
        local aiBrain = self:GetBrain()
        local index = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local pos = self:GetPlatoonPosition()
        local radius = data.Radius or 100
        if not data.Categories then
            error('PLATOON.LUA ERROR- CaptureAI requires Categories field',2)
        end

        local checkThreat = false
        if data.ThreatMin and data.ThreatMax and data.ThreatRings then
            checkThreat = true
        end
        while aiBrain:PlatoonExists(self) do
            local target = AIAttackUtils.AIFindUnitRadiusThreat(aiBrain, 'Enemy', data.Categories, pos, radius, data.ThreatMin, data.ThreatMax, data.ThreatRings)
            if target and not target.Dead then
                local blip = target:GetBlip(index)
                if blip then
                    IssueClearCommands(self:GetPlatoonUnits())
                    -- Set CaptureInProgress to prevent attacking
                    target.CaptureInProgress = true
                    IssueCapture(engineers, target)
                    local guardTarget

                    for i, unit in engineers do
                        if not unit.Dead then
                            IssueGuard(notEngineers, unit)
                            break
                        end
                    end

                    local allIdle
                    repeat
                        WaitSeconds(2)
                        if not aiBrain:PlatoonExists(self) then
                            return
                        end
                        allIdle = true
                        for k,v in self:GetPlatoonUnits() do
                            if not v.Dead and not v:IsIdleState() then
                                allIdle = false
                                break
                            end
                        end
                    until allIdle or blip:BeenDestroyed() or blip:IsKnownFake(index) or blip:IsMaybeDead(index)
                    target.CaptureInProgress = nil
                end
            else
                if data.TransportReturn then
                    local retPos = ScenarioUtils.MarkerToPosition(data.TransportReturn)
                    self:MoveToLocation(retPos, false)

                    local rect = {x0 = retPos[1]-10, y0 = retPos[3]-10, x1 = retPos[1]+10, y1 = retPos[3]+10}
                    while true do
                        local alive = 0
                        local cnt = 0
                        for k,unit in self:GetPlatoonUnits() do
                            if not unit.Dead then
                                alive = alive + 1

                                if ScenarioUtils.InRect(unit:GetPosition(), rect) then
                                    cnt = cnt + 1
                                end
                            end
                        end

                        if cnt >= alive then
                            break
                        end
                        WaitTicks(5)
                    end

                    self:ForkThread(SPAI.LandAssaultWithTransports, self)
                    break
                else
                    local location = AIUtils.RandomLocation(aiBrain:GetArmyStartPos())
                    self:MoveToLocation(location, false)
                    self:PlatoonDisband()
                end
            end
            WaitSeconds(1)
        end
    end,

-- For AI Patch V5 (patched). Multi faction support
    EngineerBuildAISorian = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local cons = self.PlatoonData.Construction

        if cons.T4 and not aiBrain.T4Building then
            aiBrain.T4Building = true
            ForkThread(SUtils.T4Timeout, aiBrain)
        end

        local platoonUnits = self:GetPlatoonUnits()
        local armyIndex = aiBrain:GetArmyIndex()
        local x,z = aiBrain:GetArmyStartPos()
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile

        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.CONSTRUCTION, v) then
                if not eng then
                    eng = v
                else
                    IssueClearCommands({v})
                    IssueGuard({v}, eng)
                end
            end
        end

        if not eng or eng.Dead then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end

        local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
        local factionIndex = cons.FactionIndex or FactionToIndex[eng.factionCategory]

        if not SUtils.CheckForMapMarkers(aiBrain) and cons.NearMarkerType and (cons.NearMarkerType == 'Rally Point' or
        cons.NearMarkerType == 'Protected Experimental Construction') then
            cons.NearMarkerType = nil
            cons.BaseTemplate = nil
        end

        buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
        buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
        baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]

        if self.PlatoonData.NeedGuard then
            eng.NeedGuard = true
        end

        -------- CHOOSE APPROPRIATE BUILD FUNCTION AND SETUP BUILD VARIABLES --------
        local reference = false
        local refName = false
        local buildFunction
        local closeToBuilder
        local relative
        local baseTmplList = {}

        -- if we have nothing to build, disband!
        if not cons.BuildStructures then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end

        if cons.NearUnitCategory then
            self:SetPrioritizedTargetList('support', {ParseEntityCategory(cons.NearUnitCategory)})
            local unitNearBy = self:FindPrioritizedUnit('support', 'Ally', false, self:GetPlatoonPosition(), cons.NearUnitRadius or 50)
            --LOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." attempt near: ", cons.NearUnitCategory)
            if unitNearBy then
                reference = table.copy(unitNearBy:GetPosition())
                -- get commander home position
                --LOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." Near unit: ", cons.NearUnitCategory)
                if cons.NearUnitCategory == 'COMMAND' and unitNearBy.CDRHome then
                    reference = unitNearBy.CDRHome
                end
            else
                reference = table.copy(eng:GetPosition())
            end
            relative = false
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
        elseif cons.Wall then
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or self:GetPlatoonPosition()
            local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100
            relative = false
            reference = AIUtils.GetLocationNeedingWalls(aiBrain, 200, 5, 'DEFENSE', cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            table.insert(baseTmplList, 'Blank')
            buildFunction = AIBuildStructures.WallBuilder
        elseif cons.NearBasePatrolPoints then
            relative = false
            reference = AIUtils.GetBasePatrolPointsSorian(aiBrain, cons.Location or 'MAIN', cons.Radius or 100)
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, v))
            end
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
        elseif cons.NearMarkerType and cons.ExpansionBase then
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or self:GetPlatoonPosition()
            local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100

            if cons.FireBase and cons.FireBaseRange then
                reference, refName = AIUtils.AIFindFirebaseLocationSorian(aiBrain, cons.LocationType, cons.FireBaseRange, cons.NearMarkerType,
                                                    cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType,
                                                    cons.MarkerUnitCount, cons.MarkerUnitCategory, cons.MarkerRadius)
                if not reference or not refName then
                    self:PlatoonDisband()
                end
            elseif cons.NearMarkerType == 'Expansion Area' then
                reference, refName = AIUtils.AIFindExpansionAreaNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                end
            elseif cons.NearMarkerType == 'Naval Area' then
                reference, refName = AIUtils.AIFindNavalAreaNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                end
            else
                local mapSizeX, mapSizeZ = GetMapSize()
                if mapSizeX > 512 and mapSizeZ > 512 then
                    reference, refName = AIUtils.AIFindStartLocationNeedsEngineerSorian(aiBrain, cons.LocationType,
                            (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                else
                    reference, refName = AIUtils.AIFindStartLocationNeedsEngineer(aiBrain, cons.LocationType,
                            (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                end
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                end
            end

            -- If moving far from base, tell the assisting platoons to not go with
            if cons.FireBase or cons.ExpansionBase then
                local guards = eng:GetGuards()
                for k,v in guards do
                    if not v.Dead and v.PlatoonHandle and EntityCategoryContains(categories.CONSTRUCTION, v) then
                        v.PlatoonHandle:PlatoonDisband()
                    end
                end
            end

            if not cons.BaseTemplate and (cons.NearMarkerType == 'Naval Area' or cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            if cons.ExpansionBase and refName then
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, eng, cons)
            end
            relative = false
            if reference and aiBrain:GetThreatAtPosition(reference , 1, true, 'AntiSurface') > 0 then
                --aiBrain:ExpansionHelp(eng, reference)
            end
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            --buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
            buildFunction = AIBuildStructures.AIBuildBaseTemplate
        elseif cons.NearMarkerType and cons.FireBase and cons.FireBaseRange then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIFindFirebaseLocationSorian(aiBrain, cons.LocationType, cons.FireBaseRange, cons.NearMarkerType,
                                                cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType,
                                                cons.MarkerUnitCount, cons.MarkerUnitCategory, cons.MarkerRadius)

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIFindDefensivePointNeedsStructureSorian(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Naval Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIFindNavalDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Expansion Area' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIFindExpansionPointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType then
            --WARN('*Data weird for builder named - ' .. self.BuilderName)
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            if not cons.BaseTemplate and (cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            relative = false
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if cons.ExpansionBase and refName then
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, (cons.ExpansionRadius or 100), cons.ExpansionTypes, nil, cons)
            end
            if reference and aiBrain:GetThreatAtPosition(reference, 1, true) > 0 then
                --aiBrain:ExpansionHelp(eng, reference)
            end
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.AvoidCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager:GetLocationCoords()
            local cat = ParseEntityCategory(cons.AdjacencyCategory)
            local avoidCat = ParseEntityCategory(cons.AvoidCategory)
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.FindUnclutteredArea(aiBrain, cat, pos, radius, cons.maxUnits, cons.maxRadius, avoidCat)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            table.insert(baseTmplList, baseTmpl)
        elseif cons.AdjacencyCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager:GetLocationCoords()
            local cat = ParseEntityCategory(cons.AdjacencyCategory)
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.GetOwnUnitsAroundPointSorian(aiBrain, cat, pos, radius, cons.ThreatMin,
                                                        cons.ThreatMax, cons.ThreatRings, 'Overall', cons.MinRadius or 0)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            table.insert(baseTmplList, baseTmpl)
        else
            table.insert(baseTmplList, baseTmpl)
            relative = true
            reference = true
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        end
        if cons.BuildClose then
            closeToBuilder = eng
        end
        if cons.BuildStructures[1] == 'T1Resource' or cons.BuildStructures[1] == 'T2Resource' or cons.BuildStructures[1] == 'T3Resource' then
            relative = true
            closeToBuilder = eng
            local guards = eng:GetGuards()
            for k,v in guards do
                if not v.Dead and v.PlatoonHandle and aiBrain:PlatoonExists(v.PlatoonHandle) and EntityCategoryContains(categories.CONSTRUCTION, v) then
                    v.PlatoonHandle:PlatoonDisband()
                end
            end
        end

        --LOG("*AI DEBUG: Setting up Callbacks for " .. eng.Sync.id)
        self.SetupEngineerCallbacksSorian(eng)

        -------- BUILD BUILDINGS HERE --------
        for baseNum, baseListData in baseTmplList do
            for k, v in cons.BuildStructures do
                if aiBrain:PlatoonExists(self) then
                    if not eng.Dead then
                        local faction = SUtils.GetEngineerFaction(eng)
                        if aiBrain.CustomUnits[v] and aiBrain.CustomUnits[v][faction] then
                            local replacement = SUtils.GetTemplateReplacement(aiBrain, v, faction, buildingTmpl)
                            if replacement then
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, replacement, baseListData, reference, cons.NearMarkerType)
                            else
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons.NearMarkerType)
                            end
                        else
                            buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons.NearMarkerType)
                        end
                    else
                        if aiBrain:PlatoonExists(self) then
                            WaitTicks(1)
                            self:PlatoonDisband()
                            return
                        end
                    end
                end
            end
        end

        -- wait in case we're still on a base
        if not eng.Dead then
            local count = 0
            while eng:IsUnitState('Attached') and count < 2 do
                WaitSeconds(6)
                count = count + 1
            end
        end

        if not eng:IsUnitState('Building') then
            return self.ProcessBuildCommandSorian(eng, false)
        end
    end,

-- For AI Patch V5 (patched). fixed debug text
    UnitUpgradeAI = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = self:GetPlatoonUnits()
        local factionIndex = aiBrain:GetFactionIndex()
        local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
        local UnitBeingUpgradeFactionIndex = nil
        local upgradeIssued = false
        self:Stop()
        --LOG('* UnitUpgradeAI: PlatoonName:'..repr(self.BuilderName))
        for k, v in platoonUnits do
            --LOG('* UnitUpgradeAI: Upgrading unit '..v:GetUnitId()..' ('..v.factionCategory..')')
            local upgradeID
            -- Get the factionindex from the unit to get the right update (in case we have captured this unit from another faction)
            UnitBeingUpgradeFactionIndex = FactionToIndex[v.factionCategory] or factionIndex
            --LOG('* UnitUpgradeAI: UnitBeingUpgradeFactionIndex '..UnitBeingUpgradeFactionIndex)
            if self.PlatoonData.OverideUpgradeBlueprint then
                local tempUpgradeID = self.PlatoonData.OverideUpgradeBlueprint[UnitBeingUpgradeFactionIndex]
                if not tempUpgradeID then
                    --WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] *UnitUpgradeAI WARNING: OverideUpgradeBlueprint ' .. repr(v:GetUnitId()) .. ' failed. (Override unitID is empty' )
                elseif type(tempUpgradeID) ~= 'string' then
                    WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] *UnitUpgradeAI WARNING: OverideUpgradeBlueprint ' .. repr(v:GetUnitId()) .. ' failed. (Override unit not present.)' )
                elseif v:CanBuild(tempUpgradeID) then
                    upgradeID = tempUpgradeID
                else
                    -- in case the unit can't upgrade with OverideUpgradeBlueprint, warn the programmer
                    -- this can happen if the AI relcaimed a factory and tries to upgrade to a support factory without having a HQ factory from the reclaimed factory faction.
                    -- in this case we fall back to HQ upgrade template and upgrade to a HQ factory instead of support.
                    -- Output: WARNING: [platoon.lua, line:xxx] *UnitUpgradeAI WARNING: OverideUpgradeBlueprint UnitId:CanBuild(tempUpgradeID) failed. (Override tree not available, upgrading to default instead.)
                    WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] *UnitUpgradeAI WARNING: OverideUpgradeBlueprint ' .. repr(v:GetUnitId()) .. ':CanBuild( '..tempUpgradeID..' ) failed. (Override tree not available, upgrading to default instead.)' )
                end
            end
            if not upgradeID and EntityCategoryContains(categories.MOBILE, v) then
                upgradeID = aiBrain:FindUpgradeBP(v:GetUnitId(), UnitUpgradeTemplates[UnitBeingUpgradeFactionIndex])
                -- if we can't find a UnitUpgradeTemplate for this unit, warn the programmer
                if not upgradeID then
                    -- Output: WARNING: [platoon.lua, line:xxx] *UnitUpgradeAI ERROR: Can\'t find UnitUpgradeTemplate for mobile unit: ABC1234
                    WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] *UnitUpgradeAI ERROR: Can\'t find UnitUpgradeTemplate for mobile unit: ' .. repr(v:GetUnitId()) )
                end
            elseif not upgradeID then
                upgradeID = aiBrain:FindUpgradeBP(v:GetUnitId(), StructureUpgradeTemplates[UnitBeingUpgradeFactionIndex])
                -- if we can't find a StructureUpgradeTemplate for this unit, warn the programmer
                if not upgradeID then
                    -- Output: WARNING: [platoon.lua, line:xxx] *UnitUpgradeAI ERROR: Can\'t find StructureUpgradeTemplate for structure: ABC1234
                    WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] *UnitUpgradeAI ERROR: Can\'t find StructureUpgradeTemplate for structure: ' .. repr(v:GetUnitId()) .. '  faction: ' .. repr(v.factionCategory) )
                end
            end
            if upgradeID and EntityCategoryContains(categories.STRUCTURE, v) and not v:CanBuild(upgradeID) then
                -- in case the unit can't upgrade with upgradeID, warn the programmer
                -- Output: WARNING: [platoon.lua, line:xxx] *UnitUpgradeAI ERROR: ABC1234:CanBuild(upgradeID) failed!
                WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] *UnitUpgradeAI ERROR: ' .. repr(v:GetUnitId()) .. ':CanBuild( '..upgradeID..' ) failed!' )
                continue
            end
            if upgradeID then
                upgradeIssued = true
                IssueUpgrade({v}, upgradeID)
                --LOG('-- Upgrading unit '..v:GetUnitId()..' ('..v.factionCategory..') with '..upgradeID)
            end
        end
        if not upgradeIssued then
            self:PlatoonDisband()
            return
        end
        local upgrading = true
        while aiBrain:PlatoonExists(self) and upgrading do
            WaitSeconds(3)
            upgrading = false
            for k, v in platoonUnits do
                if v and not v.Dead then
                    upgrading = true
                end
            end
        end
        if not aiBrain:PlatoonExists(self) then
            return
        end
        WaitTicks(1)
        self:PlatoonDisband()
    end,

-- UVESO's Stuff: ------------------------------------------------------------------------------------
    BaseManagersDistressAI = function(self)
       -- Only use this with AI-Uveso
        if not self.Uveso then
            return OldPlatoonClass.BaseManagersDistressAI(self)
        end
        WaitTicks(10)
        -- We are leaving this forked thread here because we don't need it.
        KillThread(CurrentThread())
    end,

    InterceptorAIUveso = function(self)
        AIAttackUtils.GetMostRestrictiveLayer(self) -- this will set self.MovementLayer to the platoon
        local aiBrain = self:GetBrain()
        -- Search all platoon units and activate Stealth and Cloak (mostly Modded units)
        local platoonUnits = self:GetPlatoonUnits()
        local PlatoonStrength = table.getn(platoonUnits)
        if platoonUnits and PlatoonStrength > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        --LOG('* InterceptorAIUveso: Switching RULEUTC_StealthToggle')
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        --LOG('* InterceptorAIUveso: Switching RULEUTC_CloakToggle')
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        local MoveToCategories = {}
        if self.PlatoonData.MoveToCategories then
            for k,v in self.PlatoonData.MoveToCategories do
                table.insert(MoveToCategories, v )
            end
        else
            LOG('* InterceptorAIUveso: MoveToCategories missing in platoon '..self.BuilderName)
        end
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                table.insert(WeaponTargetCategories, v )
            end
        end
        self:SetPrioritizedTargetList('Attack', WeaponTargetCategories)
        local target
        local bAggroMove = self.PlatoonData.AggressiveMove
        local path
        local reason
        local maxRadius = self.PlatoonData.SearchRadius or 100
        local PlatoonPos = self:GetPlatoonPosition()
        local LastTargetPos = PlatoonPos
        local basePosition
        if self.MovementLayer == 'Water' then
            -- we could search for the nearest naval base here, but buildposition is almost at the same location
            basePosition = PlatoonPos
        else
            -- land and air units are assigned to mainbase
            basePosition = aiBrain.BuilderManagers['MAIN'].Position
        end
        local GetTargetsFromBase = self.PlatoonData.GetTargetsFromBase
        local GetTargetsFrom = basePosition
        local TargetSearchCategory = self.PlatoonData.TargetSearchCategory or 'ALLUNITS'
        local LastTargetCheck
        local DistanceToBase = 0
        while aiBrain:PlatoonExists(self) do
            PlatoonPos = self:GetPlatoonPosition()
            if not GetTargetsFromBase then
                GetTargetsFrom = PlatoonPos
            else
                DistanceToBase = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, basePosition[1] or 0, basePosition[3] or 0)
                if DistanceToBase > maxRadius then
                    target = nil
                end
            end
            -- only get a new target and make a move command if the target is dead
            if not target or target.Dead or target:BeenDestroyed() then
                UnitWithPath, UnitNoPath, path, reason = AIUtils.AIFindNearestCategoryTargetInRange(aiBrain, self, 'Attack', GetTargetsFrom, maxRadius, MoveToCategories, TargetSearchCategory, false )
                if UnitWithPath then
                    --LOG('*InterceptorAIUveso: found UnitWithPath')
                    self:Stop()
                    target = UnitWithPath
                    if self.PlatoonData.IgnorePathing then
                        self:AttackTarget(UnitWithPath)
                    elseif path then
                        self:MovePath(aiBrain, path, bAggroMove, UnitWithPath)
                    -- if we dont have a path, but UnitWithPath is true, then we have no map markers but PathCanTo() found a direct path
                    else
                        self:MoveDirect(aiBrain, bAggroMove, UnitWithPath)
                    end
                    -- We moved to the target, attack it now if its still exists
                    if aiBrain:PlatoonExists(self) and UnitWithPath and not UnitWithPath.Dead and not UnitWithPath:BeenDestroyed() then
                        self:AttackTarget(UnitWithPath)
                    end
                elseif UnitNoPath then
                    --LOG('*InterceptorAIUveso: found UnitNoPath')
                    self:Stop()
                    target = UnitNoPath
                    self:Stop()
                    if self.MovementLayer == 'Air' then
                        self:AttackTarget(UnitNoPath)
                    else
                        self:SimpleReturnToBase(basePosition)
                    end
                else
                    --LOG('*InterceptorAIUveso: no target found '..repr(reason))
                    -- we have no target return to main base
                    self:Stop()
                    if self.MovementLayer == 'Air' then
                        if VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, basePosition[1] or 0, basePosition[3] or 0) > 30 then
                            self:MoveToLocation(basePosition, false)
                        else
                            -- we are at home and we don't have a target. Disband!
                            if aiBrain:PlatoonExists(self) then
                                self:PlatoonDisband()
                                return
                            end
                        end
                    else
                        if not self.SuicideMode then
                            self.SuicideMode = true
                            self.PlatoonData.AttackEnemyStrength = 1000
                            self.PlatoonData.GetTargetsFromBase = false
                            self.PlatoonData.MoveToCategories = { categories.EXPERIMENTAL, categories.TECH3, categories.TECH2, categories.ALLUNITS }
                            self.PlatoonData.WeaponTargetCategories = { categories.EXPERIMENTAL, categories.TECH3, categories.TECH2, categories.ALLUNITS }
                            self:InterceptorAIUveso()
                        else
                            self:SimpleReturnToBase(basePosition)
                        end
                    end
                end
            -- targed exists and is not dead
            end
            WaitTicks(1)
            if aiBrain:PlatoonExists(self) and target and not target.Dead then
                LastTargetPos = target:GetPosition()
                if VDist2(basePosition[1] or 0, basePosition[3] or 0, LastTargetPos[1] or 0, LastTargetPos[3] or 0) < maxRadius then
                    self:Stop()
                    if self.PlatoonData.IgnorePathing or VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, LastTargetPos[1] or 0, LastTargetPos[3] or 0) < 60 then
                        self:AttackTarget(target)
                    else
                        self:MoveToLocation(LastTargetPos, false)
                    end
                    WaitTicks(10)
                else
                    target = nil
                end
            end
            WaitTicks(10)
        end
    end,

    LandAttackAIUveso = function(self)
        AIAttackUtils.GetMostRestrictiveLayer(self) -- this will set self.MovementLayer to the platoon
        -- Search all platoon units and activate Stealth and Cloak (mostly Modded units)
        local platoonUnits = self:GetPlatoonUnits()
        local PlatoonStrength = table.getn(platoonUnits)
        local ExperimentalInPlatoon = false
        if platoonUnits and PlatoonStrength > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if IsDestroyed(v) then
                        WARN('Unit is not Dead but DESTROYED')
                    end
                    if v:BeenDestroyed() then
                        WARN('Unit is not Dead but DESTROYED')
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    if EntityCategoryContains(categories.EXPERIMENTAL, v) then
                        ExperimentalInPlatoon = true
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        local MoveToCategories = {}
        if self.PlatoonData.MoveToCategories then
            for k,v in self.PlatoonData.MoveToCategories do
                table.insert(MoveToCategories, v )
            end
        else
            LOG('* LandAttackAIUveso: MoveToCategories missing in platoon '..self.BuilderName)
        end
        -- Set the target list to all platoon units
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                table.insert(WeaponTargetCategories, v )
            end
        end
        self:SetPrioritizedTargetList('Attack', WeaponTargetCategories)
        local aiBrain = self:GetBrain()
        local target
        local bAggroMove = self.PlatoonData.AggressiveMove
        local WantsTransport = self.PlatoonData.RequireTransport
        local maxRadius = self.PlatoonData.SearchRadius
        local TargetSearchCategory = self.PlatoonData.TargetSearchCategory or 'ALLUNITS'
        local PlatoonPos = self:GetPlatoonPosition()
        local LastTargetPos = PlatoonPos
        local DistanceToTarget = 0
        local basePosition = aiBrain.BuilderManagers['MAIN'].Position
        local losttargetnum = 0
        while aiBrain:PlatoonExists(self) do
            PlatoonPos = self:GetPlatoonPosition()
            -- only get a new target and make a move command if the target is dead or after 10 seconds
            if not target or target.Dead then
                UnitWithPath, UnitNoPath, path, reason = AIUtils.AIFindNearestCategoryTargetInRange(aiBrain, self, 'Attack', PlatoonPos, maxRadius, MoveToCategories, TargetSearchCategory, false )
                if UnitWithPath then
                    losttargetnum = 0
                    self:Stop()
                    target = UnitWithPath
                    LastTargetPos = table.copy(target:GetPosition())
                    DistanceToTarget = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, LastTargetPos[1] or 0, LastTargetPos[3] or 0)
                    if DistanceToTarget > 30 then
                        -- if we have a path then use the waypoints
                        if self.PlatoonData.IgnorePathing then
                            self:Stop()
                            self:SetPlatoonFormationOverride('AttackFormation')
                            self:AttackTarget(UnitWithPath)
                        elseif path then
                            self:MoveToLocationInclTransport(target, LastTargetPos, bAggroMove, WantsTransport, basePosition, ExperimentalInPlatoon)
                        -- if we dont have a path, but UnitWithPath is true, then we have no map markers but PathCanTo() found a direct path
                        else
                            self:MoveDirect(aiBrain, bAggroMove, target)
                        end
                        -- We moved to the target, attack it now if its still exists
                        if aiBrain:PlatoonExists(self) and UnitWithPath and not UnitWithPath.Dead and not UnitWithPath:BeenDestroyed() then
                            self:Stop()
                            self:SetPlatoonFormationOverride('AttackFormation')
                            self:AttackTarget(UnitWithPath)
                        end
                    end
                elseif UnitNoPath then
                    losttargetnum = 0
                    self:Stop()
                    target = UnitNoPath
                    self:MoveWithTransport(aiBrain, bAggroMove, target, basePosition, ExperimentalInPlatoon)
                    -- We moved to the target, attack it now if its still exists
                    if aiBrain:PlatoonExists(self) and UnitNoPath and not UnitNoPath.Dead and not UnitNoPath:BeenDestroyed() then
                        self:SetPlatoonFormationOverride('AttackFormation')
                        self:AttackTarget(UnitNoPath)
                    end
                else
                    -- we have no target return to main base
                    losttargetnum = losttargetnum + 1
                    if losttargetnum > 2 then
                        if not self.SuicideMode then
                            self.SuicideMode = true
                            self.PlatoonData.AttackEnemyStrength = 1000
                            self.PlatoonData.GetTargetsFromBase = false
                            self.PlatoonData.MoveToCategories = { categories.EXPERIMENTAL, categories.TECH3, categories.TECH2, categories.ALLUNITS }
                            self.PlatoonData.WeaponTargetCategories = { categories.EXPERIMENTAL, categories.TECH3, categories.TECH2, categories.ALLUNITS }
                            self:Stop()
                            self:SetPlatoonFormationOverride('NoFormation')
                            self:LandAttackAIUveso()
                        else
                            self:Stop()
                            self:SetPlatoonFormationOverride('NoFormation')
                            self:ForceReturnToNearestBaseAIUveso()
                        end
                    end
                end
            else
                if aiBrain:PlatoonExists(self) and target and not target.Dead and not target:BeenDestroyed() then
                    self:SetPlatoonFormationOverride('AttackFormation')
                    self:AttackTarget(target)
                    WaitSeconds(2)
                end
            end
            WaitSeconds(1)
        end
    end,

    NavalAttackAIUveso = function(self)
        AIAttackUtils.GetMostRestrictiveLayer(self) -- this will set self.MovementLayer to the platoon
        -- Search all platoon units and activate Stealth and Cloak (mostly Modded units)
        local platoonUnits = self:GetPlatoonUnits()
        local PlatoonStrength = table.getn(platoonUnits)
        local ExperimentalInPlatoon = false
        if platoonUnits and PlatoonStrength > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_JammingToggle') then
                        v:SetScriptBit('RULEUTC_JammingToggle', false)
                    end
                    if EntityCategoryContains(categories.EXPERIMENTAL, v) then
                        ExperimentalInPlatoon = true
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        local MoveToCategories = {}
        if self.PlatoonData.MoveToCategories then
            for k,v in self.PlatoonData.MoveToCategories do
                table.insert(MoveToCategories, v )
            end
        else
            LOG('* NavalAttackAIUveso: MoveToCategories missing in platoon '..self.BuilderName)
        end
        -- Set the target list to all platoon units
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                table.insert(WeaponTargetCategories, v )
            end
        end
        self:SetPrioritizedTargetList('Attack', WeaponTargetCategories)
        local aiBrain = self:GetBrain()
        local target
        local bAggroMove = self.PlatoonData.AggressiveMove
        local maxRadius = self.PlatoonData.SearchRadius or 250
        local TargetSearchCategory = self.PlatoonData.TargetSearchCategory or 'ALLUNITS'
        local PlatoonPos = self:GetPlatoonPosition()
        local LastTargetPos = PlatoonPos
        local DistanceToTarget = 0
        local basePosition = PlatoonPos   -- Platoons will be created near a base, so we can return to this position if we don't have targets.
        local losttargetnum = 0
        while aiBrain:PlatoonExists(self) do
            PlatoonPos = self:GetPlatoonPosition()
            -- only get a new target and make a move command if the target is dead or after 10 seconds
            if not target or target.Dead then
                UnitWithPath, UnitNoPath, path, reason = AIUtils.AIFindNearestCategoryTargetInRange(aiBrain, self, 'Attack', PlatoonPos, maxRadius, MoveToCategories, TargetSearchCategory, false )
                if UnitWithPath then
                    losttargetnum = 0
                    self:Stop()
                    target = UnitWithPath
                    LastTargetPos = table.copy(target:GetPosition())
                    DistanceToTarget = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, LastTargetPos[1] or 0, LastTargetPos[3] or 0)
                    if DistanceToTarget > 30 then
                        -- if we have a path then use the waypoints
                        if self.PlatoonData.IgnorePathing then
                            self:Stop()
                            self:AttackTarget(UnitWithPath)
                        elseif path then
                            self:MovePath(aiBrain, path, bAggroMove, target)
                        -- if we dont have a path, but UnitWithPath is true, then we have no map markers but PathCanTo() found a direct path
                        else
                            self:MoveDirect(aiBrain, bAggroMove, target)
                        end
                        -- We moved to the target, attack it now if its still exists
                        if aiBrain:PlatoonExists(self) and UnitWithPath and not UnitWithPath.Dead and not UnitWithPath:BeenDestroyed() then
                            self:Stop()
                            self:AttackTarget(UnitWithPath)
                        end
                    end
                else
                    -- we have no target return to main base
                    losttargetnum = losttargetnum + 1
                    if losttargetnum > 2 then
                        if not self.SuicideMode then
                            self.SuicideMode = true
                            self.PlatoonData.AttackEnemyStrength = 1000
                            self.PlatoonData.GetTargetsFromBase = false
                            self.PlatoonData.MoveToCategories = { categories.EXPERIMENTAL, categories.TECH3, categories.TECH2, categories.ALLUNITS }
                            self.PlatoonData.WeaponTargetCategories = { categories.EXPERIMENTAL, categories.TECH3, categories.TECH2, categories.ALLUNITS }
                            self:Stop()
                            self:SetPlatoonFormationOverride('NoFormation')
                            self:NavalAttackAIUveso()
                        else
                            self:Stop()
                            self:SetPlatoonFormationOverride('NoFormation')
                            self:ForceReturnToNavalBaseAIUveso(aiBrain, basePosition)
                        end
                    end
                end
            else
                if aiBrain:PlatoonExists(self) and target and not target.Dead and not target:BeenDestroyed() then
                    self:AttackTarget(target)
                    WaitSeconds(2)
                end
            end
            WaitSeconds(1)
        end
    end,
    
    ACUAttackAIUveso = function(self)
        --LOG('* ACUAttackAIUveso: START '..self.BuilderName)
        AIAttackUtils.GetMostRestrictiveLayer(self) -- this will set self.MovementLayer to the platoon
        local aiBrain = self:GetBrain()
        local PlatoonUnits = self:GetPlatoonUnits()
        local cdr = PlatoonUnits[1]
        -- There should be only the commander inside this platoon. Check it.
        if not cdr then
            WARN('* ACUAttackAIUveso: Platoon formed but Commander unit not found!')
            WaitTicks(1)
            for k,v in self:GetPlatoonUnits() or {} do
                if EntityCategoryContains(categories.COMMAND, v) then
                    WARN('* ACUAttackAIUveso: Commander found in platoon on index: '..k)
                    cdr = v
                else
                    WARN('* ACUAttackAIUveso: Platoon unit Index '..k..' is not a commander!')
                end
            end
            if not cdr then
                self:PlatoonDisband()
                return
            end
        end
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        cdr.HealthOLD = 100
        cdr.CDRHome = aiBrain.BuilderManagers['MAIN'].Position
        local MoveToCategories = {}
        if self.PlatoonData.MoveToCategories then
            for k,v in self.PlatoonData.MoveToCategories do
                table.insert(MoveToCategories, v )
            end
        else
            LOG('* ACUAttackAIUveso: MoveToCategories missing in platoon '..self.BuilderName)
        end
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                table.insert(WeaponTargetCategories, v )
            end
        end
        self:SetPrioritizedTargetList('Attack', WeaponTargetCategories)
        -- prevent ACU from reclaiming while attack moving
        cdr:RemoveCommandCap('RULEUCC_Reclaim')
        cdr:RemoveCommandCap('RULEUCC_Repair')
        local TargetUnit, DistanceToTarget
        local PlatoonPos = self:GetPlatoonPosition()
        -- land and air units are assigned to mainbase
        local GetTargetsFromBase = self.PlatoonData.GetTargetsFromBase
        local GetTargetsFrom = cdr.CDRHome
        local TargetSearchCategory = self.PlatoonData.TargetSearchCategory or 'ALLUNITS'
        local LastTargetCheck
        local DistanceToBase = 0
        local UnitsInACUBaseRange
        local ReturnToBaseAfterGameTime = self.PlatoonData.ReturnToBaseAfterGameTime or false
        local DoNotLeavePlatoonUnderHealth = self.PlatoonData.DoNotLeavePlatoonUnderHealth or 30
        local maxRadius
        local maxTimeRadius
        local SearchRadius = self.PlatoonData.SearchRadius or 250
        while aiBrain:PlatoonExists(self) do
            if cdr.Dead then break end
            cdr.position = self:GetPlatoonPosition()
            -- leave the loop and disband this platton in time
            if ReturnToBaseAfterGameTime and ReturnToBaseAfterGameTime < GetGameTimeSeconds()/60 then
                --LOG('* ACUAttackAIUveso: ReturnToBaseAfterGameTime:'..ReturnToBaseAfterGameTime..' >= '..GetGameTimeSeconds()/60)
                UUtils.CDRParkingHome(self,cdr)
                break
            end
            -- the maximum radis that the ACU can be away from base
            maxRadius = (UUtils.ComHealth(cdr)-65)*7 -- If the comanders health is 100% then we have a maxtange of ~250 = (100-65)*7
            maxTimeRadius = 240 - GetGameTimeSeconds()/60*6 -- reduce the radius by 6 map units per minute. After 30 minutes it's (240-180) = 60
            if maxRadius > maxTimeRadius then 
                maxRadius = math.max( 60, maxTimeRadius ) -- IF maxTimeRadius < 60 THEN maxTimeRadius = 60
            end
            if maxRadius > SearchRadius then
                maxRadius = SearchRadius
            end
            UnitsInACUBaseRange = aiBrain:GetUnitsAroundPoint( TargetSearchCategory, cdr.CDRHome, maxRadius, 'Enemy')
            -- get the position of this platoon (ACU)
            if not GetTargetsFromBase then
                -- we don't get out targets relativ to base position. Use the ACU position
                GetTargetsFrom = cdr.position
            end
            ----------------------------------------------
            --- This is the start of the main ACU loop ---
            ----------------------------------------------
            if aiBrain:GetEconomyStoredRatio('ENERGY') > 0.95 and UUtils.ComHealth(cdr) < 100 then
                cdr:SetAutoOvercharge(true)
            else
                cdr:SetAutoOvercharge(false)
            end
           
            -- in case we have no Factory left, recover!
            if not aiBrain:GetListOfUnits(categories.STRUCTURE * categories.FACTORY * categories.LAND - categories.SUPPORTFACTORY, false)[1] then
                --LOG('* ACUAttackAIUveso: exiting attack function. RECOVER')
                self:PlatoonDisband()
                return
            -- check if we are further away from base then the closest enemy
            elseif UUtils.CDRRunHomeEnemyNearBase(self,cdr,UnitsInACUBaseRange) then
                --LOG('* ACUAttackAIUveso: CDRRunHomeEnemyNearBase')
                TargetUnit = false
            -- check if we get actual damage, then move home
            elseif UUtils.CDRRunHomeAtDamage(self,cdr) then
                --LOG('* ACUAttackAIUveso: CDRRunHomeAtDamage')
                TargetUnit = false
            -- check how much % health we have and go closer to our base
            elseif UUtils.CDRRunHomeHealthRange(self,cdr,maxRadius) then
                --LOG('* ACUAttackAIUveso: CDRRunHomeHealthRange')
                TargetUnit = false
            -- can we upgrade ?
            elseif table.getn(UnitsInACUBaseRange) <= 0 and VDist2(cdr.position[1], cdr.position[3], cdr.CDRHome[1], cdr.CDRHome[3]) < 60 and self:BuildACUEnhancememnts(cdr) then
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts')
                -- Do nothing if BuildACUEnhancememnts is true. we are upgrading!
            -- only get a new target and make a move command if the target is dead
            else
               --LOG('* ACUAttackAIUveso: ATTACK')
                -- ToDo: scann for enemy COM and change target if needed
                TargetUnit, _, _, _ = AIUtils.AIFindNearestCategoryTargetInRangeCDR(aiBrain, GetTargetsFrom, maxRadius, MoveToCategories, TargetSearchCategory, false)
                -- if we have a target, move to the target and attack
                if TargetUnit then
                    --LOG('* ACUAttackAIUveso: ATTACK TargetUnit')
                    if aiBrain:PlatoonExists(self) and TargetUnit and not TargetUnit.Dead and not TargetUnit:BeenDestroyed() then
                        local targetPos = TargetUnit:GetPosition()
                        local cdrNewPos = {}
                        cdr:GetNavigator():AbortMove()
                        cdrNewPos[1] = targetPos[1] + Random(-3, 3)
                        cdrNewPos[2] = targetPos[2]
                        cdrNewPos[3] = targetPos[3] + Random(-3, 3)
                        self:MoveToLocation(cdrNewPos, false)
                        WaitTicks(1)
                        if TargetUnit and not TargetUnit.Dead and not TargetUnit:BeenDestroyed() then
                            self:AttackTarget(TargetUnit)
                        end
                    end
                -- if we have no target, move to base. If we are at base, dance. (random moves)
                elseif UUtils.CDRForceRunHome(self,cdr) then
                    --LOG('* ACUAttackAIUveso: CDRForceRunHome true. we are running home')
                -- we are at home, dance if we have nothing to do.
                else
                    -- There is nothing to fight; so we left the attack function and see if we can build something
                    --LOG('* ACUAttackAIUveso:We are at home and dancing')
                    --LOG('* ACUAttackAIUveso: exiting attack function')
                    self:PlatoonDisband()
                    return
                end
            end
            --DrawCircle(cdr.CDRHome, maxRadius, '00FFFF')
            WaitTicks(10)
            --------------------------------------------
            --- This is the end of the main ACU loop ---
            --------------------------------------------
        end
        --LOG('* ACUAttackAIUveso: END '..self.BuilderName)
        self:PlatoonDisband()
    end,
    
    BuildACUEnhancememnts = function(platoon,cdr)
        local EnhancementsByUnitID = {
            -- UEF
            ['uel0001'] = {'HeavyAntiMatterCannon', 'DamageStabilization', 'Shield', 'ShieldGeneratorField'},
            -- Aeon
            ['ual0001'] = {'HeatSink', 'CrysalisBeam', 'Shield', 'ShieldHeavy'},
            -- Cybran
            ['url0001'] = {'CoolingUpgrade', 'StealthGenerator', 'MicrowaveLaserGenerator', 'CloakingGenerator'},
            -- Seraphim
            ['xsl0001'] = {'RateOfFire', 'DamageStabilization', 'BlastAttack', 'DamageStabilizationAdvanced'},
            -- Nomads
            ['xnl0001'] = {'Capacitor', 'GunUpgrade', 'MovementSpeedIncrease', 'DoubleGuns'},

            -- UEF - Black Ops ACU
            ['eel0001'] = {'GatlingEnergyCannon', 'CombatEngineering', 'ShieldBattery', 'AutomaticBarrelStabalizers', 'AssaultEngineering', 'ImprovedShieldBattery', 'EnhancedPowerSubsystems', 'ApocalypticEngineering', 'AdvancedShieldBattery'},
            -- Aeon
            ['eal0001'] = {'PhasonBeamCannon', 'CombatEngineering', 'ShieldBattery', 'DualChannelBooster', 'AssaultEngineering', 'ImprovedShieldBattery', 'EnergizedMolecularInducer', 'ApocalypticEngineering', 'AdvancedShieldBattery'},
            -- Cybram
            ['erl0001'] = {'EMPArray', 'CombatEngineering', 'ArmorPlating', 'AdjustedCrystalMatrix', 'AssaultEngineering', 'StructuralIntegrityFields', 'EnhancedLaserEmitters', 'ApocalypticEngineering', 'CompositeMaterials'},
            -- Seraphim
            ['esl0001'] = {'PlasmaGatlingCannon', 'CombatEngineering', 'ElectronicsEnhancment', 'PhasedEnergyFields', 'AssaultEngineering', 'PersonalTeleporter', 'SecondaryPowerFeeds', 'ApocalypticEngineering', 'CloakingSubsystems'},
        }
        local CRDBlueprint = cdr:GetBlueprint()
        --LOG('BlueprintId '..repr(CRDBlueprint.BlueprintId))
        local ACUUpgradeList = EnhancementsByUnitID[CRDBlueprint.BlueprintId]
        --LOG('ACUUpgradeList '..repr(ACUUpgradeList))
        local NextEnhancement = false
        local HaveEcoForEnhancement = false
        for _,enhancement in ACUUpgradeList or {} do
            local wantedEnhancementBP = CRDBlueprint.Enhancements[enhancement]
            --LOG('wantedEnhancementBP '..repr(wantedEnhancementBP))
            if cdr:HasEnhancement(enhancement) then
                NextEnhancement = false
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts: Enhancement is already installed: '..enhancement)
            elseif platoon:EcoGoodForUpgrade(cdr, wantedEnhancementBP) then
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts: Eco is good for '..enhancement)
                if not NextEnhancement then
                    NextEnhancement = enhancement
                    HaveEcoForEnhancement = true
                    --LOG('* ACUAttackAIUveso: *** Set as Enhancememnt: '..NextEnhancement)
                end
            else
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts: Eco is bad for '..enhancement)
                if not NextEnhancement then
                    NextEnhancement = enhancement
                    HaveEcoForEnhancement = false
                    -- if we don't have the eco for this ugrade, stop the search
                    --LOG('* ACUAttackAIUveso: canceled search. no eco available')
                    break
                end
            end
        end
        if NextEnhancement and HaveEcoForEnhancement then
            --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts Building '..NextEnhancement)
            if platoon:BuildEnhancememnt(cdr, NextEnhancement) then
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts returned true'..NextEnhancement)
                return true
            else
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts returned false'..NextEnhancement)
                return false
            end
        end
        return false
    end,
    
    EcoGoodForUpgrade = function(platoon,cdr,enhancement)
        local aiBrain = platoon:GetBrain()
        local BuildRate = cdr:GetBuildRate()
        --LOG('cdr:GetBuildRate() '..BuildRate..'')
        local drainMass = (BuildRate / enhancement.BuildTime) * enhancement.BuildCostMass
        local drainEnergy = (BuildRate / enhancement.BuildTime) * enhancement.BuildCostEnergy
        --LOG('drain: m'..drainMass..'  e'..drainEnergy..'')
        --LOG('Pump: m'..math.floor(aiBrain:GetEconomyTrend('MASS')*10)..'  e'..math.floor(aiBrain:GetEconomyTrend('ENERGY')*10)..'')
        if aiBrain.HasParagon then
            return true
        elseif aiBrain:GetEconomyTrend('MASS')*10 >= drainMass and aiBrain:GetEconomyTrend('ENERGY')*10 >= drainEnergy
        and aiBrain:GetEconomyStoredRatio('MASS') > 0.05 and aiBrain:GetEconomyStoredRatio('ENERGY') > 0.95 then

            local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
            if personality == 'uvesorush' or personality == 'uvesorushcheat' then
                if aiBrain:GetEconomyStoredRatio('MASS') < 0.90 then
                    return false
                end
            end
            return true
        end
        return false
    end,
    
    BuildEnhancememnt = function(platoon,cdr,enhancement)
        --LOG('* ACUAttackAIUveso: BuildEnhancememnt '..enhancement)
        local aiBrain = platoon:GetBrain()

        IssueStop({cdr})
        IssueClearCommands({cdr})
        
        if not cdr:HasEnhancement(enhancement) then
            local order = { TaskName = "EnhanceTask", Enhancement = enhancement }
            --LOG('* ACUAttackAIUveso: BuildEnhancememnt: '..platoon:GetBrain().Nickname..' IssueScript: '..enhancement)
            IssueScript({cdr}, order)
        end
        while not cdr.Dead and not cdr:HasEnhancement(enhancement) do
            if UUtils.ComHealth(cdr) < 60 then
                --LOG('* ACUAttackAIUveso: BuildEnhancememnt: '..platoon:GetBrain().Nickname..' Emergency!!! low health, canceling Enhancement '..enhancement)
                IssueStop({cdr})
                IssueClearCommands({cdr})
                return false
            end
            WaitTicks(10)
        end
        --LOG('* ACUAttackAIUveso: BuildEnhancememnt: '..platoon:GetBrain().Nickname..' Upgrade finished '..enhancement)
        return true
    end,

    MoveWithTransport = function(self, aiBrain, bAggroMove, target, basePosition, ExperimentalInPlatoon)
        local TargetPosition = table.copy(target:GetPosition())
        local usedTransports = false
        self:SetPlatoonFormationOverride('NoFormation')
        --LOG('* MoveWithTransport: CanPathTo() failed for '..repr(TargetPosition)..' forcing SendPlatoonWithTransportsNoCheck.')
        if not ExperimentalInPlatoon and aiBrain:PlatoonExists(self) then
            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, TargetPosition, true, false)
        end
        if not usedTransports then
            --LOG('* MoveWithTransport: SendPlatoonWithTransportsNoCheck failed.')
            local PlatoonPos = self:GetPlatoonPosition() or TargetPosition
            local DistanceToTarget = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, TargetPosition[1] or 0, TargetPosition[3] or 0)
            local DistanceToBase = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, basePosition[1] or 0, basePosition[3] or 0)
            if DistanceToBase < DistanceToTarget or DistanceToTarget > 50 then
                --LOG('* MoveWithTransport: base is nearer then distance to target or distance to target over 50. Return To base')
                self:SimpleReturnToBase(basePosition)
            else
                --LOG('* MoveWithTransport: Direct move to Target')
                if bAggroMove then
                    self:AggressiveMoveToLocation(TargetPosition)
                else
                    self:MoveToLocation(TargetPosition, false)
                end
            end
        else
            --LOG('* MoveWithTransport: We got a transport!!')
        end
    end,

    MoveDirect = function(self, aiBrain, bAggroMove, target)
        local platoonUnits = self:GetPlatoonUnits()
        self:SetPlatoonFormationOverride('NoFormation')
        local TargetPosition = table.copy(target:GetPosition())
        local PlatoonPosition
        local Lastdist
        local dist
        local Stuck = 0
        local ATTACKFORMATION = false
        if bAggroMove then
            self:AggressiveMoveToLocation(TargetPosition)
        else
            self:MoveToLocation(TargetPosition, false)
        end
        while aiBrain:PlatoonExists(self) do
            PlatoonPosition = self:GetPlatoonPosition() or TargetPosition
            dist = VDist2( TargetPosition[1], TargetPosition[3], PlatoonPosition[1], PlatoonPosition[3] )
            local platoonUnitscheck = self:GetPlatoonUnits()
            if table.getn(platoonUnits) > table.getn(platoonUnitscheck) then
                --LOG('* MoveDirect: unit in platoon destroyed!!!')
                self:SetPlatoonFormationOverride('AttackFormation')
            end
            --LOG('* MoveDirect: dist to next Waypoint: '..dist)
            --LOG('* MoveDirect: dist to target: '..dist)
            if not ATTACKFORMATION and dist < 80 then
                ATTACKFORMATION = true
                --LOG('* MoveDirect: dist < 50 '..dist)
                self:SetPlatoonFormationOverride('AttackFormation')
            end
            if dist < 20 then
                return
            end
            -- Do we move ?
            if Lastdist ~= dist then
                Stuck = 0
                Lastdist = dist
            -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
            else
                Stuck = Stuck + 1
                if Stuck > 20 then
                    --LOG('* MoveDirect: Stucked while moving to target. Stuck='..Stuck)
                    self:Stop()
                    return
                end
            end
            -- If we lose our target, stop moving to it.
            if not target or target.Dead then
                --LOG('* MoveDirect: Lost target while moving to target. ')
                return
            end
            WaitTicks(10)
        end
    end,

    MovePath = function(self, aiBrain, path, bAggroMove, target)
        local platoonUnits = self:GetPlatoonUnits()
        self:SetPlatoonFormationOverride('NoFormation')
        local AirCUT = 0
        if self.MovementLayer == 'Air' then
            AirCUT = 3
        end
        local PathNodesCount = table.getn(path)
        local ATTACKFORMATION = false
        for i=1, PathNodesCount - AirCUT do
            local PlatoonPosition
            local Lastdist
            local dist
            local Stuck = 0
            --LOG('* MovePath: moving to destination. i: '..i..' coords '..repr(path[i]))
            if bAggroMove then
                self:AggressiveMoveToLocation(path[i])
            else
                self:MoveToLocation(path[i], false)
            end
            while aiBrain:PlatoonExists(self) do
                PlatoonPosition = self:GetPlatoonPosition() or path[i]
                dist = VDist2( path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3] )
                local platoonUnitscheck = self:GetPlatoonUnits()
                if table.getn(platoonUnits) > table.getn(platoonUnitscheck) then
                    --LOG('* MovePath: unit in platoon destroyed!!!')
                    self:SetPlatoonFormationOverride('AttackFormation')
                end
                --LOG('* MovePath: dist to next Waypoint: '..dist)
                distEnd = VDist2( path[PathNodesCount][1], path[PathNodesCount][3], PlatoonPosition[1], PlatoonPosition[3] )
                --LOG('* MovePath: dist to Path End: '..distEnd)
                if not ATTACKFORMATION and distEnd < 80 then
                    ATTACKFORMATION = true
                    --LOG('* MovePath: distEnd < 50 '..distEnd)
                    self:SetPlatoonFormationOverride('AttackFormation')
                end
                -- are we closer then 20 units from the next marker ? Then break and move to the next marker
                if dist < 20 then
                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                    self:Stop()
                    break
                end
                -- Do we move ?
                if Lastdist ~= dist then
                    Stuck = 0
                    Lastdist = dist
                -- No, we are not moving, wait 20 ticks then break and use the next weaypoint
                else
                    Stuck = Stuck + 1
                    if Stuck > 20 then
                        --LOG('* MovePath: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                        self:Stop()
                        break -- break the while aiBrain:PlatoonExists(self) do loop and move to the next waypoint
                    end
                end
                -- If we lose our target, stop moving to it.
                if not target or target.Dead then
                    --LOG('* MovePath: Lost target while moving to Waypoint. '..repr(path[i]))
                    return
                end
                WaitTicks(10)
            end
        end
    end,

    MoveToLocationInclTransport = function(self, target, TargetPosition, bAggroMove, WantsTransport, basePosition, ExperimentalInPlatoon)
        local platoonUnits = self:GetPlatoonUnits()
        self:SetPlatoonFormationOverride('NoFormation')
        if not TargetPosition then
            TargetPosition = table.copy(target:GetPosition())
        end
        local aiBrain = self:GetBrain()
        local PlatoonPosition = self:GetPlatoonPosition()
        -- this will be true if we got our units transported to the destination
        local usedTransports = false
        local TransportNotNeeded, bestGoalPos
        -- check, if we can reach the destination without a transport
        local unit = AIAttackUtils.GetMostRestrictiveLayer(self) -- this will set self.MovementLayer to the platoon
        local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer or 'Land' , PlatoonPosition, TargetPosition, 1000, 512)
        if not aiBrain:PlatoonExists(self) then
            return
        end
        -- don't use a transporter if we have a path and the target is closer then 100 map units
        if path and VDist2( PlatoonPosition[1], PlatoonPosition[3], TargetPosition[1], TargetPosition[3] ) < 100 then
            --LOG('* MoveToLocationInclTransport: no trasnporter used for target distance '..VDist2( PlatoonPosition[1], PlatoonPosition[3], TargetPosition[1], TargetPosition[3] ) )
        -- use a transporter if we don't have a path, or if we want a transport
        elseif not ExperimentalInPlatoon and ((not path and reason ~= 'NoGraph') or WantsTransport)  then
            --LOG('* MoveToLocationInclTransport: SendPlatoonWithTransportsNoCheck')
            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, TargetPosition, true, false)
        end
        -- if we don't got a transport, try to reach the destination by path or directly
        if not usedTransports then
            -- clear commands, so we don't get stuck if we have an unreachable destination
            IssueClearCommands(self:GetPlatoonUnits())
            if path then
                --LOG('* MoveToLocationInclTransport: No transport used, and we dont need it.')
                if table.getn(path) > 1 then
                    --LOG('* MoveToLocationInclTransport: table.getn(path): '..table.getn(path))
                end
                local PathNodesCount = table.getn(path)
                local ATTACKFORMATION = false
                for i=1, PathNodesCount do
                    --LOG('* MoveToLocationInclTransport: moving to destination. i: '..i..' coords '..repr(path[i]))
                    if bAggroMove then
                        self:AggressiveMoveToLocation(path[i])
                    else
                        self:MoveToLocation(path[i], false)
                    end
                    local PlatoonPosition
                    local Lastdist
                    local dist
                    local Stuck = 0
                    while aiBrain:PlatoonExists(self) do
                        PlatoonPosition = self:GetPlatoonPosition() or nil
                        if not PlatoonPosition then break end
                        dist = VDist2( path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3] )
                        local platoonUnitscheck = self:GetPlatoonUnits()
                        if table.getn(platoonUnits) > table.getn(platoonUnitscheck) then
                            --LOG('* MoveToLocationInclTransport: unit in platoon destroyed!!!')
                            self:SetPlatoonFormationOverride('AttackFormation')
                        end
                        --LOG('* MoveToLocationInclTransport: dist to next Waypoint: '..dist)
                        distEnd = VDist2( path[PathNodesCount][1], path[PathNodesCount][3], PlatoonPosition[1], PlatoonPosition[3] )
                        --LOG('* MoveToLocationInclTransport: dist to Path End: '..distEnd)
                        if not ATTACKFORMATION and distEnd < 80 then
                            ATTACKFORMATION = true
                            --LOG('* MoveToLocationInclTransport: distEnd < 50 '..distEnd)
                            self:SetPlatoonFormationOverride('AttackFormation')
                        end
                        -- are we closer then 20 units from the next marker ? Then break and move to the next marker
                        if dist < 20 then
                            -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                            self:Stop()
                            break
                        end
                        -- Do we move ?
                        if Lastdist ~= dist then
                            Stuck = 0
                            Lastdist = dist
                        -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                        else
                            Stuck = Stuck + 1
                            if Stuck > 20 then
                                --LOG('* MoveToLocationInclTransport: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                self:Stop()
                                break -- break the while aiBrain:PlatoonExists(self) do loop and move to the next waypoint
                            end
                        end
                        -- If we lose our target, stop moving to it.
                        if not target then
                            --LOG('* MoveToLocationInclTransport: Lost target while moving to Waypoint. '..repr(path[i]))
                            self:Stop()
                            return
                        end
                        WaitTicks(10)
                    end
                end
            else
                --LOG('* MoveToLocationInclTransport: No transport used, and we have no Graph to reach the destination. Checking CanPathTo()')
                if reason == 'NoGraph' then
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, TargetPosition)
                    if success then
                        --LOG('* MoveToLocationInclTransport: No transport used, found a way with CanPathTo(). moving to destination')
                        if bAggroMove then
                            self:AggressiveMoveToLocation(bestGoalPos)
                        else
                            self:MoveToLocation(bestGoalPos, false)
                        end
                        local PlatoonPosition
                        local Lastdist
                        local dist
                        local Stuck = 0
                        while aiBrain:PlatoonExists(self) do
                            PlatoonPosition = self:GetPlatoonPosition() or nil
                            if not PlatoonPosition then continue end
                            dist = VDist2( bestGoalPos[1], bestGoalPos[3], PlatoonPosition[1], PlatoonPosition[3] )
                            if dist < 20 then
                                break
                            end
                            -- Do we move ?
                            if Lastdist ~= dist then
                                Stuck = 0
                                Lastdist = dist
                            -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                            else
                                Stuck = Stuck + 1
                                if Stuck > 20 then
                                    --LOG('* MoveToLocationInclTransport: Stucked while moving to target. Stuck='..Stuck)
                                    self:Stop()
                                    break -- break the while aiBrain:PlatoonExists(self) do loop and move to the next waypoint
                                end
                            end
                            -- If we lose our target, stop moving to it.
                            if not target then
                                --LOG('* MoveToLocationInclTransport: Lost target while moving to target. ')
                                self:Stop()
                                return
                            end
                            WaitTicks(10)
                        end
                    else
                        --LOG('* MoveToLocationInclTransport: CanPathTo() failed for '..repr(TargetPosition)..' forcing SendPlatoonWithTransportsNoCheck.')
                        if not ExperimentalInPlatoon then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, TargetPosition, true, false)
                        end
                        if not usedTransports then
                            --LOG('* MoveToLocationInclTransport: CanPathTo() and SendPlatoonWithTransportsNoCheck failed. SimpleReturnToBase!')
                            local PlatoonPos = self:GetPlatoonPosition()
                            local DistanceToTarget = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, TargetPosition[1] or 0, TargetPosition[3] or 0)
                            local DistanceToBase = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, basePosition[1] or 0, basePosition[3] or 0)
                            if DistanceToBase < DistanceToTarget and DistanceToTarget > 50 then
                                --LOG('* MoveToLocationInclTransport: base is nearer then distance to target and distance to target over 50. Return To base')
                                self:SimpleReturnToBase(basePosition)
                            else
                                --LOG('* MoveToLocationInclTransport: Direct move to Target')
                                if bAggroMove then
                                    self:AggressiveMoveToLocation(TargetPosition)
                                else
                                    self:MoveToLocation(TargetPosition, false)
                                end
                            end
                        else
                            --LOG('* MoveToLocationInclTransport: CanPathTo() failed BUT we got an transport!!')
                        end

                    end
                else
                    --LOG('* MoveToLocationInclTransport: We have no path but there is a Graph with markers. So why we don\'t get a path ??? (Island or threat too high?) - reason: '..repr(reason))
                end
            end
        else
            --LOG('* MoveToLocationInclTransport: TRANSPORTED.')
        end
    end,

    TransferAIUveso = function(self)
        local aiBrain = self:GetBrain()
        if not aiBrain.BuilderManagers[self.PlatoonData.MoveToLocationType] then
            --LOG('* TransferAIUveso: Location ('..self.PlatoonData.MoveToLocationType..') has no BuilderManager!')
            self:PlatoonDisband()
            return
        end
        local eng = self:GetPlatoonUnits()[1]
        if eng and not eng.Dead and eng.BuilderManagerData.EngineerManager then
            --LOG('* TransferAIUveso: '..repr(self.BuilderName))
            eng.BuilderManagerData.EngineerManager:RemoveUnit(eng)
            --LOG('* TransferAIUveso: AddUnit units to - BuilderManagers: '..self.PlatoonData.MoveToLocationType..' - ' .. aiBrain.BuilderManagers[self.PlatoonData.MoveToLocationType].EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) )
            aiBrain.BuilderManagers[self.PlatoonData.MoveToLocationType].EngineerManager:AddUnit(eng, true)
            -- Move the unit to the desired base after transfering BuilderManagers to the new LocationType
            local basePosition = aiBrain.BuilderManagers[self.PlatoonData.MoveToLocationType].Position
            --LOG('* TransferAIUveso: Moving transfer-units to - ' .. self.PlatoonData.MoveToLocationType)
            self:MoveToLocationInclTransport(true, basePosition, false, false, basePosition, false)
        end
        if aiBrain:PlatoonExists(self) then
            self:PlatoonDisband()
        end
    end,

    ReclaimAIUveso = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = self:GetPlatoonUnits()
        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.MOBILE * categories.ENGINEER, v) then
                eng = v
                break
            end
        end
        if eng then
            eng.UnitBeingBuilt = eng
            UUtils.ReclaimAIThread(self,eng,aiBrain)
            eng.UnitBeingBuilt = nil
        end
        self:PlatoonDisband()
    end,

    FinisherAI = function(self)
        local aiBrain = self:GetBrain()
        -- Only use this with AI-Uveso
        if not self.PlatoonData or not self.PlatoonData.LocationType then
            self:PlatoonDisband()
            return
        end
        local eng = self:GetPlatoonUnits()[1]
        local engineerManager = aiBrain.BuilderManagers[self.PlatoonData.LocationType].EngineerManager
        if not engineerManager then
            self:PlatoonDisband()
            return
        end
        local unfinishedUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE + categories.EXPERIMENTAL, engineerManager:GetLocationCoords(), engineerManager.Radius, 'Ally')
        for k,v in unfinishedUnits do
            local FractionComplete = v:GetFractionComplete()
            if FractionComplete < 1 and table.getn(v:GetGuards()) < 1 then
                self:Stop()
                IssueRepair(self:GetPlatoonUnits(), v)
                break
            end
        end
        local count = 0
        repeat
            WaitSeconds(2)
            if not aiBrain:PlatoonExists(self) then
                return
            end
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 30
        self:PlatoonDisband()
    end,

    TMLAIUveso = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = self:GetPlatoonUnits()
        local TML
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM * categories.TECH2, v) then
                TML = v
                break
            end
        end
        UUtils.TMLAIThread(self,TML,aiBrain)
        self:PlatoonDisband()
    end,

    PlatoonMerger = function(self)
        --LOG('* PlatoonMerger: called from Builder: '..(self.BuilderName or 'Unknown'))
        local aiBrain = self:GetBrain()
        local PlatoonPlan = self.PlatoonData.AIPlan
        --LOG('* PlatoonMerger: AIPlan: '..(PlatoonPlan or 'Unknown'))
        if not PlatoonPlan then
            return
        end
        -- Get all units from the platoon
        local platoonUnits = self:GetPlatoonUnits()
        -- check if we have already a Platoon with this AIPlan
        local AlreadyMergedPlatoon
        local PlatoonList = aiBrain:GetPlatoonsList()
        for _,Platoon in PlatoonList do
            if Platoon:GetPlan() == PlatoonPlan then
                --LOG('* PlatoonMerger: Found Platton with plan '..PlatoonPlan)
                AlreadyMergedPlatoon = Platoon
                break
            end
            --LOG('* PlatoonMerger: Found '..repr(Platoon:GetPlan()))
        end
        -- If we dont have already a platton for this AIPlan, create one.
        if not AlreadyMergedPlatoon then
            AlreadyMergedPlatoon = aiBrain:MakePlatoon( PlatoonPlan..'Platoon', PlatoonPlan )
            AlreadyMergedPlatoon.PlanName = PlatoonPlan
            AlreadyMergedPlatoon.BuilderName = PlatoonPlan..'Platoon'
--            AlreadyMergedPlatoon:UniquelyNamePlatoon(PlatoonPlan)
        end
        -- Add our unit(s) to the platoon
        aiBrain:AssignUnitsToPlatoon( AlreadyMergedPlatoon, platoonUnits, 'support', 'none' )
        -- Disband this platoon, it's no longer needed.
        self:PlatoonDisbandNoAssign()
    end,

    ExtractorUpgradeAI = function(self)
        --LOG('+++ ExtractorUpgradeAI: START')
        local aiBrain = self:GetBrain()
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        while aiBrain:PlatoonExists(self) do
            local ratio = 0.3
            if aiBrain.HasParagon then
                -- if we have a paragon, upgrade mex as fast as possible. Mabye we lose the paragon and need mex again.
                ratio = 1.0
            elseif aiBrain:GetEconomyIncome('MASS') * 10 > 600 then
                --LOG('Mass over 200. Eco running with 30%')
                ratio = 0.25
            elseif GetGameTimeSeconds() > 1800 then -- 30 * 60
                ratio = 0.25
            elseif GetGameTimeSeconds() > 1200 then -- 20 * 60
                ratio = 0.20
            elseif GetGameTimeSeconds() > 900 then -- 15 * 60
                ratio = 0.15
            elseif GetGameTimeSeconds() > 600 then -- 10 * 60
                ratio = 0.15
            elseif GetGameTimeSeconds() > 360 then -- 6 * 60
                ratio = 0.10
            elseif GetGameTimeSeconds() <= 360 then -- 6 * 60 run the first 6 minutes with 0% Eco and 100% Army
                ratio = 0.00
            end
            local platoonUnits = self:GetPlatoonUnits()
            local MassExtractorUnitList = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * (categories.TECH1 + categories.TECH2 + categories.TECH3), false, false)
            -- Check if we can pause/unpause TECH3 Extractors (for more energy)
            if not UUtils.ExtractorPause( self, aiBrain, MassExtractorUnitList, ratio, 'TECH3') then
                -- Check if we can pause/unpause TECH2 Extractors
                if not UUtils.ExtractorPause( self, aiBrain, MassExtractorUnitList, ratio, 'TECH2') then
                    -- Check if we can pause/unpause TECH1 Extractors
                    if not UUtils.ExtractorPause( self, aiBrain, MassExtractorUnitList, ratio, 'TECH1') then
                        -- We have nothing to pause or unpause, lets upgrade more extractors
                        -- if we have 10% TECH1 extractors left (and 90% TECH2), then upgrade TECH2 to TECH3
                        if UUtils.HaveUnitRatio( aiBrain, 0.90, categories.MASSEXTRACTION * categories.TECH1, '<=', categories.MASSEXTRACTION * categories.TECH2 ) then
                            -- Try to upgrade a TECH2 extractor.
                            if not UUtils.ExtractorUpgrade(self, aiBrain, MassExtractorUnitList, ratio, 'TECH2', UnitUpgradeTemplates, StructureUpgradeTemplates) then
                                -- We can't upgrade a TECH2 extractor. Try to upgrade from TECH1 to TECH2
                                UUtils.ExtractorUpgrade(self, aiBrain, MassExtractorUnitList, ratio, 'TECH1', UnitUpgradeTemplates, StructureUpgradeTemplates)
                            end
                        else
                            -- We have less than 90% TECH2 extractors compared to TECH1. Upgrade more TECH1
                            UUtils.ExtractorUpgrade(self, aiBrain, MassExtractorUnitList, ratio, 'TECH1', UnitUpgradeTemplates, StructureUpgradeTemplates)
                        end
                    end
                end
            end
            -- Check the Eco every x Ticks
            WaitTicks(10)
            -- find dead units inside the platoon and disband if we find one
            for k,v in self:GetPlatoonUnits() do
                if not v or v.Dead or v:BeenDestroyed() then
                    -- We found a dead unit inside this platoon. Disband the platton; It will be reformed
                    --LOG('+++ ExtractorUpgradeAI: Found Dead unit, self:PlatoonDisbandNoAssign()')
                    -- needs PlatoonDisbandNoAssign, or extractors will stop upgrading if the platton is disbanded
                    self:PlatoonDisbandNoAssign()
                    return
                end
            end
        end
        -- No return here. We will never reach this position. After disbanding this platoon, the forked 'ExtractorUpgradeAI' thread will be terminated from outside.
    end,

    SimpleReturnToBase = function(self, basePosition)
        local aiBrain = self:GetBrain()
        local PlatoonPosition
        local Lastdist
        local dist
        local Stuck = 0
        self:Stop()
        self:MoveToLocation(basePosition, false)
        while aiBrain:PlatoonExists(self) do
            PlatoonPosition = self:GetPlatoonPosition()
            if not PlatoonPosition then
                --LOG('* SimpleReturnToBase: no Platoon Position')
                break
            end
            dist = VDist2( basePosition[1], basePosition[3], PlatoonPosition[1], PlatoonPosition[3] )
            if dist < 20 then
                break
            end
            -- Do we move ?
            if Lastdist ~= dist then
                Stuck = 0
                Lastdist = dist
            -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
            else
                Stuck = Stuck + 1
                if Stuck > 20 then
                    self:Stop()
                    break
                end
            end
            WaitTicks(10)
        end
        self:PlatoonDisband()
    end,

    ForceReturnToNearestBaseAIUveso = function(self)
        local platPos = self:GetPlatoonPosition() or false
        if not platPos then
            return
        end
        local aiBrain = self:GetBrain()
        local nearestbase = false
        for k,v in aiBrain.BuilderManagers do
            -- check if we can move to this base
            if not AIUtils.ValidateLayer(v.FactoryManager.Location,self.MovementLayer) then
                --LOG('ForceReturnToNearestBaseAIUveso Can\'t return to This base. Wrong movementlayer: '..repr(v.FactoryManager.LocationType))
                continue
            end
            local dist = VDist2( platPos[1], platPos[3], v.FactoryManager.Location[1], v.FactoryManager.Location[3] )
            if not nearestbase or nearestbase.dist > dist then
                nearestbase = {}
                nearestbase.Pos = v.FactoryManager.Location
                nearestbase.dist = dist
            end
        end
        if not nearestbase then
            return
        end
        self:Stop()
        self:MoveToLocationInclTransport(true, nearestbase.Pos, false, false, nearestbase.Pos, false)
        -- Disband the platoon so the locationmanager can assign a new task to the units.
        WaitTicks(30)
        self:PlatoonDisband()
    end,

    ForceReturnToNavalBaseAIUveso = function(self, aiBrain, basePosition)
        local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer or 'Water' , self:GetPlatoonPosition(), basePosition, 1000, 512)
        -- clear commands, so we don't get stuck if we have an unreachable destination
        IssueClearCommands(self:GetPlatoonUnits())
        if path then
            if table.getn(path) > 1 then
                --LOG('* ForceReturnToNavalBaseAIUveso: table.getn(path): '..table.getn(path))
            end
            --LOG('* ForceReturnToNavalBaseAIUveso: moving to destination by path.')
            for i=1, table.getn(path) do
                --LOG('* ForceReturnToNavalBaseAIUveso: moving to destination. i: '..i..' coords '..repr(path[i]))
                self:MoveToLocation(path[i], false)
                --LOG('* ForceReturnToNavalBaseAIUveso: moving to Waypoint')
                local PlatoonPosition
                local Lastdist
                local dist
                local Stuck = 0
                while aiBrain:PlatoonExists(self) do
                    PlatoonPosition = self:GetPlatoonPosition()
                    dist = VDist2( path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3] )
                    -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                    if dist < 20 then
                        -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                        self:Stop()
                        break
                    end
                    -- Do we move ?
                    if Lastdist ~= dist then
                        Stuck = 0
                        Lastdist = dist
                    -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                    else
                        Stuck = Stuck + 1
                        if Stuck > 15 then
                            --LOG('* ForceReturnToNavalBaseAIUveso: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                            self:Stop()
                            break
                        end
                    end
                    WaitTicks(10)
                end
            end
        else
            --LOG('* ForceReturnToNavalBaseAIUveso: we have no Graph to reach the destination. Checking CanPathTo()')
            if reason == 'NoGraph' then
                local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, basePosition)
                if success then
                    --LOG('* ForceReturnToNavalBaseAIUveso: found a way with CanPathTo(). moving to destination')
                    self:MoveToLocation(basePosition, false)
                else
                    --LOG('* ForceReturnToNavalBaseAIUveso: CanPathTo() failed for '..repr(basePosition)..'.')
                end
            end
        end
        local oldDist = 100000
        local platPos = self:GetPlatoonPosition() or basePosition
        local Stuck = 0
        while aiBrain:PlatoonExists(self) do
            self:MoveToLocation(basePosition, false)
            --LOG('* ForceReturnToNavalBaseAIUveso: Waiting for moving to base')
            platPos = self:GetPlatoonPosition() or basePosition
            dist = VDist2(platPos[1], platPos[3], basePosition[1], basePosition[3])
            if dist < 20 then
                --LOG('* ForceReturnToNavalBaseAIUveso: We are home! disband!')
                -- Wait some second, so all platoon units have time to reach the base.
                WaitSeconds(5)
                self:Stop()
                break
            end
            -- if we haven't moved in 5 seconds... leave the loop
            if oldDist - dist < 0 then
                break
            end
            oldDist = dist
            Stuck = Stuck + 1
            if Stuck > 4 then
                self:Stop()
                break
            end
            WaitSeconds(5)
        end
        -- Disband the platoon so the locationmanager can assign a new task to the units.
        WaitTicks(30)
        self:PlatoonDisband()
    end,

    U3AntiNukeAI = function(self)
        local aiBrain = self:GetBrain()
        while aiBrain:PlatoonExists(self) do
            local platoonUnits = self:GetPlatoonUnits()
            -- find dead units inside the platoon and disband if we find one
            for k,unit in platoonUnits do
                if not unit or unit.Dead or unit:BeenDestroyed() then
                    -- We found a dead unit inside this platoon. Disband the platton; It will be reformed
                    -- needs PlatoonDisbandNoAssign, or launcher will stop building nukes if the platton is disbanded
                    self:PlatoonDisbandNoAssign()
                    --LOG('* U3AntiNukeAI: PlatoonDisband')
                    return
                else
                    unit:SetAutoMode(true)
                end
            end
            WaitTicks(50)
        end
    end,

    U34ArtilleryAI = function(self)
        local aiBrain = self:GetBrain()
        local ClosestTarget = nil
        local LastTarget = nil
        while aiBrain:PlatoonExists(self) do
            -- Primary Target
            ClosestTarget = nil
            -- We always use the PrimaryTarget from the targetmanager first:
            if aiBrain.PrimaryTarget and not aiBrain.PrimaryTarget.Dead then
                ClosestTarget = aiBrain.PrimaryTarget
            else
                -- We have no PrimaryTarget from the tagetmanager.
                -- That means there is no paragon, no experimental and no Tech3 Factories left as target.
                -- No need to search for any of this here.
            end
            -- in case we found a target, attack it until it's dead or we have another Primary Target
            if ClosestTarget == LastTarget then
                --LOG('* U34ArtilleryAI: ClosestTarget == LastTarget')
            elseif ClosestTarget and not ClosestTarget.Dead then
                local BlueprintID = ClosestTarget:GetBlueprint().BlueprintId
                LastTarget = ClosestTarget
                -- Wait until the target is dead
                while ClosestTarget and not ClosestTarget.Dead do
                    -- leave the loop if the primary target has changed
                    if aiBrain.PrimaryTarget and aiBrain.PrimaryTarget ~= ClosestTarget then
                        break
                    end
                    platoonUnits = self:GetPlatoonUnits()
                    for _, Arty in platoonUnits do
                        if not Arty or Arty.Dead then
                            return
                        end
                        local Target = Arty:GetTargetEntity()
                        if Target == ClosestTarget then
                            --Arty:SetCustomName('continue '..BlueprintID)
                        else
                            --Arty:SetCustomName('Attacking '..BlueprintID)
                            --IssueStop({v})
                            IssueClearCommands({Arty})
                            WaitTicks(1)
                            if ClosestTarget and not ClosestTarget.Dead then
                                IssueAttack({Arty}, ClosestTarget)
                            end
                        end
                    end
                    WaitSeconds(5)
                end
            end
            -- Reaching this point means we have no special target and our arty is using it's own weapon target priorities.
            -- So we are still attacking targets at this point.
            WaitSeconds(5)
        end
    end,

    ShieldRepairAI = function(self)
        local aiBrain = self:GetBrain()
        local BuilderManager = aiBrain.BuilderManagers['MAIN']
        local lastSHIELD = 0
        local lastSUB = 0
        local numSUB
        local SUBCOMs
        local platoonUnits

        while aiBrain:PlatoonExists(self) do
            platoonUnits = self:GetPlatoonUnits()
            numSUB = table.getn(platoonUnits) or 0
            local Shields = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.SHIELD, BuilderManager.Position, 256)
            local lasthighestHealth
            local highestHealth
            local numSHIELD = 0
            -- get the shield with the highest health
            for k,Shield in Shields do
                if not Shield or Shield.Dead then continue end
                if not highestHealth or Shield.MyShield:GetMaxHealth() > highestHealth then
                    highestHealth = Shield.MyShield:GetMaxHealth()
                end
                numSHIELD = numSHIELD + 1
            end
            for k,Shield in Shields do
                if not Shield or Shield.Dead then continue end
                if (not lasthighestHealth or Shield.MyShield:GetMaxHealth() > lasthighestHealth) and Shield.MyShield:GetMaxHealth() < highestHealth then
                    lasthighestHealth = Shield.MyShield:GetMaxHealth()
                end
            end
            if numSUB ~= lastSUB or numSHIELD ~= lastSHIELD then
                self:Stop()
                -- Wait for stopping assist
                WaitTicks(1)
                lastSUB = numSUB
                lastSHIELD = numSHIELD
                for i,unit in self:GetPlatoonUnits() do
--                    IssueClearCommands({unit})
                    unit.AssistSet = nil
                    unit.UnitBeingAssist = nil
                end
                while true do
                    local numAssisters
                    local ShieldWithleastAssisters
                    -- get a shield with highest Health and lowest assistees
                    numAssisters = nil
                    -- Fist check all shields with the highest health
                    for k,Shield in Shields do
                        if not Shield or Shield.Dead or Shield.MyShield:GetMaxHealth() ~= highestHealth then continue end
                        if not numAssisters or table.getn(Shield:GetGuards()) < numAssisters  then
                            numAssisters = table.getn(Shield:GetGuards())
                            -- set a maximum of 10 assisters per shield
                            if numAssisters < 10 then
                                ShieldWithleastAssisters = Shield
                            end
                        end
                    end
                    -- If we have assister on all high shilds then spread the remaining SUBCOMs over lower shields
                    if not ShieldWithleastAssisters and lasthighestHealth and lasthighestHealth ~= highestHealth then
                        for k,Shield in Shields do
                            if not Shield or Shield.Dead or Shield.MyShield:GetMaxHealth() ~= lasthighestHealth then continue end
                            if not numAssisters or table.getn(Shield:GetGuards()) < numAssisters  then
                                numAssisters = table.getn(Shield:GetGuards())
                                ShieldWithleastAssisters = Shield
                            end
                        end
                    end
                    
                    if not ShieldWithleastAssisters then
                        --LOG('*ShieldRepairAI: not ShieldWithleastAssisters. break!')
                        break
                    end
                    local shieldPos = ShieldWithleastAssisters:GetPosition() or nil
                    -- search for the closest idle unit
                    local closest
                    local bestUnit
                    for i,unit in self:GetPlatoonUnits() do
                        if not unit or unit.Dead or unit:BeenDestroyed() then
                            self:PlatoonDisbandNoAssign()
                            return
                        end
                        if unit.AssistSet then continue end
                        local unitPos = unit:GetPosition() or nil
                        if unitPos and shieldPos then
                            local dist = VDist2(shieldPos[1], shieldPos[3], unitPos[1], unitPos[3])
                            if not closest or dist < closest then
                                closest = dist
                                bestUnit = unit
                            end
                        end
                    end
                    if not bestUnit then
                        --LOG('*ShieldRepairAI: not bestUnit. break!')
                        break
                    end
                    IssueClearCommands({bestUnit})
                    WaitTicks(1)
                    IssueGuard({bestUnit}, ShieldWithleastAssisters)
                    bestUnit.AssistSet = true
                    bestUnit.UnitBeingAssist = ShieldWithleastAssisters
                    WaitTicks(1)
                end

            end
            WaitTicks(30)
        end
    end,

    NukePlatoonAI = function(self)
        local NUKEDEBUG = false
        local aiBrain = self:GetBrain()
        local ECOLoopCounter = 0
        local mapSizeX, mapSizeZ = GetMapSize()
        local platoonUnits
        local LauncherFull
        local LauncherReady
        local ExperimentalLauncherReady
        local LauncherCount
        local EnemyAntiMissile
        local EnemyUnits
        local EnemyTargetPositions
        local MissileCount
        local EnemyTarget
        local NukeSiloAmmoCount
        local TargetPosition

        while aiBrain:PlatoonExists(self) do
            ---------------------------------------------------------------------------------------------------
            -- Count Launchers, set them to automode, count stored missiles
            ---------------------------------------------------------------------------------------------------
            platoonUnits = self:GetPlatoonUnits()
            LauncherFull = {}
            LauncherReady = {}
            ExperimentalLauncherReady = {}
            HighMissileCountLauncherReady = {}
            MissileCount = 0
            LauncherCount = 0
            HighestMissileCount = 0
            NukeSiloAmmoCount = 0
            WaitTicks(100)
            for _, Launcher in platoonUnits do
                -- We found a dead unit inside this platoon. Disband the platton; It will be reformed
                -- needs PlatoonDisbandNoAssign, or launcher will stop building nukes if the platton is disbanded
                if not Launcher or Launcher.Dead or Launcher:BeenDestroyed() then
                    self:PlatoonDisbandNoAssign()
                    return
                end
                Launcher:SetAutoMode(true)
                IssueClearCommands({Launcher})
                NukeSiloAmmoCount = Launcher:GetNukeSiloAmmoCount() or 0
                if not HighMissileCountLauncherReady.MissileCount or HighMissileCountLauncherReady.MissileCount < NukeSiloAmmoCount then
                    HighMissileCountLauncherReady = Launcher
                    HighMissileCountLauncherReady.MissileCount = NukeSiloAmmoCount
                end
                -- check if the launcher is full:
                local bp = Launcher:GetBlueprint()
                local weapon = bp.Weapon[1]
                local MaxLoad = weapon.MaxProjectileStorage or 5
                if NUKEDEBUG then
                    LOG('* NukePlatoonAI: launcher can load '..MaxLoad..' missiles ')
                end

                if NukeSiloAmmoCount >= MaxLoad then
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: launcher can load '..MaxLoad..' missiles and has '..NukeSiloAmmoCount..' = FULL ')
                    end
                    table.insert(LauncherFull, Launcher)
                end
                if NukeSiloAmmoCount > 0 and EntityCategoryContains(categories.NUKE * categories.EXPERIMENTAL, Launcher) then
                    table.insert(ExperimentalLauncherReady, Launcher)
                    MissileCount = MissileCount + NukeSiloAmmoCount
                elseif NukeSiloAmmoCount > 0 then
                    table.insert(LauncherReady, Launcher)
                    MissileCount = MissileCount + NukeSiloAmmoCount
                end
                LauncherCount = LauncherCount + 1
                -- count experimental launcher seraphim
            end
            EnemyAntiMissile = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * ((categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3) + (categories.SHIELD * categories.EXPERIMENTAL)), Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
            if NUKEDEBUG then
                LOG('************************************************************************************************')
                LOG('* NukePlatoonAI: Checking for Targets. Launcher:('..LauncherCount..') Ready:('..table.getn(LauncherReady)..') Full:('..table.getn(LauncherFull)..') - Missiles:('..MissileCount..') - EnemyAntiMissile:('..table.getn(EnemyAntiMissile)..')')
            end
            -- Don't check all nuke functions if we have no missile.
            if LauncherCount < 1 or ( table.getn(LauncherReady) < 1 and table.getn(LauncherFull) < 1 ) then
                continue
            end
            ---------------------------------------------------------------------------------------------------
            -- PrimaryTarget, launch a single nuke on primary targets.
            ---------------------------------------------------------------------------------------------------
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Unprotected) Experimental PrimaryTarget ')
            end
            if 1 == 1 and aiBrain.PrimaryTarget and table.getn(LauncherReady) > 0 and EntityCategoryContains(categories.EXPERIMENTAL, aiBrain.PrimaryTarget) then
                -- Only shoot if the target is not protected by antimissile or experimental shields
                if not self:IsTargetNukeProtected(aiBrain.PrimaryTarget, EnemyAntiMissile) then
                    -- Lead target function
                    TargetPos = self:LeadNukeTarget(aiBrain.PrimaryTarget)
                    if not TargetPos then
                        -- Our Target is dead. break
                        break
                    end
                    -- Only shoot if we are not damaging our own structures
                    if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE, TargetPos, 50 , 'Ally') <= 0 then
                        if not self:NukeSingleAttack(HighMissileCountLauncherReady, TargetPos) then
                            if self:NukeSingleAttack(LauncherReady, TargetPos) then
                                if NUKEDEBUG then
                                    LOG('* NukePlatoonAI: (Unprotected) Experimental PrimaryTarget FIRE LauncherReady!')
                                end
                                WaitTicks(450)-- wait 45 seconds for the missile flight, then get new targets
                                continue
                            end
                        else
                            if NUKEDEBUG then
                                    LOG('* NukePlatoonAI: (Unprotected) Experimental PrimaryTarget FIRE HighMissileCountLauncherReady!')
                            end
                            WaitTicks(450)-- wait 45 seconds for the missile flight, then get new targets
                            continue
                        end
                    end
                end
            end
            ---------------------------------------------------------------------------------------------------
            -- first try to target all targets that are not protected from enemy anti missile
            ---------------------------------------------------------------------------------------------------
            EnemyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE - categories.MASSEXTRACTION - categories.TECH1 - categories.TECH2 , Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
            EnemyTargetPositions = {}
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Unprotected) EnemyUnits. Checking enemy units: '..table.getn(EnemyUnits))
            end
            for _, EnemyTarget in EnemyUnits do
                -- get position of the possible next target
                local EnemyTargetPos = EnemyTarget:GetPosition() or nil
                if not EnemyTargetPos then continue end
                local ToClose = false
                -- loop over all already attacked targets
                for _, ETargetPosition in EnemyTargetPositions do
                    -- Check if the target is closeer then 40 to an already attacked target
                    if VDist2(EnemyTargetPos[1],EnemyTargetPos[3],ETargetPosition[1],ETargetPosition[3]) < 40 then
                        ToClose = true
                        break -- break out of the EnemyTargetPositions loop
                    end
                end
                if ToClose then
                    continue -- Skip this enemytarget and check the next
                end
                -- Check if the target is not protected by an antinuke
                if not self:IsTargetNukeProtected(EnemyTarget, EnemyAntiMissile) then
                    table.insert(EnemyTargetPositions, EnemyTargetPos)
                end
            end
            ---------------------------------------------------------------------------------------------------
            -- Now, if we have unprotected targets, shot at it
            ---------------------------------------------------------------------------------------------------
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Unprotected) EnemyUnits: Unprotected enemy units: '..table.getn(EnemyTargetPositions))
            end
            if 1 == 1 and table.getn(EnemyTargetPositions) > 0 and table.getn(LauncherReady) > 0 then
                -- loopß over all targets
                self:NukeJerichoAttack(LauncherReady, EnemyTargetPositions)
                WaitTicks(450)-- wait 45 seconds for the missile flight, then get new targets
                continue
            end
            ---------------------------------------------------------------------------------------------------
            -- Try to overwhelm anti nuke, search for targets
            ---------------------------------------------------------------------------------------------------
            EnemyProtectorsNum = 0
            TargetPosition = false
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Overwhelm) Check for MissileCount > 8  [ '..MissileCount..' > 8 ]')
            end
            if 1 == 1 and MissileCount > 8 and table.getn(EnemyAntiMissile) > 0 then
                if NUKEDEBUG then
                    LOG('* NukePlatoonAI: (Overwhelm) MissileCount, EnemyAntiMissile  [ '..MissileCount..', '..table.getn(EnemyAntiMissile)..' ]')
                end
                local AntiMissileRanger = {}
                -- get a list with all antinukes and distance to each other
                for MissileIndex, AntiMissileSTART in EnemyAntiMissile do
                    AntiMissileRanger[MissileIndex] = 0
                    -- get the location of AntiMissile
                    local AntiMissilePosSTART = AntiMissileSTART:GetPosition() or nil
                    if not AntiMissilePosSTART then break end
                    for _, AntiMissileEND in EnemyAntiMissile do
                        local AntiMissilePosEND = AntiMissileSTART:GetPosition() or nil
                        if not AntiMissilePosEND then continue end
                        local dist = VDist2(AntiMissilePosSTART[1],AntiMissilePosSTART[3],AntiMissilePosEND[1],AntiMissilePosEND[3])
                        AntiMissileRanger[MissileIndex] = AntiMissileRanger[MissileIndex] + dist
                    end
                end
                -- find the least protected anti missile
                local HighestDistance = 0
                local HighIndex = false
                for MissileIndex, MissileRange in AntiMissileRanger do
                    if MissileRange > HighestDistance then
                        HighestDistance = MissileRange
                        HighIndex = MissileIndex
                    end
                end
                if HighIndex and EnemyAntiMissile[HighIndex] and not EnemyAntiMissile[HighIndex].Dead then
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Overwhelm) Antimissile with highest distance to other antimissiles has HighIndex = '..HighIndex)
                    end
                    -- kill the launcher will all missiles we have
                    EnemyTarget = EnemyAntiMissile[HighIndex]
                    TargetPosition = EnemyTarget:GetPosition() or false
                elseif EnemyAntiMissile[1] and not EnemyAntiMissile[1].Dead then
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Overwhelm) Targetting Antimissile[1]')
                    end
                    EnemyTarget = EnemyAntiMissile[1]
                    TargetPosition = EnemyTarget:GetPosition() or false
                end
                -- Scan how many antinukes are protecting the least defended target:
                local ProtectorUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * ((categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3) + (categories.SHIELD * categories.EXPERIMENTAL)), TargetPosition, 90, 'Enemy')
                if ProtectorUnits then
                    EnemyProtectorsNum = table.getn(ProtectorUnits)
                end
            end
            ---------------------------------------------------------------------------------------------------
            -- Try to overwhelm anti nuke, search for targets
            ---------------------------------------------------------------------------------------------------
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Overwhelm) missiles > antimissiles  [ '..MissileCount..' > '..(EnemyProtectorsNum * 8)..' ]')
            end
            if 1 == 1 and EnemyTarget and TargetPosition and EnemyProtectorsNum > 0 and MissileCount > EnemyProtectorsNum * 8 then
                -- Fire as long as the target exists
                if NUKEDEBUG then
                    LOG('* NukePlatoonAI: (Overwhelm) while EnemyTarget do ')
                end
                while EnemyTarget and not EnemyTarget.Dead do
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Overwhelm) Loop!')
                    end
                    local missile = false
                    for k, Launcher in platoonUnits do
                        if not Launcher or Launcher.Dead or Launcher:BeenDestroyed() then
                            -- We found a dead unit inside this platoon. Disband the platton; It will be reformed
                            -- needs PlatoonDisbandNoAssign, or launcher will stop building nukes if the platton is disbanded
                            self:PlatoonDisbandNoAssign()
                            return
                        end
                        if NUKEDEBUG then
                            LOG('* NukePlatoonAI: (Overwhelm) Fireing Nuke: '..repr(k))
                        end
                        if Launcher:GetNukeSiloAmmoCount() > 0 then
                            if Launcher:GetNukeSiloAmmoCount() > 1 then
                                missile = true
                            end
                            IssueNuke({Launcher}, TargetPosition)
                            table.remove(LauncherReady, k)
                            MissileCount = MissileCount - 1
                        end
                        if not EnemyTarget or EnemyTarget.Dead then
                            if NUKEDEBUG then
                                LOG('* NukePlatoonAI: (Overwhelm) Target is dead. break fire loop')
                            end
                            break -- break the "for Index, Launcher in platoonUnits do" loop
                        end
                    end
                    if not missile then
                        if NUKEDEBUG then
                            LOG('* NukePlatoonAI: (Overwhelm) Nukes are empty')
                        end
                        break -- break the "while EnemyTarget do" loop
                    end
                    -- Wait for the missleflight of all missiles, then shoot again.
                    WaitTicks(450)
                    continue
                end
            end
            ---------------------------------------------------------------------------------------------------
            -- Jericho! Check if we can attack all targets at the same time
            ---------------------------------------------------------------------------------------------------
            EnemyTargetPositions = {}
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Jericho) Searching for EnemyTargetPositions')
            end
            for _, EnemyTarget in EnemyUnits do
                -- get position of the possible next target
                local EnemyTargetPos = EnemyTarget:GetPosition() or nil
                if not EnemyTargetPos then continue end
                local ToClose = false
                -- loop over all already attacked targets
                for _, ETargetPosition in EnemyTargetPositions do
                    -- Check if the target is closer then 40 to an already attacked target
                    if VDist2(EnemyTargetPos[1],EnemyTargetPos[3],ETargetPosition[1],ETargetPosition[3]) < 40 then
                        ToClose = true
                        break -- break out of the EnemyTargetPositions loop
                    end
                end
                if ToClose then
                    continue -- Skip this enemytarget and check the next
                end
                table.insert(EnemyTargetPositions, EnemyTargetPos)
            end
            ---------------------------------------------------------------------------------------------------
            -- Now, if we have more launchers ready then targets start Jericho bombardment
            ---------------------------------------------------------------------------------------------------
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Jericho) Checking for Launcher:('..LauncherCount..') Ready:('..table.getn(LauncherReady)..') Full:('..table.getn(LauncherFull)..') - Missiles:('..MissileCount..') - Enemy Targets:('..table.getn(EnemyTargetPositions)..')')
            end
            if 1 == 1 and table.getn(LauncherReady) >= table.getn(EnemyTargetPositions) and table.getn(EnemyTargetPositions) > 0 and table.getn(LauncherFull) > 0 then
                if NUKEDEBUG then
                    LOG('* NukePlatoonAI: Jericho!')
                end
                -- loopß over all targets
                self:NukeJerichoAttack(LauncherReady, EnemyTargetPositions)
                WaitTicks(450)-- wait 45 seconds for the missile flight, then get new targets
                continue
            end
            ---------------------------------------------------------------------------------------------------
            -- If we have an launcher with 5 missiles fire one.
            ---------------------------------------------------------------------------------------------------
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Launcher Full) Checking for Full Launchers. Launcher:('..LauncherCount..') Ready:('..table.getn(LauncherReady)..') Full:('..table.getn(LauncherFull)..') - Missiles:('..MissileCount..')')
            end
            if 1 == 1 and table.getn(LauncherFull) > 0 then
                if NUKEDEBUG then
                    LOG('* NukePlatoonAI: (Launcher Full) - Launcher is full!')
                end
                EnemyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.EXPERIMENTAL, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
                if table.getn(EnemyUnits) > 0 then
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Launcher Full) Enemy Experimental Buildings: ('..table.getn(EnemyUnits)..')')
                    end
                end
                if table.getn(EnemyUnits) <= 0 then
                    EnemyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.TECH3 , Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Launcher Full) Enemy TECH3 Buildings: ('..table.getn(EnemyUnits)..')')
                    end
                end
                if table.getn(EnemyUnits) <= 0 then
                    EnemyUnits = aiBrain:GetUnitsAroundPoint(categories.MOBILE * categories.EXPERIMENTAL - categories.AIR, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Launcher Full) Enemy Experimental Units: ('..table.getn(EnemyUnits)..')')
                    end
                end
                if table.getn(EnemyUnits) <= 0 then
                    EnemyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE , Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Launcher Full) Enemy Buildings: ('..table.getn(EnemyUnits)..')')
                    end
                end
                if table.getn(EnemyUnits) <= 0 then
                    EnemyUnits = aiBrain:GetUnitsAroundPoint(categories.MOBILE - categories.AIR, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Launcher Full) Enemy Mobile Units: ('..table.getn(EnemyUnits)..')')
                    end
                end
                if table.getn(EnemyUnits) > 0 then
                    if NUKEDEBUG then
                        LOG('* NukePlatoonAI: (Launcher Full) MissileCount ('..MissileCount..') > EnemyUnits ('..table.getn(EnemyUnits)..')')
                    end
                    EnemyTargetPositions = {}
                    -- get enemy target positions
                    for _, EnemyTarget in EnemyUnits do
                        -- get position of the possible next target
                        local EnemyTargetPos = EnemyTarget:GetPosition() or nil
                        if not EnemyTargetPos then continue end
                        local ToClose = false
                        -- loop over all already attacked targets
                        for _, ETargetPosition in EnemyTargetPositions do
                            -- Check if the target is closeer then 40 to an already attacked target
                            if VDist2(EnemyTargetPos[1],EnemyTargetPos[3],ETargetPosition[1],ETargetPosition[3]) < 40 then
                                ToClose = true
                                break -- break out of the EnemyTargetPositions loop
                            end
                        end
                        if ToClose then
                            continue -- Skip this enemytarget and check the next
                        end
                        table.insert(EnemyTargetPositions, EnemyTargetPos)
                    end
                end
            end
            ---------------------------------------------------------------------------------------------------
            -- Now, if we have targets, shot at it
            ---------------------------------------------------------------------------------------------------
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: (Launcher Full) Attack only with full Launchers. Launcher:('..LauncherCount..') Ready:('..table.getn(LauncherReady)..') Full:('..table.getn(LauncherFull)..') - Missiles:('..MissileCount..') - Enemy Targets:('..table.getn(EnemyTargetPositions)..')')
            end
            if 1 == 1 and table.getn(EnemyTargetPositions) > 0 and table.getn(LauncherFull) > 0 then
                self:NukeJerichoAttack(LauncherFull, EnemyTargetPositions)
                WaitTicks(450)-- wait 45 seconds for the missile flight, then get new targets
                continue
            end
            if NUKEDEBUG then
                LOG('* NukePlatoonAI: END. Launcher:('..LauncherCount..') Ready:('..table.getn(LauncherReady)..') Full:'..table.getn(LauncherFull)..' - Missiles:('..MissileCount..')')
            end

        end -- while aiBrain:PlatoonExists(self) do
    end,
    
    LeadNukeTarget = function(self, target)
        local TargetPos
        -- Get target position in 1 second intervals.
        -- This allows us to get speed and direction from the target
        local TargetStartPosition=0
        local Target1SecPos=0
        local Target2SecPos=0
        local XmovePerSec=0
        local YmovePerSec=0
        local XmovePerSecCheck=-1
        local YmovePerSecCheck=-1
        -- Check if the target is runing straight or circling
        -- If x/y and xcheck/ycheck are equal, we can be sure the target is moving straight
        -- in one direction. At least for the last 2 seconds.
        local LoopSaveGuard = 0
        while target and not target.Dead and (XmovePerSec ~= XmovePerSecCheck or YmovePerSec ~= YmovePerSecCheck) and LoopSaveGuard < 10 do
            if not target or target.Dead then return false end
            -- 1st position of target
            TargetPos = target:GetPosition()
            TargetStartPosition = {TargetPos[1], 0, TargetPos[3]}
            WaitTicks(10)
            -- 2nd position of target after 1 second
            TargetPos = target:GetPosition()
            Target1SecPos = {TargetPos[1], 0, TargetPos[3]}
            XmovePerSec = (TargetStartPosition[1] - Target1SecPos[1])
            YmovePerSec = (TargetStartPosition[3] - Target1SecPos[3])
            WaitTicks(10)
            -- 3rd position of target after 2 seconds to verify straight movement
            TargetPos = target:GetPosition()
            Target2SecPos = {TargetPos[1], TargetPos[2], TargetPos[3]}
            XmovePerSecCheck = (Target1SecPos[1] - Target2SecPos[1])
            YmovePerSecCheck = (Target1SecPos[3] - Target2SecPos[3])
            --We leave the while-do check after 10 loops (20 seconds) and try collateral damage
            --This can happen if a player try to fool the targetingsystem by circling a unit.
            LoopSaveGuard = LoopSaveGuard + 1
        end
        if not target or target.Dead then return false end
        local MissileImpactTime = 25
        -- Create missile impact corrdinates based on movePerSec * MissileImpactTime
        local MissileImpactX = Target2SecPos[1] - (XmovePerSec * MissileImpactTime)
        local MissileImpactY = Target2SecPos[3] - (YmovePerSec * MissileImpactTime)
        return {MissileImpactX, Target2SecPos[2], MissileImpactY}
    end,

    NukeSingleAttack = function(self, Launchers, EnemyTargetPosition)
        --LOG('** NukeSingleAttack: Launcher count: '..table.getn(Launchers))
        if table.getn(Launchers) <= 0 then
            --LOG('** NukeSingleAttack: No Launcher ready.')
            return false
        end
        -- loop over all nuke launcher
        for k, Launcher in Launchers do
            if not Launcher or Launcher.Dead or Launcher:BeenDestroyed() then
                -- We found a dead unit inside this platoon. Disband the platton; It will be reformed
                -- needs PlatoonDisbandNoAssign, or launcher will stop building nukes if the platton is disbanded
                --LOG('** NukeSingleAttack: Found destroyed launcher inside platoon. Disbanding...')
                self:PlatoonDisbandNoAssign()
                return
            end
            -- check if the target is closer then 20000
            LauncherPos = Launcher:GetPosition() or nil
            if not LauncherPos then
                --LOG('** NukeSingleAttack: no Launcher Pos. Skiped')
                continue
            end
            if not EnemyTargetPosition then
                --LOG('** NukeSingleAttack: no Target Pos. Skiped')
                continue
            end
            if VDist2(LauncherPos[1],LauncherPos[3],EnemyTargetPosition[1],EnemyTargetPosition[3]) > 20000 then
                --LOG('** NukeSingleAttack: Target out of range. Skiped')
                -- Target is out of range, skip this launcher
                continue
            end
            -- Attack the target
            --LOG('** NukeSingleAttack: Attacking Enemy Position!')
            IssueNuke({Launcher}, EnemyTargetPosition)
            -- stop seraching for available launchers and check the next target
            return true
        end
    end,

    NukeJerichoAttack = function(self, Launchers, EnemyTargetPositions)
        --LOG('* NukeJerichoAttack: Launcher: '..table.getn(Launchers))
        if table.getn(Launchers) <= 0 then
            --LOG('* NukeSingleAttack: Launcher empty')
            return false
        end
        for _, ActualTargetPos in EnemyTargetPositions do
            -- loop over all nuke launcher
            for k, Launcher in Launchers do
                if not Launcher or Launcher.Dead or Launcher:BeenDestroyed() then
                    -- We found a dead unit inside this platoon. Disband the platton; It will be reformed
                    -- needs PlatoonDisbandNoAssign, or launcher will stop building nukes if the platton is disbanded
                    --LOG('* NukeJerichoAttack: Found destroyed launcher inside platoon. Disbanding...')
                    self:PlatoonDisbandNoAssign()
                    return
                end
                -- check if the target is closer then 20000
                LauncherPos = Launcher:GetPosition() or nil
                if not LauncherPos then
                    --LOG('* NukeJerichoAttack: no Launcher Pos. Skiped')
                    continue
                end
                if not ActualTargetPos then
                    --LOG('* NukeJerichoAttack: no Target Pos. Skiped')
                    continue
                end
                if VDist2(LauncherPos[1],LauncherPos[3],ActualTargetPos[1],ActualTargetPos[3]) > 20000 then
                    --LOG('* NukeJerichoAttack: Target out of range. Skiped')
                    -- Target is out of range, skip this launcher
                    continue
                end
                -- Attack the target
                --LOG('* NukeJerichoAttack: Attacking Enemy Position!')
                IssueNuke({Launcher}, ActualTargetPos)
                -- remove the launcher from the table, so it can't be used for the next target
                table.remove(Launchers, k)
                -- stop seraching for available launchers and check the next target
                break -- for k, Launcher in Launcher do
            end
            --LOG('* NukeJerichoAttack: Launcher after shoot: '..table.getn(Launchers))
            if table.getn(Launchers) < 1 then
                --LOG('* NukeJerichoAttack: All Launchers are bussy! Break!')
                -- stop seraching for targets, we don't hava a launcher ready.
                break -- for _, ActualTargetPos in EnemyTargetPositions do
            end
        end
    end,

    IsTargetNukeProtected = function(self, Target, EnemyAntiMissile)
        TargetPos = Target:GetPosition() or nil
        if not TargetPos then
            -- we don't have a target position, so we return ture like we have a protected target.
            return true
        end
        for _, AntiMissile in EnemyAntiMissile do
            if not AntiMissile or AntiMissile.Dead or AntiMissile:BeenDestroyed() then continue end
            -- if the launcher is still in build, don't count it.
            local FractionComplete = AntiMissile:GetFractionComplete() or nil
            if not FractionComplete then continue end
            if FractionComplete < 1 then
                --LOG('* IsTargetNukeProtected: Target TAntiMissile:GetFractionComplete() < 1')
                continue
            end
            -- get the location of AntiMissile
            local AntiMissilePos = AntiMissile:GetPosition() or nil
            if not AntiMissilePos then
               --LOG('* IsTargetNukeProtected: Target AntiMissilePos NIL')
                continue 
            end
            -- Check if our target is inside range of an antimissile
            if VDist2(TargetPos[1],TargetPos[3],AntiMissilePos[1],AntiMissilePos[3]) < 90 then
                --LOG('* IsTargetNukeProtected: Target in range of Nuke Anti Missile. Skiped')
                return true
            end
        end
        return false
    end,

    SACUTeleportAI = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = self:GetPlatoonUnits()
        local platoonPosition = self:GetPlatoonPosition()
        local TargetPosition
        AIAttackUtils.GetMostRestrictiveLayer(self) -- this will set self.MovementLayer to the platoon
        -- start upgrading all SubCommanders as teleporter
        while aiBrain:PlatoonExists(self) do
            local allEnhanced = true
            for k, unit in platoonUnits do
                IssueClearCommands({unit})
                WaitTicks(1)
                if not unit.Dead then
                    for k, Assister in platoonUnits do
                        if not Assister.Dead and Assister ~= unit then
                            -- only assist if we have the energy for it
                            if aiBrain:GetEconomyTrend('ENERGY')*10 > 5000 or aiBrain.HasParagon then
                                IssueGuard({Assister}, unit)
                            end
                        end
                    end
                    if self:BuildSACUEnhancememnts(unit) then
                        allEnhanced = false
                    end
                end
            end
            if allEnhanced == true then
                break
            end
            WaitTicks(1)
        end
        --                         
        self:Stop()
        local MoveToCategories = {}
        if self.PlatoonData.MoveToCategories then
            for k,v in self.PlatoonData.MoveToCategories do
                table.insert(MoveToCategories, v )
            end
        else
            LOG('* SACUTeleportAI: MoveToCategories missing in platoon '..self.BuilderName)
        end
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                table.insert(WeaponTargetCategories, v )
            end
        end
        self:SetPrioritizedTargetList('Attack', WeaponTargetCategories)
        local TargetSearchCategory = self.PlatoonData.TargetSearchCategory or 'ALLUNITS'
        local maxRadius = self.PlatoonData.SearchRadius or 100
        -- search for a target
        local Target
        while not Target do
            WaitTicks(30)
            Target, _, _, _ = AIUtils.AIFindNearestCategoryTeleportLocation(aiBrain, platoonPosition, maxRadius, MoveToCategories, TargetSearchCategory, false)
        end
        if Target and not Target.Dead then
            TargetPosition = Target:GetPosition()
            for k, unit in platoonUnits do
                if not unit.Dead then
                    IssueStop({unit})
                    WaitTicks(2)
                    IssueTeleport({unit}, UUtils.RandomizePosition(TargetPosition))
                end
            end
        else
            self:PlatoonDisband()
            return
        end
        local count = 0
        while aiBrain:PlatoonExists(self) do
            platoonPos = self:GetPlatoonPosition()
            local RangeToTarget = VDist2(platoonPos[1], platoonPos[3], TargetPosition[1], TargetPosition[3])
            --LOG(count..'Range to target: '..RangeToTarget)
            if RangeToTarget < 40 then
                break
            end
            WaitTicks(10)
            count = count + 1
            if count > 120 then
                --LOG('Waiting for 120 seconds for teleport. Disbanding platoon')
                self:PlatoonDisband()
                return
            end
        end        
        -- Fight
        WaitTicks(1)
        self:LandAttackAIUveso()
    end,

    BuildSACUEnhancememnts = function(platoon,unit)
        local EnhancementsByUnitID = {
            -- UEF
            ['uel0301'] = {'xxx', 'xxx', 'xxx'},
            -- Aeon
            ['ual0301'] = {'StabilitySuppressant', 'Teleporter'},
            -- Cybram
            ['url0301'] = {'xxx', 'xxx', 'xxx'},
            -- Seraphim
            ['xsl0301'] = {'DamageStabilization', 'Teleporter'},
            -- Nomads
            ['xsl0301'] = {'xxx', 'xxx', 'xxx'},
        }
        local CRDBlueprint = unit:GetBlueprint()
        --LOG('BlueprintId '..repr(CRDBlueprint.BlueprintId))
        local ACUUpgradeList = EnhancementsByUnitID[CRDBlueprint.BlueprintId]
        --LOG('ACUUpgradeList '..repr(ACUUpgradeList))
        local NextEnhancement = false
        local HaveEcoForEnhancement = false
        for _,enhancement in ACUUpgradeList or {} do
            local wantedEnhancementBP = CRDBlueprint.Enhancements[enhancement]
            --LOG('wantedEnhancementBP '..repr(wantedEnhancementBP))
            if unit:HasEnhancement(enhancement) then
                NextEnhancement = false
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts: Enhancement is already installed: '..enhancement)
            elseif platoon:EcoGoodForUpgrade(unit, wantedEnhancementBP) then
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts: Eco is good for '..enhancement)
                if not NextEnhancement then
                    NextEnhancement = enhancement
                    HaveEcoForEnhancement = true
                    --LOG('* ACUAttackAIUveso: *** Set as Enhancememnt: '..NextEnhancement)
                end
            else
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts: Eco is bad for '..enhancement)
                if not NextEnhancement then
                    NextEnhancement = enhancement
                    HaveEcoForEnhancement = false
                    -- if we don't have the eco for this ugrade, stop the search
                    --LOG('* ACUAttackAIUveso: canceled search. no eco available')
                    break
                end
            end
        end
        if NextEnhancement and HaveEcoForEnhancement then
            --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts Building '..NextEnhancement)
            if platoon:BuildEnhancememnt(unit, NextEnhancement) then
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts returned true'..NextEnhancement)
                return true
            else
                --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts returned false'..NextEnhancement)
                return false
            end
        end
        --LOG('* ACUAttackAIUveso: BuildACUEnhancememnts returned false END')
        return false
    end,

    RenamePlatoon = function(self, text)
        for k, v in self:GetPlatoonUnits() do
            if v and not v.Dead then
                v:SetCustomName(text..' '..math.floor(GetGameTimeSeconds()))
            end
        end
    end,

    AirSuicideAI = function(self)
        LOG('*AirSuicideAI: START')
        AIAttackUtils.GetMostRestrictiveLayer(self) -- this will set self.MovementLayer to the platoon
        local aiBrain = self:GetBrain()
        -- Search all platoon units and activate Stealth and Cloak (mostly Modded units)
        local platoonUnits = self:GetPlatoonUnits()
        local PlatoonStrength = table.getn(platoonUnits)
        if platoonUnits and PlatoonStrength > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        LOG('* AirSuicideAI: Switching RULEUTC_StealthToggle')
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        LOG('* AirSuicideAI: Switching RULEUTC_CloakToggle')
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        local MoveToCategories = {}
        if self.PlatoonData.MoveToCategories then
            for k,v in self.PlatoonData.MoveToCategories do
                table.insert(MoveToCategories, v )
            end
        else
            LOG('* AirSuicideAI: MoveToCategories missing in platoon '..self.BuilderName)
        end
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                table.insert(WeaponTargetCategories, v )
            end
        end
        self:SetPrioritizedTargetList('Attack', WeaponTargetCategories)
        local target
        local bAggroMove = self.PlatoonData.AggressiveMove
        local path
        local reason
        local maxRadius = self.PlatoonData.SearchRadius or 100
        local PlatoonPos = self:GetPlatoonPosition()
        local LastTargetPos = PlatoonPos
        local basePosition
        if self.MovementLayer == 'Water' then
            -- we could search for the nearest naval base here, but buildposition is almost at the same location
            basePosition = PlatoonPos
        else
            -- land and air units are assigned to mainbase
            basePosition = aiBrain.BuilderManagers['MAIN'].Position
        end
        local GetTargetsFromBase = self.PlatoonData.GetTargetsFromBase
        local GetTargetsFrom = basePosition
        local TargetSearchCategory = self.PlatoonData.TargetSearchCategory or 'ALLUNITS'
        local LastTargetCheck
        local DistanceToBase = 0
        while aiBrain:PlatoonExists(self) do
            PlatoonPos = self:GetPlatoonPosition()
            if not GetTargetsFromBase then
                GetTargetsFrom = PlatoonPos
            else
                DistanceToBase = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, basePosition[1] or 0, basePosition[3] or 0)
                if DistanceToBase > maxRadius then
                    target = nil
                end
            end
            -- only get a new target and make a move command if the target is dead
            if not target or target.Dead or target:BeenDestroyed() then
                UnitWithPath, UnitNoPath, path, reason = AIUtils.AIFindNearestCategoryTargetInRange(aiBrain, self, 'Attack', GetTargetsFrom, maxRadius, MoveToCategories, TargetSearchCategory, false )
                if UnitWithPath then
                    LOG('*AirSuicideAI: found UnitWithPath')
                    self:Stop()
                    target = UnitWithPath
                    LastTargetPos = target:GetPosition()
                    if LastTargetPos then
                        self:MoveToLocation(LastTargetPos, false)
                        self.AirSuicideTargetPos = LastTargetPos
                    end
                elseif UnitNoPath then
                    LOG('*AirSuicideAI: found UnitNoPath')
                    self:Stop()
                    target = UnitNoPath
                    LastTargetPos = target:GetPosition()
                    if LastTargetPos then
                        self:MoveToLocation(LastTargetPos, false)
                        self.AirSuicideTargetPos = LastTargetPos
                    end
                else
                    --LOG('*AirSuicideAI: no target found '..repr(reason))
                    -- we have no target return to main base
                    self:Stop()
                    if self.MovementLayer == 'Air' then
                        if VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, basePosition[1] or 0, basePosition[3] or 0) > 30 then
                            self:MoveToLocation(basePosition, false)
                        else
                            -- we are at home and we don't have a target. Disband!
                            if aiBrain:PlatoonExists(self) then
                                self:PlatoonDisband()
                                return
                            end
                        end
                    else
                        self:SimpleReturnToBase(basePosition)
                    end
                end
            -- targed exists and is not dead
            end
            WaitTicks(1)
            
            local LastPlatoonPos = false
            local FlightElevation = platoonUnits[1]:GetBlueprint().Physics.Elevation
            local FlightMaxAirspeed = platoonUnits[1]:GetBlueprint().Air.MaxAirspeed
            while aiBrain:PlatoonExists(self) and self.AirSuicideTargetPos do
                PlatoonPos = self:GetPlatoonPosition()
                -- 24 ticks for crash
                --LOG('*AirSuicideAI: PlatoonExists + AirSuicideTargetPos '..VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, self.AirSuicideTargetPos[1] or 0, self.AirSuicideTargetPos[3] or 0))
                local CrashFlightDistance = FlightMaxAirspeed/10 * FlightElevation
                CrashFlightDistance = 18
                if VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, self.AirSuicideTargetPos[1] or 0, self.AirSuicideTargetPos[3] or 0) <= CrashFlightDistance then
                    LOG('*AirSuicideAI: CrashFlightDistance: '..CrashFlightDistance)
                    for k, v in platoonUnits do
                        local vx, vy, vz = v:GetVelocity()
                        LOG('*AirSuicideAI: Kill unit. Velocity: vx'..vx..' vx'..vy..' vx'..vz..' ')
                        v:Kill()
                    end
                    local x = 0
                    while true do
                        x = x + 1
                        PlatoonPos = self:GetPlatoonPosition()
                        LOG(FlightMaxAirspeed..' '..FlightElevation..' '..((FlightMaxAirspeed/10)*FlightElevation)..' '..x..'*AirSuicideAI: Crashing '..VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, self.AirSuicideTargetPos[1] or 0, self.AirSuicideTargetPos[3] or 0)..' '..PlatoonPos[2]..' ')
                        WaitTicks(1)
                    end
                end
                WaitTicks(1)
            end
        end
    end,

    BuildOnMassAI = function(self)
        local aiBrain = self:GetBrain()
        local engineer = self:GetPlatoonUnits()[1]
        if not engineer or engineer.Dead or engineer:BeenDestroyed() then
            LOG('* AI-Uveso: BuildOnMassAI: Platoon failed to form')
            return
        end
        -- block AssignEngineerTask from using this engineer
        engineer.UnitBeingAssist = true
        -- block ProcessBuildCommand() from using this engineer
        engineer.AssistSet = true
        engineer.UnitBeingBuiltBehavior = true
        -- block the uveso-ecomanager from pausing this unit
        engineer.noPause = true
        -- get the faction index from the actual brain
        local factionIndex = aiBrain:GetFactionIndex()
        -- get the faction from the engineer in case we have an engineer from a different faction captured
        local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
        local EngineerFactionIndex = FactionToIndex[engineer.factionCategory] or factionIndex
        -- get the unit id from T1Resource building from the engineer faction
        local buildingTmpl = import('/lua/BuildingTemplates.lua')['BuildingTemplates'][factionIndex]
        local T1ResourceUnitID
        for Key, Data in buildingTmpl do
            if Data[1] and Data[2] and Data[1] == 'T1Resource' then
                T1ResourceUnitID = Data[2]
                break
            end
        end
        if not T1ResourceUnitID then
            WARN('* AI-Uveso: BuildOnMassAI: can\'t find massextractor unitID for faction '..repr(engineer.factionCategory)..' ')
            return
        end
        --LOG('* AI-Uveso: BuildOnMassAI: EngineerFactionIndex '..EngineerFactionIndex..' can build unitID '..T1ResourceUnitID)
        --get the basetemplate file
        local baseTmplFile = import('/lua/BaseTemplates.lua')
        local baseTmpl = baseTmplFile['BaseTemplates'][factionIndex]

        -- loop as long as the engineer is alive
        while aiBrain:PlatoonExists(self) and not engineer.Dead do
            -- The engineer is the first unit iside this platoon
            engineer = self:GetPlatoonUnits()[1]
            -- if we get a target then build there
            if engineer.MexToCap then
                
                -- Move to the target
                if AIUtils.EngineerMoveWithSafePath(aiBrain, engineer, engineer.MexToCap.Position) then

                    if AIUtils.EngineerTryReclaimCaptureArea(aiBrain, engineer, engineer.MexToCap.Position) then
                        WaitTicks(3)
                        while  not engineer.Dead and (engineer:IsUnitState('Building') or not engineer:IsIdleState()) do
                            WaitTicks(5)
                        end
                    end

                    --LOG('**AI-Uveso: BuildOnMassAI: Want to build MexToCap at Position: '..repr(engineer.MexToCap.Position))

                    if aiBrain:CanBuildStructureAt(T1ResourceUnitID, engineer.MexToCap.Position) then
                        --LOG('* AI-Uveso: BuildOnMassAI: MexToCap CanBuildStructureAt '..repr(engineer.MexToCap.Position))
                        IssueStop({engineer})
                        IssueClearCommands({engineer})
                        aiBrain:BuildStructure(engineer, T1ResourceUnitID, {engineer.MexToCap.Position[1], engineer.MexToCap.Position[3], 0} , false)
                    end

                    WaitTicks(5)

                    if not engineer:IsUnitState('Building') and engineer:IsIdleState() then
                        --LOG('* AI-Uveso: BuildOnMassAI: Build failed, searching for an alternative building place ')
                        local location = aiBrain:FindPlaceToBuild('T1Resource', T1ResourceUnitID, baseTmpl, false, nil, 'Enemy', engineer.MexToCap.Position[1], engineer.MexToCap.Position[3], 5)
                        --LOG('* AI-Uveso: BuildOnMassAI: FindPlaceToBuild Position: '..repr(location))
                        aiBrain:BuildStructure(engineer, T1ResourceUnitID, {location[1], location[3], 0} , false)
                     end

                    WaitTicks(5)

                    while not engineer.Dead and (engineer:IsUnitState('Building') or not engineer:IsIdleState()) do
                        WaitTicks(5)
                    end
                end
                engineer.MexToCap = nil
            end
            WaitTicks(1)
        end
    end,

    StrikeForceAI = function(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(atkPri, v)
                table.insert(categoryList, ParseEntityCategory(v))
            end
        end
        table.insert(atkPri, 'ALLUNITS')
        table.insert(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', categoryList)
        local target
        local blip = false
        local maxRadius = data.SearchRadius or 50
        local movingToScout = false
        while aiBrain:PlatoonExists(self) do
            if not target or target.Dead then
                --if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                --    aiBrain:PickEnemyLogic()
                --end
                local mult = { 1,10,25 }
                for _,i in mult do
                    target = AIUtils.AIFindBrainTargetInRange(aiBrain, self, 'Attack', maxRadius * i, atkPri)
                    if target then
                        break
                    end
                    WaitSeconds(1) --DUNCAN - was 3
                    if not aiBrain:PlatoonExists(self) then
                        return
                    end
                end

                --target = self:FindPrioritizedUnit('Attack', 'Enemy', true, self:GetPlatoonPosition(), maxRadius)

                --DUNCAN - added to target experimentals if they exist.
                local newtarget
                if AIAttackUtils.GetSurfaceThreatOfUnits(self) > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL + categories.STRUCTURE))
                elseif AIAttackUtils.GetAirThreatOfUnits(self) > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * categories.AIR)
                end
                if newtarget then
                    target = newtarget
                end

                if target then
                    self:Stop()
                    if not data.UseMoveOrder then
                        self:AttackTarget(target)
                    else
                        self:MoveToLocation(table.copy(target:GetPosition()), false)
                    end
                    movingToScout = false
                elseif not movingToScout then
                    movingToScout = true
                    self:Stop()
                    for k,v in AIUtils.AIGetSortedMassLocations(aiBrain, 10, nil, nil, nil, nil, self:GetPlatoonPosition()) do
                        if v[1] < 0 or v[3] < 0 or v[1] > ScenarioInfo.size[1] or v[3] > ScenarioInfo.size[2] then
                            --LOG('*AI DEBUG: STRIKE FORCE SENDING UNITS TO WRONG LOCATION - ' .. v[1] .. ', ' .. v[3])
                        end
                        self:MoveToLocation((v), false)
                    end
                end
            end
            WaitSeconds(7)
        end
    end,

    StrikeForceAISwarm = function(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(atkPri, v)
                table.insert(categoryList, ParseEntityCategory(v))
            end
        end
        table.insert(atkPri, 'ALLUNITS')
        table.insert(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', categoryList)
        local target = false
        local oldTarget = false
        local blip = false
        local maxRadius = data.SearchRadius or 50
        local movingToScout = false
        AIAttackUtils.GetMostRestrictiveLayer(self)
        while aiBrain:PlatoonExists(self) do
            if target then
                local targetCheck = true
                for k,v in atkPri do
                    local category = ParseEntityCategory(v)
                    if EntityCategoryContains(category, target) and v != 'ALLUNITS' then
                        targetCheck = false
                        break
                    end
                end
                if targetCheck then
                    target = false
                    oldTarget = false
                end
            end
            if not target or target.Dead or not target:GetPosition() then
                if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    aiBrain:PickEnemyLogicSorian()
                end
                --local mult = { 1,10,25 }
                --for _,i in mult do
                    target = AIUtils.AIFindBrainTargetInRange(aiBrain, self, 'Attack', maxRadius * 25, atkPri, aiBrain:GetCurrentEnemy())
                --    if target then
                --        break
                --    end
                --    WaitSeconds(3)
                --    if not aiBrain:PlatoonExists(self) then
                --        return
                --    end
                --end
                local newtarget = false
                if AIAttackUtils.GetSurfaceThreatOfUnits(self) > 0 and (aiBrain.T4ThreatFound['Land'] or aiBrain.T4ThreatFound['Naval'] or aiBrain.T4ThreatFound['Structure']) then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL + categories.STRUCTURE + categories.ARTILLERY))
                elseif AIAttackUtils.GetAirThreatOfUnits(self) > 0 and aiBrain.T4ThreatFound['Air'] then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * categories.AIR)
                end
                if newtarget then
                    target = newtarget
                end
                if target and (target != oldTarget or movingToScout) then
                    oldTarget = target
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, self:GetPlatoonPosition(), target:GetPosition(), 10)
                    self:Stop()
                    if not path then
                        if reason == 'NoStartNode' or reason == 'NoEndNode' then
                            if not data.UseMoveOrder then
                                self:AttackTarget(target)
                            else
                                self:MoveToLocation(table.copy(target:GetPosition()), false)
                            end
                        end
                    else
                        local pathSize = table.getn(path)
                        for wpidx,waypointPath in path do
                            if wpidx == pathSize and not data.UseMoveOrder then
                                self:AttackTarget(target)
                            else
                                self:MoveToLocation(waypointPath, false)
                            end
                        end
                    end
                    movingToScout = false
                elseif not movingToScout and not target and self.MovementLayer != 'Water' then
                    movingToScout = true
                    self:Stop()
                    local MassSpots = AIUtils.AIGetSortedMassLocations(aiBrain, 10, nil, nil, nil, nil, self:GetPlatoonPosition())
                    if table.getn(MassSpots) > 0 then
                        for k,v in MassSpots do
                            self:MoveToLocation(v, false)
                        end
                    else
                        local x,z = aiBrain:GetArmyStartPos()
                        local position = AIUtils.RandomLocation(x,z)
                        local safePath, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Air', self:GetPlatoonPosition(), position, 200)
                        if safePath then
                            for _,p in safePath do
                                self:MoveToLocation(p, false)
                            end
                        else
                            self:MoveToLocation(position, false)
                        end
                    end
                elseif not movingToScout and not target and self.MovementLayer == 'Water' then
                    movingToScout = true
                    self:Stop()
                    local scoutPath = {}
                    scoutPath = AIUtils.AIGetSortedNavalLocations(self:GetBrain())
                    for k, v in scoutPath do
                        self:Patrol(v)
                    end
                end
            end
            if self.MovementLayer == 'Air' then
                local waitLoop = 0
                repeat
                    WaitSeconds(1)
                    waitLoop = waitLoop + 1
                until waitLoop >= 7 or (target and (target.Dead or not target:GetPosition()))
            else
                WaitSeconds(7)
            end
        end
    end,

    TacticalAISwarm = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local platoonUnits = self:GetPlatoonUnits()
        local unit

        if not aiBrain:PlatoonExists(self) then return end

        --GET THE Launcher OUT OF THIS PLATOON
        for k, v in platoonUnits do
            if EntityCategoryContains(categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, v) then
                unit = v
                break
            end
        end

        if not unit then return end

        local bp = unit:GetBlueprint()
        local weapon = bp.Weapon[1]
        local maxRadius = weapon.MaxRadius
        local minRadius = weapon.MinRadius
        unit:SetAutoMode(true)

        --DUNCAN - commented out
        --local atkPri = { 'COMMAND', 'STRUCTURE STRATEGIC', 'STRUCTURE DEFENSE', 'CONSTRUCTION', 'EXPERIMENTAL MOBILE LAND', 'TECH3 MOBILE LAND',
        --    'TECH2 MOBILE LAND', 'TECH1 MOBILE LAND', 'ALLUNITS' }

        --DUNCAN - added energy production, removed construction, repriotised.
        self:SetPrioritizedTargetList('Attack', {
            categories.COMMAND,
            categories.EXPERIMENTAL,
            categories.MASSEXTRACTION * categories.TECH3,
            categories.ENERGYPRODUCTION * categories.TECH3,
            categories.MASSEXTRACTION * categories.TECH2,
            categories.ENERGYPRODUCTION * categories.TECH2,
            categories.STRUCTURE,
            categories.TECH3 * categories.MOBILE})
        while aiBrain:PlatoonExists(self) do
            local target = false
            local blip = false
            while unit:GetTacticalSiloAmmoCount() < 1 or not target do
                WaitSeconds(7)
                target = false
                while not target do

                    --DUNCAN - Commented out
                    --if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    --    aiBrain:PickEnemyLogic()
                    --end
                    --target = AIUtils.AIFindBrainTargetInRange(aiBrain, self, 'Attack', maxRadius, atkPri, aiBrain:GetCurrentEnemy())

                    if not target then
                        target = self:FindPrioritizedUnit('Attack', 'Enemy', true, unit:GetPosition(), maxRadius)
                    end
                    if target then
                        break
                    end
                    WaitSeconds(3)
                    if not aiBrain:PlatoonExists(self) then
                        return
                    end
                end
            end
            if not target.Dead then
                --LOG('*AI DEBUG: Firing Tactical Missile at enemy swine!')
                IssueTactical({unit}, target)
            end
            WaitSeconds(3)
        end
    end,

    HuntAISwarm = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local platoonUnits = self:GetPlatoonUnits()
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)
        while aiBrain:PlatoonExists(self) do
            local mySurfaceThreat = AIAttackUtils.GetSurfaceThreatOfUnits(self)
            local inWater = AIAttackUtils.InWaterCheck(self)
            local pos = self:GetPlatoonPosition()
            local threatatLocation = aiBrain:GetThreatAtPosition(pos, 1, true, 'AntiSurface')
            target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.NAVAL - categories.SCOUT)
            if target then
                blip = target:GetBlip(armyIndex)
                self:Stop()
                if not inWater then
                    IssueAggressiveMove(platoonUnits, target:GetPosition())
                else
                    IssueMove(platoonUnits, target:GetPosition())
                end
            end
            WaitSeconds(17)
        end
    end,

    GunshipHuntAI = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local hadtarget = false
        while aiBrain:PlatoonExists(self) do
            target = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL + categories.STRUCTURE))
            if not target then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.WALL)
            end
            if target then
                blip = target:GetBlip(armyIndex)
                self:Stop()
                self:AggressiveMoveToLocation(table.copy(target:GetPosition()))
                hadtarget = true
            elseif not target and hadtarget then
                local x,z = aiBrain:GetArmyStartPos()
                local position = AIUtils.RandomLocation(x,z)
                local safePath, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Air', self:GetPlatoonPosition(), position, 200)
                if safePath then
                    for _,p in safePath do
                        self:MoveToLocation(p, false)
                    end
                else
                    self:MoveToLocation(position, false)
                end
                hadtarget = false
            end
            WaitSeconds(17)
        end
    end,

    AttackForceAISwarm = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()

        -- get units together
        if not self:GatherUnitsSorian() then
            self:PlatoonDisband()
        end

        -- Setup the formation based on platoon functionality

        --local enemy = aiBrain:GetCurrentEnemy()

        local platoonUnits = self:GetPlatoonUnits()
        local numberOfUnitsInPlatoon = table.getn(platoonUnits)
        local oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon
        local platoonTechLevel = SUtils.GetPlatoonTechLevel(platoonUnits)
        local platoonThreatTable = {4,28,80}
        local stuckCount = 0

        self.PlatoonAttackForce = true
        -- formations have penalty for taking time to form up... not worth it here
        -- maybe worth it if we micro
        --self:SetPlatoonFormationOverride('GrowthFormation')
        local bAggro = self.PlatoonData.AggressiveMove or false
        local PlatoonFormation = self.PlatoonData.UseFormation or 'No Formation'
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local maxRange, selectedWeaponArc, turretPitch = AIAttackUtils.GetLandPlatoonMaxRangeSorian(aiBrain, self)
        --local quickReset = false

        while aiBrain:PlatoonExists(self) do
            local pos = self:GetPlatoonPosition() -- update positions; prev position done at end of loop so not done first time

            -- if we can't get a position, then we must be dead
            if not pos then
                self:PlatoonDisband()
            end


            -- if we're using a transport, wait for a while
            if self.UsingTransport then
                WaitSeconds(10)
                continue
            end

            -- pick out the enemy
            --if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                aiBrain:PickEnemyLogicSorian()
            --end

            -- merge with nearby platoons
            --if aiBrain:PlatoonExists(self) then
            --    self:MergeWithNearbyPlatoonsSorian('AttackForceAISwarm', 10)
            --end

            -- rebuild formation
            platoonUnits = self:GetPlatoonUnits()
            numberOfUnitsInPlatoon = table.getn(platoonUnits)
            -- if we have a different number of units in our platoon, regather
            local threatatLocation = aiBrain:GetThreatAtPosition(pos, 1, true, 'AntiSurface')
            if (oldNumberOfUnitsInPlatoon != numberOfUnitsInPlatoon) and threatatLocation < 1 then
                self:StopAttack()
                self:SetPlatoonFormationOverride(PlatoonFormation)
                oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon
            end

            -- deal with lost-puppy transports
            local strayTransports = {}
            for k,v in platoonUnits do
                if EntityCategoryContains(categories.TRANSPORTATION, v) then
                    table.insert(strayTransports, v)
                end
            end
            if table.getn(strayTransports) > 0 then
                local dropPoint = pos
                dropPoint[1] = dropPoint[1] + Random(-3, 3)
                dropPoint[3] = dropPoint[3] + Random(-3, 3)
                IssueTransportUnload(strayTransports, dropPoint)
                WaitSeconds(10)
                local strayTransports = {}
                for k,v in platoonUnits do
                    local parent = v:GetParent()
                    if parent and EntityCategoryContains(categories.TRANSPORTATION, parent) then
                        table.insert(strayTransports, parent)
                        break
                    end
                end
                if table.getn(strayTransports) > 0 then
                    local MAIN = aiBrain.BuilderManagers.MAIN
                    if MAIN then
                        dropPoint = MAIN.Position
                        IssueTransportUnload(strayTransports, dropPoint)
                        WaitSeconds(30)
                    end
                end
                self.UsingTransport = false
                AIUtils.ReturnTransportsToPool(strayTransports, true)
                platoonUnits = self:GetPlatoonUnits()
            end


            --Disband platoon if it's all air units, so they can be picked up by another platoon
            local mySurfaceThreat = AIAttackUtils.GetSurfaceThreatOfUnits(self)
            if mySurfaceThreat == 0 and AIAttackUtils.GetAirThreatOfUnits(self) > 0 then
                self:PlatoonDisband()
                return
            end

            local cmdQ = {}
            -- fill cmdQ with current command queue for each unit
            for k,v in platoonUnits do
                if not v.Dead then
                    local unitCmdQ = v:GetCommandQueue()
                    for cmdIdx,cmdVal in unitCmdQ do
                        table.insert(cmdQ, cmdVal)
                        break
                    end
                end
            end

            if (oldNumberOfUnitsInPlatoon != numberOfUnitsInPlatoon) then
                maxRange, selectedWeaponArc, turretPitch = AIAttackUtils.GetLandPlatoonMaxRangeSorian(aiBrain, self)
            end

            if not maxRange then maxRange = 50 end

            -- if we're on our final push through to the destination, and we find a unit close to our destination
            --local closestTarget = self:FindClosestUnit('attack', 'enemy', true, categories.ALLUNITS)
            local closestTarget = SUtils.FindClosestUnitPosToAttack(aiBrain, self, 'attack', maxRange + 20, categories.ALLUNITS - categories.AIR - categories.NAVAL - categories.SCOUT, selectedWeaponArc, turretPitch)
            local nearDest = false
            local oldPathSize = table.getn(self.LastAttackDestination)
            if self.LastAttackDestination then
                nearDest = oldPathSize == 0 or VDist3(self.LastAttackDestination[oldPathSize], pos) < 20
            end

            local inWater = AIAttackUtils.InWaterCheck(self)

        -- if we're near our destination and we have a unit closeby to kill, kill it
            if table.getn(cmdQ) <= 1 and closestTarget and nearDest then
                self:StopAttack()
                if not inWater then
                    self:AggressiveMoveToLocation(closestTarget:GetPosition())
                else
                    self:MoveToLocation(closestTarget:GetPosition(), false)
                end
                cmdQ = {1}
--              quickReset = true
            -- if we have a target and can attack it, attack!
            elseif closestTarget then
                self:StopAttack()
                if not inWater then
                    self:AggressiveMoveToLocation(closestTarget:GetPosition())
                else
                    self:MoveToLocation(closestTarget:GetPosition(), false)
                end
                cmdQ = {1}
--              quickReset = true
            -- if we have nothing to do, but still have a path (because of one of the above)
            elseif table.getn(cmdQ) == 0 and oldPathSize > 0 then
                self.LastAttackDestination = {}
                self:StopAttack()
                cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorSorian(aiBrain, self, bAggro)
                stuckCount = 0
            -- if we have nothing to do, try finding something to do
            elseif table.getn(cmdQ) == 0 then
                self:StopAttack()
                cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorSorian(aiBrain, self, bAggro)
                stuckCount = 0
            -- if we've been stuck and unable to reach next marker? Ignore nearby stuff and pick another target
            elseif self.LastPosition and VDist2Sq(self.LastPosition[1], self.LastPosition[3], pos[1], pos[3]) < (self.PlatoonData.StuckDistance or 8) then
                stuckCount = stuckCount + 1
                if stuckCount >= 2 then
                    self:StopAttack()
                    self.LastAttackDestination = {}
                    cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorSorian(aiBrain, self, bAggro)
                    stuckCount = 0
                end
            else
                stuckCount = 0
            end

            self.LastPosition = pos

--[[            if table.getn(cmdQ) == 0 then --and mySurfaceThreat < 4 then
                -- if we have a low threat value, then go and defend an engineer or a base
                if mySurfaceThreat < platoonThreatTable[platoonTechLevel]
                    and mySurfaceThreat > 0 and not self.PlatoonData.NeverGuard
                    and not (self.PlatoonData.NeverGuardEngineers and self.PlatoonData.NeverGuardBases) then
                    --LOG('*DEBUG: Trying to guard')
                    --if platoonTechLevel > 1 then
                    --  return self:GuardExperimentalSorian(self.AttackForceAISorian)
                    --else
                        return self:GuardEngineer(self.AttackForceAISorian)
                    --end
                end

                -- we have nothing to do, so find the nearest base and disband
                if not self.PlatoonData.NeverMerge then
                    return self:ReturnToBaseAISorian()
                end
                WaitSeconds(5)
            else
                -- wait a little longer if we're stuck so that we have a better chance to move
                if quickReset then
                    quickReset = false
                    WaitSeconds(6)
                else ]]--
                WaitSeconds(Random(5,11) + 2 * stuckCount)
--              end
--            end
        end
    end,

    GuardMarkerSwarm = function(self)
        local aiBrain = self:GetBrain()

        local platLoc = self:GetPlatoonPosition()

        if not aiBrain:PlatoonExists(self) or not platLoc then
            return
        end

        -----------------------------------------------------------------------
        -- Platoon Data
        -----------------------------------------------------------------------
        -- type of marker to guard
        -- Start location = 'Start Location'... see MarkerTemplates.lua for other types
        local markerType = self.PlatoonData.MarkerType or 'Expansion Area'

        -- what should we look for for the first marker?  This can be 'Random',
        -- 'Threat' or 'Closest'
        local moveFirst = self.PlatoonData.MoveFirst or 'Threat'

        -- should our next move be no move be (same options as before) as well as 'None'
        -- which will cause the platoon to guard the first location they get to
        local moveNext = self.PlatoonData.MoveNext or 'None'

        -- Minimum distance when looking for closest
        local avoidClosestRadius = self.PlatoonData.AvoidClosestRadius or 0

        -- set time to wait when guarding a location with moveNext = 'None'
        local guardTimer = self.PlatoonData.GuardTimer or 0

        -- threat type to look at
        local threatType = self.PlatoonData.ThreatType or 'AntiSurface'

        -- should we look at our own threat or the enemy's
        local bSelfThreat = self.PlatoonData.SelfThreat or false

        -- if true, look to guard highest threat, otherwise,
        -- guard the lowest threat specified
        local bFindHighestThreat = self.PlatoonData.FindHighestThreat or false

        -- minimum threat to look for
        local minThreatThreshold = self.PlatoonData.MinThreatThreshold or -1
        -- maximum threat to look for
        local maxThreatThreshold = self.PlatoonData.MaxThreatThreshold  or 99999999

        -- Avoid bases (true or false)
        local bAvoidBases = self.PlatoonData.AvoidBases or false

        -- Radius around which to avoid the main base
        local avoidBasesRadius = self.PlatoonData.AvoidBasesRadius or 0

        -- Use Aggresive Moves Only
        local bAggroMove = self.PlatoonData.AggressiveMove or false

        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        -----------------------------------------------------------------------


        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local markerLocations = AIUtils.AIGetMarkerLocations(aiBrain, markerType)

        local bestMarker = false

        if not self.LastMarker then
            self.LastMarker = {nil,nil}
        end

        -- look for a random marker
        if moveFirst == 'Random' then
            if table.getn(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in RandomIter(markerLocations) do
                if table.getn(markerLocations) <= 2 then
                    self.LastMarker[1] = nil
                    self.LastMarker[2] = nil
                end
                if self:AvoidsBasesSorian(marker.Position, bAvoidBases, avoidBasesRadius) then
                    if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                        continue
                    end
                    if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                        continue
                    end
                    bestMarker = marker
                    break
                end
            end
        elseif moveFirst == 'Threat' then
            --Guard the closest least-defended marker
            local bestMarkerThreat = 0
            if not bFindHighestThreat then
                bestMarkerThreat = 99999999
            end

            local bestDistSq = 99999999


            -- find best threat at the closest distance
            for _,marker in markerLocations do
                local markerThreat
                if bSelfThreat then
                    markerThreat = aiBrain:GetThreatAtPosition(marker.Position, 0, true, threatType, aiBrain:GetArmyIndex())
                else
                    markerThreat = aiBrain:GetThreatAtPosition(marker.Position, 0, true, threatType)
                end
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

                if markerThreat >= minThreatThreshold and markerThreat <= maxThreatThreshold then
                    if self:AvoidsBasesSorian(marker.Position, bAvoidBases, avoidBasesRadius) then
                        if self.IsBetterThreat(bFindHighestThreat, markerThreat, bestMarkerThreat) then
                            bestDistSq = distSq
                            bestMarker = marker
                            bestMarkerThreat = markerThreat
                        elseif markerThreat == bestMarkerThreat then
                            if distSq < bestDistSq then
                                bestDistSq = distSq
                                bestMarker = marker
                                bestMarkerThreat = markerThreat
                            end
                        end
                     end
                 end
            end

        else
            -- if we didn't want random or threat, assume closest (but avoid ping-ponging)
            local bestDistSq = 99999999
            if table.getn(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in markerLocations do
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])
                if self:AvoidsBasesSorian(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                    if distSq < bestDistSq then
                        if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                            continue
                        end
                        if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                            continue
                        end
                        bestDistSq = distSq
                        bestMarker = marker
                    end
                end
            end
        end


        -- did we find a threat?
        local usedTransports = false
        if bestMarker then
            self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --LOG("GuardMarker: Attacking " .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, self:GetPlatoonPosition(), bestMarker.Position, 200)
            --local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(self:GetPlatoonUnits())
            if path then
                local position = self:GetPlatoonPosition()
                if VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsSorian(aiBrain, self, bestMarker.Position, true, false, false)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsSorian(aiBrain, self, bestMarker.Position, false, false, false)
                end
                if not usedTransports then
                    local pathLength = table.getn(path)
                    for i=1, pathLength-1 do
                        if bAggroMove then
                            self:AggressiveMoveToLocation(path[i])
                        else
                            self:MoveToLocation(path[i], false)
                        end
                    end
                end
            elseif (not path and reason == 'NoPath') then
                usedTransports = AIAttackUtils.SendPlatoonWithTransportsSorian(aiBrain, self, bestMarker.Position, true, false, true)
            else
                self:PlatoonDisband()
                return
            end

            if not path and not usedTransports then
                self:PlatoonDisband()
                return
            end

            if moveNext == 'None' then
                -- guard
                IssueGuard(self:GetPlatoonUnits(), bestMarker.Position)
                -- guard forever
                if guardTimer <= 0 then return end
            else
                -- otherwise, we're moving to the location
                self:AggressiveMoveToLocation(bestMarker.Position)
            end

            -- wait till we get there
            local oldPlatPos = self:GetPlatoonPosition()
            local StuckCount = 0
            repeat
                WaitSeconds(5)
                platLoc = self:GetPlatoonPosition()
                if VDist3(oldPlatPos, platLoc) < 1 then
                    StuckCount = StuckCount + 1
                else
                    StuckCount = 0
                end
                if StuckCount > 5 then
                    return self:GuardMarkerSorian()
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 64 or not aiBrain:PlatoonExists(self)

            -- if we're supposed to guard for some time
            if moveNext == 'None' then
                -- this won't be 0... see above
                WaitSeconds(guardTimer)
                self:PlatoonDisband()
                return
            end

            if moveNext == 'Guard Base' then
                return self:GuardBaseSorian()
            end

            -- we're there... wait here until we're done
            local numGround = aiBrain:GetNumUnitsAroundPoint((categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            while numGround > 0 and aiBrain:PlatoonExists(self) do
                WaitSeconds(Random(5,10))
                numGround = aiBrain:GetNumUnitsAroundPoint((categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            end

            if not aiBrain:PlatoonExists(self) then
                return
            end

            -- set our MoveFirst to our MoveNext
            self.PlatoonData.MoveFirst = moveNext
            return self:GuardMarkerSorian()
        else
            -- no marker found, disband!
            self:PlatoonDisband()
        end
    end,

    ThreatStrikeSwarm = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local threshold = self.PlatoonData.ThreatThreshold
        while aiBrain:PlatoonExists(self) do
            local bestDist = false
            local bestTarget = false
            local position = self:GetPlatoonPosition()
            if self.BaseMonitor.AlertSounded then
                for k,v in self.BaseMonitor.AlertsTable do
                    if v.Threat < threshold then
                        continue
                    end

                    local tempDist = Utilities.XZDistanceTwoVectors(position, v.Position)

                    if not bestDist or tempDist < bestDist then
                        bestDist = tempDist
                        local height = GetTerrainHeight(v.Position[1], v.Position[3])
                        local surfHeight = GetSurfaceHeight(v.Position[1], v.Position[3])
                        if surfHeight > height then
                            height = surfHeight
                        end
                        bestTarget = { v.Position[1], height, v.Position[3] }
                    end
                end
                if bestTarget then
                    local safePath, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Air', self:GetPlatoonPosition(), bestTarget, 200)
                    if safePath then
                        local pathSize = table.getn(path)
                        for wpidx,waypointPath in path do
                            if wpidx == pathSize then
                                self:AggressiveMoveToLocation(bestTarget)
                            else
                                self:MoveToLocation(waypointPath, false)
                            end
                        end
                    else
                        self:AggressiveMoveToLocation(bestTarget)
                    end
                end
            end
            if not bestTarget then
                return self:AirHuntAI()
            end
            WaitSeconds(17)
        end
    end,

    ArtilleryAI = function(self)
        local aiBrain = self:GetBrain()

        local atkPri = { 'STRUCTURE STRATEGIC', 'STRUCTURE ENERGYPRODUCTION', 'STRUCTURE SHIELD', 'STRUCTURE FACTORY', 'COMMAND', 
            'STRUCTURE DEFENSE', 'EXPERIMENTAL LAND', 'MOBILE TECH3 LAND', 'MOBILE TECH2 LAND', 'SPECIALLOWPRI', 'ALLUNITS' }
        local atkPriTable = {}
        for k,v in atkPri do
            table.insert(atkPriTable, ParseEntityCategory(v))
        end

        --DUNCAN - changed from Attack group
        self:SetPrioritizedTargetList('Artillery', atkPriTable)

        -- Set priorities on the unit so if the target has died it will reprioritize before the platoon does
        local unit = false
        for k,v in self:GetPlatoonUnits() do
            if not v.Dead then
                unit = v
                break
            end
        end
        if not unit then
            return
        end
        unit:SetTargetPriorities(atkPriTable)
        local bp = unit:GetBlueprint()
        local weapon = bp.Weapon[1]
        local maxRadius = weapon.MaxRadius

        while aiBrain:PlatoonExists(self) do
            local target = self:FindPrioritizedUnit('Artillery', 'Enemy', true, self:GetPlatoonPosition(), maxRadius)
            if target then
                self:Stop()
                self:AttackTarget(target)
            end
            WaitSeconds(20)
        end
    end,
}

--T4 Kanonenbot
--Speed 0.8
--High 12
--Impact after 18 map units

--Schüssel
--Speed 0.8
--High 25
--Impact after 26 map units

--T4 Bomber
--Speed 2.0
--High 25
--Impact after 60

--T3 Bomber
--Speed 1.6
--High 20
--Impact after 

--T2 Kanonenbot
--Speed 1.2
--High 10
--Impact after 12  map units

