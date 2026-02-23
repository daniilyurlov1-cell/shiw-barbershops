local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false
local currentShop = nil
local storeCam = nil
local camOffsetZ = 0.0
local savedPosition = nil
local savedHeading = nil
local originalHair = nil
local originalBeard = nil
local originalMakeup = nil  -- Оверлеи макияжа (только для женщин)
local originalEyebrows = nil  -- Брови (оверлеи)
-- Хеши компонентов
local HAIR_HASH = 0x864B03AE      -- hair
local BEARD_HASH = 0xF8016BCA     -- beard (heads_accessories)

-- ==========================================
-- СКРЫТИЕ ДРУГИХ ИГРОКОВ В БАРБЕРШОПЕ
-- ==========================================
local hiddenPlayers = {}

local function HideOtherPlayers()
    local myPed = PlayerPedId()
    local myPlayer = PlayerId()
    local activePlayers = GetActivePlayers()
    
    for _, player in ipairs(activePlayers) do
        if player ~= myPlayer then
            local ped = GetPlayerPed(player)
            if ped and ped ~= 0 then
                SetEntityVisible(ped, false)
                SetEntityNoCollisionEntity(myPed, ped, false)
                hiddenPlayers[player] = ped
            end
        end
    end
end

local function ShowOtherPlayers()
    for player, ped in pairs(hiddenPlayers) do
        if DoesEntityExist(ped) then
            SetEntityVisible(ped, true)
        end
    end
    hiddenPlayers = {}
end

