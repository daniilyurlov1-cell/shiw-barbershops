local RSGCore = exports['rsg-core']:GetCoreObject()

-- ==========================================
-- ПОКУПКА СТИЛЯ
-- ==========================================
RegisterNetEvent('rsg-barbershop:server:buyStyle', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local totalPrice = 0
    
    -- Считаем стоимость
    if data.hair and data.hair.hashname then
        totalPrice = totalPrice + (Config.Prices.hair or 2.50)
    end
    if data.beard and (data.beard.hashname or data.beard.remove) then
        totalPrice = totalPrice + (Config.Prices.beard or 1.50)
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
        
        -- ★ ОБНОВЛЯЕМ ВОЛОСЫ
        if data.hair and data.hair.hashname then
            -- Сохраняем styleIndex + 1 как model (индексация с 1)
            -- Сохраняем colorIndex + 1 как color (индексация с 1)
            local hairModel = (data.hair.styleIndex or 0) + 1
            local hairColor = (data.hair.colorIndex or 0) + 1
            
            skin.hair = hairModel
            skin.hair_color = hairColor
            
            -- ★ ТАКЖЕ СОХРАНЯЕМ HASHNAME ДЛЯ ПРЯМОГО ПРИМЕНЕНИЯ
            skin.hair_hashname = data.hair.hashname
            
            print('[RSG-Barbershop] Saving hair: model=' .. tostring(hairModel) .. 
                  ' color=' .. tostring(hairColor) .. 
                  ' hashname=' .. tostring(data.hair.hashname))
        end
        
        -- ★ ОБНОВЛЯЕМ БОРОДУ
        if data.beard then
            if data.beard.remove then
                -- Удаляем бороду
                skin.beard = 0
                skin.beard_color = 0
                skin.beard_hashname = nil
                print('[RSG-Barbershop] Removing beard')
            elseif data.beard.hashname then
                local beardModel = (data.beard.styleIndex or 0) + 1
                local beardColor = (data.beard.colorIndex or 0) + 1
                
                skin.beard = beardModel
                skin.beard_color = beardColor
                
                -- ★ ТАКЖЕ СОХРАНЯЕМ HASHNAME ДЛЯ ПРЯМОГО ПРИМЕНЕНИЯ
                skin.beard_hashname = data.beard.hashname
                
                print('[RSG-Barbershop] Saving beard: model=' .. tostring(beardModel) .. 
                      ' color=' .. tostring(beardColor) .. 
                      ' hashname=' .. tostring(data.beard.hashname))
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
    
    TriggerClientEvent('rsg-barbershop:client:purchaseSuccess', src, newMoney, data.hair, data.beard)
    
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
