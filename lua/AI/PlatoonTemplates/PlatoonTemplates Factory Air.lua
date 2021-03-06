PlatoonTemplate {
    Name = 'SwarmAIFighterGroup',
    FactionSquads = {
        UEF = {
            { 'uea0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'uea0102', 1, 3, 'attack', 'None' },
            { 'uea0101', 1, 1, 'attack', 'GrowthFormation' },
        },
        Aeon = {
            { 'uaa0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'uaa0102', 1, 3, 'attack', 'None' },
            { 'uaa0101', 1, 1, 'attack', 'GrowthFormation' },
        },
        Cybran = {
            { 'ura0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'ura0102', 1, 3, 'attack', 'None' },
            { 'ura0101', 1, 1, 'attack', 'GrowthFormation' },
        },
        Seraphim = {
            { 'xsa0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'xsa0102', 1, 3, 'attack', 'None' },
            { 'xsa0101', 1, 1, 'attack', 'GrowthFormation' },
        },
    }
}

PlatoonTemplate {
    Name = 'SwarmAIT1AirAttack',
    FactionSquads = {
        UEF = {
            { 'uea0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'uea0102', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Fighter
            { 'uea0103', 1, 2, 'attack', 'GrowthFormation' }, -- T1 Bomber
        },
        Aeon = {
            { 'uaa0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'uaa0102', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Fighter
            { 'uaa0103', 1, 2, 'attack', 'GrowthFormation' }, -- T1 Bomber
        },
        Cybran = {
            { 'ura0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'ura0102', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Fighter
            { 'ura0103', 1, 2, 'attack', 'GrowthFormation' }, -- T1 Bomber
            { 'xra0105', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Gunship
            
        },
        Seraphim = {
            { 'xsa0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'xsa0102', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Fighter
            { 'xsa0103', 1, 2, 'attack', 'GrowthFormation' }, -- T1 Bomber
        },
    }
}

PlatoonTemplate {
    Name = 'SwarmAIFighterGroupT2',
    FactionSquads = {
        UEF = {
            { 'uea0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'uea0102', 1, 3, 'attack', 'None' }, -- T1 Fighter
            { 'dea0202', 1, 1, 'attack', 'None' }, -- T2 FighterBomber
        },
        Aeon = {
            { 'uaa0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'uaa0102', 1, 3, 'attack', 'None' }, -- T1 Fighter
            { 'xaa0202', 1, 1, 'attack', 'None' }, -- T2 Fighter
        },
        Cybran = {
            { 'ura0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'ura0102', 1, 3, 'attack', 'None' }, -- T1 Fighter
            { 'dra0202', 1, 1, 'attack', 'None' }, -- T2 FighterBomber
        },
        Seraphim = {
            { 'xsa0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'xsa0102', 1, 3, 'attack', 'None' }, -- T1 Fighter
            { 'xsa0202', 1, 1, 'attack', 'None' }, -- T2 FighterBomber
        },
    }
}

PlatoonTemplate {
    Name = 'SwarmAIT2AirAttack',
    FactionSquads = {
        UEF = {
            { 'uea0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'dea0202', 1, 2, 'attack', 'None' }, -- FighterBomber
            { 'uea0203', 1, 2, 'attack', 'None' }, -- Gunship
        },
        Aeon = {
            { 'uaa0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'xaa0202', 1, 1, 'attack', 'None' },-- Fighter
            { 'uaa0203', 1, 2, 'attack', 'None' },-- Gunship
        },
        Cybran = {
            { 'ura0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'dra0202', 1, 2, 'attack', 'None' },-- FighterBomber
            { 'ura0203', 1, 2, 'attack', 'None' },-- Gunship
        },
        Seraphim = {
            { 'xsa0101', 1, 1, 'attack', 'GrowthFormation' },
            { 'xsa0202', 1, 2, 'attack', 'None' },-- FighterBomber
            { 'xsa0203', 1, 2, 'attack', 'None' }, -- Gunship
        },
    },
}

PlatoonTemplate { 
    Name = 'SwarmAIT3AirFighterGroup',
    FactionSquads = {
        UEF = {
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 3, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'uea0305', 1, 1, 'Guard', 'none' },   -- Gunship
         },
        Aeon = {
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 3, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xaa0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Cybran = {
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0304', 2, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 3, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xra0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Seraphim = {
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 3, 'attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0304', 1, 1, 'Artillery', 'none' },       -- Strategic Bomber
            { 'xsa0303', 1, 2, 'Attack', 'none' },   -- Air Superiority Fighter
        },
    }
}

PlatoonTemplate { 
    Name = 'SwarmAIT3AirAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'uea0305', 1, 1, 'Guard', 'none' },   -- Gunship
         },
        Aeon = {
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xaa0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Cybran = {
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0304', 2, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xra0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Seraphim = {
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 1, 'attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0304', 1, 1, 'Artillery', 'none' },       -- Strategic Bomber
            { 'xsa0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
        },
    }
}