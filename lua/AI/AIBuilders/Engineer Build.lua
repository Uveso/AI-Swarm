local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

local BasePanicZone, BaseMilitaryZone, BaseEnemyZone = import('/mods/AI-Swarm/lua/AI/swarmutilities.lua').GetDangerZoneRadii()

local MaxCapEngineers = 0.08 -- 8% of all units can be Engineers (categories.MOBILE * categories.ENGINEER)

-- ===================================================-======================================================== --
-- ==                                 Build Engineers TECH 1,2,3 and SACU                                    == --
-- ===================================================-======================================================== --
BuilderGroup { BuilderGroupName = 'Swarm Engineer Builders',
    BuildersType = 'FactoryBuilder',
    
    -- ============ --
    --    TECH 1    --
    -- ============ --
    Builder { BuilderName = 'S1 Engineer builder - Opener',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 1100,
        BuilderConditions = {
            { UCBC, 'UnitCapCheckLess', { 0.95 } },

            { EBC, 'GreaterThanEconIncomeSwarm', { 0, 0 } },

            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER } },
         },
        BuilderType = 'All',
    },

    Builder { BuilderName = 'S1 Engineer builder Cap',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 1005,
        BuilderConditions = {
            { UCBC, 'UnitCapCheckLess', { 0.95 } },

            { EBC, 'GreaterThanEconIncomeSwarm', { 0, 0 } },

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, categories.MOBILE * categories.ENGINEER * categories.TECH1 } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.MOBILE * categories.ENGINEER * categories.TECH1} },

            { UCBC, 'GreaterThanGameTimeSeconds', { 120 } },
         },
        BuilderType = 'All',
    },

    Builder { BuilderName = 'S1 Engineer builder - Excess Mass',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 1010,
        BuilderConditions = {
            { UCBC, 'UnitCapCheckLess', { 0.95 } },

            { EBC, 'GreaterThanEconIncomeSwarm', { 0, 0 } },

            { EBC, 'GreaterThanEconStorageRatioSwarm', { 0.98, 0.50 } }, 

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 2, categories.MOBILE * categories.ENGINEER * categories.TECH1 } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.MOBILE * categories.ENGINEER * categories.TECH1} },
         },
        BuilderType = 'All',
    },

    -- ============ --
    --    TECH 2    --
    -- ============ --
    Builder { BuilderName = 'S2 Engineer builder Cap',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 1015,
        BuilderConditions = {
            { UCBC, 'UnitCapCheckLess', { 0.95 } },

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, categories.MOBILE * categories.ENGINEER * categories.TECH2 } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.MOBILE * categories.ENGINEER * categories.TECH2} },
        },
        BuilderType = 'All',
    },

    Builder { BuilderName = 'S2 Engineer builder - Excess Mass',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 1020,
        BuilderConditions = {
            { UCBC, 'UnitCapCheckLess', { 0.95 } },

            { EBC, 'GreaterThanEconIncomeSwarm', { 0, 0 } },

            { EBC, 'GreaterThanEconStorageRatioSwarm', { 0.98, 0.50 } }, 

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 2, categories.MOBILE * categories.ENGINEER * categories.TECH2 } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.MOBILE * categories.ENGINEER * categories.TECH2} },
         },
        BuilderType = 'All',
    },

    -- ============ --
    --    TECH 3    --
    -- ============ --
    Builder { BuilderName = 'S3 Engineer builder Cap',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 1025,
        BuilderConditions = {
            { UCBC, 'UnitCapCheckLess', { 0.95 } },

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, categories.MOBILE * categories.ENGINEER * categories.TECH3 } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.MOBILE * categories.ENGINEER * categories.TECH1} },
        },
        BuilderType = 'All',
    },

    Builder { BuilderName = 'S3 Engineer builder - Excess Mass',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 1030,
        BuilderConditions = {
            { UCBC, 'UnitCapCheckLess', { 0.95 } },

            { EBC, 'GreaterThanEconIncomeSwarm', { 0, 0 } },

            { EBC, 'GreaterThanEconStorageRatioSwarm', { 0.98, 0.50 } }, 

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 2, categories.MOBILE * categories.ENGINEER * categories.TECH3 } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.MOBILE * categories.ENGINEER * categories.TECH3} },
         },
        BuilderType = 'All',
    },
}

