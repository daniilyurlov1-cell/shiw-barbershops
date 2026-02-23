Config = {}

-- Локации барбершопов
Config.Barbershops = {
    {
        coords = vec4(-816.63, -1367.93, 43.75, 283.56),     -- Блеквотер
        cam = vec4(-815.02, -1367.88, 44.30, 86.47),
        name = "Парикмахерская Блеквотер"
    },
    {
        coords = vec4(2655.32, -1179.96, 53.28, 358.97),     -- Сан-Дени
        cam = vec4(2655.43, -1178.70, 54.00, 173.97),
        name = "Парикмахерская Сан-Дени"
    },
    {
        coords = vec4(-4135.74, -4360.36, 1.52, 184.66),     -- Сан-Дени
        cam = vec4(-4135.74, -4362.36, 1.57, 351.24),
        name = "Парикмахерская Чупароса"
    },
}

-- Цены
Config.Prices = {
    hair = 26.70,         -- Цена за причёску
    beard = 46.50,        -- Цена за бороду
    eyebrows = 12.0,      -- Брови (тип и цвет)
    makeup = 15.0,        -- Цена за макияж (только женщины)
    hairShave = 15.0,     -- Цена за сбрить волосы (лысо)
    hairColor = 12.75,    -- Цена за смену цвета волос
    beardColor = 24.30,   -- Цена за смену цвета бороды
}

-- Названия цветов волос
Config.HairColors = {
    { name = "Блонд",           suffix = "BLONDE" },
    { name = "Коричневый",      suffix = "BROWN" },
    { name = "Тёмно-коричневый", suffix = "DARKEST_BROWN" },
    { name = "Тёмный блонд",    suffix = "DARK_BLONDE" },
    { name = "Тёмно-рыжий",     suffix = "DARK_GINGER" },
    { name = "Тёмно-серый",     suffix = "DARK_GREY" },
    { name = "Рыжий",           suffix = "GINGER" },
    { name = "Серый",           suffix = "GREY" },
    { name = "Чёрный",          suffix = "JET_BLACK" },
    { name = "Светлый блонд",   suffix = "LIGHT_BLONDE" },
    { name = "Красно-рыжий",    suffix = "RED_GINGER" },
}

-- Настройки камеры
Config.CameraSettings = {
    fov = 35.0,
    pitch = -4.0,
}

-- Смещение относительно стула (как в spooni-interactions): x, y, z, heading
-- GenericChairs: 0, 0, 0.5, 180 — центр стула + высота сиденья
Config.BarberChairOffset = vec4(0, 0, 0.6, 180)

-- Сценарий сидения для барбершопа (просто сидеть — нейтральная поза клиента)
Config.BarberScenarios = {
    male = 'PROP_PLAYER_BARBER_SEAT',
    female = 'PROP_PLAYER_BARBER_SEAT',
}

-- Анимация вставания со стула при выходе
Config.BarberStandAnim = {
    dict = 'amb_generic@generic_seat_chair@ft_together@arthur@stand_exit@b_hands',
    anim = 'exit_front',
    duration = 2000,  -- мс ожидания
}

-- Камера выше, трекает лицо (прямо на лицо)
Config.CamDistanceFromPlayer = 1.4
Config.CamHeightOffset = 0.7    -- Высота камеры (уровень лица)
Config.CamAimAtHeadOffset = 0.5 -- Цель камеры: голова/лицо
Config.CamTrackFace = true       -- Обновлять прицел камеры каждый кадр (трек на лицо)
