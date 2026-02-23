local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false
local currentShop = nil
local storeCam = nil
local camOffsetZ = 0.0
local savedPosition = nil
local savedHeading = nil
local originalHair = nil
local originalBeard = nil

-- Хеши компонентов
local HAIR_HASH = 0x864B03AE      -- hair
local BEARD_HASH = 0xF8016BCA     -- beards_complete / heads_accessories

-- ==========================================
-- КАМЕРА (упрощённая — client.lua переопределит для режима «напротив игрока»)
-- ==========================================
local function CreateBarberCam()
    if not currentShop then return end
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local cam = currentShop.cam
    storeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(storeCam, cam.x, cam.y, cam.z)
    SetCamRot(storeCam, Config.CameraSettings.pitch or -4.0, 0.0, cam.w, 2)
    SetCamFov(storeCam, Config.CameraSettings.fov or 35.0)
    SetCamActive(storeCam, true)
    RenderScriptCams(true, false, 500, true, true)
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
    if not storeCam or not currentShop then return end
    
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local cam = currentShop.cam
    
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
        if currentShop then
            SetEntityHeading(ped, currentShop.coords.w)
        end
    end
    
    SetCamCoord(storeCam, cam.x, cam.y, cam.z + camOffsetZ)
    SetFocusPosAndVel(pedCoords.x, pedCoords.y, pedCoords.z + camOffsetZ, 0.0, 0.0, 0.0)
end

-- ==========================================
-- СОХРАНЕНИЕ/ВОССТАНОВЛЕНИЕ
-- ==========================================
local function SaveCurrentAppearance()
    local ped = PlayerPedId()
    
    -- Сохраняем текущие волосы
    originalHair = Citizen.InvokeNative(0x77BA37622E22023B, ped, HAIR_HASH)
    
    -- Сохраняем бороду (только для мужчин)
    local model = GetEntityModel(ped)
    if model == GetHashKey('mp_male') then
        originalBeard = Citizen.InvokeNative(0x77BA37622E22023B, ped, BEARD_HASH)
    end
    
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
    
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- ==========================================
-- ПРИМЕНЕНИЕ ПРИЧЕСКИ/БОРОДЫ
-- ==========================================
local function ApplyHair(hashname)
    local ped = PlayerPedId()
    local hash = GetHashKey(hashname)
    
    print('[RSG-Barbershop] Applying hair: ' .. hashname .. ' (hash=' .. string.format("0x%X", hash) .. ')')
    
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
    
    print('[RSG-Barbershop] Applying beard: ' .. hashname .. ' (hash=' .. string.format("0x%X", hash) .. ')')
    
    -- ★ FIX: Удаляем текущую бороду из ВСЕХ категорий (включая 'beard' из hairs_list)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beard"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_complete"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_stubble"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("mustache"), 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    Wait(50)
    
    -- Применяем новую
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

local function RemoveBeard()
    local ped = PlayerPedId()
    
    print('[RSG-Barbershop] Removing beard')
    
    -- ★ FIX: Удаляем из ВСЕХ категорий бороды (включая 'beard' из hairs_list)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beard"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_complete"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_stubble"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("mustache"), 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- ==========================================