BuilderGroup {
    BuilderGroupName = 'Swarm Engineering Support Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'AISwarm T2 Engineering Support UEF',
        PlatoonTemplate = 'UEFT2EngineerBuilder',
        Priority = 200,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'ENGINEERSTATION' }},

            { UCBC, 'EngineerGreaterAtLocation', { 'LocationType', 1, 'ENGINEER TECH2' } },

            { EBC, 'GreaterThanEconIncomeSwarm',  { 10, 100}},

            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.95, 1.4 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = 'FACTORY',
                BuildClose = true,
                FactionIndex = 1,
                BuildStructures = {
                    'T2EngineerSupport',
                },
            }
        }
    },
    Builder {
        BuilderName = 'AISwarm T2 Engineering Support Cybran',
        PlatoonTemplate = 'CybranT2EngineerBuilder',
        Priority = 200,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'ENGINEERSTATION' }},

            { UCBC, 'EngineerGreaterAtLocation', { 'LocationType', 1, 'ENGINEER TECH2' } },

            { EBC, 'GreaterThanEconIncomeSwarm',  { 10, 100}},

            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.95, 1.4 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = 'FACTORY',
                BuildClose = true,
                FactionIndex = 3,
                BuildStructures = {
                    'T2EngineerSupport',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'Swarm Hive+Kennel Upgrade',                           
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'S2 Kennel Upgrade',
        PlatoonTemplate = 'S2KennelUpgrade',
        Priority = 1000,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1 }}, 

            { EBC, 'GreaterThanEconTrendSwarm', { 0.0, 0.0 } }, 

            { EBC, 'GreaterThanEconStorageRatioSwarm', { 0.25, 0.99 } }, 

            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradeSwarm', { 3, categories.ENGINEERSTATION }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'S2 Hive Upgrade',
        PlatoonTemplate = 'S2HiveUpgrade',
        Priority = 1000,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 }},

            { EBC, 'GreaterThanEconTrendSwarm', { 0.0, 0.0 } },

            { EBC, 'GreaterThanEconStorageRatioSwarm', { 0.25, 0.99 } },   

            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradeSwarm', { 3, categories.ENGINEERSTATION }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'S3 Hive Upgrade',
        PlatoonTemplate = 'S3HiveUpgrade',
        Priority = 1000,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 }}, 

            { EBC, 'GreaterThanEconTrendSwarm', { 0.0, 0.0 } },

            { EBC, 'GreaterThanEconStorageRatioSwarm', { 0.30, 0.99 } },        

            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradeSwarm', { 3, categories.ENGINEERSTATION }},
        },
        BuilderType = 'Any',
    },
}


BuilderGroup { BuilderGroupName = 'Swarm SACU Builder',
    BuildersType = 'FactoryBuilder',


    Builder {
        BuilderName = 'S3 SubCommander RAMBO',
        PlatoonTemplate = 'S3 SACU RAMBO preset 12345',
        Priority = 1017,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconStorageRatioSwarm', { 0.30, 0.50}}, 

            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.RAMBOPRESET } },

            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, categories.RAMBOPRESET }},
        },
        BuilderType = 'Gate',
    },
    Builder {
        BuilderName = 'S3 SubCommander ENGINEER',
        PlatoonTemplate = 'S3 SACU ENGINEER preset 12345',
        Priority = 1020,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioSwarm', { 0.80, 0.85}},

            { MIBC, 'FactionIndex', { 1, 2, 3, 5 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 

            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.ENGINEERPRESET + categories.RASPRESET } },

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, categories.ENGINEERPRESET + categories.RASPRESET } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.ENGINEERPRESET + categories.RASPRESET} },
        },
        BuilderType = 'Gate',
    },

    Builder {
        BuilderName = 'S3 SubCommander ENGINEER - Seraphim',
        PlatoonTemplate = 'S3 SACU ENGINEER preset 12345',
        Priority = 1020,
        BuilderConditions = {
        	{ MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads

            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.ENGINEERPRESET + categories.RASPRESET } },

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, categories.ENGINEERPRESET + categories.RASPRESET } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 10, categories.ENGINEERPRESET + categories.RASPRESET} },
        },
        BuilderType = 'Gate',
    },
     
    Builder {
        BuilderName = 'S3 SubCommander RAS',
        PlatoonTemplate = 'S3 SACU RAS preset 123x5',
        Priority = 1020,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.ENGINEERPRESET + categories.RASPRESET } },

            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, categories.ENGINEERPRESET + categories.RASPRESET } },

            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 10, categories.ENGINEERPRESET + categories.RASPRESET} },
        },
        BuilderType = 'Gate',
    },
}    

-- ===================================================-======================================================== --
-- ==                                          Engineer Transfers                                            == --
-- ===================================================-======================================================== --
--[[ BuilderGroup { BuilderGroupName = 'Swarm Engineer Transfer To MainBase',
    BuildersType = 'PlatoonFormBuilder',
    -- ============================================ --
    --    Transfer from LocationType to MainBase    --
    -- ============================================ --

    Builder { BuilderName = 'S1 Engi Trans to MainBase',
        PlatoonTemplate = 'S1EngineerTransfer',
        Priority = 650,
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSeconds', { 60 } },
            { UCBC, 'BuildNotOnLocationSwarm', { 'LocationType', 'MAIN' } },
            { UCBC, 'EngineerManagerUnitsAtLocationSwarm', { 'LocationType', '>', 3,  categories.MOBILE * categories.TECH1 } },
        },
        BuilderData = {
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },


    Builder { BuilderName = 'S2 Engi Trans to MainBase',
        PlatoonTemplate = 'S2EngineerTransfer',
        Priority = 750,
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSeconds', { 90 } },
            { UCBC, 'BuildNotOnLocationSwarm', { 'LocationType', 'MAIN' } },
            { UCBC, 'EngineerManagerUnitsAtLocationSwarm', { 'LocationType', '>', 3,  categories.MOBILE * categories.TECH2 } },
        },
        BuilderData = {
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },


    Builder { BuilderName = 'S3 Engi Trans to MainBase',
        PlatoonTemplate = 'S3EngineerTransfer',
        Priority = 850,
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSeconds', { 120 } },
            { UCBC, 'BuildNotOnLocationSwarm', { 'LocationType', 'MAIN' } },
            { UCBC, 'EngineerManagerUnitsAtLocationSwarm', { 'LocationType', '>', 3,  categories.MOBILE * categories.TECH3 } },
        },
        BuilderData = {
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },
} ]]--
