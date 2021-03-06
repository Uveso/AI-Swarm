
SwarmAIBrainClass = AIBrain
AIBrain = Class(SwarmAIBrainClass) {

    -- Hook AI-Swarm, set self.Swarm = true
    OnCreateAI = function(self, planName)
        SwarmAIBrainClass.OnCreateAI(self, planName)
        local per = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        if string.find(per, 'swarm') then
            LOG('* AI-Swarm: OnCreateAI() found AI-Swarm  Name: ('..self.Name..') - personality: ('..per..') ')
            self.Swarm = true
        end
    end,

   ExpansionHelpThread = function(self)
       -- Only use this with AI-Swarm
        if not self.Swarm then
            return SwarmAIBrainClass.ExpansionHelpThread(self)
        end
        coroutine.yield(10)
        -- We are leaving this forked thread here because we don't need it.
        KillThread(CurrentThread())
    end,

    InitializeEconomyState = function(self)
        -- Only use this with AI-Swarm
        if not self.Swarm then
            return SwarmAIBrainClass.InitializeEconomyState(self)
        end
    end,

    OnIntelChange = function(self, blip, reconType, val)
        -- Only use this with AI-Swarm
        if not self.Swarm then
            return SwarmAIBrainClass.OnIntelChange(self, blip, reconType, val)
        end
    end,

    SetupAttackVectorsThread = function(self)
       -- Only use this with AI-Swarm
        if not self.Swarm then
            return SwarmAIBrainClass.SetupAttackVectorsThread(self)
        end
        coroutine.yield(10)
        -- We are leaving this forked thread here because we don't need it.
        KillThread(CurrentThread())
    end,

    ParseIntelThread = function(self)
       -- Only use this with AI-Swarm
        if not self.Swarm then
            return SwarmAIBrainClass.ParseIntelThread(self)
        end
        coroutine.yield(10)
        -- We are leaving this forked thread here because we don't need it.
        KillThread(CurrentThread())
    end,
}
