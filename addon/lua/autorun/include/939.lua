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
            local entityply = ent:GetPillUser()


            if ent.formTable.wmv_initialize then
                ent.formTable:wmv_initialize(entityply, ent, PuppetEntity)
                local hookID = "DisableFootstepID_OM:" .. ent:EntIndex()

                hook.Add("PlayerFootstep", hookID, function(ply, pos, foot, sound, volume, filter)
                    if not IsValid(ent) then
                        hook.Remove("PlayerFootstep", hookID)
                        return
                    end
                
                    local owner = ent:GetPillUser()
                    if IsValid(owner) and ply == owner then
                        return true
                    end
                end)
                
                if SERVER then
                    ent:CallOnRemove("RemoveHook_OM" .. ent:EntIndex(), function()
                        hook.Remove("PlayerFootstep", hookID)
                    end)
                end

                local self = ent
                ent.Think = function()
                    local ply = self:GetPillUser()
                    local puppet = self:GetPuppet()
                    if not IsValid(puppet) or not IsValid(ply) then return end
                    local vel = ply:GetVelocity():Length()

                    if SERVER then
                        --Anims
                        local anims = table.Copy(self.formTable.anims.default or {})
                        table.Merge(anims, (IsValid(ply:GetActiveWeapon()) and self.formTable.anims[ply:GetActiveWeapon():GetHoldType()]) or (self.forceAnimSet and self.formTable.anims[self.forceAnimSet]) or {})
                        local anim
                        --local useSeqVel=true
                        local overrideRate

                        if (not self.anim or not anims[self.anim]) then
                            self.animFreeze = nil
                            self.animStart = nil
                        end

                        if self.animFreeze and not self.plyFrozen then
                            self:ApplyMoveSpeed()
                            self.plyFrozen = true
                        elseif not self.animFreeze and self.plyFrozen then
                            self:ApplyMoveSpeed()
                            self.plyFrozen = nil
                        end

                        if self.anim and anims[self.anim] then
                            anim = anims[self.anim]
                            overrideRate = anims[self.anim .. "_rate"] or 1
                            local cycle = puppet:GetCycle()

                            if not self.animStart then
                                if cycle == 1 or (self.animCycle and self.animCycle > cycle) or (string.lower(anim) ~= string.lower(puppet:GetSequenceName(puppet:GetSequence()))) then
                                    self.anim = nil
                                    self.animCycle = nil

                                    if self.animFreeze then
                                        self.animFreeze = nil
                                    end
                                elseif self.animCycle then
                                    self.animCycle = cycle
                                end
                            end
                        elseif self.tickAnim and anims[self.tickAnim] then
                            anim = anims[self.tickAnim]
                            overrideRate = anims[self.tickAnim .. "_rate"] or 1
                            self.tickAnim = nil
                        elseif self.burrowed then
                            anim = anims["burrow_loop"]
                        elseif ply:WaterLevel() > 2 then
                            anim = anims["swim"] or anims["glide"] or anims["idle"]
                        elseif ply:IsOnGround() then
                            if ply:Crouching() then
                                if vel > ply:GetCrouchedWalkSpeed() / 4 then
                                    anim = anims["crouch_walk"] or anims["crouch"] or anims["walk"] or anims["idle"]
                                else
                                    anim = anims["crouch"] or anims["idle"]
                                end
                            else
                                if vel > (ply:GetWalkSpeed() + ply:GetRunSpeed()) / 2 then
                                    anim = anims["run"] or anims["walk"] or anims["idle"]
                                elseif vel > ply:GetWalkSpeed() / 4 then
                                    anim = anims["walk"] or anims["idle"]
                                else
                                    anim = anims["idle"]
                                end
                            end
                        else
                            anim = anims["glide"] or anims["idle"]
                        end

                        if anim == anims["idle"] or anim == anims["crouch"] then
                            overrideRate = 1
                        end
                        
                        if isIdleNow and not self._wmv_WasIdle and CurTime() >= self._wmv_NextIdleSound then
                            self:PillSound("idle")
                            self._wmv_NextIdleSound = CurTime() + IDLE_SOUND_COOLDOWN
                        end
                        
                        self._wmv_WasIdle = isIdleNow

                        if (anim and puppet:GetSequence() ~= puppet:LookupSequence(anim)) or self.animStart or (self.formTable.autoRestartAnims and puppet:GetCycle() == 1) then
                            puppet:ResetSequence(puppet:LookupSequence(anim))
                            puppet:SetCycle(0)
                            self.animCycle = 0
                        end

                        self.animStart = nil
                        local seq_vel = puppet:GetSequenceGroundSpeed(puppet:GetSequence())



                        --print(puppet:GetCycle())
                        if self.formTable.movePoseMode then
                            --
                            if self.formTable.movePoseMode == "yaw" then
                                local move_dir = puppet:WorldToLocalAngles(ply:GetVelocity():Angle())
                                puppet:SetPoseParameter("move_yaw", move_dir.y)
                            elseif self.formTable.movePoseMode == "xy" then
                                if not overrideRate then
                                    local localvel = ply:WorldToLocal(ply:GetPos() + ply:GetVelocity())
                                    local maxdim = math.Max(math.abs(localvel.x), math.abs(localvel.y))
                                    local clampedvel = maxdim == 0 and Vector(0, 0, 0) or localvel / maxdim
                                    puppet:SetPoseParameter("move_x", clampedvel.x)
                                    puppet:SetPoseParameter("move_y", -clampedvel.y)
                                    seq_vel = puppet:GetSequenceGroundSpeed(puppet:GetSequence())

                                    if seq_vel ~= 0 then
                                        puppet:SetPoseParameter("move_x", math.Clamp(localvel.x / seq_vel, -.99, .99))
                                        puppet:SetPoseParameter("move_y", math.Clamp(-localvel.y / seq_vel, -.99, .99))
                                    end
                                    --print(puppet:GetPlaybackRate())
                                else
                                    puppet:SetPoseParameter("move_x", 0)
                                    puppet:SetPoseParameter("move_y", 0)
                                end
                            elseif self.formTable.movePoseMode == "xy-bot" then
                                if not overrideRate then
                                    local localvel = ply:WorldToLocal(ply:GetPos() + ply:GetVelocity())
                                    local maxdim = math.Max(math.abs(localvel.x), math.abs(localvel.y))
                                    local clampedvel = maxdim == 0 and Vector(0, 0, 0) or localvel / maxdim
                                    local move_dir = puppet:WorldToLocalAngles(ply:GetVelocity():Angle())
                                    puppet:SetPoseParameter("move_x", clampedvel.x)
                                    puppet:SetPoseParameter("move_y", -clampedvel.y)
                                    puppet:SetPoseParameter("move_yaw", move_dir.y)
                                    puppet:SetPoseParameter("move_scale", 1)
                                    seq_vel = puppet:GetSequenceGroundSpeed(puppet:GetSequence())

                                    if seq_vel ~= 0 then
                                        puppet:SetPoseParameter("move_x", math.Clamp(localvel.x / seq_vel, -.99, .99))
                                        puppet:SetPoseParameter("move_y", math.Clamp(-localvel.y / seq_vel, -.99, .99))
                                        puppet:SetPoseParameter("move_scale", math.Clamp(localvel:Length() / seq_vel, -.99, .99))
                                    end
                                    --print(puppet:GetPlaybackRate())
                                else
                                    puppet:SetPoseParameter("move_x", 0)
                                    puppet:SetPoseParameter("move_y", 0)
                                    puppet:SetPoseParameter("move_yaw", 0)
                                    puppet:SetPoseParameter("move_scale", 0)
                                end
                            end
                        end

                        --Aimage
                        if self.formTable.aim then
                            if self.formTable.aim.xPose then
                                local yaw = math.AngleDifference(ply:EyeAngles().y, self:GetAngles().y)

                                if self.formTable.aim.xInvert then
                                    yaw = -yaw
                                end

                                puppet:SetPoseParameter(self.formTable.aim.xPose, yaw)
                            end

                            if self.formTable.aim.yPose then
                                local pitch = math.AngleDifference(ply:EyeAngles().p, self:GetAngles().p)

                                if self.formTable.aim.yInvert then
                                    pitch = -pitch
                                end

                                puppet:SetPoseParameter(self.formTable.aim.yPose, pitch)
                            end
                        end

                        --gliding and landing
                        if not ply:IsOnGround() and ply:WaterLevel() == 0 and self.formTable.glideThink then
                            self.formTable.glideThink(ply, self)
                        end

                        if not ply:IsOnGround() and not self.touchingWater and ply:WaterLevel() > 0 and self.formTable.land then
                            self.formTable.land(ply, self)
                        end

                        --water death
                        self.touchingWater = ply:WaterLevel() > 1

                        if not SherlockHNS and self.formTable.damageFromWater and self.touchingWater then
                            if self.formTable.damageFromWater == -1 then
                                --self:PillDie()
                                ply:Kill()
                            else
                                ply:TakeDamage(self.formTable.damageFromWater)
                                --TODO APPLY DAMAGE
                            end
                        end

                        --tick attack
                        if ply:KeyDown(IN_ATTACK) and self.formTable.attack and self.formTable.attack.mode == "tick" then
                            self.formTable.attack.func(ply, self, self.formTable.attack)
                        end

                        if ply:KeyDown(IN_ATTACK2) and self.formTable.attack2 and self.formTable.attack2.mode == "tick" then
                            self.formTable.attack2.func(ply, self, self.formTable.attack2)
                        end

                        --auto attack
                        if ply:KeyDown(IN_ATTACK) and self.formTable.attack and self.formTable.attack.mode == "auto" then
                            if not self.formTable.aim then
                                self:PillLoopSound("attack")
                            else
                                self:PillLoopStop("attack")
                            end

                            if (not self.lastAttack or (self.formTable.attack.interval or self.formTable.attack.delay) < CurTime() - self.lastAttack) then
                                self.formTable.attack.func(ply, self, self.formTable.attack)
                                self.lastAttack = CurTime()
                            end
                        else
                            self:PillLoopStop("attack")
                        end

                        if ply:KeyDown(IN_ATTACK2) and self.formTable.attack2 and self.formTable.attack2.mode == "auto" then
                            if not self.formTable.aim then
                                self:PillLoopSound("attack2")
                            else
                                self:PillLoopStop("attack2")
                            end

                            if not self.lastAttack2 or (self.formTable.attack2.interval or self.formTable.attack2.delay) < CurTime() - self.lastAttack2 then
                                self.formTable.attack2.func(ply, self, self.formTable.attack2)
                                self.lastAttack2 = CurTime()
                            end
                        else
                            self:PillLoopStop("attack2")
                        end

                        --charge
                        if not SherlockHNS and self:GetChargeTime() ~= 0 then
                            if ply:OnGround() then
                                local charge = self.formTable.charge
                                local angs = ply:EyeAngles()
                                self:PillAnimTick("charge_loop")
                                local hit_ent = ply:TraceHullAttack(ply:EyePos(), ply:EyePos() + angs:Forward() * 100, Vector(-20, -20, -20), Vector(20, 20, 20), charge.dmg, DMG_CRUSH, 1, true)

                                if IsValid(hit_ent) then
                                    self:PillAnim("charge_hit", true)
                                    --self:PillGesture("charge_hit")
                                    self:PillSound("charge_hit")
                                    self:SetChargeTime(0)
                                    self:PillLoopStop("charge")
                                end
                            else
                                self:SetChargeTime(0)
                                self:PillLoopStop("charge")
                            end
                        end

                        --Cloak
                        if self.formTable.cloak then
                            local cloak = self.formTable.cloak

                            if self.iscloaked then
                                local cloakamt = self:GetCloakLeft()

                                if cloakamt ~= -1 then
                                    cloakamt = cloakamt - FrameTime()

                                    if cloakamt < 0 then
                                        cloakamt = 0
                                        self:ToggleCloak()
                                    end

                                    self:SetCloakLeft(cloakamt)
                                end
                            else
                                local cloakamt = self:GetCloakLeft()

                                if cloakmt ~= -1 and cloakamt < cloak.max then
                                    cloakamt = cloakamt + FrameTime() * cloak.rechargeRate

                                    if cloakamt > cloak.max then
                                        cloakamt = cloak.max
                                    end

                                    self:SetCloakLeft(cloakamt)
                                end
                            end

                            local color = self:GetPuppet():GetColor()

                            if self.iscloaked then
                                if color.a > 0 then
                                    color.a = color.a - 5
                                    self:GetPuppet():SetColor(color)
                                end
                            else
                                if color.a < 255 then
                                    color.a = color.a + 5
                                    self:GetPuppet():SetColor(color)
                                end
                            end

                            --PrintTable(color)
                            if IsValid(self.wepmdl) and self.wepmdl:GetColor().a ~= color.a then
                                self.wepmdl:SetColor(color)
                            end
                        end

                        --if !IsValid(ply) then self:NextThink(CurTime()) return true end
                        --wepon-no longer SO hackey
                        if not self.formTable.hideWeapons then
                            local realWep = self:GetPillUser():GetActiveWeapon()

                            --&&self:GetPillUser()!=ply or pk_pills.var_thirdperson:GetBool()) then
                            if IsValid(realWep) and realWep:GetModel() ~= "" then
                                --hiding the real thing [BROKEN]
                                --[[if realWep:GetRenderMode()!=RENDERMODE_NONE then
                                    realWep:SetRenderMode(RENDERMODE_NONE)
                                end]]
                                if realWep.pill_attachment then
                                    if IsValid(self.wepmdl) then
                                        self.wepmdl:Remove()
                                    end

                                    self.wepmdl = ents.Create("pill_attachment_wep")
                                    self.wepmdl:SetParent(self:GetPuppet())
                                    self.wepmdl:SetModel(realWep:GetModel())
                                    self.wepmdl.attachment = realWep.pill_attachment
                                    self.wepmdl:Spawn()

                                    if realWep.pill_offset then
                                        self.wepmdl:SetWepOffset(realWep.pill_offset)
                                    end

                                    if realWep.pill_angle then
                                        self.wepmdl:SetWepAng(realWep.pill_angle)
                                    end

                                    realWep.pill_proxy = self.wepmdl
                                elseif not IsValid(self.wepmdl) then
                                    self.wepmdl = ents.Create("pill_attachment_wep")
                                    self.wepmdl:SetParent(self:GetPuppet())
                                    self.wepmdl:SetModel(realWep:GetModel())
                                    self.wepmdl:Spawn()
                                    realWep.pill_proxy = self.wepmdl
                                elseif self.wepmdl:GetModel() ~= realWep:GetModel() then
                                    self.wepmdl:SetModel(realWep:GetModel())
                                end
                            elseif IsValid(self.wepmdl) then
                                self.wepmdl:Remove()
                            end
                        end
                    else
                        self:SetNWBool('clientsideshould', not pk_pills.convars.cl_thirdperson:GetBool())

                        if self:GetPillUser() == LocalPlayer() then
                            puppet:SetNoDraw(pk_pills.convars.cl_thirdperson:GetBool())
                        end

                        local realWep = self:GetPillUser():GetActiveWeapon()

                        if IsValid(realWep) and realWep:GetModel() ~= "" and not realWep:GetNoDraw() then
                            realWep:SetNoDraw(true)
                        end
                    end

                    --Align pos and angles with player
                    if SERVER then
                        puppet:SetPos(ply:GetPos())
                        self:SetAngles(ply:GetAngles())
                    else
                        puppet:SetRenderOrigin(ply:GetPos())
                    end

                    if vel > 0 or math.abs(math.AngleDifference(puppet:GetAngles().y, ply:EyeAngles().y)) > 350 or self:GetNWBool('clientsideshould') then
                        local angs = ply:EyeAngles()
                        angs.p = 0

                        if SERVER then
                            puppet:SetAngles(angs)
                        else
                            puppet:SetAngles(angs)
                            puppet:SetRenderAngles(angs)
                        end
                    end

                    self:NextThink(CurTime())

                    return true
                end


            else
            end
        end

        if ent.formTable.HandleAnimEvent_g_rac then
            print(1)
            local PuppetEntity = ent:GetPuppet()
            local entityply = ent:GetPillUser()

            if IsValid(PuppetEntity) then
                print(2)
                function PuppetEntity:AcceptInput(inputName, activator, caller, data)
                    ent.formTable.HandleAnimEvent_g_rac(entityply, ent, inputName)
                    return true
                end
            end
        end
    end)
