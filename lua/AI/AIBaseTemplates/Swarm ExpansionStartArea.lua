#***************************************************************************
#*
#**  File     :  /lua/ai/AIBaseTemplates/TurtleExpansion.lua
#**
#**  Summary  : Manage engineers for a location
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

BaseBuilderTemplate {
    BaseTemplateName = 'SwarmStartArea',
    Builders = {
        -----------------------------------------------------------------------------
        -- ==== Expansion Builders ==== --
        -----------------------------------------------------------------------------
        -- Build an Expansion
        'Swarm Expansion Builder', 

        -----------------------------------------------------------------------------
        -- ==== Engineer ==== --
        -----------------------------------------------------------------------------
        -- Build Engineers Tech 1,2,3 and SACU
        'Swarm Engineer Builders',            -- Priority = 900
        'Swarm Engineering Support Builder',
        -- Assistees
        'Swarm Engineer Assistees',
        -- Reclaim mass
        'Swarm Engineer Reclaim',
        -- Return engineers back to base
        'Swarm Engineer Transfer To MainBase',

        -----------------------------------------------------------------------------
        -- ==== Mass ==== --
        -----------------------------------------------------------------------------
        -- Build MassExtractors / Creators
        'U1 MassBuilders',
        -- Build Mass Storage (Adjacency)
        'U1 MassStorage Builder',

        -----------------------------------------------------------------------------
        -- ==== Energy ==== --
        -----------------------------------------------------------------------------
        -- Build Power Tech 1,2,3
        'U123 Energy Builders',                       -- Priority = 1100

        -----------------------------------------------------------------------------
        -- ==== Factory ==== --
        -----------------------------------------------------------------------------
        -- Build Land/Air Factories
        'Swarm Factory Builders Expansions',
        -- Upgrade Factories TECH1->TECH2 and TECH2->TECH3
        'Swarm Factory Upgrader Rush',

        -----------------------------------------------------------------------------
        -- ==== Land Units BUILDER ==== --
        -----------------------------------------------------------------------------
        'Swarm Land Builders Ratio',

        -----------------------------------------------------------------------------
        -- ==== Land Units FORMER==== --
        -----------------------------------------------------------------------------
        'AISwarm Platoon Builder',

        -----------------------------------------------------------------------------
        -- ==== Air Units BUILDER ==== --
        -----------------------------------------------------------------------------
        'Swarm Air Builders',
        -- Build Air Transporter
        'Swarm Air Transport Builders',

        -----------------------------------------------------------------------------
        -- ==== Air Units FORMER==== --
        -----------------------------------------------------------------------------
        'Swarm Air Formers',
        
        -----------------------------------------------------------------------------
        -- ==== EXPERIMENTALS BUILDER ==== --
        -----------------------------------------------------------------------------
        'Swarm Land Experimental Builders',
        'Swarm Air Experimental Builders',
        'U4 Economic Experimental Builders',
        
        -----------------------------------------------------------------------------
        -- ==== EXPERIMENTALS FORMER ==== --
        -----------------------------------------------------------------------------
        'Swarm Land Experimental Formers',
        'Swarm Air Experimental Formers PanicZone',
        'Swarm Air Experimental Formers MilitaryZone',
        'Swarm Air Experimental Formers EnemyZone',
        'Swarm Air Experimental Formers Trasher',

        -----------------------------------------------------------------------------
        -- ==== Structure Shield BUILDER ==== --
        -----------------------------------------------------------------------------
        'Swarm Shields Builder',
        'Swarm Shields Upgrader',

        -----------------------------------------------------------------------------
        -- ==== Defenses BUILDER ==== --
        -----------------------------------------------------------------------------
        'Swarm Strategic Builder',
        'Strategic Platoon Formers',
        'Swarm T2 Tactical Missile Defenses Builder',
        'Swarm SMD Builder',
        
        -- Build Anti Air near AirFactories
        'Swarm Defense Anti Air Builders',

        'Swarm Defense Anti Ground Builders',
        -----------------------------------------------------------------------------
        -- ==== FireBase BUILDER ==== --
        -----------------------------------------------------------------------------

        -----------------------------------------------------------------------------
        -- ==== Scout BUILDER ==== --
        -----------------------------------------------------------------------------

        -----------------------------------------------------------------------------
        -- ==== Scout FORMER ==== --
        -----------------------------------------------------------------------------

    },
    -- We need intel in case the commander is dead.
    NonCheatBuilders = {

    },

    BaseSettings = {
        FactoryCount = {
            Land = 4,
            Air = 1,
            Sea = 1,
            Gate = 0,
        },
        EngineerCount = {
            Tech1 = 2,
            Tech2 = 1,
            Tech3 = 1,
            SCU = 0,
        },
        MassToFactoryValues = {
            T1Value = 6,
            T2Value = 15,
            T3Value = 22.5
        },
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if markerType ~= 'Start Location' then
            return -1
        end
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        if personality == 'swarmgrowing' or personality == 'swarmgrowingcheat' 
        or personality == 'swarmterror' or personality == 'swarmterrorcheat' 
        or personality == 'eternalswarm' or personality == 'eternalswarm' then
            return 5000, 'swarmterror'
        end
    end,
}
