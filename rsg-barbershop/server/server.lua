local RSGCore = exports['rsg-core']:GetCoreObject()

-- ==========================================
-- КОНВЕРТАЦИЯ ЦВЕТА ИЗ СУФФИКСА В ИНДЕКС
-- ==========================================
local function GetColorIndexFromSuffix(suffix)
    local colorMap = {
        ["BLONDE"] = 1,
        ["BROWN"] = 2,
        ["DARKEST_BROWN"] = 3,
        ["DARK_BLONDE"] = 4,
        ["DARK_GINGER"] = 5,
        ["DARK_GREY"] = 6,
        ["GINGER"] = 7,
        ["GREY"] = 8,
        ["JET_BLACK"] = 9,
        ["LIGHT_BLONDE"] = 10,
        ["RED_GINGER"] = 11,
    }
    return colorMap[suffix] or 1
end

-- ==========================================
-- ПОКУПКА СТИЛЯ
-- ==========================================
RegisterNetEvent('rsg-barbershop:server:buyStyle', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local totalPrice = 0
    
    if data.eyebrows and type(data.eyebrows) == 'table' and next(data.eyebrows) then
        totalPrice = totalPrice + (Config.Prices.eyebrows or 12.0)
    end
    if data.makeup and type(data.makeup) == 'table' and next(data.makeup) then
        totalPrice = totalPrice + (Config.Prices.makeup or 15.0)
    end
    if data.hair then
        if data.hair.remove then
            totalPrice = totalPrice + (Config.Prices.hairShave or Config.Prices.hair * 0.5 or 15.0)
        elseif data.hair.hashname then
            totalPrice = totalPrice + (Config.Prices.hair or 2.50)
        end
    end
    if data.beard and (data.beard.hashname or data.beard.remove) then
        totalPrice = totalPrice + (data.beard.remove and (Config.Prices.beard or 1.50) * 0.5 or (Config.Prices.beard or 1.50))
    end
    
    local playerMoney = Player.PlayerData.money.cash or 0
    
    if playerMoney < totalPrice then
        TriggerClientEvent('rsg-barbershop:client:purchaseFailed', src, 'Недостаточно денег')
        return
    end
    
    local success = Player.Functions.RemoveMoney('cash', totalPrice, 'barbershop-service')
    
    if not success then
        TriggerClientEvent('rsg-barbershop:client:purchaseFailed', src, 'Ошибка оплаты')
        return
    end
    
    local newMoney = Player.PlayerData.money.cash
    local citizenid = Player.PlayerData.citizenid
    
    -- ==========================================
    -- ОБНОВЛЯЕМ SKIN В БАЗЕ ДАННЫХ
    -- ==========================================
    
    -- Получаем текущий skin из БД
    local result = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = ?', { citizenid })
    
    if result and result[1] and result[1].skin then
        local skin = json.decode(result[1].skin)
        
        -- Обновляем волосы
        if data.hair then
            if data.hair.remove then
                skin.hair = 0
                skin.hair_color = 0
                skin.hair_hashname = nil
                print('[RSG-Barbershop] Removing hair (shave)')
            elseif data.hair.hashname then
            -- ★ FIX: ВСЕГДА сохраняем hashname — это главный источник правды при загрузке
            -- LoadHair в rsg-appearance сначала проверяет hair_hashname
            skin.hair_hashname = data.hair.hashname
            
            -- Парсим hashname для получения model и color (fallback)
            -- Формат: CLOTHING_ITEM_M_HAIR_001_BLONDE или CLOTHING_ITEM_F_HAIR_001_BLONDE
            local styleNum, colorSuffix = string.match(data.hair.hashname, "CLOTHING_ITEM_[MF]_HAIR_(%d+)_(.+)")
            
            if styleNum then
                skin.hair = tonumber(styleNum) or 1
                skin.hair_color = GetColorIndexFromSuffix(colorSuffix) or 1
            else
                print('[RSG-Barbershop] WARNING: Could not parse hair hashname: ' .. tostring(data.hair.hashname))
            end
            
            print('[RSG-Barbershop] Saving hair: hashname=' .. tostring(data.hair.hashname) .. 
                  ' model=' .. tostring(skin.hair) .. ' color=' .. tostring(skin.hair_color))
            end
        end
        
        -- Обновляем брови (оверлеи)
        if data.eyebrows and type(data.eyebrows) == 'table' and next(data.eyebrows) then
            for _, k in ipairs({'eyebrows_t', 'eyebrows_op', 'eyebrows_id', 'eyebrows_c1'}) do
                if data.eyebrows[k] ~= nil then
                    skin[k] = data.eyebrows[k]
                end
            end
            print('[RSG-Barbershop] Saving eyebrows overlays')
        end
        
        -- Обновляем макияж (оверлеи)
        if data.makeup and type(data.makeup) == 'table' and next(data.makeup) then
            local overlayKeys = {
                'shadows_t','shadows_op','shadows_id','shadows_c1',
                'blush_t','blush_op','blush_id','blush_c1',
                'lipsticks_t','lipsticks_op','lipsticks_id','lipsticks_c1','lipsticks_c2',
                'eyeliners_t','eyeliners_op','eyeliners_id','eyeliners_c1'
            }
            for _, k in ipairs(overlayKeys) do
                if data.makeup[k] ~= nil then
                    skin[k] = data.makeup[k]
                end
            end
            print('[RSG-Barbershop] Saving makeup overlays')
        end
        
        -- Обновляем бороду
        if data.beard then
            if data.beard.remove then
                -- Удаляем бороду
                skin.beard = 0
                skin.beard_color = 0
                skin.beard_hashname = nil
                print('[RSG-Barbershop] Removing beard')
            elseif data.beard.hashname then
                -- ★ FIX: ВСЕГДА сохраняем hashname — это главный источник правды при загрузке
                -- LoadBeard в rsg-appearance сначала проверяет beard_hashname
                skin.beard_hashname = data.beard.hashname
                
                -- Парсим hashname для получения model и color (fallback)
                -- ★ FIX: Поддерживаем форматы BEARD, MUSTACHE и BEARDS_COMPLETE
                local styleNum, colorSuffix = string.match(data.beard.hashname, "CLOTHING_ITEM_M_BEARD_(%d+)_(.+)")
                
                if not styleNum then
                    styleNum, colorSuffix = string.match(data.beard.hashname, "CLOTHING_ITEM_M_MUSTACHE_(%d+)_(.+)")
                end
                
                if not styleNum then
                    styleNum, colorSuffix = string.match(data.beard.hashname, "CLOTHING_ITEM_M_BEARDS_COMPLETE_(%d+)_(.+)")
                end
                
                if styleNum then
                    skin.beard = tonumber(styleNum) or 1
                    skin.beard_color = GetColorIndexFromSuffix(colorSuffix) or 1
                else
                    print('[RSG-Barbershop] WARNING: Could not parse beard hashname: ' .. tostring(data.beard.hashname))
                end
                
                print('[RSG-Barbershop] Saving beard: hashname=' .. tostring(data.beard.hashname) .. 
                      ' model=' .. tostring(skin.beard) .. ' color=' .. tostring(skin.beard_color))
            end
        end
        
        -- Сохраняем обновлённый skin
        local encodedSkin = json.encode(skin)
        MySQL.Async.execute('UPDATE playerskins SET skin = @skin WHERE citizenid = @citizenid', {
            ['@skin'] = encodedSkin,
            ['@citizenid'] = citizenid
        }, function(rowsChanged)
            print('[RSG-Barbershop] Updated skin in database, rows changed: ' .. tostring(rowsChanged))
        end)
    else
        print('[RSG-Barbershop] ERROR: No skin found for citizenid ' .. citizenid)
    end
    
    TriggerClientEvent('rsg-barbershop:client:purchaseSuccess', src, newMoney, data.hair, data.beard, data.eyebrows, data.makeup)
    
    print(string.format('[RSG-Barbershop] %s %s - услуги на $%.2f', 
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname,
        totalPrice
    ))
end)

-- ==========================================
-- CALLBACK ДЛЯ ПОЛУЧЕНИЯ ДЕНЕГ
-- ==========================================
RSGCore.Functions.CreateCallback('rsg-barbershop:server:getPlayerMoney', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        cb(Player.PlayerData.money.cash or 0)
    else
        cb(0)
    end
end)