-- Поток для постоянного скрытия других игроков пока открыт барбершоп
CreateThread(function()
    while true do
        if isOpen then
            HideOtherPlayers()
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

-- Трек камеры на лицо (обновляет прицел каждый кадр)
local BONE_HEAD = 0x796E -- SKEL_Head
CreateThread(function()
    while true do
        if isOpen and camInFrontMode and storeCam and Config.CamTrackFace then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local headCoords = GetPedBoneCoords(ped, BONE_HEAD, 0.0, 0.0, 0.0)
                PointCamAtCoord(storeCam, headCoords.x, headCoords.y, headCoords.z)
            end
        end
        Wait(0)
    end
end)

-- ==========================================
-- КАМЕРА (напротив игрока при сидении в кресле)
-- ==========================================
local camInFrontMode = false -- true = камера напротив лица

local function CreateBarberCam()
    if not currentShop then return end
    
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    
    storeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(storeCam, Config.CameraSettings.fov or 35.0)
    SetCamActive(storeCam, true)
    RenderScriptCams(true, false, 500, true, true)
    
    if camInFrontMode then
        -- Камера выше, ровно на лицо (напротив игрока)
        local h = GetEntityHeading(ped)
        local rad = math.rad(h)
        local dist = Config.CamDistanceFromPlayer or 1.5
        local heightOff = Config.CamHeightOffset or 0.5
        local camX = pedCoords.x - math.sin(rad) * dist
        local camY = pedCoords.y + math.cos(rad) * dist
        local camZ = pedCoords.z + heightOff
        SetCamCoord(storeCam, camX, camY, camZ)
        local aimZ = pedCoords.z + (Config.CamAimAtHeadOffset or 0.18)
        PointCamAtCoord(storeCam, pedCoords.x, pedCoords.y, aimZ)
    else
        local cam = currentShop.cam
        SetCamCoord(storeCam, cam.x, cam.y, cam.z)
        SetCamRot(storeCam, Config.CameraSettings.pitch, 0.0, cam.w, 2)
    end
    
    SetFocusPosAndVel(pedCoords.x, pedCoords.y, pedCoords.z, 0.0, 0.0, 0.0)
    camOffsetZ = 0.0
end

local function DestroyBarberCam()
    if storeCam then
        DestroyAllCams(true)
        RenderScriptCams(false, true, 500, true, true)
        storeCam = nil
        SetFocusEntity(PlayerPedId())
    end
end

local function MoveBarberCam(direction)
    if not storeCam then return end
    
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    
    if direction == 'up' then
        camOffsetZ = math.min(camOffsetZ + 0.15, 0.5)
    elseif direction == 'down' then
        camOffsetZ = math.max(camOffsetZ - 0.15, -0.3)
    elseif direction == 'left' then
        local heading = GetEntityHeading(ped) + 15.0
        SetEntityHeading(ped, heading)
    elseif direction == 'right' then
        local heading = GetEntityHeading(ped) - 15.0
        SetEntityHeading(ped, heading)
    elseif direction == 'reset' then
        camOffsetZ = 0.0
        if currentShop and currentShop.coords then
            SetEntityHeading(ped, currentShop.coords.w or 0)
        end
    end
    
    if camInFrontMode then
        local h = GetEntityHeading(ped)
        local rad = math.rad(h)
        local dist = Config.CamDistanceFromPlayer or 1.5
        local heightOff = Config.CamHeightOffset or 0.5
        local camX = pedCoords.x - math.sin(rad) * dist
        local camY = pedCoords.y + math.cos(rad) * dist
        local camZ = pedCoords.z + heightOff + camOffsetZ
        SetCamCoord(storeCam, camX, camY, camZ)
        local aimZ = pedCoords.z + (Config.CamAimAtHeadOffset or 0.18) + camOffsetZ * 0.5
        PointCamAtCoord(storeCam, pedCoords.x, pedCoords.y, aimZ)
    elseif currentShop and currentShop.cam then
        local cam = currentShop.cam
        SetCamCoord(storeCam, cam.x, cam.y, cam.z + camOffsetZ)
    end
    SetFocusPosAndVel(pedCoords.x, pedCoords.y, pedCoords.z + camOffsetZ, 0.0, 0.0, 0.0)
end

-- ==========================================
-- СОХРАНЕНИЕ/ВОССТАНОВЛЕНИЕ
-- ==========================================
local function GetCurrentMakeupFromSkin()
    local skin = nil
    local ok = pcall(function()
        skin = exports['rsg-appearance']:GetCurrentSkinData()
    end)
    if not ok or not skin then return nil end
    local m = {}
    for k, v in pairs({'shadows_t','shadows_op','shadows_id','shadows_c1','blush_t','blush_op','blush_id','blush_c1','lipsticks_t','lipsticks_op','lipsticks_id','lipsticks_c1','lipsticks_c2','eyeliners_t','eyeliners_op','eyeliners_id','eyeliners_c1'}) do
        if skin[v] ~= nil then m[v] = skin[v] end
    end
    return next(m) and m or nil
end

local function GetCurrentEyebrowsFromSkin()
    local skin = nil
    local ok = pcall(function()
        skin = exports['rsg-appearance']:GetCurrentSkinData()
    end)
    if not ok or not skin then return nil end
    local e = {}
    for _, k in ipairs({'eyebrows_t', 'eyebrows_op', 'eyebrows_id', 'eyebrows_c1'}) do
        if skin[k] ~= nil then e[k] = skin[k] end
    end
    return next(e) and e or nil
end

local function SaveCurrentAppearance()
    local ped = PlayerPedId()
    
    -- Сохраняем текущие волосы
    originalHair = Citizen.InvokeNative(0x77BA37622E22023B, ped, HAIR_HASH)
    
    -- Сохраняем бороду (только для мужчин)
    local model = GetEntityModel(ped)
    if model == GetHashKey('mp_male') then
        originalBeard = Citizen.InvokeNative(0x77BA37622E22023B, ped, BEARD_HASH)
    else
        -- Женщины: сохраняем макияж для отката
        originalMakeup = GetCurrentMakeupFromSkin()
    end
    originalEyebrows = GetCurrentEyebrowsFromSkin()
    
    print('[RSG-Barbershop] Saved: hair=' .. tostring(originalHair) .. ' beard=' .. tostring(originalBeard))
end

local function RestoreOriginalAppearance()
    local ped = PlayerPedId()
    
    if originalHair and originalHair ~= 0 then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, originalHair, true, true, true)
    end
    
    if originalBeard and originalBeard ~= 0 then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, originalBeard, true, true, true)
    end

    -- Восстанавливаем макияж (женщины)
    if originalMakeup then
        local ok = pcall(function()
            exports['rsg-appearance']:SetFaceOverlays(ped, originalMakeup)
        end)
        originalMakeup = nil
    end
    
    -- Восстанавливаем брови
    if originalEyebrows then
        local ok = pcall(function()
            exports['rsg-appearance']:SetFaceOverlays(ped, originalEyebrows)
        end)
        originalEyebrows = nil
    end
    
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- ==========================================
-- ПРИМЕНЕНИЕ ПРИЧЕСКИ/БОРОДЫ
-- ==========================================
local function RemoveHair()
    local ped = PlayerPedId()
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, HAIR_HASH, 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

