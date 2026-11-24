local hnsActions = {}
local function GetPillEnt(ply)
    if not IsValid(ply) then return nil end
    if pk_pills and pk_pills.getMappedEnt then
        local e = pk_pills.getMappedEnt(ply)
        if IsValid(e) then return e end
    end
    if IsValid(ply.pk_pill_ent) then return ply.pk_pill_ent end
end

hook.Add("PlayerFootstep", "wmv_MuteSteps_PlayerFootstep", function(ply)
    local ent = GetPillEnt(ply)
    if not IsValid(ent) or not ent.formTable then return end
    if ent.formTable.muteSteps == true then
        return true
    end
end)

local WMV_MIMIC_STEP_SCRIPT_SOUNDS = {
    ["nexus.wmv.walk"] = true,
    ["nexus.wmv.cwalk"] = true,
    ["nexus.wmv.run"] = true,
}

local WMV_MIMIC_STEP_SOUND_PATHS = {
    "nexus/939/scp_939_footstep",
    "nexus/939/scp_939_footstep_crouch",
}

local function WMV_IsMimicStepSound(snd)
    snd = string.lower(snd or "")

    if WMV_MIMIC_STEP_SCRIPT_SOUNDS[snd] then
        return true
    end

    for _, path in ipairs(WMV_MIMIC_STEP_SOUND_PATHS) do
        if string.find(snd, path, 1, true) then
            return true
        end
    end
end

local function WMV_IsMimicStepSound(snd)
    snd = string.lower(snd or "")

    if WMV_MIMIC_STEP_SCRIPT_SOUNDS[snd] then
        return true
    end

    for _, path in ipairs(WMV_MIMIC_STEP_SOUND_PATHS) do
        if string.find(snd, path, 1, true) then
            return true
        end
    end

    return false
end

local function WMV_GetPillFromSoundEntity(e)
    if not IsValid(e) then return nil end

    if e:IsPlayer() then
        return GetPillEnt(e)
    end

    if e:GetClass() == "pill_ent_costume" then
        return e
    end

    local parent = e.GetParent and e:GetParent() or nil

    if IsValid(parent) then
        if parent:IsPlayer() then
            return GetPillEnt(parent)
        end

        if parent:GetClass() == "pill_ent_costume" then
            return parent
        end
    end

    for _, pillEnt in ipairs(ents.FindByClass("pill_ent_costume")) do
        if not IsValid(pillEnt) then continue end

        local puppet = pillEnt.GetPuppet and pillEnt:GetPuppet() or nil
        if puppet == e then
            return pillEnt
        end
    end

    return nil
end


hook.Add("EntityEmitSound", "wmv_MuteSteps_EmitSound", function(t)
    if not t then return end

    local e = t.Entity
    local s = t.SoundName or ""
    if s == "" then return end

    local pillEnt = WMV_GetPillFromSoundEntity(e)
    if not IsValid(pillEnt) or not pillEnt.formTable then return end


    if pillEnt:GetNWFloat("WMV_MIMIC_STEPS_MUTED_UNTIL", 0) > CurTime() then
        if WMV_IsMimicStepSound(s) then
            return false
        end
    end

    -- Normal passive muteSteps behavior.
    if pillEnt.formTable.muteSteps ~= true then return end

    if string.find(string.lower(s), "player/footsteps/", 1, true) then
        return false
    end
end)