end)

local wmv_FirstPersonPuppetOffsets = {
    pill_nwmv = Vector(0, 0, 0),
}

hook.Add("PostDrawOpaqueRenderables", "wmv_DrawLocalPillPuppet_FirstPerson", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local ent = pk_pills.getMappedEnt(ply)
    if not IsValid(ent) then return end
    if ent.formTable and ent.formTable.hud_id ~= "wmv" then return end
    if pk_pills.convars.cl_thirdperson:GetBool() then return end

    local puppet = ent.GetPuppet and ent:GetPuppet() or nil
    if not IsValid(puppet) then return end

    local oldNoDraw = puppet:GetNoDraw()
    local oldOrigin = puppet:GetRenderOrigin()
    local oldAngles = puppet:GetRenderAngles()

    local basePos = puppet:GetPos()
    local baseAng = puppet:GetAngles()
    local offset = wmv_FirstPersonPuppetOffsets[ent:GetClass()] or vector_origin

    local drawPos = basePos
        + baseAng:Forward() * offset.x
        + baseAng:Right() * offset.y
        + baseAng:Up() * offset.z

    local drawAng = Angle(0, ply:EyeAngles().y, 0)

    puppet:SetNoDraw(false)
    puppet:SetRenderOrigin(drawPos)
    puppet:SetRenderAngles(drawAng)
    puppet:SetupBones()
    puppet:DrawModel()
    puppet:SetRenderOrigin(oldOrigin)
    puppet:SetRenderAngles(oldAngles)
    puppet:SetNoDraw(oldNoDraw)
end)

hook.Add("Think", "TrackPillCostumes_wmv", function()
    for _, ent in ipairs(ents.FindByClass("pill_ent_costume")) do
        if !IsValid(ent) then continue end
        local ply = ent:GetPillUser()
        local puppet = ent:GetPuppet()

        if not IsValid(puppet) or not IsValid(ply) then continue end

        if ent.formTable.think_n_wmv then
            ent.formTable.think_n_wmv(ply, ent)
        end
    end
end)



if SERVER then
    AddCSLuaFile()
    util.AddNetworkString('wmv_jumpscare_gen')
    util.AddNetworkString('wmv_pilljumpscare_gen')
else

    hook.Add("InitPostEntity", "wmv_Init_CalcView", function()
        hook.Remove("CalcView", "wmv_939_calcview")

        hook.Add("CalcView", "wmv_939_calcview", function(ply, pos, ang, fov)
            local ent = pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(ply)
            if not IsValid(ent) then return end
            
            local hud = ent.formTable and ent.formTable.hud_id
            if hud ~= "wmv" then
                return
            end

        if IsValid(ent) and ply:GetViewEntity() == ply then
            local startpos

            if ent.formTable.type == "phys" then
                startpos = ent:LocalToWorld(ent.formTable.camera and ent.formTable.camera.offset or Vector(0, 0, 0))
            else
                startpos = pos
            end

            if pk_pills.convars.cl_thirdperson:GetBool() then

                if ent.formTable.ThirdPersonBone then

                    if IsValid(ent:GetPuppet()) then
                        local puppet = ent:GetPuppet()
                        local bonename = ent.formTable.ThirdPersonBone[1]
                        local boneID = puppet:LookupBone(bonename)
                        
                        puppet:InvalidateBoneCache()
                        puppet:SetupBones()
                        local rawBonePos, boneAng = puppet:GetBonePosition(boneID)
                        if not rawBonePos then return end
                        
                        -- Re-anchor: bone offset relative to puppet's logical pos, applied to render pos (player pos)
                        local boneOffset = rawBonePos - puppet:GetPos()
                        local bonePos = ply:GetPos() + boneOffset
                        
                        if bonePos:DistToSqr(ply:GetPos()) > (2000 * 2000) then
                            return
                        end

                        local dist

                        if ent.formTable.type == "phys" and ent.formTable.camera and ent.formTable.camera.distFromSize then
                            dist = ent:BoundingRadius() * 5
                        else
                            dist = ent.formTable.camera and ent.formTable.camera.dist or 100
                        end
                        local startpos = bonePos + LocalPlayer():GetForward() * (ent.formTable.ThirdPersonBone[2]) + LocalPlayer():GetUp() * (ent.formTable.ThirdPersonBone[4])+ LocalPlayer():GetRight() * (ent.formTable.ThirdPersonBone[3])
                        local underslung = ent.formTable.camera and ent.formTable.camera.underslung
                        local offset = LocalToWorld(Vector(-dist, 0, underslung and -dist / 5 or dist / 5), Angle(0, 0, 0), Vector(0, 0, 0), ang)

                        local tr = util.TraceHull({
                            start = startpos,
                            endpos = startpos + offset,
                            filter = ent.camTraceFilter,
                            mins = Vector(-5, -5, -5),
                            maxs = Vector(5, 5, 5),
                            mask = MASK_VISIBLE
                        })

                        local view = {}
                        view.origin = tr.HitPos
                        view.angles = ang
                        local pillFOV =
                        ent.formTable.camera and ent.formTable.camera.fov
                        or ent.formTable.viewFOV
                        or fov
                    
                        local finalFOV = pillFOV

                        local dur = ent:GetNWFloat("FOXY_FOV_DUR", 0)
                        if dur > 0 then
                            local t0 = ent:GetNWFloat("FOXY_FOV_T0", 0)
                            local delta = ent:GetNWFloat("FOXY_FOV_DELTA", 0)
                            local fadeOut = ent:GetNWFloat("FOXY_FOV_FADEOUT", 0.25)
                        
                            local now = CurTime()
                            local chargeT = math.Clamp((now - t0) / dur, 0, 1)
                        
                            local releaseT0 = ent:GetNWFloat("FOXY_FOV_REL_T0", 0)
                            local releasing = releaseT0 > 0
                        
                            if not releasing then
                                finalFOV = Lerp(chargeT, pillFOV, pillFOV + delta)
                            else
                                local rt = math.Clamp((now - releaseT0) / fadeOut, 0, 1)
                                finalFOV = Lerp(rt, pillFOV + delta, pillFOV)
                            end
                        end

                        local bdur = ent:GetNWFloat("wmv_FOV_DUR", 0)
                        if bdur > 0 then
                            local bt0 = ent:GetNWFloat("wmv_FOV_T0", 0)
                            local bdelta = ent:GetNWFloat("wmv_FOV_DELTA", 10)
                            local bfadeOut = ent:GetNWFloat("wmv_FOV_FADEOUT", 0.5)
                        
                            local now = CurTime()
                            local bchargeT = math.Clamp((now - bt0) / bdur, 0, 1)
                        
                            local brelT0 = ent:GetNWFloat("wmv_FOV_REL_T0", 0)
                            local breleasing = brelT0 > 0
                        
                            if not breleasing then
                                finalFOV = Lerp(bchargeT, finalFOV, finalFOV + bdelta)
                            else
                                local brt = math.Clamp((now - brelT0) / bfadeOut, 0, 1)
                                finalFOV = Lerp(brt, finalFOV + bdelta, finalFOV)
                            end
                        end
                        
                        view.fov = finalFOV
                        view.drawviewer = true

                        return view
                    end
                end

                local dist

                if ent.formTable.type == "phys" and ent.formTable.camera and ent.formTable.camera.distFromSize then
                    dist = ent:BoundingRadius() * 5
                else
                    dist = ent.formTable.camera and ent.formTable.camera.dist or 100
                end

                local underslung = ent.formTable.camera and ent.formTable.camera.underslung
                local offset = LocalToWorld(Vector(-dist, 0, underslung and -dist / 5 or dist / 5), Angle(0, 0, 0), Vector(0, 0, 0), ang)

                local tr = util.TraceHull({
                    start = startpos,
                    endpos = startpos + offset,
                    filter = ent.camTraceFilter,
                    mins = Vector(-5, -5, -5),
                    maxs = Vector(5, 5, 5),
                    mask = MASK_VISIBLE
                })

                local view = {}
                view.origin = tr.HitPos
                view.angles = ang
                local pillFOV =
                ent.formTable.camera and ent.formTable.camera.fov
                or ent.formTable.viewFOV
                or fov
            
                local finalFOV = pillFOV

                local dur = ent:GetNWFloat("FOXY_FOV_DUR", 0)
                if dur > 0 then
                    local t0 = ent:GetNWFloat("FOXY_FOV_T0", 0)
                    local delta = ent:GetNWFloat("FOXY_FOV_DELTA", 0)
                    local fadeOut = ent:GetNWFloat("FOXY_FOV_FADEOUT", 0.25)
                
                    local now = CurTime()
                    local chargeT = math.Clamp((now - t0) / dur, 0, 1)
                
                    local releaseT0 = ent:GetNWFloat("FOXY_FOV_REL_T0", 0)
                    local releasing = releaseT0 > 0
                
                    if not releasing then
                        finalFOV = Lerp(chargeT, pillFOV, pillFOV + delta)
                    else
                        local rt = math.Clamp((now - releaseT0) / fadeOut, 0, 1)
                        finalFOV = Lerp(rt, pillFOV + delta, pillFOV)
                    end
                end

                local bdur = ent:GetNWFloat("wmv_FOV_DUR", 0)
                if bdur > 0 then
                    local bt0 = ent:GetNWFloat("wmv_FOV_T0", 0)
                    local bdelta = ent:GetNWFloat("wmv_FOV_DELTA", 10)
                    local bfadeOut = ent:GetNWFloat("wmv_FOV_FADEOUT", 0.5)
                
                    local now = CurTime()
                    local bchargeT = math.Clamp((now - bt0) / bdur, 0, 1)
                
                    local brelT0 = ent:GetNWFloat("wmv_FOV_REL_T0", 0)
                    local breleasing = brelT0 > 0
                
                    if not breleasing then
                        finalFOV = Lerp(bchargeT, finalFOV, finalFOV + bdelta)
                    else
                        local brt = math.Clamp((now - brelT0) / bfadeOut, 0, 1)
                        finalFOV = Lerp(brt, finalFOV + bdelta, finalFOV)
                    end
                end
                
                view.fov = finalFOV
                view.drawviewer = true

                return view
            else
                if ent.formTable.FirstPersonBone then
                    if IsValid(ent:GetPuppet()) then
                        local bonename = ent.formTable.FirstPersonBone[1]
                        local boneID = ent:GetPuppet():LookupBone(bonename)
                        local bonePos, boneAng = ent:GetPuppet():GetBonePosition(boneID)
                        if not bonePos or bonePos == vector_origin or bonePos:DistToSqr(ply:GetPos()) > (2000 * 2000) then
                            return
                        end
                        local view = {}
                        view.origin = bonePos + LocalPlayer():GetForward() * (ent.formTable.FirstPersonBone[2]) + LocalPlayer():GetUp() * (ent.formTable.FirstPersonBone[4])+ LocalPlayer():GetRight() * (ent.formTable.FirstPersonBone[3])
                        view.angles = ang
                        local pillFOV =
                        ent.formTable.camera and ent.formTable.camera.fov
                        or ent.formTable.viewFOV
                        or fov
                    
                        local finalFOV = pillFOV

                        local dur = ent:GetNWFloat("FOXY_FOV_DUR", 0)
                        if dur > 0 then
                            local t0 = ent:GetNWFloat("FOXY_FOV_T0", 0)
                            local delta = ent:GetNWFloat("FOXY_FOV_DELTA", 0)
                            local fadeOut = ent:GetNWFloat("FOXY_FOV_FADEOUT", 0.25)
                        
                            local now = CurTime()
                            local chargeT = math.Clamp((now - t0) / dur, 0, 1)
                        
                            local releaseT0 = ent:GetNWFloat("FOXY_FOV_REL_T0", 0)
                            local releasing = releaseT0 > 0
                        
                            if not releasing then
                                finalFOV = Lerp(chargeT, pillFOV, pillFOV + delta)
                            else
                                local rt = math.Clamp((now - releaseT0) / fadeOut, 0, 1)
                                finalFOV = Lerp(rt, pillFOV + delta, pillFOV)
                            end
                        end

                        local bdur = ent:GetNWFloat("wmv_FOV_DUR", 0)
                        if bdur > 0 then
                            local bt0 = ent:GetNWFloat("wmv_FOV_T0", 0)
                            local bdelta = ent:GetNWFloat("wmv_FOV_DELTA", 10)
                            local bfadeOut = ent:GetNWFloat("wmv_FOV_FADEOUT", 0.5)
                        
                            local now = CurTime()
                            local bchargeT = math.Clamp((now - bt0) / bdur, 0, 1)
                        
                            local brelT0 = ent:GetNWFloat("wmv_FOV_REL_T0", 0)
                            local breleasing = brelT0 > 0
                        
                            if not breleasing then
                                finalFOV = Lerp(bchargeT, finalFOV, finalFOV + bdelta)
                            else
                                local brt = math.Clamp((now - brelT0) / bfadeOut, 0, 1)
                                finalFOV = Lerp(brt, finalFOV + bdelta, finalFOV)
                            end
                        end
                        
                        view.fov = finalFOV
                        view.drawviewer = true
                        return view
                    end
                end
            end
        end
    end)
end)



    hook.Add("SetupPlayerVisibility", "VisibilityHandler_v2", function()
        local ply = LocalPlayer()

        local pillentity = ply.pk_pill_ent
        if IsValid(pillentity) then
            if ( pillentity:GetNWInt('Swallhaks', 0) >= CurTime() ) then

                for _, ent in ipairs(ents.GetAll()) do
                    if IsValid(ent) then
                        if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
                            AddOriginToPVS(plr:GetPos())
                        end
                    end
                end
            end
        end
    end)


    hook.Add( "PreDrawHalos", "wmvseason_v2", function()
        local ply = LocalPlayer()

        local pillentity = ply.pk_pill_ent
        if IsValid(pillentity) then
            if ( pillentity:GetNWInt('Swallhaks', 0) >= CurTime() ) then
                local entities = {}

                for _, ent in ipairs(ents.GetAll()) do
                    if IsValid(ent) then
                        if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
                            if ent == ply then continue end 
                            if ent == pillentity then continue end 
                            if ent:IsPlayer() and ent:Team() == TEAM_SPECTATOR then continue end

                            if ent:GetColor().a <= 30 then continue end
                            if ent:GetClass() == "pill_puppet" then continue end

                            table.insert(entities, ent)
                            
                        end
                    end
                end

                local alpha = 0
                local endTime = pillentity:GetNWInt('Swallhaks', 0) 

                if endTime > CurTime() then
                    local totalDuration = 10
                    local startTime = endTime - totalDuration
                    local fadeDuration = 1
                    if CurTime() < startTime + fadeDuration then
                        alpha = Lerp((CurTime() - startTime) / fadeDuration, 0, 155)
                    elseif CurTime() > endTime - fadeDuration then
                        alpha = Lerp((endTime - CurTime()) / fadeDuration, 0, 155)
                    else
                        alpha = 155
                    end
                end

                halo.Add(entities, Color(alpha,0,alpha), 5, 5, 50, true, true)
            end
        end
    end )


    net.Receive('wmv_jumpscare_gen', function()
        local ent = net.ReadEntity()
        local state = net.ReadBool()
        local startTime = CurTime()

        local hookID = "wmv_jumpscare_" .. LocalPlayer():SteamID()

        --print(state)

        if not state then
            hook.Remove('CalcView', hookID)
        else
            hook.Add('CalcView', hookID, function(ply, pos, angles, fov)
                if not IsValid(ply) or not ply:Alive() or !IsValid(ent) then
                    hook.Remove('CalcView', hookID)
                    if IsValid(ply) then
                        ply:RemoveFlags(FL_NOTARGET)
                        ply:Freeze(false)
                        ply:DrawViewModel(true)
                    end
                    return
                end

                local cam = ent:GetAttachment(ent:LookupAttachment('camera'))

                ply:AddFlags(FL_NOTARGET)
                ply:Freeze(true)
                ply:DrawViewModel(false)

                local lerpFactor = math.Clamp((CurTime() - startTime) / (0.7/3), 0, 1)
                
                local targetFOV = 75 

                local orgiginlerpto = LerpVector(lerpFactor, pos, cam.Pos)
                local angleslerpto = LerpAngle(lerpFactor, angles, cam.Ang)
                local interpolatedFOV = Lerp(lerpFactor, fov, targetFOV)

                local view = {
                    origin = orgiginlerpto,
                    angles = angleslerpto,
                    fov = interpolatedFOV,
                    drawviewer = false
                }
                return view
            end)
        end
    end)

    net.Receive('wmv_pilljumpscare_gen', function()
        local ent = net.ReadEntity()
        local state = net.ReadBool()
        local startTime = CurTime()
    
        local hookID = "wmv_pilljumpscare_" .. LocalPlayer():SteamID()
    
        --print(state)
    
        if not state then
            hook.Remove('CalcView', hookID)
        else
            hook.Add('CalcView', hookID, function(ply, pos, angles, fov)
                if not IsValid(ply) or not ply:Alive() or !IsValid(ent) then
                    hook.Remove('CalcView', hookID)
                    if IsValid(ply) then
                        ply:RemoveFlags(FL_NOTARGET)
                        ply:Freeze(false)
                        ply:DrawViewModel(true)
                    end
                    return
                end
    
                local cam = ent:GetAttachment(ent:LookupAttachment('pillcamera'))
    
                ply:AddFlags(FL_NOTARGET)
                ply:Freeze(true)
                ply:DrawViewModel(true)
    
                local lerpFactor = math.Clamp((CurTime() - startTime) / (0.7/3), 0, 1)
                
                local targetFOV = 75 
    
                local orgiginlerpto = LerpVector(lerpFactor, pos, cam.Pos)
                local angleslerpto = LerpAngle(lerpFactor, angles, cam.Ang)
                local interpolatedFOV = Lerp(lerpFactor, fov, targetFOV)
    
                local view = {
                    origin = orgiginlerpto,
                    angles = angleslerpto,
                    fov = interpolatedFOV,
                    drawviewer = false
                }
                return view
            end)
        end
    end)
