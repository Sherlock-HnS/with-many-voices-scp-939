if not CLIENT then return end

WMVHUD = WMVHUD or {}
local HUD = WMVHUD

HUD.pills = HUD.pills or {}
HUD.cooldowns = HUD.cooldowns or {}
HUD.pillStage = HUD.pillStage or 1 -- current stage for pill icon

surface.CreateFont("WMV_HUDTimer", {
    font = "zai Courier Polski 1941",
    size = 48,
    weight = 10,
    antialias = true,
    additive = false
})

surface.CreateFont("WMV_HUDKey", {
    font = "zai Courier Polski 1941",
    size = 40,
    weight = 500,
    antialias = true,
    additive = false
})

-- ability circles
local AB_RADIUS     = 55
local AB_GAP        = 135

-- pill circle
local PILL_RADIUS   = 120
local PILL_OFFSET_X = 140

local GREY = Color(150, 150, 150, 230)

local BASE_X        = 110
local BASE_Y_OFFSET = 220

local KEY_DEFAULT_OFFSET_Y = AB_RADIUS + 10

local ROW_OFFSETS = {
    [1] = -AB_GAP,  -- top
    [2] = 0,        -- middle
    [3] = AB_GAP    -- bottom
}

local function GetLocalPill()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local tbl = {
        ply.pk_pill_ent,
        ply.pill_ent,
        ply.pk_pill,
        ply.pill
    }

    for _, v in ipairs(tbl) do
        if IsValid(v) then return v end
    end

    return nil
end

local function GetActiveHUD()
    local pill = GetLocalPill()
    if not IsValid(pill) then return nil end
    if not pill.formTable then return nil end
    if not pill.formTable.hud_id then return nil end

    return HUD.pills[pill.formTable.hud_id]
end

function HUD.RegisterPillHUD(id, data)
    HUD.pills[id] = data
end

function HUD.StartCooldown(slotId, duration)
    HUD.cooldowns[slotId] = {
        endTime = CurTime() + duration,
        duration = duration
    }
end

function HUD.SetPillStage(stage)
    stage = tonumber(stage) or 1
    if stage < 1 then stage = 1 end
    HUD.pillStage = stage
end

HUD.pillModel = HUD.pillModel or nil
HUD.pillModelAnim = HUD.pillModelAnim or nil

local function EnsurePillModel(mdlPath, animName)
    if IsValid(HUD.pillModel) and HUD.pillModel:GetModel() == mdlPath then
        if animName and HUD.pillModelAnim ~= animName then
            HUD.pillModel:ResetSequenceInfo()
            HUD.pillModel:SetSequence(HUD.pillModel:LookupSequence(animName) or 0)
            HUD.pillModelAnim = animName
        end
        return HUD.pillModel
    end

    if IsValid(HUD.pillModel) then
        HUD.pillModel:Remove()
        HUD.pillModel = nil
    end

    local mdl = ClientsideModel(mdlPath, RENDERGROUP_OTHER)
    if not IsValid(mdl) then return nil end

    mdl:SetNoDraw(true)

    local seq = mdl:LookupSequence(animName or "idle") or 0
    mdl:SetSequence(seq)
    mdl:SetPlaybackRate(1)

    HUD.pillModel = mdl
    HUD.pillModelAnim = animName
    return mdl
end

local function DrawDiamondStencil(cx, cy, radius)
    render.SetStencilEnable(true)
    render.SetStencilWriteMask(0xFF)
    render.SetStencilTestMask(0xFF)
    render.SetStencilReferenceValue(1)
    render.SetStencilCompareFunction(STENCIL_ALWAYS)
    render.SetStencilPassOperation(STENCIL_REPLACE)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.ClearStencil()

    render.SetColorMaterial()
    render.SetBlend(0)

    draw.NoTexture()
    surface.SetDrawColor(20, 0, 0, 255)
    surface.DrawPoly({
        { x = cx,          y = cy - radius },
        { x = cx + radius, y = cy          },
        { x = cx,          y = cy + radius },
        { x = cx - radius, y = cy          },
    })

    render.SetBlend(1)

    render.SetStencilCompareFunction(STENCIL_EQUAL)
    render.SetStencilPassOperation(STENCIL_KEEP)
end

local function EndDiamondStencil()
    render.SetStencilEnable(false)
end

local function DrawPillModel(mdlPath, animName, cx, cy, radius)
    local mdl = EnsurePillModel(mdlPath, animName)
    if not IsValid(mdl) then return end
    mdl:FrameAdvance(FrameTime())

    local sz = radius * 2

    DrawDiamondStencil(cx, cy, radius)

    cam.Start3D(
        Vector(80, 45, 22),
        Angle(0, 180, 0),
        70,
        cx - radius, cy - radius,
        sz, sz
    )
        mdl:SetPos(Vector(0, 0, 0))
        mdl:SetAngles(Angle(0, 50, 0))
        mdl:DrawModel()
    cam.End3D()

    EndDiamondStencil()
end

net.Receive("WMV_StartCooldown", function()
    local slotId = net.ReadString()
    local duration = net.ReadFloat()

    if WMVHUD and WMVHUD.StartCooldown then
        WMVHUD.StartCooldown(slotId, duration)
    end
end)

net.Receive("WMV_SetPillStage", function()
    local stage = net.ReadUInt(8) or 1

    if WMVHUD and WMVHUD.SetPillStage then
        WMVHUD.SetPillStage(stage)
    end
end)