local function ApplyHair(hashname)
    local ped = PlayerPedId()
    local hash = GetHashKey(hashname)
    
    print('[RSG-Barbershop] Applying hair: ' .. hashname .. ' (' .. hash .. ')')
    
    -- Удаляем текущие волосы
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, HAIR_HASH, 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    Wait(50)
    
    -- Применяем новые
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

local function ApplyBeard(hashname)
    local ped = PlayerPedId()
    local hash = GetHashKey(hashname)
    
    print('[RSG-Barbershop] Applying beard: ' .. hashname .. ' (' .. hash .. ')')
    
    -- Удаляем текущую бороду
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, BEARD_HASH, 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    Wait(50)
    
    -- Применяем новую
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

local function RemoveBeard()
    local ped = PlayerPedId()
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, BEARD_HASH, 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- ==========================================
-- ЗАГРУЗКА ДАННЫХ ПРИЧЁСОК
-- ==========================================
local function GetHairsDataForGender(isMale)
    local gender = isMale and 'male' or 'female'
    local prefix = isMale and 'M' or 'F'
    
    local data = {
        hair = {},
        beard = isMale and {} or nil
    }
    
    -- Загружаем из rsg-appearance
    local hairsList = nil
    local success = pcall(function()
        hairsList = exports['rsg-appearance']:GetHairsList()
    end)
    
    if not success or not hairsList then
        -- Генерируем базовые данные
        print('[RSG-Barbershop] Generating default hair data')
        
        -- Волосы
        for i = 1, 30 do
            local styleNum = string.format("%03d", i)
            local style = {
                index = i,
                name = "Причёска " .. i,
                colors = {}
            }
            
            for _, colorSuffix in ipairs(HairColorOrder) do
                local hashname = string.format("CLOTHING_ITEM_%s_HAIR_%s_%s", prefix, styleNum, colorSuffix)
                table.insert(style.colors, {
                    name = HairColorNames[colorSuffix] or colorSuffix,
                    hashname = hashname,
                    hash = GetHashKey(hashname)
                })
            end
            
            table.insert(data.hair, style)
        end
        
        -- Борода (только мужчины)
        if isMale then
            for i = 1, 20 do
                local styleNum = string.format("%03d", i)
                local style = {
                    index = i,
                    name = "Борода " .. i,
                    colors = {}
                }
                
                for _, colorSuffix in ipairs(HairColorOrder) do
                    local hashname = string.format("CLOTHING_ITEM_M_BEARD_%s_%s", styleNum, colorSuffix)
                    table.insert(style.colors, {
                        name = HairColorNames[colorSuffix] or colorSuffix,
                        hashname = hashname,
                        hash = GetHashKey(hashname)
                    })
                end
                
                table.insert(data.beard, style)
            end
        end
        
        return data
    end
    
    -- Преобразуем данные из hairs_list
    if hairsList[gender] then
        -- Волосы
        if hairsList[gender].hair then
            for styleIdx, colors in pairs(hairsList[gender].hair) do
                local style = {
                    index = styleIdx,
                    name = "Причёска " .. styleIdx,
                    colors = {}
                }
                
                for colorIdx, colorData in pairs(colors) do
                    table.insert(style.colors, {
                        name = HairColorNames[string.match(colorData.hashname or "", "_([^_]+)$")] or ("Цвет " .. colorIdx),
                        hashname = colorData.hashname,
                        hash = colorData.hash
                    })
                end
                
                table.insert(data.hair, style)
            end
        end
        
        -- Борода
        if isMale and hairsList[gender].beard then
            for styleIdx, colors in pairs(hairsList[gender].beard) do
                local style = {
                    index = styleIdx,
                    name = "Борода " .. styleIdx,
                    colors = {}
                }
                
                for colorIdx, colorData in pairs(colors) do
                    table.insert(style.colors, {
                        name = HairColorNames[string.match(colorData.hashname or "", "_([^_]+)$")] or ("Цвет " .. colorIdx),
                        hashname = colorData.hashname,
                        hash = colorData.hash
                    })
                end
                
                table.insert(data.beard, style)
            end
        end
    end
    
    -- Сортируем по индексу
    table.sort(data.hair, function(a, b) return a.index < b.index end)
    if data.beard then
        table.sort(data.beard, function(a, b) return a.index < b.index end)
    end
    
    return data
end