-- ЗАГРУЗКА ДАННЫХ ПРИЧЁСОК ИЗ RSG-APPEARANCE
-- ==========================================
local function GetHairsDataForGender(isMale)
    local gender = isMale and 'male' or 'female'
    local prefix = isMale and 'M' or 'F'
    
    local data = {
        hair = {},
        beard = isMale and {} or nil
    }
    
    -- ★ ПРОБУЕМ ПОЛУЧИТЬ ИЗ RSG-APPEARANCE HAIRS_LIST
    local hairs_list = nil
    local success = pcall(function()
        hairs_list = exports['rsg-appearance']:GetHairsList()
    end)
    
    local usedExport = false
    
    if success and hairs_list and hairs_list[gender] and hairs_list[gender]['hair'] then
        print('[RSG-Barbershop] Using hairs_list from rsg-appearance')
        usedExport = true
        
        -- ★ ВОЛОСЫ
        for styleIdx, colors in pairs(hairs_list[gender]['hair']) do
            local style = {
                index = styleIdx,
                name = "Причёска " .. styleIdx,
                colors = {}
            }
            
            for colorIdx, colorData in pairs(colors) do
                -- Извлекаем название цвета из hashname
                local colorSuffix = string.match(colorData.hashname or "", "_([^_]+)$") or ""
                local colorName = HairColorNames[colorSuffix] or ("Цвет " .. colorIdx)
                
                table.insert(style.colors, {
                    index = colorIdx,
                    name = colorName,
                    hashname = colorData.hashname,
                    hash = colorData.hash
                })
            end
            
            -- Сортируем цвета по индексу
            table.sort(style.colors, function(a, b) return a.index < b.index end)
            
            table.insert(data.hair, style)
        end
        
        -- ★ БОРОДА (только для мужчин) - проверяем beard (или mustache для совместимости)
        local beardKey = (hairs_list[gender]['beard'] and 'beard') or (hairs_list[gender]['mustache'] and 'mustache') or nil
        if isMale and beardKey and hairs_list[gender][beardKey] then
            for styleIdx, colors in pairs(hairs_list[gender][beardKey]) do
                local style = {
                    index = styleIdx,
                    name = "Борода " .. styleIdx,
                    colors = {}
                }
                
                for colorIdx, colorData in pairs(colors) do
                    local colorSuffix = string.match(colorData.hashname or "", "_([^_]+)$") or ""
                    local colorName = HairColorNames[colorSuffix] or ("Цвет " .. colorIdx)
                    
                    table.insert(style.colors, {
                        index = colorIdx,
                        name = colorName,
                        hashname = colorData.hashname,
                        hash = colorData.hash
                    })
                end
                
                table.sort(style.colors, function(a, b) return a.index < b.index end)
                
                table.insert(data.beard, style)
            end
        end
    end
    
    -- ★ FALLBACK: Генерируем базовые данные ЕСЛИ экспорт не сработал ИЛИ данных мало
    if not usedExport or #data.hair == 0 then
        print('[RSG-Barbershop] Generating default hair data')
        
        -- Волосы
        for i = 1, 30 do
            local styleNum = string.format("%03d", i)
            local style = {
                index = i,
                name = "Причёска " .. i,
                colors = {}
            }
            
            for colorIdx, colorSuffix in ipairs(HairColorOrder) do
                local hashname = string.format("CLOTHING_ITEM_%s_HAIR_%s_%s", prefix, styleNum, colorSuffix)
                table.insert(style.colors, {
                    index = colorIdx,
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
                
                for colorIdx, colorSuffix in ipairs(HairColorOrder) do
                    local hashname = string.format("CLOTHING_ITEM_M_BEARD_%s_%s", styleNum, colorSuffix)
                    table.insert(style.colors, {
                        index = colorIdx,
                        name = HairColorNames[colorSuffix] or colorSuffix,
                        hashname = hashname,
                        hash = GetHashKey(hashname)
                    })
                end
                
                table.insert(data.beard, style)
            end
        end
    end
    
    -- ★ ДОПОЛНИТЕЛЬНЫЙ FALLBACK ДЛЯ БОРОДЫ если экспорт сработал но бород нет
    if isMale and (not data.beard or #data.beard == 0) then
        print('[RSG-Barbershop] Generating default beard data (fallback)')
        data.beard = {}
        for i = 1, 20 do
            local styleNum = string.format("%03d", i)
            local style = {
                index = i,
                name = "Борода " .. i,
                colors = {}
            }
            
            for colorIdx, colorSuffix in ipairs(HairColorOrder) do
                local hashname = string.format("CLOTHING_ITEM_M_BEARD_%s_%s", styleNum, colorSuffix)
                table.insert(style.colors, {
                    index = colorIdx,
                    name = HairColorNames[colorSuffix] or colorSuffix,
                    hashname = hashname,
                    hash = GetHashKey(hashname)
                })
            end
            
            table.insert(data.beard, style)
        end
    end
    
    -- Сортируем по индексу
    table.sort(data.hair, function(a, b) return a.index < b.index end)
    if data.beard then
        table.sort(data.beard, function(a, b) return a.index < b.index end)
    end
    
    print('[RSG-Barbershop] Loaded ' .. #data.hair .. ' hair styles, ' .. (data.beard and #data.beard or 0) .. ' beard styles')
    
    return data
end

-- ==========================================
-- ОТКРЫТИЕ/ЗАКРЫТИЕ (client.lua переопределит для ox_target + кресло)
-- ==========================================
function OpenBarbershop(shopIndex)
    if isOpen then return end
    
    local shop = Config.Barbershops[shopIndex]
    if not shop then return end
    
    currentShop = shop
    isOpen = true
    
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isMale = model == GetHashKey('mp_male')
    
    -- Сохраняем позицию
    savedPosition = GetEntityCoords(ped)
    savedHeading = GetEntityHeading(ped)
    
    -- Телепортируем к месту
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, shop.coords.x, shop.coords.y, shop.coords.z, false, false, false)
    SetEntityHeading(ped, shop.coords.w)
    
    Wait(300)
    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do Wait(10) end
    
    -- Сохраняем внешность
    SaveCurrentAppearance()
    
    -- Создаём камеру
    CreateBarberCam()
    
    -- Получаем данные
    local hairsData = GetHairsDataForGender(isMale)
    
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
        prices = Config.Prices
    })
end

function CloseBarbershop(purchased)
    if not isOpen then return end
    
    isOpen = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    
    DestroyBarberCam()
    
    -- Если не купили - восстанавливаем
    if not purchased then
        RestoreOriginalAppearance()
    end
    
    local ped = PlayerPedId()
    
    -- Возвращаемся
    if savedPosition then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(10) end
        
        SetEntityCoordsNoOffset(ped, savedPosition.x, savedPosition.y, savedPosition.z, false, false, false)
        SetEntityHeading(ped, savedHeading)
        
        Wait(300)
        FreezeEntityPosition(ped, false)
        DoScreenFadeIn(500)
    else
        FreezeEntityPosition(ped, false)
    end
    
    savedPosition = nil
    savedHeading = nil
    currentShop = nil
    originalHair = nil
    originalBeard = nil
end

-- ==========================================
-- NUI CALLBACKS
-- ==========================================
RegisterNUICallback('previewHair', function(data, cb)
    if data.hashname then
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
    
    print('[RSG-Barbershop] Purchase successful!')
end)

RegisterNetEvent('rsg-barbershop:client:purchaseFailed', function(reason)
    SendNUIMessage({
        action = 'purchaseFailed',
        reason = reason
    })
end)

-- Обработчик openShop и промпты/ox_target — в client.lua

-- ==========================================
-- ОЧИСТКА ПРИ ОСТАНОВКЕ
-- ==========================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isOpen then
            CloseBarbershop(false)
        end
        
        -- Удаляем промпты
        for i = 1, #Config.Barbershops do
            pcall(function()
                exports['rsg-core']:deletePrompt('barbershop_' .. i)
            end)
        end
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