hook.Add("OnEntityCreated", "wmvt_initialize_gem_2", function(ent)
    timer.Simple(0.01, function()
        if !IsValid(ent) then return end
        if ent:GetClass() ~= "pill_ent_costume" then return end


        if ent.formTable then
            local PuppetEntity = ent:GetPuppet()
            local targetOrigin = ent:LocalToWorld(Vector(0, 0, 50))
local entity
if SherlockHNS then
    entity = SherlockHNS.FindVictim(ply, targetOrigin, 130, {
        filter = function(v)
            local trace = util.TraceLine({
                start = ent:EyePos(),
                endpos = v:EyePos(),
                filter = {ent, ply},
                mask = MASK_VISIBLE
            })
            return not trace.Hit
        end,
    })
else
    for k, v in pairs(ents.FindInSphere(ent:LocalToWorld(Vector(0, 0, 50)), 130)) do
                    if v:IsPlayer() or v:IsNextBot() or v:IsNPC() then
                        if v == ent or v == ply then continue end
        
                        if (v:IsPlayer() and v:Team() ~= TEAM_SPECTATOR) or ((v:IsNPC() or v:IsNextBot()) and v:Health() > 0) then
                            local trace = util.TraceLine({
                                start = ent:EyePos(),
                                endpos = v:EyePos(),
                                filter = {ent, ply},
                                mask = MASK_VISIBLE
                            })
        
                            if not trace.Hit then
                                entity = v
                                break
                            end
                        end
                    end
                end
end

if SherlockHNS and IsValid(entity) and entity:IsPlayer() then
                return pk_pills.playHNSJumpscare(ply, ent, entity, 0.7, {
                    camera = "wmv_jumpscare_gen",
                    offset = 50,
                    animation = "jumpscare",
                    sound = "jumpscare",
                    attachment = "camera",
                    ownerCamera = "wmv_pilljumpscare_gen",
                    ownerAttachment = "pillcamera",
                })
            end

            if not IsValid(entity) then return end
            ent:SetNWBool("WMV_MIDKILL", true)

            local DYN_RAGDOLL_YAW_OFFSET = 0
    
            local pill = ent:GetPuppet()
    
            if entity:IsPlayer() then
                entity:Freeze(true)
                entity:AddFlags(FL_NOTARGET)
                entity:DrawViewModel(false)
                entity:SetActiveWeapon(nil)
    
                net.Start('wmv_jumpscare_gen')
                net.WriteEntity(pill)       -- the puppet entity
                net.WriteBool(true)         -- start
                net.WriteString("camera")   -- victim uses the puppet's "camera" attachment
                net.Send(entity)
                
                -- start -> pill owner (ply)
                net.Start('wmv_pilljumpscare_gen')
                net.WriteEntity(pill)
                net.WriteBool(true)
                net.WriteString("pillcamera")
                net.Send(ply)

                SetVictimHidden(entity, true)

            else
                entity:NextThink(CurTime() + 1e9)
            end
    
            entity:SetPos(pill:GetPos() + pill:GetForward() * 50)
    
            ply:Freeze(true)
            ply:ConCommand("pk_pill_cl_thirdperson 0")
    
            ent:PillAnim('jumpscare')
            ent:PillSound('jumpscare')

            

            local DYN_KILL_OFFSET_FWD   = 5
            local DYN_KILL_OFFSET_RIGHT = 0
            local DYN_KILL_OFFSET_UP    = 1
            local DYN_RAGDOLL_YAW_OFFSET = 0
            
            local ragdoll_dynamic = ents.Create("prop_dynamic")
            if not IsValid(ragdoll_dynamic) then return end
            local seq = ragdoll_dynamic:LookupSequence("wos_wmvkill")
            ragdoll_dynamic:SetModel(entity:GetModel())
            local puppet = ent:GetPuppet()
            ragdoll_dynamic:SetParent(puppet)
            ragdoll_dynamic:SetLocalPos(Vector(
                DYN_KILL_OFFSET_FWD,
                DYN_KILL_OFFSET_RIGHT,
                DYN_KILL_OFFSET_UP
            ))
            
            ragdoll_dynamic:SetLocalAngles(Angle(0, DYN_RAGDOLL_YAW_OFFSET, 0))
            ragdoll_dynamic:Spawn()
            local ang = ent:GetPuppet():GetAngles()
            ang.p = 0
            ang.r = 0
            ang.y = ang.y + DYN_RAGDOLL_YAW_OFFSET
            ragdoll_dynamic:SetAngles(ang)
            if entity:IsNPC() or entity:IsNextBot() then
                ragdoll_dynamic:SetModelScale(0)
            else
                ragdoll_dynamic:SetModelScale(1)
            end

            timer.Create(entity:EntIndex() .. "_SequenceTimer", 0.0001, 500, function()
                if IsValid(ragdoll_dynamic) then
                    local seq = ragdoll_dynamic:LookupSequence("wos_wmvkill")
                    ragdoll_dynamic:ResetSequence(seq)
                    ragdoll_dynamic:SetCycle(0)
                end
            end)
            ragdoll_dynamic:Spawn()
            local victimEntIndex = entity:EntIndex()
            local sequenceTimerName = victimEntIndex .. "_SequenceTimer"
            
            ent:CallOnRemove("WMV_cleanup_dyn_" .. victimEntIndex, function()
                if IsValid(ragdoll_dynamic) then
                    ragdoll_dynamic:Remove()
                end
            
                timer.Remove(sequenceTimerName)
            end)


            for i = 0, ragdoll_dynamic:GetPhysicsObjectCount() - 1 do
                local phys = ragdoll_dynamic:GetPhysicsObjectNum(i)
                if IsValid(phys) then
                    phys:EnableMotion(false)
                end
            end

            timer.Simple(.03, function()
                if IsValid(entity) then
                    entity:SetNWBool("isPlayingDeathAnim", true)
                end
            end)

            timer.Simple(0.4, function()
                if not IsValid(ent) or not IsValid(ragdoll_dynamic) or not IsValid(pill) then return end
            
                local effectPos = WMV_GetBoneEffectPos(
                    pill,
                    "Upperjaw",
                    ragdoll_dynamic:GetPos()
                )
            
                for i = 1, 10 do
                    local ed = EffectData()
                    ed:SetOrigin(effectPos + VectorRand() * 22)
                    ed:SetNormal((VectorRand() + Vector(0, 0, 1)):GetNormalized())
                    ed:SetScale(18)
                    ed:SetRadius(40)
                    ed:SetMagnitude(35)
                    util.Effect("BloodImpact", ed, true, true)
                end
            
                for i = 1, 4 do
                    local ed = EffectData()
                    ed:SetOrigin(effectPos + VectorRand() * 18)
                    ed:SetNormal((pill:GetForward() + VectorRand() * 0.35):GetNormalized())
                    ed:SetScale(12)
                    ed:SetRadius(30)
                    ed:SetMagnitude(45)
                    util.Effect("bloodspray", ed, true, true)
                end
            end)
    
            timer.Simple(0.7, function()
                if not (IsValid(entity) and IsValid(ent)) then return end
    
                if entity:IsPlayer() then
                    entity:Kill(ply)
    
                    net.Start('wmv_jumpscare_gen')
                    net.WriteEntity(pill)
                    net.WriteBool(false)
                    net.WriteString("")
                    net.Send(entity)
    
                    entity:RemoveFlags(FL_NOTARGET)
                    entity:Freeze(false)
                    entity:DrawViewModel(true)
                else
                    entity:NextThink(CurTime())
                    entity:TakeDamage(1e9, ply)
                    
                end
            end)
    
            timer.Simple(1.2, function()
                ply.OnHold = false
            
                local victim = entity   -- capture before anything else can clobber it
                SetVictimHidden(victim, false)
            
            
                if IsValid(ragdoll_dynamic) then ragdoll_dynamic:Remove() end
                timer.Remove(sequenceTimerName)
            
                ply:Freeze(false)
                ent:SetNWBool("WMV_MIDKILL", false)
            
                net.Start('wmv_pilljumpscare_gen')
                net.WriteEntity(pill)
                net.WriteBool(false)
                net.WriteString("")
                net.Send(ply)
            
                ply:ConCommand("pk_pill_cl_thirdperson 1")
                entity = nil
            end)
        end,
    },
	
    --Right Click Attack Function
	attack2={
        mode = "trigger",
        func = function(ply, ent)
            ent:PillSound("rclick")
    end,
},
    

noragdoll=true,
	
	-- R click function
    reload = function(ply, ent)
        
    end,
	
    
    flashlight=function(ply,ent)
        
    end,
	
	-- Jump Attack Spacebar Function 
    jump=function(ply,ent)
        
    end
}, function(form)
    -- The legacy damage branches are for Sandbox and NPCs.
    form.hnsKillAPI = true
    form.hnsAbilities = {
        { id = "wmv_amnesticgas", name = "Gás amnésico", keyLabel = "2", OnUse = hnsActions.wmv_amnesticgas },
        { id = "wmv_mimicry", name = "Imitar voz", keyLabel = "3", OnUse = hnsActions.wmv_mimicry },
        { id = "wmv_cycle", name = "Selecionar voz", keyLabel = "R", OnUse = hnsActions.wmv_cycle },
        { id = "wmv_extendrange", name = "Ampliar sentidos", keyLabel = "1", OnUse = hnsActions.wmv_extendrange },
        { id = "attack", name = "Ataque", key = IN_ATTACK, OnUse = form.attack.func },
        { id = "voice", name = "Vocalização", key = IN_ATTACK2, OnUse = form.attack2.func },
    }
    form.attack, form.attack2, form.reload = nil, nil, nil
    pk_pills.bindHNSButtons(form, "wmvThermalVision", {
        { id = "thermal", name = "Visão térmica", button = KEY_N, keyLabel = "N", cooldown = 0.2 },
    })
end)