local function GetCooldown(slotId)
    local cd = HUD.cooldowns[slotId]
    if not cd then return 0,0 end

    local remain = cd.endTime - CurTime()
    if remain <= 0 then
        HUD.cooldowns[slotId] = nil
        return 0,0
    end

    return remain, cd.duration
end

hook.Add("HUDPaint", "WMV_AbilityHUD", function()
    if SherlockHNS then return end
    local hud = GetActiveHUD()
    if not hud then return end

    local scrH = ScrH()
    local midY = scrH - BASE_Y_OFFSET

    if hud.pill then
        local pill = hud.pill
        local px = BASE_X + PILL_OFFSET_X + (pill.offsetX or 0)
        local py = midY + (pill.offsetY or 0)

        if pill.bg then
            surface.SetMaterial(pill.bg)
            surface.SetDrawColor(255, 255, 255)
            local sz = PILL_RADIUS * 2
            surface.DrawTexturedRect(px - PILL_RADIUS, py - PILL_RADIUS, sz, sz)
        end

        local stage = HUD.pillStage or 1

        if pill.modelPath then
            local animName = (pill.modelAnims and pill.modelAnims[stage]) or pill.modelAnim or "idle"
            DrawPillModel(pill.modelPath, animName, px, py, PILL_RADIUS * 0.95)
        else
            local icon = pill.icon

            if pill.icons and pill.icons[stage] then
                icon = pill.icons[stage]
            end

            local stagedKey = "icon_stage" .. tostring(stage)
            if pill[stagedKey] then
                icon = pill[stagedKey]
            end

            if icon then
                surface.SetMaterial(icon)
                surface.SetDrawColor(255, 255, 255)
                local sz = PILL_RADIUS * 1.9
                surface.DrawTexturedRect(px - sz / 2, py - sz / 2, sz, sz)
            end
        end
    end

    if not hud.slots then return end

    table.sort(hud.slots, function(a, b)
        return (a.row or 1) < (b.row or 1)
    end)

    for _, slot in ipairs(hud.slots) do
        local row = slot.row or 1
        local cx = BASE_X + (slot.offsetX or 0)
        local cy = midY + (ROW_OFFSETS[row] or 0) + (slot.offsetY or 0)
        local r = slot.size * 58 or AB_RADIUS  -- per-slot size, falls back to default
    
        local bg   = slot.bg
        local icon = slot.icon
    
        if bg then
            surface.SetMaterial(bg)
            surface.SetDrawColor(255, 255, 255)
            surface.DrawTexturedRect(cx - r, cy - r, r * 2, r * 2)
        end
    
        if icon then
            surface.SetMaterial(icon)
            surface.SetDrawColor(255, 255, 255)
            local sz = r * 1.6
            surface.DrawTexturedRect(cx - sz / 2, cy - sz / 2, sz, sz)
        end
    
        local remaining, duration = GetCooldown(slot.id)
        if remaining > 0 then
            if bg then
                surface.SetMaterial(bg)
                surface.SetDrawColor(GREY.r, GREY.g, GREY.b, GREY.a)
                surface.DrawTexturedRect(cx - r, cy - r, r * 2, r * 2)
            else
                draw.NoTexture()
                surface.SetDrawColor(GREY.r, GREY.g, GREY.b, GREY.a)
                surface.DrawRect(cx - r, cy - r, r * 2, r * 2)
            end
    
            draw.SimpleText(
                math.ceil(remaining),
                "WMV_HUDTimer",
                cx, cy,
                Color(0, 0, 0),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        else
            if slot.key then
                local keyX = cx + (slot.keyOffsetX or 0)
                local keyY = cy + (slot.keyOffsetY or (r + 10))
    
                draw.SimpleText(
                    slot.key,
                    "WMV_HUDKey",
                    keyX, keyY,
                    Color(255, 255, 255),
                    TEXT_ALIGN_CENTER
                )
            end
        end
    end
end)

local hud_background = Material("nexus/hud/abilitybg")
local default_offset_key_y = -25

HUD.RegisterPillHUD("wmv", {
    pill = {
        bg          = hud_background,
        modelPath   = "models/nexus/scp/939/939.mdl", -- path to the pill's actual model
        modelAnims  = {
            [1] = "cidle",    -- animation for stage 1
            [2] = "idle",    -- animation for stage 2 (e.g. when activated)
        },
        offsetX = 25,
        offsetY = 0
    },
    slots = {
        {
            id   = "wmv_extendrange",
            key  = "1",
            row  = 1,
            size = 1.2,
            bg   = hud_background,
            icon = Material("nexus/hud/ability2icon"),
            offsetX = 50,
            offsetY = 0,
            keyOffsetX = 0,
            keyOffsetY = AB_RADIUS + default_offset_key_y
        },
        {
            id   = "wmv_amnesticgas",
            key  = "2",
            row  = 2,
            size = 1.2,
            bg   = hud_background,
            icon = Material("nexus/hud/ability1icon"),
            offsetX = -40,
            offsetY = 0,
            keyOffsetX = 0,
            keyOffsetY = AB_RADIUS + default_offset_key_y
        },
        {
            id   = "wmv_mimicry",
            key  = "3",
            row  = 3,
            size = 1.2,
            bg   = hud_background,
            icon = Material("nexus/hud/ability3icon"),
            offsetX = 50,
            offsetY = -10,
            keyOffsetX = 0,
            keyOffsetY = AB_RADIUS + default_offset_key_y
        },
    }
})