-- ==========================================
-- ОТКРЫТИЕ/ЗАКРЫТИЕ
-- ==========================================
function OpenBarbershop(shopIndex, chairEntity)
    if isOpen then return end
    
    local shop = Config.Barbershops[shopIndex]
    if not shop then return end
    
    currentShop = shop
    isOpen = true
    camInFrontMode = (chairEntity ~= nil)
    
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isMale = model == GetHashKey('mp_male')
    
    savedPosition = GetEntityCoords(ped)
    savedHeading = GetEntityHeading(ped)
    
    if chairEntity and DoesEntityExist(chairEntity) then
        -- Как в spooni-interactions: TaskStartScenarioAtPosition на стул без ручных смещений
        local objCoords = GetEntityCoords(chairEntity)
        local objHeading = GetEntityHeading(chairEntity)
        local off = Config.BarberChairOffset or vec4(0, 0, 0.5, 180)
        local r = math.rad(objHeading)
        local cosr = math.cos(r)
        local sinr = math.sin(r)
        local x = (off.x or 0) * cosr - (off.y or 0) * sinr + objCoords.x
        local y = (off.y or 0) * cosr + (off.x or 0) * sinr + objCoords.y
        local z = (off.z or 0.5) + objCoords.z
        local h = (off.w or off[4] or 180) + objHeading
        
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, true)
        local scenario = Config.BarberScenarios and Config.BarberScenarios.male or 'PROP_PLAYER_BARBER_SEAT'
        TaskStartScenarioAtPosition(ped, GetHashKey(scenario), x, y, z, h, -1, false, true)
        Wait(2000)
    else
        -- Legacy: телепорт к coords
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(10) end
        FreezeEntityPosition(ped, true)
        SetEntityCoordsNoOffset(ped, shop.coords.x, shop.coords.y, shop.coords.z, false, false, false)
        SetEntityHeading(ped, shop.coords.w)
        Wait(300)
        DoScreenFadeIn(500)
        while not IsScreenFadedIn() do Wait(10) end
    end
    
    SaveCurrentAppearance()
    HideOtherPlayers()
    CreateBarberCam()
    
    -- Получаем данные
    local hairsData = GetHairsDataForGender(isMale)
    local makeupData = (not isMale) and (MakeupData or {}) or nil
    local currentMakeup = (not isMale) and GetCurrentMakeupFromSkin() or nil
    local eyebrowsData = EyebrowsData and EyebrowsData.eyebrows or { t_min = 1, t_max = 22, op_max = 100, id_max = 25, c1_max = 64 }
    local currentEyebrows = GetCurrentEyebrowsFromSkin()
    
    -- Получаем деньги
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local money = PlayerData.money.cash or 0
    
    -- Открываем UI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        isMale = isMale,
        money = money,
        shopName = shop.name,
        hairsData = hairsData,
        makeupData = makeupData,
        currentMakeup = currentMakeup,
        eyebrowsData = eyebrowsData,
        currentEyebrows = currentEyebrows,
        prices = Config.Prices
    })
end

function CloseBarbershop(purchased)
    if not isOpen then return end
    
    isOpen = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    
    DestroyBarberCam()
    
    -- Показываем других игроков
    ShowOtherPlayers()
    
    -- Если не купили - восстанавливаем
    if not purchased then
        RestoreOriginalAppearance()
    end
    
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    
    -- Анимация вставания
    local standCfg = Config.BarberStandAnim
    if standCfg and standCfg.dict and standCfg.anim then
        local dict = standCfg.dict
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end
        if HasAnimDictLoaded(dict) then
            local dur = standCfg.duration or 2000
            TaskPlayAnim(ped, dict, standCfg.anim, 8.0, -8.0, dur, 0, 0, false, false, false)
            Wait(dur)
        end
    end
    
    FreezeEntityPosition(ped, false)
    
    -- Возвращаемся
    if savedPosition then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(10) end
        
        SetEntityCoordsNoOffset(ped, savedPosition.x, savedPosition.y, savedPosition.z, false, false, false)
        SetEntityHeading(ped, savedHeading)
        
        Wait(200)
        DoScreenFadeIn(500)
    end
    
    savedPosition = nil
    savedHeading = nil
    currentShop = nil
    originalHair = nil
    originalBeard = nil
    originalMakeup = nil
    originalEyebrows = nil
    Wait(500)
    ExecuteCommand('loadcharacter')
end

-- ==========================================
-- NUI CALLBACKS
-- ==========================================
RegisterNUICallback('previewHair', function(data, cb)
    if data.remove then
        RemoveHair()
    elseif data.hashname then
        ApplyHair(data.hashname)
    end
    cb('ok')
end)