end

local function AdvancedPillSound(SoundData, ent)
    if IsValid(ent) then
        SoundData = SoundData or {}
        SoundData.stringe = SoundData.stringe or {}
        SoundData.soundLevel = SoundData.soundLevel or 75
        SoundData.pitchPercent = SoundData.pitchPercent or 100
        SoundData.volume = SoundData.volume or 1
        SoundData.channel = SoundData.channel or CHAN_AUTO
        SoundData.soundFlags = SoundData.soundFlags or 0
        SoundData.dsp = SoundData.dsp or 0
        SoundData.filter = SoundData.filter or nil

        local chosenSound = SoundData.stringe

        if istable(SoundData.stringe) then
            local index = math.random(1, #SoundData.stringe)
            chosenSound = SoundData.stringe[index]
        end

        ent:EmitSound(
            chosenSound,
            SoundData.soundLevel,
            SoundData.pitchPercent,
            SoundData.volume,
            SoundData.channel,
            SoundData.soundFlags,
            SoundData.dsp,
            SoundData.filter
        )
    end
    return true
end


local function wmvjackietien_jumpscare(ply, ent, duration, customanimstuff)
    if not ent.IsInJumpscare then ent.IsInJumpscare = 0 end
    if ent.IsInJumpscare >= CurTime() then return end
    if not ent.IsInJumpscareCooldown then ent.IsInJumpscareCooldown = 0 end
    if ent.IsInJumpscareCooldown >= CurTime() then return end

    local jumpscare_entity = nil

if SherlockHNS then
    jumpscare_entity = SherlockHNS.FindVictim(ply, ent:LocalToWorld(Vector(0, 0, 50)), 90)
else
    for _, ent2 in pairs(ents.FindInSphere(ent:LocalToWorld(Vector(0, 0, 50)), 90)) do
            if (ent2:IsPlayer() or ent2:IsNextBot() or ent2:IsNPC()) and ent2:Health() >= 0.1 then
                if ent2 == ply then continue end
                if ent2:IsPlayer() and ent2:Team() == TEAM_SPECTATOR then continue end
    
                if IsValid(ent2) then
                    jumpscare_entity = ent2
                    break
                end
            end
        end
end

if SherlockHNS and IsValid(jumpscare_entity) and jumpscare_entity:IsPlayer() then
        return pk_pills.playHNSJumpscare(ply, ent, jumpscare_entity, duration, {
            camera = "wmv_jumpscare_gen",
            onStart = customanimstuff,
            attachment = "camera",
        })
    end

    if jumpscare_entity ~= nil then
        
        ent.JuumpscareStart = CurTime()

        ent.jumpscare_entity = jumpscare_entity
        ent.entitylastpos = jumpscare_entity:GetPos()
        ent.entitylastang = jumpscare_entity:GetAngles()

        local targetAngle = (ply:GetPos() - jumpscare_entity:GetPos()):Angle()

        targetAngle.p = 0
        targetAngle.r = 0

        ply:SetNWInt("DisableMovement_jumpscare_pill_wmv", duration+CurTime())
        jumpscare_entity:SetNWInt("DisableMovement_jumpscare_pill_wmv", duration+CurTime())

        ent.IsInJumpscare = CurTime() + duration

        local puppet = ent:GetPuppet()

        if jumpscare_entity:IsPlayer() then
            net.Start('wmv_jumpscare_gen')
            net.WriteEntity(puppet)
            net.WriteBool(true)
            net.WriteString("camera")
            net.Send(jumpscare_entity)
            
            net.Start('wmv_pilljumpscare_gen')
            net.WriteEntity(puppet)
            net.WriteBool(true)
            net.WriteString("pillcamera")
            net.Send(ply)
        else
            jumpscare_entity:NextThink(duration+0.1+CurTime())
        end
        
        jumpscare_entity:AddFlags(FL_NOTARGET)

        ent:CallOnRemove("wmvJumpscare"..ent:EntIndex(), function()
            if !IsValid(jumpscare_entity) then return end

            jumpscare_entity:RemoveFlags(FL_NOTARGET)
            ent.jumpscare_entity = nil

            if jumpscare_entity:IsPlayer() then
                net.Start('wmv_jumpscare_gen')
                net.WriteEntity(puppet)
                net.WriteBool(false)
                net.WriteString("")
                net.Send(jumpscare_entity)
                
                net.Start('wmv_pilljumpscare_gen')
                net.WriteEntity(puppet)
                net.WriteBool(false)
                net.WriteString("")
                net.Send(ply)
            else
                jumpscare_entity:NextThink(CurTime())
            end
            jumpscare_entity:SetPos(ent.entitylastpos)
            jumpscare_entity:SetAngles(ent.entitylastang)
            jumpscare_entity:SetNWInt("DisableMovement_jumpscare_pill_wmv", CurTime())
        end)

        customanimstuff()
    end
end

if CLIENT then
    wmv_ThermalHelpers = wmv_ThermalHelpers or {}
    local regs = wmv_ThermalHelpers

    local function Thermal_GetMappedPillEnt(lp)
        return pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(lp)
    end

    local function Thermal_GetAmount(ent, prefix)
        if not IsValid(ent) then return 0 end

        local on = ent:GetNWBool(prefix .. "_TV_ON", false)
        local t0 = ent:GetNWFloat(prefix .. "_TV_T0", 0)
        local rel0 = ent:GetNWFloat(prefix .. "_TV_REL_T0", 0)
        local fadeIn = ent:GetNWFloat(prefix .. "_TV_FADEIN", 0.12)
        local fadeOut = ent:GetNWFloat(prefix .. "_TV_FADEOUT", 0.35)

        if on then
            if t0 <= 0 then return 1 end
            return math.Clamp((CurTime() - t0) / math.max(fadeIn, 0.01), 0, 1)
        end

        if rel0 > 0 then
            return 1 - math.Clamp((CurTime() - rel0) / math.max(fadeOut, 0.01), 0, 1)
        end

        return 0
    end

    local function Thermal_EnsureReg(id)
        regs[id] = regs[id] or {}
        regs[id].lerp = regs[id].lerp or 0
        return regs[id]
    end

    function wmv_RegisterThermal(id, cfg)
        local reg = Thermal_EnsureReg(id)
        reg.cfg = cfg
    end

    hook.Add("RenderScreenspaceEffects", "wmv_Thermal_RSE_Master", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local pillEnt = Thermal_GetMappedPillEnt(lp)
        if not IsValid(pillEnt) or not pillEnt.formTable then
            for _, reg in pairs(regs) do
                reg.lerp = Lerp(FrameTime() * 12, reg.lerp, 0)
            end
            return
        end

        for id, reg in pairs(regs) do
            local cfg = reg.cfg
            if not cfg then continue end

            if pillEnt.formTable.hud_id ~= cfg.hud_id then
                reg.lerp = Lerp(FrameTime() * 12, reg.lerp, 0)
                continue
            end

            local amt = Thermal_GetAmount(pillEnt, cfg.prefix)
            reg.lerp = Lerp(FrameTime() * 12, reg.lerp, amt)
            if reg.lerp <= 0.001 then continue end

            if cfg.vignette and render.DrawMercVignette then
                render.DrawMercVignette(
                    Lerp(reg.lerp, cfg.vignette.in1 or 1.3, cfg.vignette.in2 or 0.85),
                    Lerp(reg.lerp, cfg.vignette.out1 or 0.0, cfg.vignette.out2 or 0.45)
                )
            end

            if cfg.vhs and render.DrawMercVHS1 then
                local a = reg.lerp * (cfg.vhs.amount or 0.003)
                render.DrawMercVHS1(a, a)
            end

            if cfg.sharpen and DrawSharpen then
                local c = (cfg.sharpen.contrast or 1) * reg.lerp
                local d = (cfg.sharpen.distance or 1)
                DrawSharpen(c, d)
            end

            if cfg.colorModify then
                local cm = cfg.colorModify(reg.lerp)
                if cm then DrawColorModify(cm) end
            end
        end
    end)

    hook.Add("Think", "wmv_Thermal_NightLight_Master", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local pillEnt = Thermal_GetMappedPillEnt(lp)
        if not IsValid(pillEnt) or not pillEnt.formTable then return end

        for id, reg in pairs(regs) do
            local cfg = reg.cfg
            if not cfg or not cfg.nightLight then continue end
            if pillEnt.formTable.hud_id ~= cfg.hud_id then continue end

            if cfg.midKillNW and pillEnt:GetNWBool(cfg.midKillNW, false) then continue end

            if not pillEnt:GetNWBool(cfg.prefix .. "_NIGHTLIGHT_ON", false) then continue end

            local amt = 1

            local eyePos = lp:EyePos()
            local fwd = lp:EyeAngles():Forward()

            local pos
            if cfg.nightLight.noTrace then
                pos = eyePos + fwd * (cfg.nightLight.forward or 40)
            else
                local tr = util.TraceLine({
                    start = eyePos,
                    endpos = eyePos + fwd * (cfg.nightLight.traceDist or 120),
                    filter = lp,
                    mask = MASK_VISIBLE
                })
                pos = tr.Hit and (tr.HitPos - fwd * 2) or (eyePos + fwd * (cfg.nightLight.fallbackForward or 200))
            end

            local d = DynamicLight(lp:EntIndex() + (cfg.nightLight.idOffset or 900))
            if not d then continue end

            local c = cfg.nightLight.color or {r=200,g=150,b=0}
            d.pos = pos
            d.r = c.r or 200
            d.g = c.g or 150
            d.b = c.b or 0

            d.brightness = (cfg.nightLight.brightness or 1) + (amt * (cfg.nightLight.brightnessScale or 1.2))
            d.Decay = cfg.nightLight.decay or 900
            d.Size = (cfg.nightLight.size or 1040) + (amt * (cfg.nightLight.sizeScale or 260))
            d.DieTime = CurTime() + (cfg.nightLight.dieTime or 0.06)
        end
    end)

    hook.Add("PostDrawOpaqueRenderables", "wmv_Thermal_GlowPlayers_Master", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local pillEnt = Thermal_GetMappedPillEnt(lp)
        if not IsValid(pillEnt) or not pillEnt.formTable then return end

        for id, reg in pairs(regs) do
            local cfg = reg.cfg
            if not cfg or not cfg.playerGlow then continue end
            if pillEnt.formTable.hud_id ~= cfg.hud_id then continue end

            if cfg.midKillNW and pillEnt:GetNWBool(cfg.midKillNW, false) then return end

            local amt = Thermal_GetAmount(pillEnt, cfg.prefix)
            local speed = (amt < reg.lerp) and 22 or 12
            reg.lerp = Lerp(FrameTime() * speed, reg.lerp, amt)
            if reg.lerp <= 0.001 then return end

            render.SuppressEngineLighting(true)
            render.MaterialOverride(cfg.playerGlow.mat)

            render.SetBlend(math.Clamp(reg.lerp * (cfg.playerGlow.blendMul or 0.55), 0, 1))
            local mod = cfg.playerGlow.colorMod or {1.3, 0, 0.2}
            render.SetColorModulation(mod[1] or 1, mod[2] or 1, mod[3] or 1)

            for _, v in ipairs(player.GetAll()) do
                if not IsValid(v) then continue end
                if v == lp then continue end
                if v:Team() == TEAM_SPECTATOR then continue end
                if v:GetNWBool("InPill") == true then continue end
                v:DrawModel()
            end

            render.SetColorModulation(1, 1, 1)
            render.SetBlend(1)
            render.MaterialOverride(nil)
            render.SuppressEngineLighting(false)

            return
        end
    end)
end

local function ThermalVisionToggle(ent, prefix, fadeIn, fadeOut)
    if not IsValid(ent) then return end

    ent:SetNWFloat(prefix .. "_TV_FADEIN", fadeIn or 0.12)
    ent:SetNWFloat(prefix .. "_TV_FADEOUT", fadeOut or 0.35)

    local on = ent:GetNWBool(prefix .. "_TV_ON", false)

    if not on then
        ent:SetNWBool(prefix .. "_TV_ON", true)
        ent:SetNWFloat(prefix .. "_TV_T0", CurTime())
        ent:SetNWFloat(prefix .. "_TV_REL_T0", 0)
    else
        ent:SetNWBool(prefix .. "_TV_ON", false)
        ent:SetNWFloat(prefix .. "_TV_REL_T0", CurTime())
    end
end

local function NightLightToggle(ent, prefix)
    if not IsValid(ent) then return end

    local on = ent:GetNWBool(prefix .. "_NIGHTLIGHT_ON", false)
    ent:SetNWBool(prefix .. "_NIGHTLIGHT_ON", not on)
end



hook.Add("PlayerButtonDown", "wmv_PillHotkeys", function(ply, button)
    if button ~= KEY_N then return end

    local ent = GetPillEnt(ply)
    if not IsValid(ent) or not ent.formTable then return end

    local ft = ent.formTable

end)

hook.Add("SetupMove", "DisablePlayerMovement_wmv", function(ply, mv, cmd)
    if ply:GetNWInt("DisableMovement_jumpscare_pill_wmv") >= CurTime() then
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        mv:SetButtons(0)
    end
end)

local function SetVictimHidden(v, hidden)
    if not (IsValid(v) and v:IsPlayer()) then return end

    if hidden then
        if v._nb_oldNoDraw == nil then
            v._nb_oldNoDraw = v:GetNoDraw()
        end
        v:SetNoDraw(true)
        v:DrawShadow(false)
    else
        v:SetNoDraw(v._nb_oldNoDraw == true)
        v._nb_oldNoDraw = nil
        v:DrawShadow(true)
    end
end

hook.Add("PlayerFootstep", "wmv_DisableStep", function(ply, pos, foot, sound, volume, rf)
    if ply.pk_pill_ent == nil then return end
    if !IsValid(ply.pk_pill_ent) then return end
end)

if CLIENT then
    -- FOV pulse state
    local wmv_PULSE = {
        active = false,
        startTime = 0,
        duration = 1.2,
        peakAt = 0.35,
        zoomAmount = 18,
    }

    net.Receive("Nwmv_GlobalAbility", function()
        surface.PlaySound("nexus/wmv/Nwmvabil.wav")

        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if lp:Team() == TEAM_SPECTATOR then return end

        wmv_PULSE.active = true
        wmv_PULSE.startTime = CurTime()
    end)

    hook.Add("CalcView", "wmv_wmvGlobalPulse_FOV", function(ply, pos, ang, fov)
        if not wmv_PULSE.active then return end

        local elapsed = CurTime() - wmv_PULSE.startTime
        local dur = wmv_PULSE.duration

        if elapsed >= dur then
            wmv_PULSE.active = false
            return
        end

        local peak = wmv_PULSE.peakAt
        local t
        if elapsed <= dur * peak then
            t = elapsed / (dur * peak)
        else
            t = 1 - ((elapsed - dur * peak) / (dur * (1 - peak)))
        end

        t = t * t * (3 - 2 * t)

        local view = {
            origin = pos,
            angles = ang,
            fov = fov - (wmv_PULSE.zoomAmount * t),
            drawviewer = false,
        }
        return view
    end)

    hook.Add("RenderScreenspaceEffects", "wmv_wmvGlobalPulse_Vignette", function()
        if not wmv_PULSE.active then return end
        if not render.DrawMercVignette then return end

        local elapsed = CurTime() - wmv_PULSE.startTime
        local dur = wmv_PULSE.duration
        if elapsed >= dur then return end

        local peak = wmv_PULSE.peakAt
        local t
        if elapsed <= dur * peak then
            t = elapsed / (dur * peak)
        else
            t = 1 - ((elapsed - dur * peak) / (dur * (1 - peak)))
        end
        t = t * t * (3 - 2 * t)

        local amount = Lerp(t, 1.4, 0.9)
        local strength = Lerp(t, 0.0, 0.75)
        render.DrawMercVignette(amount, strength)
    end)
end

-- thermals



if CLIENT then
    local glowMat = Material("models/debug/debugwhite")

    wmv_RegisterThermal("wmv", {
        hud_id = "wmv",
        prefix = "wmv",
        midKillNW = "wmv_MIDKILL",

        vignette = {in1=1.3, in2=0.85, out1=0.0, out2=0.45},
        vhs = {amount = 0},
        sharpen = {contrast = 2.0, distance = 1.0},

        colorModify = function(a)
            return {
                ["$pp_colour_addr"] = a * 0.4,
                ["$pp_colour_addg"] = a * 0.4,
                ["$pp_colour_addb"] = a * 0.4,
                ["$pp_colour_brightness"] = a * -0.45,
                ["$pp_colour_contrast"] = Lerp(a, 1, 1.06),
                ["$pp_colour_colour"] = Lerp(a, 1, 0.0),
                ["$pp_colour_mulr"] = a * 0.5,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
        end,

        nightLight = {
            color = {r=100,g=100,b=100},
            brightness = 0.1,
            brightnessScale = 3,
            size = 5040,
            sizeScale = 1320,
            noTrace = true,
            forward = 100,
            dieTime = 0.06,
            idOffset = 941
        },

        playerGlow = {
            mat = glowMat,
            blendMul = 1,
            colorMod = {255, 0.3, 0}
        }
    })

end

-- mory kill stuff

local function CopyAppearance(src, dst)
    if not (IsValid(src) and IsValid(dst)) then return end

    if src.GetSkin and dst.SetSkin then
        dst:SetSkin(src:GetSkin() or 0)
    end

    if src.GetColor and dst.SetColor then
        local c = src:GetColor()
        dst:SetColor(c)
        if dst.SetRenderMode then
            dst:SetRenderMode(src.GetRenderMode and src:GetRenderMode() or RENDERMODE_NORMAL)
        end
    end

    if src.GetMaterial and dst.SetMaterial then
        dst:SetMaterial(src:GetMaterial() or "")
    end

    if src.GetRenderFX and dst.SetRenderFX then
        dst:SetRenderFX(src:GetRenderFX())
    end

    if src.GetNumBodyGroups and src.GetBodygroup and dst.SetBodygroup then
        local n = src:GetNumBodyGroups() or 0
        for i = 0, n - 1 do
            dst:SetBodygroup(i, src:GetBodygroup(i))
        end
    end

    if src.GetMaterials and dst.SetSubMaterial then
        local mats = src:GetMaterials()
        if istable(mats) then
            for i = 1, #mats do
                local sub = src.GetSubMaterial and src:GetSubMaterial(i - 1) or nil
                if sub and sub ~= "" then
                    dst:SetSubMaterial(i - 1, sub)
                end
            end
        end
    end
end

-- keybind stuf

hook.Add("PlayerButtonDown", "wmvNkey", function(ply, button)
    local pillentity = ply.pk_pill_ent
    if IsValid(pillentity) then
        if pillentity.formTable.wmvThermalVision then
            pillentity.formTable.wmvThermalVision(ply, pillentity, button)
        end
    end
end)

-- adaptive predator

if CLIENT then
    WMV_939_GasRevealed = WMV_939_GasRevealed or {}
end

if CLIENT then
    local WMV_PREDATOR_MOVE_SPEED = 155 
    local WMV_PREDATOR_HEAT_RADIUS = 100 

    local function WMV_IsLocal939()
        local lp = LocalPlayer()
        if not IsValid(lp) then return false end

        local ent = pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(lp)
        if not IsValid(ent) or not ent.formTable then return false end

        return ent.formTable.hud_id == "wmv"
    end

    local function WMV_IsHNSLMSActive()
        return GetGlobalBool("HNS_LMS_ACTIVE", false) == true
    end

    local function WMV_CanSeeTarget939(lp, target)
        if not IsValid(lp) or not IsValid(target) then return false end
        if target == lp then return true end
        if target:Team() == TEAM_SPECTATOR then return false end
    
        if WMV_IsHNSLMSActive() then
            return true
        end
    
        local revealData = WMV_939_GasRevealed
            and WMV_939_GasRevealed[target]
    
        if revealData and (revealData.endTime or 0) > CurTime() then
            return true
        end
    
        local moving =
            target:GetVelocity():Length2D() >= WMV_PREDATOR_MOVE_SPEED
    
        local close =
            target:GetPos():DistToSqr(lp:GetPos())
            <= (WMV_PREDATOR_HEAT_RADIUS * WMV_PREDATOR_HEAT_RADIUS)
    
        return moving or close
    end

    hook.Add("PrePlayerDraw", "WMV_AdaptivePredator_HideStillPlayers", function(ply)
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if not WMV_IsLocal939() then return end
        if ply == lp then return end

        if not WMV_CanSeeTarget939(lp, ply) then
            return true
        end
    end)

    local WMV_ShadowHiddenPlayers = {}

    hook.Add("Think", "WMV_AdaptivePredator_HideStillPlayerShadows", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
    
        if not WMV_IsLocal939() then
            for ply in pairs(WMV_ShadowHiddenPlayers) do
                if IsValid(ply) then
                    ply:DrawShadow(true)
                end
            end
    
            table.Empty(WMV_ShadowHiddenPlayers)
            return
        end
    
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if ply == lp then continue end
    
            local shouldSee = WMV_CanSeeTarget939(lp, ply)
    
            if shouldSee then
                if WMV_ShadowHiddenPlayers[ply] then
                    ply:DrawShadow(true)
                    WMV_ShadowHiddenPlayers[ply] = nil
                end
            else
                ply:DrawShadow(false)
                WMV_ShadowHiddenPlayers[ply] = true
            end
        end
    end)
end


local WMV_SOUND_PING_RADIUS = 1000
local WMV_SOUND_PING_RADIUS_BOOSTED = 12000
local WMV_SOUND_PING_MIN_DIST = 650
local WMV_SOUND_PING_COOLDOWN = 0.35
local WMV_MOVE_PING_SPEED = 230
local WMV_MOVE_PING_COOLDOWN = 0.75

local WMV_SENSE_DURATION = 20
local WMV_SENSE_FADEIN = 1.25
local WMV_SENSE_FADEOUT = 1.5
local WMV_SENSE_COOLDOWN = 35
local WMV_SENSE_SOUND = "nexus/wmv/Nwmvabil.wav"

local WMV_SOUND_BLACKLIST = {
    "ambient/",
    "ambience/",
    "music/",
    "soundscape",
    "wind",
    "rain",
    "thunder",
    "water",
    "loop",
}

local function WMV_Is939PillEnt(ent)
    return IsValid(ent) and ent.formTable and ent.formTable.hud_id == "wmv"
end

local function WMV_Is939Player(ply)
    local ent = GetPillEnt(ply)
    return WMV_Is939PillEnt(ent)
end

local function WMV_SmoothStep(t)
    t = math.Clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function WMV_GetSenseAmount(ent)
    if not IsValid(ent) then return 0 end

    local startTime = ent:GetNWFloat("WMV_SENSE_START", 0)
    local endTime = ent:GetNWFloat("WMV_SENSE_END", 0)
    local fadeOutStart = ent:GetNWFloat("WMV_SENSE_FADEOUT_START", 0)
    local now = CurTime()

    if endTime > now then
        return WMV_SmoothStep((now - startTime) / WMV_SENSE_FADEIN)
    end

    if fadeOutStart > 0 then
        local t = WMV_SmoothStep((now - fadeOutStart) / WMV_SENSE_FADEOUT)
        return math.Clamp(1 - t, 0, 1)
    end

    return 0
end

local function WMV_GetPingRadiusFor939(ent)
    local amt = WMV_GetSenseAmount(ent)
    return Lerp(amt, WMV_SOUND_PING_RADIUS, WMV_SOUND_PING_RADIUS_BOOSTED)
end

local function WMV_IsBlacklistedSound(snd)
    snd = string.lower(snd or "")

    if snd == "" then return true end

    for _, bad in ipairs(WMV_SOUND_BLACKLIST) do
        if string.find(snd, bad, 1, true) then
            return true
        end
    end

    return false
end

local function WMV_Get939PlayersNear(pos)
    local receivers = {}

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end

        local pillEnt = GetPillEnt(ply)
        if not WMV_Is939PillEnt(pillEnt) then continue end

        local radius = WMV_GetPingRadiusFor939(pillEnt)
        local distSqr = ply:GetPos():DistToSqr(pos)

        if distSqr <= radius * radius and distSqr >= WMV_SOUND_PING_MIN_DIST * WMV_SOUND_PING_MIN_DIST then
            table.insert(receivers, ply)
        end
    end

    return receivers
end

local function WMV_SendSoundPing(pos, pingType)
    if not SERVER then return end

    local receivers = WMV_Get939PlayersNear(pos)
    if #receivers <= 0 then return end

    net.Start("WMV_AdaptivePredator_Ping")
    net.WriteVector(pos)
    net.WriteString(pingType or "sound")
    net.Send(receivers)
end

if SERVER then
    hook.Add("Think", "WMV_AdaptivePredator_MovePings", function()
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if not ply:Alive() then continue end
            if WMV_Is939Player(ply) then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end

            local speed = ply:GetVelocity():Length2D()
            if speed < WMV_MOVE_PING_SPEED then continue end

            ply._wmv_NextMovePing = ply._wmv_NextMovePing or 0
            if ply._wmv_NextMovePing > CurTime() then continue end
            ply._wmv_NextMovePing = CurTime() + WMV_MOVE_PING_COOLDOWN

            WMV_SendSoundPing(ply:GetPos() + Vector(0, 0, 35), "move")
        end
    end)

    hook.Add("EntityEmitSound", "WMV_AdaptivePredator_SoundPings", function(data)
        if not data then return end

        local snd = data.SoundName or ""
        if WMV_IsBlacklistedSound(snd) then return end

        local ent = data.Entity
        local pos

        if IsValid(ent) then
            if ent:IsPlayer() and WMV_Is939Player(ent) then return end
            pos = ent:GetPos()
        else
            pos = data.Pos
        end

        if not pos then return end

        local volume = data.Volume or 1
        local level = data.SoundLevel or 75

        if volume <= 0.05 then return end
        if level < 45 then return end

        local key = IsValid(ent) and ent:EntIndex() or 0
        WMV_LastSoundPing = WMV_LastSoundPing or {}
        WMV_LastSoundPing[key] = WMV_LastSoundPing[key] or 0

        if WMV_LastSoundPing[key] > CurTime() then return end
        WMV_LastSoundPing[key] = CurTime() + WMV_SOUND_PING_COOLDOWN

        local class = IsValid(ent) and ent:GetClass() or ""
        local sndLower = string.lower(snd or "")
        
        if string.find(sndLower, "wood_furniture.break", 1, true)
        or string.find(sndLower, "plastic_box.break", 1, true) then
            WMV_SendSoundPing(pos + Vector(0, 0, 45), "doorbust")
        elseif string.find(sndLower, "glass.strain", 1, true)
        or string.find(sndLower, "glass", 1, true) then
            WMV_SendSoundPing(pos + Vector(0, 0, 45), "windowbust")
        elseif string.find(class, "door", 1, true) then
            WMV_SendSoundPing(pos + Vector(0, 0, 45), "door")
        elseif string.find(class, "button", 1, true) then
            WMV_SendSoundPing(pos + Vector(0, 0, 30), "button")
        else
            WMV_SendSoundPing(pos + Vector(0, 0, 35), "sound")
        end
    end)

    hook.Add("PlayerCanHearPlayersVoice", "WMV_AdaptivePredator_VoicePings", function(listener, talker)
        if not IsValid(talker) then return end
        if not talker:Alive() then return end
        if WMV_Is939Player(talker) then return end

        talker._wmv_NextVoicePing = talker._wmv_NextVoicePing or 0
        if talker._wmv_NextVoicePing > CurTime() then return end
        talker._wmv_NextVoicePing = CurTime() + 0.65

        WMV_SendSoundPing(talker:GetPos() + Vector(0, 0, 55), "voice")
    end)
end

if CLIENT then
    local WMV_Ripples = {}

    local WMV_RippleColors = {
        move = Color(255, 0, 0),
        sound = Color(255, 100, 100),
        door = Color(255, 220, 220),
        button = Color(180, 180, 220),
        voice = Color(255, 0, 0),
        doorbust = Color(255, 50, 50),
        windowbust = Color(255, 50, 50),
    }

    net.Receive("WMV_AdaptivePredator_Ping", function()
        local pos = net.ReadVector()
        local pingType = net.ReadString()

        table.insert(WMV_Ripples, {
            pos = pos,
            pingType = pingType,
            start = CurTime(),
            life = 1,
            maxRadius = 130,
        })
    end)

    local function WMV_DrawFacingCircle(pos, radius, color, viewerPos)
        local segments = 64
        local lastPos
    
        local normal = (viewerPos - pos):GetNormalized()
        local up = Vector(0, 0, 1)
        local right = normal:Cross(up):GetNormalized()
    
        if right:LengthSqr() <= 0.001 then
            right = Vector(1, 0, 0)
        end
    
        up = right:Cross(normal):GetNormalized()
    
        for i = 0, segments do
            local ang = math.rad((i / segments) * 360)
    
            local p = pos
                + right * math.cos(ang) * radius
                + up * math.sin(ang) * radius
    
            if lastPos then
                render.DrawLine(lastPos, p, color, false)
            end
    
            lastPos = p
        end
    end

    hook.Add("PostDrawTranslucentRenderables", "WMV_AdaptivePredator_DrawSoundRipples", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if not WMV_Is939Player(lp) then return end

        cam.IgnoreZ(true)

        for i = #WMV_Ripples, 1, -1 do
            local ripple = WMV_Ripples[i]
            local age = CurTime() - ripple.start
            local t = age / ripple.life

            if t >= 1 then
                table.remove(WMV_Ripples, i)
                continue
            end

            local baseColor = WMV_RippleColors[ripple.pingType] or WMV_RippleColors.sound
            local alpha = math.Clamp(255 * (1 - t), 0, 255)
            local color = Color(baseColor.r, baseColor.g, baseColor.b, alpha)

            local radius1 = Lerp(t, 10, ripple.maxRadius)
            local radius2 = Lerp(t, 1, ripple.maxRadius * 0.55)

            local viewerPos = lp:EyePos()

            WMV_DrawFacingCircle(ripple.pos, radius1, color, viewerPos)
            WMV_DrawFacingCircle(ripple.pos, radius2, Color(baseColor.r, baseColor.g, baseColor.b, alpha * 0.55), viewerPos)
        end

        cam.IgnoreZ(false)
    end)
end

if CLIENT then
    local function WMV_IsLocal939()
        local lp = LocalPlayer()
        if not IsValid(lp) then return false end

        local ent = pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(lp)
        if not IsValid(ent) or not ent.formTable then return false end

        return ent.formTable.hud_id == "wmv"
    end

    local function WMV_OverrideDoorBustEffect()
        net.Receive("BustEffect", function()
            local lp = LocalPlayer()
            if IsValid(lp) then
                lp:AnimRestartGesture(4, ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST, true)
            end

            local hitPos = net.ReadVector()
            local normal = net.ReadNormal()
            local magnit = net.ReadFloat()

            if WMV_IsLocal939() then return end

            local ef = EffectData()
            ef:SetStart(hitPos)
            ef:SetOrigin(hitPos)
            ef:SetNormal(normal)
            ef:SetMagnitude(magnit)
            util.Effect("busteffect", ef)
        end)
    end

    hook.Add("InitPostEntity", "WMV_OverrideDoorBustEffect_Init", function()
        timer.Simple(1, WMV_OverrideDoorBustEffect)
        timer.Simple(3, WMV_OverrideDoorBustEffect)
        timer.Simple(6, WMV_OverrideDoorBustEffect)
    end)
end

if CLIENT then
    local WMV_939_FOG_ENABLED = true

    local WMV_939_FOG_COLOR = Color(35, 35, 35)
    local WMV_939_FOG_START = 80
    local WMV_939_FOG_END = 1050
    local WMV_939_FOG_END_BOOSTED = 5050
    local WMV_939_FOG_DENSITY = 0.78

    local function WMV_IsLocal939Fog()
        local lp = LocalPlayer()
        if not IsValid(lp) then return false end

        local ent = pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(lp)
        if not IsValid(ent) or not ent.formTable then return false end

        return ent.formTable.hud_id == "wmv"
    end

    local function WMV_GetLocal939FogEnt()
        local lp = LocalPlayer()
        if not IsValid(lp) then return nil end

        local ent = pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(lp)
        if not IsValid(ent) or not ent.formTable then return nil end
        if ent.formTable.hud_id ~= "wmv" then return nil end

        return ent
    end

    local function WMV_GetLocalSenseFogAmount()
        local ent = WMV_GetLocal939FogEnt()
        if not IsValid(ent) then return 0 end

        local startTime = ent:GetNWFloat("WMV_SENSE_START", 0)
        local endTime = ent:GetNWFloat("WMV_SENSE_END", 0)
        local fadeOutStart = ent:GetNWFloat("WMV_SENSE_FADEOUT_START", 0)
        local now = CurTime()

        if endTime > now then
            local t = math.Clamp((now - startTime) / WMV_SENSE_FADEIN, 0, 1)
            return t * t * (3 - 2 * t)
        end

        if fadeOutStart > 0 then
            local t = math.Clamp((now - fadeOutStart) / WMV_SENSE_FADEOUT, 0, 1)
            t = t * t * (3 - 2 * t)
            return math.Clamp(1 - t, 0, 1)
        end

        return 0
    end

    hook.Add("SetupWorldFog", "WMV_939_ClientFog", function()
        if not WMV_939_FOG_ENABLED then return end
        if not WMV_IsLocal939Fog() then return end

        local senseAmt = WMV_GetLocalSenseFogAmount()
        local fogEnd = Lerp(senseAmt, WMV_939_FOG_END, WMV_939_FOG_END_BOOSTED)

        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogColor(WMV_939_FOG_COLOR.r, WMV_939_FOG_COLOR.g, WMV_939_FOG_COLOR.b)
        render.FogStart(WMV_939_FOG_START)
        render.FogEnd(fogEnd)
        render.FogMaxDensity(WMV_939_FOG_DENSITY)

        return true
    end)

    hook.Add("SetupSkyboxFog", "WMV_939_ClientSkyFog", function(scale)
        if not WMV_939_FOG_ENABLED then return end
        if not WMV_IsLocal939Fog() then return end

        local senseAmt = WMV_GetLocalSenseFogAmount()
        local fogEnd = Lerp(senseAmt, WMV_939_FOG_END, WMV_939_FOG_END_BOOSTED)

        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogColor(WMV_939_FOG_COLOR.r, WMV_939_FOG_COLOR.g, WMV_939_FOG_COLOR.b)
        render.FogStart(WMV_939_FOG_START * scale)
        render.FogEnd(fogEnd * scale)
        render.FogMaxDensity(WMV_939_FOG_DENSITY)

        return true
    end)
end

if CLIENT then
    local WMV_NEAR_VIGNETTE_MAT = Material("nexus/939/redviginettept1") -- change if your VMT is in a folder
    local WMV_NEAR_VIGNETTE_RADIUS = 1550
    local WMV_NEAR_VIGNETTE_MAX_ALPHA = 210
    local WMV_NEAR_VIGNETTE_FADE_SPEED = 8

    local WMV_NearVignetteAlpha = 0

    local function WMV_IsLocal939Vignette()
        local lp = LocalPlayer()
        if not IsValid(lp) then return false end

        local ent = pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(lp)
        if not IsValid(ent) or not ent.formTable then return false end

        return ent.formTable.hud_id == "wmv"
    end

    local function WMV_HasVisiblePlayerNear()
        local lp = LocalPlayer()
        if not IsValid(lp) then return false end

        local startPos = lp:EyePos()

        for _, target in ipairs(player.GetAll()) do
            if not IsValid(target) then continue end
            if target == lp then continue end
            if not target:Alive() then continue end
            if target:Team() == TEAM_SPECTATOR then continue end

            local targetPos = target:EyePos()
            local distSqr = startPos:DistToSqr(targetPos)

            if distSqr > WMV_NEAR_VIGNETTE_RADIUS * WMV_NEAR_VIGNETTE_RADIUS then
                continue
            end

            local tr = util.TraceLine({
                start = startPos,
                endpos = targetPos,
                filter = {lp, target},
                mask = MASK_VISIBLE
            })

            if not tr.Hit then
                return true
            end
        end

        return false
    end

    hook.Add("HUDPaint", "WMV_PlayerNearBloodVignette", function()
        if not WMV_IsLocal939Vignette() then
            WMV_NearVignetteAlpha = Lerp(FrameTime() * WMV_NEAR_VIGNETTE_FADE_SPEED, WMV_NearVignetteAlpha, 0)
            return
        end

        local targetAlpha = WMV_HasVisiblePlayerNear() and WMV_NEAR_VIGNETTE_MAX_ALPHA or 0
        WMV_NearVignetteAlpha = Lerp(FrameTime() * WMV_NEAR_VIGNETTE_FADE_SPEED, WMV_NearVignetteAlpha, targetAlpha)

        if WMV_NearVignetteAlpha <= 1 then return end

        surface.SetMaterial(WMV_NEAR_VIGNETTE_MAT)
        surface.SetDrawColor(255, 255, 255, WMV_NearVignetteAlpha)
        local xOffset = 0
        local yOffset = 100
        local sizeMul = 1.5
        
        local w = ScrW() * sizeMul
        local h = ScrH() * sizeMul
        
        local x = (ScrW() - w) / 2 + xOffset
        local y = (ScrH() - h) / 2 + yOffset
        
        surface.DrawTexturedRect(x, y, w, h)
    end)
end

-- fear radius

local WMV_ISNEAR_RADIUS = 1550

if CLIENT then
    local WMV_939_IsNearActiveSounds = {}
    local WMV_ISNEAR_FADEOUT_TIME = 1.25

    local function WMV_StopIsNearSounds()
        for i = #WMV_939_IsNearActiveSounds, 1, -1 do
            local sndObj = WMV_939_IsNearActiveSounds[i]

            if sndObj then
                sndObj:ChangeVolume(0, WMV_ISNEAR_FADEOUT_TIME)

                timer.Simple(WMV_ISNEAR_FADEOUT_TIME + 0.05, function()
                    if sndObj then
                        sndObj:Stop()
                    end
                end)
            end

            table.remove(WMV_939_IsNearActiveSounds, i)
        end
    end

    net.Receive("WMV_939_IsNearSound", function()
        local snd = net.ReadString()
        if snd == "" then return end

        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        WMV_StopIsNearSounds()

        local sndObj = CreateSound(lp, snd)
        if not sndObj then return end

        sndObj:PlayEx(1, 100)
        table.insert(WMV_939_IsNearActiveSounds, sndObj)
    end)

    net.Receive("WMV_939_StopIsNearSound", function()
        WMV_StopIsNearSounds()
    end)
end

-- spotted

local WMV_SPOTTED_RADIUS = 2500
local WMV_SPOTTED_DOT = 0.565 -- higher = must look more directly at 939
local WMV_SPOTTED_COOLDOWN = 60

if CLIENT then
    net.Receive("WMV_939_SpottedSound", function()
        local snd = net.ReadString()
        if snd == "" then return end

        surface.PlaySound(snd)
    end)
end

-- cooldown helepr

local function WMV_StartAbilityCooldown(ply, ent, slotId, duration, nextVar)
    if not SERVER then return false end
    if not IsValid(ply) or not IsValid(ent) then return false end

    if SherlockHNS and SherlockHNS.Ability.Has(ply, slotId) then
        SherlockHNS.Ability.SetCooldown(ply, slotId, duration)
        return true
    end
    ent[nextVar] = ent[nextVar] or 0

    if ent[nextVar] > CurTime() then
        return false
    end

    ent[nextVar] = CurTime() + duration

    net.Start("WMV_StartCooldown")
    net.WriteString(slotId)
    net.WriteFloat(duration)
    net.Send(ply)

    return true
end

-- amnestic breath

local WMV_GAS_KEY = KEY_2
local WMV_GAS_RADIUS = 1500
local WMV_GAS_DURATION = 120
local WMV_GAS_COOLDOWN = 45
local WMV_GAS_POINT_COUNT = 205
local WMV_GAS_POINT_TOUCH_RADIUS = 145
local WMV_GAS_SOUND_LEVEL = 80
local WMV_GAS_SPAWN_TIME = 6
local WMV_GAS_EFFECT_LINGER = 20
local WMV_GAS_REVEAL_DURATION = 4
local WMV_GAS_REVEAL_SOUND = {
    "nexus/939/939spotted-01.mp3",
    "nexus/939/939spotted-02.mp3",
    "nexus/939/939spotted-03.mp3"
}

local function WMV_GasTraceClear(startPos, endPos, filter)
    local tr = util.TraceHull({
        start = startPos,
        endpos = endPos,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8),
        filter = filter,
        mask = MASK_SOLID
    })

    return not tr.Hit
end

if SERVER then
    WMV_939_GasClouds = WMV_939_GasClouds or {}

    local function WMV_CreateGasPoints(ply, ent, origin)
        local points = {}
        local filter = {ply, ent}

        local puppet = ent.GetPuppet and ent:GetPuppet() or nil
        if IsValid(puppet) then
            table.insert(filter, puppet)
        end

        table.insert(points, origin)

        for i = 1, WMV_GAS_POINT_COUNT do
            local dir = VectorRand()
            if dir:LengthSqr() <= 0.001 then continue end

            dir:Normalize()

            local dist = math.Rand(80, WMV_GAS_RADIUS)
            local wantedPos = origin + dir * dist

            local tr = util.TraceHull({
                start = origin,
                endpos = wantedPos,
                mins = Vector(-10, -10, -10),
                maxs = Vector(10, 10, 10),
                filter = filter,
                mask = MASK_SOLID
            })

            if not tr.Hit then
                table.insert(points, wantedPos)
            elseif tr.HitPos:DistToSqr(origin) > 120 * 120 then
                table.insert(points, tr.HitPos - dir * 28)
            end
        end

        return points
    end

    local function WMV_PlayerInsideGasCloud(target, cloud)
        if not IsValid(target) then return false end
        if not target:Alive() then return false end
        if target:Team() == TEAM_SPECTATOR then return false end
        if target == cloud.owner then return false end

        local targetPos = target:WorldSpaceCenter()

        if targetPos:DistToSqr(cloud.origin) > (WMV_GAS_RADIUS + WMV_GAS_POINT_TOUCH_RADIUS) ^ 2 then
            return false
        end

        local filter = {cloud.owner, cloud.ent, target}

        local puppet = IsValid(cloud.ent) and cloud.ent.GetPuppet and cloud.ent:GetPuppet() or nil
        if IsValid(puppet) then
            table.insert(filter, puppet)
        end

        for _, point in ipairs(cloud.points) do
            if targetPos:DistToSqr(point) <= WMV_GAS_POINT_TOUCH_RADIUS * WMV_GAS_POINT_TOUCH_RADIUS then
                if WMV_GasTraceClear(point, targetPos, filter) then
                    return true
                end
            end
        end

        return false
    end

    local function WMV_Start939GasAbility(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return end
        if not WMV_Is939PillEnt(ent) then return end
    
        if not WMV_StartAbilityCooldown(ply, ent, "wmv_amnesticgas", WMV_GAS_COOLDOWN, "_wmv_NextGasAbility") then
            return
        end

        ent:PillSound("amensticgas")
    
        local puppet = ent:GetPuppet()
        local origin = IsValid(puppet) and puppet:WorldSpaceCenter() or ply:WorldSpaceCenter()
        origin = origin + ply:EyeAngles():Forward() * 90
    
        local sounds = ent.formTable.sounds or {}
    
        ply:SetNWInt("DisableMovement_jumpscare_pill_wmv", CurTime() + WMV_GAS_SPAWN_TIME)
    
        local points = WMV_CreateGasPoints(ply, ent, origin)
    
        net.Start("WMV_939_GasCloud")
        net.WriteVector(origin)
        net.WriteFloat(WMV_GAS_DURATION + WMV_GAS_SPAWN_TIME)
        net.WriteFloat(WMV_GAS_SPAWN_TIME)
        net.WriteUInt(math.min(#points, 255), 8)
    
        for i = 1, math.min(#points, 255) do
            net.WriteVector(points[i])
        end
    
        net.Send(ply)
    
        timer.Simple(WMV_GAS_SPAWN_TIME, function()
            if not IsValid(ply) or not IsValid(ent) then return end
    
            local cloud = {
                owner = ply,
                ent = ent,
                origin = origin,
                points = points,
                startTime = CurTime(),
                endTime = CurTime() + WMV_GAS_DURATION,
                touched = {}
            }
    
            WMV_939_GasClouds = WMV_939_GasClouds or {}
            table.insert(WMV_939_GasClouds, cloud)
    
            ent:CallOnRemove("WMV_ClearGas_" .. ent:EntIndex(), function()
                for _, target in ipairs(player.GetAll()) do
                    if IsValid(target) then
                        target:SetNWBool("WMV_IN_939_GAS", false)
                        target:SetNWFloat("WMV_939_GAS_END", 0)
                    end
                end
            end)
        end)
    end

    local wmv_amnesticgas = function(ply, button)
        if button ~= WMV_GAS_KEY then return end
    
        local ent = GetPillEnt(ply)
        if not WMV_Is939PillEnt(ent) then return end
    
        WMV_Start939GasAbility(ply, ent)
    end
    hnsActions.wmv_amnesticgas = function(ply) return wmv_amnesticgas(ply, KEY_2) end
    hook.Add("PlayerButtonDown", "WMV_939_GasAbility_KEY2", function(ply, button)
        if button ~= KEY_2 then return end
        if SherlockHNS then
            local ent = GetPillEnt(ply)
            if WMV_Is939PillEnt(ent) then SherlockHNS.Ability.Use(ply, "wmv_amnesticgas") end
        else
            wmv_amnesticgas(ply, button)
        end
    end)

    hook.Add("Think", "WMV_939_GasCloudThink", function()
        if not WMV_939_GasClouds then return end

        local gasTouchedNow = {}

        for i = #WMV_939_GasClouds, 1, -1 do
            local cloud = WMV_939_GasClouds[i]

            if not cloud or CurTime() >= cloud.endTime or not IsValid(cloud.owner) or not IsValid(cloud.ent) then
                table.remove(WMV_939_GasClouds, i)
                continue
            end

            for _, target in ipairs(player.GetAll()) do
                if WMV_PlayerInsideGasCloud(target, cloud) then
                    gasTouchedNow[target] = true
            
                    cloud.touched = cloud.touched or {}
            
                    if not cloud.touched[target] then
                        cloud.touched[target] = true
            
                        if IsValid(cloud.owner) then
                            local revealSound = WMV_GAS_REVEAL_SOUND

                            if istable(revealSound) then
                                revealSound = revealSound[math.random(1, #revealSound)]
                            end
                            
                            revealSound = tostring(revealSound or "")
                            
                            net.Start("WMV_939_GasReveal")
                            net.WriteEntity(target)
                            net.WriteFloat(WMV_GAS_REVEAL_DURATION)
                            net.WriteString(revealSound)
                            net.Send(cloud.owner)
                        end
                    end
                end
            end
        end

        for target in pairs(gasTouchedNow) do
            if IsValid(target) then
                target:SetNWFloat("WMV_939_GAS_END", CurTime() + WMV_GAS_EFFECT_LINGER)
                target:SetNWBool("WMV_IN_939_GAS", true)
            end
        end
        
        for _, target in ipairs(player.GetAll()) do
            if not IsValid(target) then continue end
        
            if target:GetNWBool("WMV_IN_939_GAS", false) and target:GetNWFloat("WMV_939_GAS_END", 0) <= CurTime() then
                target:SetNWBool("WMV_IN_939_GAS", false)
                target:SetNWFloat("WMV_939_GAS_END", 0)
            end
        end
    end)
end

if CLIENT then
    local WMV_939_ClientGasClouds = {}
    local WMV_GAS_MAT = Material("particle/particle_smokegrenade")

    net.Receive("WMV_939_GasCloud", function()
        local origin = net.ReadVector()
        local duration = net.ReadFloat()
        local spawnTime = net.ReadFloat()
        local count = net.ReadUInt(8)
        local points = {}
    
        for i = 1, count do
            points[i] = net.ReadVector()
        end
    
        table.insert(WMV_939_ClientGasClouds, {
            origin = origin,
            points = points,
            startTime = CurTime(),
            endTime = CurTime() + duration,
            spawnTime = spawnTime
        })
    end)

    hook.Add("PostDrawTranslucentRenderables", "WMV_939_DrawClientGasClouds", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if not WMV_Is939Player(lp) then return end
    
        render.SetMaterial(WMV_GAS_MAT)
    
        for i = #WMV_939_ClientGasClouds, 1, -1 do
            local cloud = WMV_939_ClientGasClouds[i]
    
            if CurTime() >= cloud.endTime then
                table.remove(WMV_939_ClientGasClouds, i)
                continue
            end
    
            local age = CurTime() - cloud.startTime
            local spawnTime = cloud.spawnTime or 0
            local spawnFrac = 1
    
            if spawnTime > 0 then
                spawnFrac = math.Clamp(age / spawnTime, 0, 1)
            end
    
            local visibleCount = math.max(1, math.floor(#cloud.points * spawnFrac))
    
            local fadeIn = math.Clamp(age / math.max(spawnTime, 1), 0, 1)
            local fadeOut = math.Clamp((cloud.endTime - CurTime()) / 1.5, 0, 1)
            local alphaMul = math.min(fadeIn, fadeOut)
    
            for n = 1, visibleCount do
                local point = cloud.points[n]
                if not point then continue end
    
                local pointFrac = n / #cloud.points
                local pointAlpha = math.Clamp((spawnFrac - pointFrac) * 8, 0, 1)
    
                local pulse = 0.75 + math.sin(CurTime() * 1.4 + point.x * 0.01) * 0.25
                local size = 135 * pulse
                local alpha = 70 * alphaMul * pointAlpha
    
                render.DrawSprite(
                    point,
                    size,
                    size,
                    Color(160, 160, 160, alpha)
                )
            end
        end
    end)
end

if CLIENT then
    local WMV_GAS_RENDER_939_RADIUS = 250 -- how close 939 must be to be visible while player is gassed
    local WMV_GAS_EFFECT_FADE_SPEED = 7

    local WMV_GasEffectAmount = 0
    local WMV_GasHiddenEnts = {}

    local WMV_GAS_FOG_ENABLED = true
    local WMV_GAS_FOG_COLOR = Color(125, 125, 125)
    local WMV_GAS_FOG_START = 40
    local WMV_GAS_FOG_END = 830
    local WMV_GAS_FOG_DENSITY = 0.98

    local function WMV_LocalPlayerGassed()
        local lp = LocalPlayer()
        if not IsValid(lp) then return false end
    
        if lp:GetNWBool("WMV_IN_939_GAS", false) then
            return true
        end
    
        return lp:GetNWFloat("WMV_939_GAS_END", 0) > CurTime()
    end

    local function WMV_Get939Pills()
        local pills = {}

        for _, ent in ipairs(ents.FindByClass("pill_ent_costume")) do
            if not IsValid(ent) then continue end
            if not ent.formTable then continue end
            if ent.formTable.hud_id ~= "wmv" then continue end

            local owner = ent.GetPillUser and ent:GetPillUser() or nil
            local puppet = ent.GetPuppet and ent:GetPuppet() or nil

            table.insert(pills, {
                ent = ent,
                owner = owner,
                puppet = puppet
            })
        end

        return pills
    end

    local function WMV_SetClientNoDraw(ent, state)
        if not IsValid(ent) then return end

        if state then
            if WMV_GasHiddenEnts[ent] == nil then
                WMV_GasHiddenEnts[ent] = ent:GetNoDraw()
            end

            ent:SetNoDraw(true)
            ent:DrawShadow(false)
        else
            if WMV_GasHiddenEnts[ent] ~= nil then
                ent:SetNoDraw(WMV_GasHiddenEnts[ent])
                ent:DrawShadow(true)
                WMV_GasHiddenEnts[ent] = nil
            end
        end
    end

    hook.Add("Think", "WMV_939_Gas_HideFar939", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local gassed = WMV_LocalPlayerGassed()

        if not gassed then
            for ent in pairs(WMV_GasHiddenEnts) do
                WMV_SetClientNoDraw(ent, false)
            end

            return
        end

        local lpPos = lp:WorldSpaceCenter()
        local maxDistSqr = WMV_GAS_RENDER_939_RADIUS * WMV_GAS_RENDER_939_RADIUS

        for _, data in ipairs(WMV_Get939Pills()) do
            local owner = data.owner
            local puppet = data.puppet
            local pillEnt = data.ent

            local checkPos = nil

            if IsValid(owner) then
                checkPos = owner:WorldSpaceCenter()
            elseif IsValid(puppet) then
                checkPos = puppet:WorldSpaceCenter()
            elseif IsValid(pillEnt) then
                checkPos = pillEnt:WorldSpaceCenter()
            end

            if not checkPos then continue end

            local tooFar = lpPos:DistToSqr(checkPos) > maxDistSqr

            if IsValid(owner) and owner ~= lp then
                WMV_SetClientNoDraw(owner, tooFar)
            end

            if IsValid(puppet) then
                WMV_SetClientNoDraw(puppet, tooFar)
            end

            if IsValid(pillEnt) then
                WMV_SetClientNoDraw(pillEnt, tooFar)
            end
        end
    end)

    hook.Add("RenderScreenspaceEffects", "WMV_939_Gas_ScreenEffects", function()
        local target = WMV_LocalPlayerGassed() and 1 or 0
        WMV_GasEffectAmount = Lerp(FrameTime() * WMV_GAS_EFFECT_FADE_SPEED, WMV_GasEffectAmount, target)

        if WMV_GasEffectAmount <= 0.01 then return end

        local a = WMV_GasEffectAmount

        if render.DrawMercRadialBlur then
            render.DrawMercRadialBlur(0.5,0.5, 0.16 * a)
        end


        if render.DrawMercBlur then
            render.DrawMercBlur(0.0106 * a)
        end

        DrawMotionBlur( 0.3, 0.6, 0.01 )

    end)

    hook.Add("SetupWorldFog", "WMV_939_Gas_PlayerFog", function()
        if not WMV_GAS_FOG_ENABLED then return end
        if WMV_GasEffectAmount <= 0.01 then return end

        local a = math.Clamp(WMV_GasEffectAmount, 0, 1)

        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogColor(
            WMV_GAS_FOG_COLOR.r,
            WMV_GAS_FOG_COLOR.g,
            WMV_GAS_FOG_COLOR.b
        )
        render.FogStart(Lerp(a, 400, WMV_GAS_FOG_START))
        render.FogEnd(Lerp(a, 2500, WMV_GAS_FOG_END))
        render.FogMaxDensity(WMV_GAS_FOG_DENSITY * a)

        return true
    end)

    hook.Add("SetupSkyboxFog", "WMV_939_Gas_PlayerSkyFog", function(scale)
        if not WMV_GAS_FOG_ENABLED then return end
        if WMV_GasEffectAmount <= 0.01 then return end

        local a = math.Clamp(WMV_GasEffectAmount, 0, 1)

        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogColor(
            WMV_GAS_FOG_COLOR.r,
            WMV_GAS_FOG_COLOR.g,
            WMV_GAS_FOG_COLOR.b
        )
        render.FogStart(Lerp(a, 400, WMV_GAS_FOG_START) * scale)
        render.FogEnd(Lerp(a, 2500, WMV_GAS_FOG_END) * scale)
        render.FogMaxDensity(WMV_GAS_FOG_DENSITY * a)

        return true
    end)

end

if CLIENT then


    local WMV_HALLUCINATION_ENABLED = true

    local WMV_HALLUCINATION_MODEL = "models/nexus/scp/939/939.mdl"

    local WMV_HALLUCINATION_SOUNDS = {
        "nexus/939/939spotted-01.mp3",
        "nexus/939/939spotted-02.mp3",
        "nexus/939/939spotted-03.mp3",
    }

    local WMV_HALLUCINATION_MODEL_CHANCE = 1
    local WMV_HALLUCINATION_MIN_DELAY = 2.5
    local WMV_HALLUCINATION_MAX_DELAY = 6.5

    local WMV_HALLUCINATION_LIFE = 3.0
    local WMV_HALLUCINATION_MIN_DIST = 420
    local WMV_HALLUCINATION_MAX_DIST = 900
    local WMV_HALLUCINATION_SPEED = 560

    local WMV_HALLUCINATION_ALPHA = 255
    local WMV_HALLUCINATION_SOUND_LEVEL = 72
    local WMV_HALLUCINATION_SOUND_VOLUME = 0.85


    local WMV_HALLUCINATION_ANIMS = {
        "run",
    }

    local WMV_Hallucinations = {}
    local WMV_NextHallucination = 0
    local WMV_WasGassed = false

    local function WMV_LocalPlayerGassedForHallucinations()
        local lp = LocalPlayer()
        if not IsValid(lp) then return false end

        if lp:GetNWBool("WMV_IN_939_GAS", false) then
            return true
        end

        return lp:GetNWFloat("WMV_939_GAS_END", 0) > CurTime()
    end

    local function WMV_GetRandomHallucinationSound()
        if not istable(WMV_HALLUCINATION_SOUNDS) or #WMV_HALLUCINATION_SOUNDS <= 0 then
            return nil
        end

        return WMV_HALLUCINATION_SOUNDS[math.random(1, #WMV_HALLUCINATION_SOUNDS)]
    end

    local function WMV_FindHallucinationSpawnPos(lp)
        if not IsValid(lp) then return nil end

        local base = lp:GetPos()
        local eyeAng = lp:EyeAngles()

        for i = 1, 12 do
            local yaw = math.Rand(0, 360)


            if math.random() < 0.45 then
                yaw = eyeAng.y + math.Rand(110, 250)
            end

            local dir = Angle(0, yaw, 0):Forward()
            local dist = math.Rand(WMV_HALLUCINATION_MIN_DIST, WMV_HALLUCINATION_MAX_DIST)
            local wanted = base + dir * dist

            local groundTrace = util.TraceHull({
                start = wanted + Vector(0, 0, 90),
                endpos = wanted - Vector(0, 0, 160),
                mins = Vector(-20, -20, 0),
                maxs = Vector(20, 20, 80),
                filter = lp,
                mask = MASK_SOLID
            })

            if groundTrace.Hit then
                local pos = groundTrace.HitPos + Vector(0, 0, 4)

                local wallTrace = util.TraceHull({
                    start = lp:EyePos(),
                    endpos = pos + Vector(0, 0, 45),
                    mins = Vector(-8, -8, -8),
                    maxs = Vector(8, 8, 8),
                    filter = lp,
                    mask = MASK_SOLID_BRUSHONLY
                })

                if not wallTrace.StartSolid then
                    return pos
                end
            end
        end

        return nil
    end

    local function WMV_SetHallucinationAnim(mdl)
        if not IsValid(mdl) then return end

        for _, seqName in ipairs(WMV_HALLUCINATION_ANIMS) do
            local seq = mdl:LookupSequence(seqName)

            if seq and seq >= 0 then
                mdl:ResetSequence(seq)
                mdl:SetCycle(0)
                mdl:SetPlaybackRate(1)
                return
            end
        end
    end

    local function WMV_RemoveHallucination(h)
        if not h then return end

        if IsValid(h.mdl) then
            h.mdl:Remove()
        end

        h.dead = true
    end

    local function WMV_ClearHallucinations()
        for i = #WMV_Hallucinations, 1, -1 do
            WMV_RemoveHallucination(WMV_Hallucinations[i])
            table.remove(WMV_Hallucinations, i)
        end
    end

    local function WMV_SpawnHallucinationModel()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local pos = WMV_FindHallucinationSpawnPos(lp)
        if not pos then return end

        local mdl = ClientsideModel(WMV_HALLUCINATION_MODEL, RENDERGROUP_TRANSLUCENT)
        if not IsValid(mdl) then return end

        mdl:SetPos(pos)
        mdl:SetAngles(Angle(0, (lp:GetPos() - pos):Angle().y, 0))
        mdl:SetModelScale(1, 0)
        mdl:SetRenderMode(RENDERMODE_TRANSALPHA)
        mdl:SetColor(Color(255, 255, 255, WMV_HALLUCINATION_ALPHA))
        mdl:DrawShadow(false)

        WMV_SetHallucinationAnim(mdl)

        local snd = WMV_GetRandomHallucinationSound()
        if snd then
            sound.Play(
                snd,
                pos + Vector(0, 0, 45),
                WMV_HALLUCINATION_SOUND_LEVEL,
                math.random(92, 108),
                WMV_HALLUCINATION_SOUND_VOLUME
            )
        end

        table.insert(WMV_Hallucinations, {
            mdl = mdl,
            spawnTime = CurTime(),
            dieTime = CurTime() + WMV_HALLUCINATION_LIFE,
            startAlpha = WMV_HALLUCINATION_ALPHA,
            rush = math.random() < 0.75,
            flickerSeed = math.Rand(0, 100)
        })
    end

    local function WMV_PlayRandomHallucinationSound()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local snd = WMV_GetRandomHallucinationSound()
        if not snd then return end

        local yaw = math.Rand(0, 360)
        local dir = Angle(0, yaw, 0):Forward()
        local dist = math.Rand(180, 750)

        local pos = lp:EyePos() + dir * dist + Vector(0, 0, math.Rand(-15, 45))

        sound.Play(
            snd,
            pos,
            WMV_HALLUCINATION_SOUND_LEVEL,
            math.random(85, 115),
            WMV_HALLUCINATION_SOUND_VOLUME
        )
    end

    local function WMV_DoHallucinationEvent()
        WMV_PlayRandomHallucinationSound()

        if math.Rand(0, 1) <= WMV_HALLUCINATION_MODEL_CHANCE then
            WMV_SpawnHallucinationModel()
        end
    end

    hook.Add("Think", "WMV_939_GasHallucinationThink", function()
        if not WMV_HALLUCINATION_ENABLED then return end

        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local gassed = WMV_LocalPlayerGassedForHallucinations()

        if not gassed then
            if WMV_WasGassed then
                WMV_ClearHallucinations()
            end

            WMV_WasGassed = false
            WMV_NextHallucination = 0
            return
        end

        WMV_WasGassed = true

        if WMV_NextHallucination <= CurTime() then
            WMV_NextHallucination = CurTime() + math.Rand(WMV_HALLUCINATION_MIN_DELAY, WMV_HALLUCINATION_MAX_DELAY)
            WMV_DoHallucinationEvent()
        end

        for i = #WMV_Hallucinations, 1, -1 do
            local h = WMV_Hallucinations[i]

            if not h or h.dead or not IsValid(h.mdl) or CurTime() >= h.dieTime then
                WMV_RemoveHallucination(h)
                table.remove(WMV_Hallucinations, i)
                continue
            end

            local mdl = h.mdl
            local age = CurTime() - h.spawnTime
            local life = math.max(0.01, h.dieTime - h.spawnTime)
            local t = math.Clamp(age / life, 0, 1)

            local pos = mdl:GetPos()
            local targetPos = lp:GetPos()

            local dir = targetPos - pos
            dir.z = 0

            local dist = dir:Length()

            if dist > 1 then
                dir:Normalize()

                if h.rush then
                    local newPos = pos + dir * WMV_HALLUCINATION_SPEED * FrameTime()
                    mdl:SetPos(newPos)
                end

                mdl:SetAngles(Angle(0, dir:Angle().y, 0))
            end

            mdl:FrameAdvance(FrameTime())

            -- Fade + flicker
            local fadeOut = 1
            if t > 0.65 then
                fadeOut = 1 - math.Clamp((t - 0.65) / 0.35, 0, 1)
            end

            local flicker = 0.65 + math.sin(CurTime() * 22 + h.flickerSeed) * 0.35
            local alpha = math.Clamp(h.startAlpha * fadeOut * flicker, 0, h.startAlpha)

            mdl:SetColor(Color(255, 255, 255, alpha))

            -- If it gets too close, vanish with a sound sting.
            if dist <= 95 then
                local snd = WMV_GetRandomHallucinationSound()
                if snd then
                    sound.Play(snd, lp:EyePos(), 75, math.random(95, 110), 0.9)
                end

                WMV_RemoveHallucination(h)
                table.remove(WMV_Hallucinations, i)
            end
        end
    end)

    hook.Add("ShutDown", "WMV_939_GasHallucinationCleanup", function()
        WMV_ClearHallucinations()
    end)
end

if CLIENT then
    WMV_939_GasRevealed = WMV_939_GasRevealed or {}

    local WMV_GAS_REVEAL_FADE_IN = 0.35
    local WMV_GAS_REVEAL_FADE_OUT = 0.6

    net.Receive("WMV_939_GasReveal", function()
        local target = net.ReadEntity()
        local duration = net.ReadFloat()
        local snd = net.ReadString()

        if IsValid(target) then
            WMV_939_GasRevealed[target] = {
                startTime = CurTime(),
                endTime = CurTime() + duration
            }
        end

        if snd and snd ~= "" then
            surface.PlaySound(snd)
        end
    end)

    hook.Add("PreDrawHalos", "WMV_939_GasRevealHalos", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        -- Only 939 should see these reveal halos.
        if not WMV_Is939Player(lp) then return end

        local now = CurTime()

        for target, data in pairs(WMV_939_GasRevealed) do
            if not IsValid(target) then
                WMV_939_GasRevealed[target] = nil
                continue
            end

            local startTime = data.startTime or now
            local endTime = data.endTime or 0

            if endTime <= now then
                WMV_939_GasRevealed[target] = nil
                continue
            end

            local timeSinceStart = now - startTime
            local timeLeft = endTime - now

            local alpha = 220

            if timeSinceStart < WMV_GAS_REVEAL_FADE_IN then
                alpha = Lerp(timeSinceStart / WMV_GAS_REVEAL_FADE_IN, 0, 220)
            elseif timeLeft < WMV_GAS_REVEAL_FADE_OUT then
                alpha = Lerp(timeLeft / WMV_GAS_REVEAL_FADE_OUT, 0, 220)
            end

            alpha = math.Clamp(alpha, 0, 220)

            local strength = alpha / 220
            local haloSize = Lerp(strength, 1, 3)
            local passes = math.max(1, math.floor(Lerp(strength, 1, 4)))

            halo.Add(
                { target },
                Color(255, 0, 0, alpha),
                haloSize,
                haloSize,
                passes,
                true,
                true
            )
        end
    end)
end

-- with many voices

local WMV_MIMIC_DISPLAY_SELECTED = 1
local WMV_MIMIC_LAST_SELECTED = 1
local WMV_MIMIC_CYCLE_PUNCH = 0
local WMV_MIMIC_UNMUTE_DURATION = 5
local WMV_MIMIC_COOLDOWN = 25
local WMV_MIMIC_HUD_ID = "wmv_mimicry"

local WMV_MIMIC_VOICES = {
    {
        name = "SCP:CB",
        icon = "materials/nexus/mimicicons/scpcb.png",
        sounds = {
            "nexus/939/mimicry/scpcbvl-01.mp3",
            "nexus/939/mimicry/scpcbvl-02.mp3",
            "nexus/939/mimicry/scpcbvl-03.mp3",
            "nexus/939/mimicry/scpcbvl-04.mp3",
            "nexus/939/mimicry/scpcbvl-05.mp3",
        }
    },
    {
        name = "Gentoi",
        icon = "materials/nexus/mimicicons/gentoi.png",
        sounds = {
            "nexus/939/playermimicry/gentoivoiceline1.mp3",
            "nexus/939/playermimicry/gentoivoiceline2.mp3",
            "nexus/939/playermimicry/gentoivoiceline3.mp3",
            "nexus/939/playermimicry/gentoivoiceline4.mp3",
            "nexus/939/playermimicry/gentoivoiceline6.mp3",
            "nexus/939/playermimicry/gentoivoiceline7.mp3",
            "nexus/939/playermimicry/gentoivoiceline8.mp3",
        }
    },
    {
        name = "Slice",
        icon = "materials/nexus/mimicicons/slice.png",
        sounds = {
            "nexus/939/playermimicry/slicevoice-01.mp3",
            "nexus/939/playermimicry/slicevoice-02.mp3",
            "nexus/939/playermimicry/slicevoice-03.mp3",
            "nexus/939/playermimicry/slicevoice-04.mp3",
        }
    },
    {
        name = "SpendingSky",
        icon = "materials/nexus/mimicicons/sky.png",
        sounds = {
            "nexus/939/playermimicry/playermimicry-01.mp3",
            "nexus/939/playermimicry/playermimicry-02.mp3",
            "nexus/939/playermimicry/playermimicry-03.mp3",
            "nexus/939/playermimicry/playermimicry-04.mp3",
        }
    },
    {
        name = "Blastnit",
        icon = "materials/nexus/mimicicons/blast.png",
        sounds = {
            "nexus/939/playermimicry/nexus 1.mp3",
            "nexus/939/playermimicry/nexus 2.mp3",
            "nexus/939/playermimicry/nexus 3.mp3",
            "nexus/939/playermimicry/nexus 4.mp3",
            "nexus/939/playermimicry/nexus 5.mp3",
        }
    },
    {
        name = "Eddygar",
        icon = "materials/nexus/mimicicons/eddygar.png",
        sounds = {
            "nexus/939/playermimicry/eddy1.mp3",
            "nexus/939/playermimicry/eddy2.mp3",
            "nexus/939/playermimicry/eddy3.mp3",
            "nexus/939/playermimicry/eddy4.mp3",
        }
    },
    {
        name = "ChiknSandwich",
        icon = "materials/nexus/mimicicons/chikn.png",
        sounds = {
            "nexus/939/playermimicry/chikn voiceline-01.mp3",
            "nexus/939/playermimicry/chikn voiceline-02.mp3",
            "nexus/939/playermimicry/chikn voiceline-03.mp3",
            "nexus/939/playermimicry/chikn voiceline-04.mp3",
            "nexus/939/playermimicry/chikn voiceline-05.mp3",
            "nexus/939/playermimicry/chikn voiceline-06.mp3",
            "nexus/939/playermimicry/chikn voiceline-07.mp3",
            "nexus/939/playermimicry/chikn voiceline-08.mp3",
        }
    },
    {
        name = "Nexus",
        icon = "materials/nexus/mimicicons/nexus.png",
        sounds = {
            "nexus/939/playermimicry/nexuslines-01.mp3",
            "nexus/939/playermimicry/nexuslines-02.mp3",
            "nexus/939/playermimicry/nexuslines-03.mp3",
            "nexus/939/playermimicry/nexuslines-04.mp3",
        }
    },
    {
        name = "Region",
        icon = "materials/nexus/mimicicons/region.png",
        sounds = {
            "nexus/939/playermimicry/region1.mp3",
            "nexus/939/playermimicry/region2.mp3",
            "nexus/939/playermimicry/region3.mp3",
            "nexus/939/playermimicry/region4.mp3",
        }
    },
    {
        name = "Dark Star",
        icon = "materials/nexus/mimicicons/dark.png",
        sounds = {
            "nexus/939/playermimicry/dark1.wav",
            "nexus/939/playermimicry/dark2.wav",
            "nexus/939/playermimicry/dark3.wav",
            "nexus/939/playermimicry/dark4.wav",
            "nexus/939/playermimicry/dark5.wav",
            "nexus/939/playermimicry/dark6.wav",
            "nexus/939/playermimicry/dark7.wav",
            "nexus/939/playermimicry/dark8.wav",
        }
    },
}

if SERVER then
    util.AddNetworkString("WMV_939_MimicFeedback")

    local function WMV_939_StartMimicCooldown(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return end
    
        local endTime = CurTime() + WMV_MIMIC_COOLDOWN
    
        ent:SetNWFloat("WMV_MIMIC_CD_END", endTime)
        ent:SetNWFloat("WMV_MIMIC_CD_DUR", WMV_MIMIC_COOLDOWN)
    
        if SherlockHNS then return end
        if WMV_StartAbilityCooldown then
            WMV_StartAbilityCooldown(ply, WMV_MIMIC_HUD_ID, WMV_MIMIC_COOLDOWN)
        elseif wmv_StartAbilityCooldown then
            wmv_StartAbilityCooldown(ply, WMV_MIMIC_HUD_ID, WMV_MIMIC_COOLDOWN)
        elseif ent.StartAbilityCooldown then
            ent:StartAbilityCooldown(WMV_MIMIC_HUD_ID, WMV_MIMIC_COOLDOWN)
        end
    end
    
    local function WMV_939_MimicCooldownLeft(ent)
        if not IsValid(ent) then return 0 end
        return math.max(0, ent:GetNWFloat("WMV_MIMIC_CD_END", 0) - CurTime())
    end

    local function WMV_939_CloseMimicMenu(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return end

        ent:SetNWBool("WMV_MIMIC_MENU_OPEN", false)
        ent:SetNWInt("WMV_MIMIC_SELECTED", ent:GetNWInt("WMV_MIMIC_SELECTED", 1))
    end

    local function WMV_939_OpenMimicMenu(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return end

        ent:SetNWBool("WMV_MIMIC_MENU_OPEN", true)

        if ent:GetNWInt("WMV_MIMIC_SELECTED", 0) <= 0 then
            ent:SetNWInt("WMV_MIMIC_SELECTED", 1)
        end

        net.Start("WMV_939_MimicFeedback")
        net.WriteString("open")
        net.Send(ply)
    end

    local function WMV_939_CycleMimic(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return end
        if not ent:GetNWBool("WMV_MIMIC_MENU_OPEN", false) then return end

        local selected = ent:GetNWInt("WMV_MIMIC_SELECTED", 1)
        selected = selected + 1

        if selected > #WMV_MIMIC_VOICES then
            selected = 1
        end

        ent:SetNWInt("WMV_MIMIC_SELECTED", selected)

        net.Start("WMV_939_MimicFeedback")
        net.WriteString("cycle")
        net.Send(ply)
    end

    local function WMV_939_PlaySelectedMimic(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return end
        if not WMV_Is939PillEnt(ent) then return end
        if not WMV_StartAbilityCooldown(ply, ent, "wmv_mimicry", WMV_MIMIC_COOLDOWN, "_wmv_NextMimicryAbility") then
            net.Start("WMV_939_MimicFeedback")
            net.WriteString("deny")
            net.Send(ply)
            return
        end

        local selected = ent:GetNWInt("WMV_MIMIC_SELECTED", 1)
        local data = WMV_MIMIC_VOICES[selected]
        if not data or not istable(data.sounds) or #data.sounds <= 0 then return end

        local snd = data.sounds[math.random(1, #data.sounds)]

        ent:EmitSound(snd, 100, 100, 1, CHAN_VOICE)
        WMV_939_StartMimicCooldown(ply, ent)

        -- Temporarily unmute 939 footsteps after mimicry.
        ent._WMV_MimicOldMuteSteps = ent.formTable.muteSteps
        ent.formTable.muteSteps = false
        
        ent:SetNWFloat("WMV_MIMIC_STEPS_MUTED_UNTIL", CurTime() + WMV_MIMIC_UNMUTE_DURATION)
        
        timer.Remove("WMV_939_MimicRestoreMute_" .. ent:EntIndex())
        timer.Create("WMV_939_MimicRestoreMute_" .. ent:EntIndex(), WMV_MIMIC_UNMUTE_DURATION, 1, function()
            if not IsValid(ent) or not ent.formTable then return end
        
            ent.formTable.muteSteps = ent._WMV_MimicOldMuteSteps
            ent:SetNWFloat("WMV_MIMIC_STEPS_MUTED_UNTIL", 0)
        
            ent._WMV_MimicOldMuteSteps = nil
        end)

        WMV_939_CloseMimicMenu(ply, ent)

        net.Start("WMV_939_MimicFeedback")
        net.WriteString("play")
        net.Send(ply)
    end

    local wmv_mimicry = function(ply, button)
        if button ~= KEY_3 then return end
        local ent = GetPillEnt(ply)
        if not WMV_Is939PillEnt(ent) then return end
        if not SherlockHNS and WMV_939_MimicCooldownLeft(ent) > 0 then
            net.Start("WMV_939_MimicFeedback")
            net.WriteString("deny")
            net.Send(ply)
            return
        end

        if ent:GetNWBool("WMV_MIMIC_MENU_OPEN", false) then
            WMV_939_PlaySelectedMimic(ply, ent)
        else
            WMV_939_OpenMimicMenu(ply, ent)
        end
    end
    hnsActions.wmv_mimicry = function(ply) return wmv_mimicry(ply, KEY_3) end
    hook.Add("PlayerButtonDown", "WMV_939_Mimicry_KEY3", function(ply, button)
        if button ~= KEY_3 then return end
        if SherlockHNS then
            local ent = GetPillEnt(ply)
            if WMV_Is939PillEnt(ent) then SherlockHNS.Ability.Use(ply, "wmv_mimicry") end
        else
            wmv_mimicry(ply, button)
        end
    end)

    local wmv_cycle = function(ply, button)
        if button ~= KEY_R then return end

        local ent = GetPillEnt(ply)
        if not WMV_Is939PillEnt(ent) then return end
        if not ent:GetNWBool("WMV_MIMIC_MENU_OPEN", false) then return end

        WMV_939_CycleMimic(ply, ent)
    end
    hnsActions.wmv_cycle = function(ply) return wmv_cycle(ply, KEY_R) end
    hook.Add("PlayerButtonDown", "WMV_939_Mimicry_R_Cycle", function(ply, button)
        if button ~= KEY_R then return end
        if SherlockHNS then
            local ent = GetPillEnt(ply)
            if WMV_Is939PillEnt(ent) then SherlockHNS.Ability.Use(ply, "wmv_cycle") end
        else
            wmv_cycle(ply, button)
        end
    end)

    hook.Add("SetupMove", "WMV_939_BlockReloadWhileMimicMenuOpen", function(ply, mv, cmd)
        local ent = GetPillEnt(ply)
        if not WMV_Is939PillEnt(ent) then return end
        if not ent:GetNWBool("WMV_MIMIC_MENU_OPEN", false) then return end

        mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_RELOAD)))
    end)
end

if CLIENT then
    local WMV_MIMIC_ICON_MATS = {}

    local function WMV_GetMimicIconMat(path)
        WMV_MIMIC_ICON_MATS[path] = WMV_MIMIC_ICON_MATS[path] or Material(path, "smooth")
        return WMV_MIMIC_ICON_MATS[path]
    end

    net.Receive("WMV_939_MimicFeedback", function()
        local mode = net.ReadString()

        if mode == "open" then
            surface.PlaySound("buttons/button15.wav")
        elseif mode == "cycle" then
            surface.PlaySound("buttons/lightswitch2.wav")
        end
    end)

    hook.Add("HUDPaint", "WMV_939_MimicryWheelHUD", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local ent = GetPillEnt(lp)
        if not WMV_Is939PillEnt(ent) then return end
        if not ent:GetNWBool("WMV_MIMIC_MENU_OPEN", false) then return end

        local selected = ent:GetNWInt("WMV_MIMIC_SELECTED", 1)

        if selected ~= WMV_MIMIC_LAST_SELECTED then
            local count = #WMV_MIMIC_VOICES
        
            if WMV_MIMIC_LAST_SELECTED == count and selected == 1 then
                WMV_MIMIC_DISPLAY_SELECTED = WMV_MIMIC_DISPLAY_SELECTED + 1
            elseif WMV_MIMIC_LAST_SELECTED == 1 and selected == count then
                WMV_MIMIC_DISPLAY_SELECTED = WMV_MIMIC_DISPLAY_SELECTED - 1
            else
                WMV_MIMIC_DISPLAY_SELECTED = selected
            end
        
            WMV_MIMIC_LAST_SELECTED = selected
            WMV_MIMIC_CYCLE_PUNCH = 1
        end
        
        local displayTarget = selected
        
        if WMV_MIMIC_DISPLAY_SELECTED > #WMV_MIMIC_VOICES then
            displayTarget = #WMV_MIMIC_VOICES + 1
        elseif WMV_MIMIC_DISPLAY_SELECTED < 1 then
            displayTarget = 0
        else
            displayTarget = selected
        end
        
        WMV_MIMIC_DISPLAY_SELECTED = Lerp(FrameTime() * 10, WMV_MIMIC_DISPLAY_SELECTED, displayTarget)
        WMV_MIMIC_CYCLE_PUNCH = Lerp(FrameTime() * 12, WMV_MIMIC_CYCLE_PUNCH, 0)
        
        if math.abs(WMV_MIMIC_DISPLAY_SELECTED - (#WMV_MIMIC_VOICES + 1)) < 0.03 then
            WMV_MIMIC_DISPLAY_SELECTED = 1
        elseif math.abs(WMV_MIMIC_DISPLAY_SELECTED - 0) < 0.03 then
            WMV_MIMIC_DISPLAY_SELECTED = #WMV_MIMIC_VOICES
        end

        local sw, sh = ScrW(), ScrH()

        -- Positive X outside screen makes the circle half-hidden on the right.
        local centerX = sw + 70
        local centerY = sh * 0.5
        local radius = 180

        local iconSize = 68
        local selectedSize = 84

        draw.SimpleText(
            "R: Cycle   |   3: Mimic",
            "DermaDefaultBold",
            sw - 260,
            centerY - 225,
            Color(255, 255, 255, 210),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )

        local selectedSlotAngle = 180
        local stepAngle = 360 / #WMV_MIMIC_VOICES

        local wheelRotation = selectedSlotAngle - ((WMV_MIMIC_DISPLAY_SELECTED - 1) * stepAngle)
        
        for i, data in ipairs(WMV_MIMIC_VOICES) do
            local ang = math.rad(((i - 1) * stepAngle) + wheelRotation)
        
            local x = centerX + math.cos(ang) * radius
            local y = centerY + math.sin(ang) * radius
        
            local isSelected = i == selected
            local pulse = isSelected and (WMV_MIMIC_CYCLE_PUNCH * 10) or 0
            local size = (isSelected and selectedSize or iconSize) + pulse
            local half = size * 0.5

            local bgColor = isSelected and Color(255, 0, 0, 210) or Color(20, 20, 20, 170)
            local outlineColor = isSelected and Color(255, 255, 255, 255) or Color(120, 120, 120, 180)

            draw.RoundedBox(12, x - half - 4, y - half - 4, size + 8, size + 8, bgColor)

            surface.SetDrawColor(outlineColor)
            surface.DrawOutlinedRect(x - half - 4, y - half - 4, size + 8, size + 8, 2)

            if data.icon and data.icon ~= "" then
                local mat = WMV_GetMimicIconMat(data.icon)
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255, isSelected and 255 or 200)
                surface.DrawTexturedRect(x - half, y - half, size, size)
            else
                draw.RoundedBox(8, x - half, y - half, size, size, Color(80, 80, 80, 220))
            end

            if isSelected then
                draw.SimpleText(
                    data.name or ("Voice " .. i),
                    "DermaDefaultBold",
                    x,
                    y + half + 18,
                    Color(255, 255, 255, 255),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end
    end)
end



-- ability 1
local function WMV_PlayClientOnlySound(ply, snd)
    if not SERVER then return end
    if not IsValid(ply) then return end
    if not snd or snd == "" then return end

    net.Start("WMV_939_ClientOnlySound")
        net.WriteString(snd)
    net.Send(ply)
end

if CLIENT then
    net.Receive("WMV_939_ClientOnlySound", function()
        local snd = net.ReadString()
        if snd == "" then return end

        surface.PlaySound(snd)
    end)
end

if SERVER then
    local wmv_extendrange = function(ply, button)
        if button ~= KEY_1 then return end

        local ent = GetPillEnt(ply)
        if not WMV_Is939PillEnt(ent) then return end

        if not WMV_StartAbilityCooldown(ply, ent, "wmv_extendrange", WMV_SENSE_COOLDOWN, "_wmv_NextSenseAbility") then
            return
        end

        WMV_PlayClientOnlySound(ply, "nexus/939/939growl.mp3")

        timer.Simple(2.5, function()
            if not IsValid(ply) or not IsValid(ent) then return end
            if not WMV_Is939PillEnt(ent) then return end

            ent:SetNWFloat("WMV_SENSE_START", CurTime())
            ent:SetNWFloat("WMV_SENSE_END", CurTime() + WMV_SENSE_DURATION)
            ent:SetNWFloat("WMV_SENSE_FADEOUT_START", CurTime() + WMV_SENSE_DURATION)

            ply:EmitSound(WMV_SENSE_SOUND, 75, 100, 1, CHAN_AUTO)
        end)
    end
    hnsActions.wmv_extendrange = function(ply) return wmv_extendrange(ply, KEY_1) end
    hook.Add("PlayerButtonDown", "WMV_939_SenseAbility_KEY1", function(ply, button)
        if button ~= KEY_1 then return end
        if SherlockHNS then
            local ent = GetPillEnt(ply)
            if WMV_Is939PillEnt(ent) then SherlockHNS.Ability.Use(ply, "wmv_extendrange") end
        else
            wmv_extendrange(ply, button)
        end
    end)
end

 -- net strings

 local function WMV_GetBoneEffectPos(modelEnt, boneName, fallbackPos)
    if not IsValid(modelEnt) then return fallbackPos end
    if not modelEnt.LookupBone then return fallbackPos end
    if not modelEnt.GetBonePosition then return fallbackPos end

    local boneID = modelEnt:LookupBone(boneName)
    if not boneID then return fallbackPos end

    if modelEnt.InvalidateBoneCache then
        modelEnt:InvalidateBoneCache()
    end

    if modelEnt.SetupBones then
        modelEnt:SetupBones()
    end

    local bonePos = modelEnt:GetBonePosition(boneID)
    if not bonePos or bonePos == vector_origin then
        return fallbackPos
    end

    return bonePos
end

if SERVER then
    util.AddNetworkString("WMV_StartCooldown")
    util.AddNetworkString("WMV_AdaptivePredator_Ping")
    util.AddNetworkString("WMV_939_IsNearSound")
    util.AddNetworkString("WMV_939_StopIsNearSound")
    util.AddNetworkString("WMV_939_SpottedSound")
    util.AddNetworkString("WMV_939_GasCloud")
    util.AddNetworkString("WMV_939_GasReveal")
    util.AddNetworkString("WMV_939_MimicFeedback")
    util.AddNetworkString("WMV_939_ClientOnlySound")
end




AddCSLuaFile()

pk_pills.packStart("SCP-939","SCP-939","icon/scp_icon.png") --the icon of the pill PACK (would be inside material folder, then another folder named icon)

pk_pills.register("pill_nexus_scp939",{ -- to give the PILL ITSELF an icon go into the same materials folder but instead of using the ICON folder put it inside a "pills" folder, and name it the same as your pill_

    printName="With Many Voices",
	
    model="models/nexus/scp/939/939.mdl", -- the same name as at the top of the qc just with models/ attatched
	
	modelScale="1",

    hud_id="wmv",
	
    anims={
        default={
            idle="idle",
			run="run",
            walk="walk",
			attack="jumpscare",
			jumpscare="jumpscare",
            crouch="cidle",
            crouch_walk="cwalk",
        },
    },
	
    moveSpeed={
        walk=80,
        run=580,
        ducked=80,
    },
	
    sounds={
		jumpscare="nexus/939/SCP_939_kill2.mp3",
        rclick="your/sound/path.wav",
        idle="nexus/939/SCP_939_idle.mp3",
        spotted=pk_pills.helpers.makeList("nexus/939/939spotted-0#.mp3",6),
        isnear="nexus/939/939isnear.mp3",
        growl="nexus/939/939growl.mp3",
        amensticbreathing="nexus/939/amnesticbreathing.mp3",
        amensticgas="nexus/939/amensticgas.mp3",
        playermimicry=pk_pills.helpers.makeList("nexus/939/playermimicry/playermimicry-0#.mp3",4),
        mimicry=pk_pills.helpers.makeList("nexus/939/mimicry/mimicry-0#.mp3",3),
    },
	

    type="ply",
    muteSteps=true,

    ThirdPersonBone = {
        'Head',
        20,
        30,
        0,
    },

    camera = {
        offset = Vector(0, 0, 75),
        dist=160,
    },
	
    jumpPower=0,
	
    health=250000,
	
	movePoseMode="xy",
		aim={
		xPose="aim_yaw",
		yPose="aim_pitch",
		nocrosshair = true
	},
	
	canAim=function(ply,ent)
		return ent.active
	end,

    

    think_n_wmv = function(ply, ent)
        if CLIENT then return end
        if not IsValid(ply) or not IsValid(ent) then return end
    
        if not ent._wmv_IsNearCleanupAdded then
            ent._wmv_IsNearCleanupAdded = true
    
            ent:CallOnRemove("WMV_StopIsNearSounds_" .. ent:EntIndex(), function()
                net.Start("WMV_939_StopIsNearSound")
                net.Broadcast()
            end)
        end
    
        if ent:GetNWBool("wmv_TV_ON", false) ~= true then
            ent:SetNWBool("wmv_TV_ON", true)
            ent:SetNWFloat("wmv_TV_T0", CurTime())
            ent:SetNWFloat("wmv_TV_REL_T0", 0)
            ent:SetNWFloat("wmv_TV_FADEIN", 0.35)
            ent:SetNWFloat("wmv_TV_FADEOUT", 0.35)
        end
    
        ent._wmv_NextIsNearCheck = ent._wmv_NextIsNearCheck or 0
        if ent._wmv_NextIsNearCheck > CurTime() then return end
        ent._wmv_NextIsNearCheck = CurTime() + 0.25
    
        local sounds = ent.formTable.sounds or {}
        local nearSound = sounds.isnear
    
        ent._wmv_IsNearPlayers = ent._wmv_IsNearPlayers or {}
        local stillNear = {}
    
        local puppet = ent:GetPuppet()
        local startPos = IsValid(puppet) and puppet:EyePos() or ply:EyePos()
    
        for _, target in ipairs(player.GetAll()) do
            if not IsValid(target) then continue end
            if target == ply then continue end
            if not target:Alive() then continue end
            if target:Team() == TEAM_SPECTATOR then continue end

            if target:GetNWBool("WMV_IN_939_GAS", false) or target:GetNWFloat("WMV_939_GAS_END", 0) > CurTime() then
                continue
            end
    
            local targetPos = target:EyePos()
    
            if startPos:DistToSqr(targetPos) > WMV_ISNEAR_RADIUS * WMV_ISNEAR_RADIUS then
                continue
            end
    
            local tr = util.TraceLine({
                start = startPos,
                endpos = targetPos,
                filter = {ply, ent, puppet, target},
                mask = MASK_VISIBLE
            })
    
            if tr.Hit then
                continue
            end
    
            stillNear[target] = true
    
            if not ent._wmv_IsNearPlayers[target] then
                ent._wmv_IsNearPlayers[target] = true
    
                if nearSound then
                    local sendSound = nearSound
    
                    if istable(sendSound) then
                        sendSound = sendSound[math.random(1, #sendSound)]
                    end
    
                    if isstring(sendSound) and sendSound ~= "" then
                        net.Start("WMV_939_IsNearSound")
                        net.WriteString(sendSound)
                        net.Send(target)
                    end
                end
            end
        end
    
        for target in pairs(ent._wmv_IsNearPlayers) do
            local isGassed = IsValid(target) and (
                target:GetNWBool("WMV_IN_939_GAS", false) or
                target:GetNWFloat("WMV_939_GAS_END", 0) > CurTime()
            )
        
            if not IsValid(target) or not stillNear[target] or isGassed then
                ent._wmv_IsNearPlayers[target] = nil
        
                if IsValid(target) then
                    net.Start("WMV_939_StopIsNearSound")
                    net.Send(target)
                end
            end
        end

        ent._wmv_NextSpottedCheck = ent._wmv_NextSpottedCheck or 0
if ent._wmv_NextSpottedCheck <= CurTime() then
    ent._wmv_NextSpottedCheck = CurTime() + 0.15

    local spottedSound = ent.formTable.sounds and ent.formTable.sounds.spotted

    if spottedSound then
        local puppet = ent:GetPuppet()
        local seenPos = IsValid(puppet) and puppet:EyePos() or ply:EyePos()

        for _, target in ipairs(player.GetAll()) do
            if not IsValid(target) then continue end
            if target == ply then continue end
            if not target:Alive() then continue end
            if target:Team() == TEAM_SPECTATOR then continue end

            if target:GetNWBool("WMV_IN_939_GAS", false) or target:GetNWFloat("WMV_939_GAS_END", 0) > CurTime() then
                continue
            end

            local eyePos = target:EyePos()

            if eyePos:DistToSqr(seenPos) > WMV_SPOTTED_RADIUS * WMV_SPOTTED_RADIUS then
                continue
            end

            local dirTo939 = (seenPos - eyePos):GetNormalized()
            local lookingDot = target:EyeAngles():Forward():Dot(dirTo939)

            if lookingDot < WMV_SPOTTED_DOT then
                continue
            end

            local tr = util.TraceLine({
                start = eyePos,
                endpos = seenPos,
                filter = {target, ply, ent, puppet},
                mask = MASK_VISIBLE
            })

            if tr.Hit then
                continue
            end

            target._wmv_Next939SpottedSound = target._wmv_Next939SpottedSound or 0
            if target._wmv_Next939SpottedSound > CurTime() then
                continue
            end

            target._wmv_Next939SpottedSound = CurTime() + WMV_SPOTTED_COOLDOWN

            local sendSound = spottedSound

            if istable(sendSound) then
                sendSound = sendSound[math.random(1, #sendSound)]
            end

            if isstring(sendSound) and sendSound ~= "" then
                net.Start("WMV_939_SpottedSound")
                net.WriteString(sendSound)
                net.Send(target)
            end
        end
    end
end


    end,

    wmvThermalVision = function(ply, ent, button)
        if CLIENT then return end
        if button ~= KEY_N then return end
        if not IsValid(ply) or not IsValid(ent) then return end
    
        ent._wmv_NL_LAST = ent._wmv_NL_LAST or 0
        if CurTime() - ent._wmv_NL_LAST < 0.2 then return end
        ent._wmv_NL_LAST = CurTime()
    
        NightLightToggle(ent, "wmv")
    end,
	
    --Left Click Attack Function
    attack = {
        mode = 'trigger',
        func = function(ply, ent)
            local entity -- make it local to avoid persisting between attacks
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


