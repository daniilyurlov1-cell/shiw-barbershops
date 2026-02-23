-- ==========================================
-- ДАННЫЕ ПРИЧЁСОК И БОРОД ДЛЯ БАРБЕРШОПА
-- ==========================================

HairsData = {}

-- Цвета волос (порядок важен для индексации!)
HairColorOrder = {
    "BLONDE",
    "BROWN", 
    "DARKEST_BROWN",
    "DARK_BLONDE",
    "DARK_GINGER",
    "DARK_GREY",
    "GINGER",
    "GREY",
    "JET_BLACK",
    "LIGHT_BLONDE",
    "RED_GINGER"
}

HairColorNames = {
    ["BLONDE"] = "Блонд",
    ["BROWN"] = "Коричневый",
    ["DARKEST_BROWN"] = "Тёмно-коричневый", 
    ["DARK_BLONDE"] = "Тёмный блонд",
    ["DARK_GINGER"] = "Тёмно-рыжий",
    ["DARK_GREY"] = "Тёмно-серый",
    ["GINGER"] = "Рыжий",
    ["GREY"] = "Серый",
    ["JET_BLACK"] = "Чёрный",
    ["LIGHT_BLONDE"] = "Светлый блонд",
    ["RED_GINGER"] = "Красно-рыжий"
}

-- Функция получения хеша по hashname
function GetHairHashByName(hashname)
    return GetHashKey(hashname)
end

-- ★ ИНДЕКСЫ ЦВЕТОВ ДЛЯ ОБРАТНОЙ КОНВЕРТАЦИИ
HairColorIndex = {
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

-- Функция получения индекса цвета из суффикса
function GetColorIndexFromSuffix(suffix)
    return HairColorIndex[suffix] or 1
end

-- Функция получения суффикса цвета из индекса
function GetColorSuffixFromIndex(index)
    return HairColorOrder[index] or "JET_BLACK"
end