RegisterNUICallback('previewBeard', function(data, cb)
    if data.hashname then
        ApplyBeard(data.hashname)
    elseif data.remove then
        RemoveBeard()
    end
    cb('ok')
end)

RegisterNUICallback('previewMakeup', function(data, cb)
    if not data or type(data) ~= 'table' then cb('ok') return end
    local ped = PlayerPedId()
    local ok = pcall(function()
        exports['rsg-appearance']:SetFaceOverlays(ped, data)
    end)
    cb('ok')
end)

RegisterNUICallback('previewEyebrows', function(data, cb)
    if not data or type(data) ~= 'table' then cb('ok') return end
    local ped = PlayerPedId()
    local ok = pcall(function()
        exports['rsg-appearance']:SetFaceOverlays(ped, data)
    end)
    cb('ok')
end)

RegisterNUICallback('buyStyle', function(data, cb)
    -- Отправляем на сервер для покупки
    TriggerServerEvent('rsg-barbershop:server:buyStyle', data)
    cb('ok')
end)

RegisterNUICallback('moveCamera', function(data, cb)
    MoveBarberCam(data.direction)
    cb('ok')
end)

RegisterNUICallback('closeShop', function(data, cb)
    CloseBarbershop(data.purchased or false)
    cb('ok')
end)

-- ==========================================
-- СЕРВЕРНЫЕ СОБЫТИЯ
-- ==========================================
RegisterNetEvent('rsg-barbershop:client:purchaseSuccess', function(newMoney, hairData, beardData)
    SendNUIMessage({
        action = 'purchaseSuccess',
        newMoney = newMoney
    })
    
    -- Данные уже сохранены на сервере в playerskins.skin
    -- Ничего дополнительно делать не нужно
    print('[RSG-Barbershop] Purchase successful!')
end)

RegisterNetEvent('rsg-barbershop:client:purchaseFailed', function(reason)
    SendNUIMessage({
        action = 'purchaseFailed',
        reason = reason
    })
end)

RegisterNetEvent('rsg-barbershop:client:openShop', function(shopIndex, chairEntity)
    OpenBarbershop(shopIndex, chairEntity)
end)

-- ==========================================
-- OX_TARGET на креслах барбера (p_barberchair01x, 02x, 03x)
-- ==========================================
CreateThread(function()
    while RSGCore == nil do
        Wait(100)
    end
    if GetResourceState('ox_target') ~= 'started' then
        print('[RSG-Barbershop] ox_target не найден, барбершоп недоступен')
        return
    end
    Wait(1000)

    local barberOptions = {
        {
            name = 'barbershop_use',
            icon = 'fas fa-cut',
            label = 'Подстричься',
            distance = 2.0,
            canInteract = function()
                return not isOpen
            end,
            onSelect = function(data)
                local entity = data.entity
                if not entity or not DoesEntityExist(entity) then return end
                
                local chairCoords = GetEntityCoords(entity)
                local closestIdx = 1
                local closestDist = 999999.0
                for i, shop in ipairs(Config.Barbershops or {}) do
                    local sc = shop.coords
                    local d = #(chairCoords - vector3(sc.x, sc.y, sc.z))
                    if d < closestDist then
                        closestDist = d
                        closestIdx = i
                    end
                end
                TriggerEvent('rsg-barbershop:client:openShop', closestIdx, entity)
            end,
        },
    }
    for _, model in ipairs({'p_barberchair01x', 'p_barberchair02x', 'p_barberchair03x'}) do
        exports.ox_target:addModel(model, barberOptions)
    end
    
    -- Блипы
    for i, shop in ipairs(Config.Barbershops or {}) do
        local blip = BlipAddForCoords(1664425300, shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, GetHashKey('blip_shop_barber'), true)
        SetBlipScale(blip, 0.2)
        SetBlipName(blip, shop.name)
    end
end)

-- ==========================================
-- ОЧИСТКА ПРИ ОСТАНОВКЕ
-- ==========================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isOpen then
            CloseBarbershop(false)
        end
        ShowOtherPlayers()
    end
end)
-- ==========================================
-- УПРАВЛЕНИЕ
-- ==========================================
CreateThread(function()
    while true do
        Wait(0)
        if isOpen then
            DisableAllControlActions(0)
            if IsControlJustPressed(0, 0x156F7119) then -- Backspace
                CloseBarbershop(false)
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isOpen then
            CloseBarbershop(false)
        end
    end
end)