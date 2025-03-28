BINDING_NAME_DETAILSTTSMENU = "Open Details TTS Menu"
BINDING_NAME_DETAILSTTSUP = "Cycle up"
BINDING_NAME_DETAILSTTSDOWN = "Cycle down"
BINDING_NAME_DETAILSTTSENTER = "Select a menu item"


VITooltipsSpeechDB = VITooltipsSpeechDB or {}
VITooltipsSpeechDB.Speech = VITooltipsSpeechDB.Speech or {
    voiceID = 2,
    speechRate = 2,
    speechVolume = 100
}
Speech = {}
Speech.db = VITooltipsSpeechDB.Speech
local Details = _G.Details

local menuOpen = false
local currentOption = 1
local selectingPlayer = false
local playerNames = {}
local selectedPlayerIndex = 1

local ones = {
    [1] = "one", [2] = "two", [3] = "three", [4] = "four", [5] = "five",
    [6] = "six", [7] = "seven", [8] = "eight", [9] = "nine", [10] = "ten",
    [11] = "eleven", [12] = "twelve", [13] = "thirteen", [14] = "fourteen",
    [15] = "fifteen", [16] = "sixteen", [17] = "seventeen", [18] = "eighteen",
    [19] = "nineteen"
}

local tens = {
    [2] = "twenty", [3] = "thirty", [4] = "forty", [5] = "fifty",
    [6] = "sixty", [7] = "seventy", [8] = "eighty", [9] = "ninety"
}

local function convertGroup(n)
    n = tonumber(n)
    if n == 0 then return "" end
    if n < 20 then
        return ones[n]
    elseif n < 100 then
        local ten = math.floor(n / 10)
        local one = n % 10
        return tens[ten] .. (one > 0 and "-" .. ones[one] or "")
    elseif n < 1000 then
        local hundred = math.floor(n / 100)
        local rest = n % 100
        return ones[hundred] .. " hundred" .. (rest > 0 and " and " .. convertGroup(rest) or "")
    end
    return ""
end

local function numberToWords(num)
    if num == 0 then return "Zero" end
    
    local function splitIntoGroups(n)
        local groups = {}
        local str = tostring(n)
        while #str > 0 do
            groups[#groups + 1] = tonumber(str:sub(-3))
            str = str:sub(1, -4)
        end
        return groups
    end

    local groups = splitIntoGroups(num)
    local scales = {"", "thousand", "million", "billion", "trillion"}
    local result = {}
    
    for i = #groups, 1, -1 do
        local value = groups[i]
        if value and value > 0 then
            local words = convertGroup(value)
            if words ~= "" then
                local scale = scales[i]
                if scale ~= "" then
                    table.insert(result, words .. " " .. scale)
                else
                    table.insert(result, words)
                end
            end
        end
    end
    
    -- Join the parts with appropriate spacing
    local final = table.concat(result, " ")
    
    -- Add "and" before the last two digits if appropriate
    if num > 100 then
        local lastTwoDigits = num % 100
        if lastTwoDigits > 0 and lastTwoDigits < 20 then
            final = final:gsub("(%s%w+)$", " and%1")
        end
    end
    
    return final:sub(1,1):upper() .. final:sub(2)
end

local function GetPartyMemberNames()
    local partyNames = { UnitName("player") }

    -- Check if we are in a party or a raid
    if IsInGroup() then
        -- If in a raid, loop through all raid members
        if IsInRaid() then
            for i = 1, GetNumRaidMembers() do
                local name = UnitName("raid" .. i)
                if name then
                    table.insert(partyNames, name)
                end
            end
        -- If in a party, loop through all party members (up to 4 party members)
        else
            for i = 1, 4 do
                local name = UnitName("party" .. i)
                if name then
                    table.insert(partyNames, name)
                end
            end
        end
    end

    return partyNames
end

local function UpdatePlayerList()
    playerNames = GetPartyMemberNames()
    selectedPlayerIndex = 1
end

function Speech:speak(text)
    if C_VoiceChat and C_VoiceChat.SpeakText then
        C_VoiceChat.SpeakText(VITooltipsSpeechDB.Speech.voiceID, text, Enum.VoiceTtsDestination.ScreenReader, VITooltipsSpeechDB.Speech.speechRate, VITooltipsSpeechDB.Speech.speechVolume)
    else
        print("VoiceChat API is unavailable for TTS.")
    end
end

local function GetAllPlayersInfo()
    if not Details or not Details:GetCurrentCombat() then
        print("Details is not available or no combat data.")
        return
    end
    
    local combat = Details:GetCurrentCombat()
    local partyNames = GetPartyMemberNames()
    local damageActors = combat:GetActorList(DETAILS_ATTRIBUTE_DAMAGE)
    local healingActors = combat:GetActorList(DETAILS_ATTRIBUTE_HEAL)
	local miscActors = combat:GetActorList(DETAILS_ATTRIBUTE_MISC)
    local playerData = {}

    -- Collect damage and damage taken
    for _, actor in ipairs(damageActors) do
        if table.contains(partyNames, actor.nome) then
            playerData[actor.nome] = playerData[actor.nome] or {}
            playerData[actor.nome].damageDone = math.floor(actor.total or 0)
            playerData[actor.nome].damageTaken = math.floor(actor.damage_taken or 0)
        end
    end

    -- Collect healing data
    for _, actor in ipairs(healingActors) do
        if table.contains(partyNames, actor.nome) then
            playerData[actor.nome] = playerData[actor.nome] or {}
            playerData[actor.nome].healingDone = math.floor(actor.total or 0)
        end
    end
	
	-- Collect inturrupt data
    for _, actor in ipairs(miscActors) do
        if table.contains(partyNames, actor.nome) then
            playerData[actor.nome] = playerData[actor.nome] or {}
            playerData[actor.nome].interruptsDone = math.floor(actor.interrupt or 0)
        end
    end


    -- Format output
    local output = ""
    for playerName, data in pairs(playerData) do
        output = output .. string.format("%s dealt %s damage, healed %s health, took %s damage, inturrupted %s times.\n",
            playerName, numberToWords(data.damageDone) or "Zero", numberToWords(data.healingDone) or "Zero", numberToWords(data.damageTaken) or "Zero", numberToWords(data.interruptsDone) or "Zero")
    end

    print(output)
    Speech:speak(output)
end

local function GetSpellNameById(spellId)
    if spellId == 1 then
        return "Auto Attack" -- Autoattacks dont have a spell id and they default to 1, which has been unused to years, we can consider spellid 1 to be autoattacks
    end
	
    local spellInfo = C_Spell.GetSpellInfo(spellId)
    return spellInfo and spellInfo.name or "Unknown Spell"
end

local function GetDamageForPlayer(playerName)
    if not Details or not Details:GetCurrentCombat() then
        print("Details is not available or no combat data.")
        return
    end
    if playerName == nil or playerName == "" then
        local playerNameWithRealm = UnitName("player")
        playerName = playerNameWithRealm:gsub("nil", "")

        print("Player Name: " .. playerName)
    end
    
    local combat = Details:GetCurrentCombat()
    local damageActors = combat:GetActorList(DETAILS_ATTRIBUTE_DAMAGE)
    local output = ""

    for _, actor in ipairs(damageActors) do
        if actor.nome == playerName then
            local actorName = actor.nome
            local damageDone = math.floor(actor.total or 0)
            
            output = output .. actorName .. " did " .. numberToWords(damageDone) .. " damage.\n"

            if actor.spells and actor.spells._ActorTable then
                for spellId, spellData in pairs(actor.spells._ActorTable) do
                    local spellName = GetSpellNameById(spellId)
                    local totalDamage = spellData.total or 0
                    local hits = spellData.counter or 0
                    output = output .. string.format("Spell %s - Damage %s - Hits - %s\n", spellName, numberToWords(totalDamage), numberToWords(hits))
                end
            end
        end
    end

    print(output)
    Speech:speak(output)
end

local function GetInterruptsForPlayer(playerName)
    if not Details or not Details:GetCurrentCombat() then
        print("Details is not available or no combat data.")
        return
    end

    local combat = Details:GetCurrentCombat()
    local miscActors = combat:GetActorList(DETAILS_ATTRIBUTE_MISC)
    local output = ""

    for _, actor in ipairs(miscActors) do
        if actor.nome == playerName then
            local interrupts = tonumber(actor.interrupt) or 0
            output = output .. playerName .. " interrupted " .. numberToWords(math.floor(interrupts)) .. " times.\n"
        end
    end

    print(output)
    Speech:speak(output)
end

local function GetDispellsForPlayer(playerName)
    if not Details or not Details:GetCurrentCombat() then
        print("Details is not available or no combat data.")
        return
    end

    local combat = Details:GetCurrentCombat()
    local miscActors = combat:GetActorList(DETAILS_ATTRIBUTE_MISC)
    local output = ""

    for _, actor in ipairs(miscActors) do
        if actor.nome == playerName then
            local dispells = tonumber(actor.dispell) or 0
            output = output .. playerName .. " dispelled " .. numberToWords(math.floor(dispells)) .. " times.\n"
        end
    end

    print(output)
    Speech:speak(output)
end

local function GetHealingForPlayer(playerName)
    if not Details or not Details:GetCurrentCombat() then
        print("Details is not available or no combat data.")
        return
    end
    if playerName == nil or playerName == "" then
        local playerNameWithRealm = UnitName("player")
        playerName = playerNameWithRealm:gsub("nil", "")

        print("Player Name: " .. playerName)
    end
    
    local combat = Details:GetCurrentCombat()
    local healingActors = combat:GetActorList(DETAILS_ATTRIBUTE_HEAL)
    local output = ""

    for _, actor in ipairs(healingActors) do
        if actor.nome == playerName then
            local actorName = actor.nome
            local healingDone = math.floor(actor.total or 0)
            output = output .. actorName .. " healed for " .. numberToWords(healingDone) .. " health.\n"

            if actor.spells and actor.spells._ActorTable then
                for spellId, spellData in pairs(actor.spells._ActorTable) do
                    local spellName = GetSpellNameById(spellId)
                    local totalHealing = spellData.total or 0
                    local hits = spellData.counter or 0
                    output = output .. string.format("Healing Spell %s - Healed %s - Hits %s\n", spellName, numberToWords(totalHealing), numberToWords(hits))
                end
            end
        end
    end

    print(output)
    Speech:speak(output)
end

local function GetDamageTakenForPlayer(playerName)
    if not Details or not Details:GetCurrentCombat() then
        print("Details is not available or no combat data.")
        return
    end
    if playerName == nil or playerName == "" then
        local playerNameWithRealm = UnitName("player")
        playerName = playerNameWithRealm:gsub("nil", "")

        print("Player Name: " .. playerName)
    end
    
    local combat = Details:GetCurrentCombat()
    local damageActors = combat:GetActorList(DETAILS_ATTRIBUTE_DAMAGE)
    local output = ""

    for _, actor in ipairs(damageActors) do
        if actor.nome == playerName then
            local actorName = actor.nome
            local damageTaken = math.floor(actor.damage_taken or 0)
            output = output .. actorName .. " took " .. numberToWords(damageTaken) .. " damage.\n"
        end
    end

    print(output)
    Speech:speak(output)
end

local menuOptions = {
    {Function = GetAllPlayersInfo, Text = "Get All Players Info"},
    {Function = GetDamageForPlayer, Text = "Get Player Damage"},
    {Function = GetHealingForPlayer, Text = "Get Player Healing"},
    {Function = GetDamageTakenForPlayer, Text = "Get Player Damage Taken"},
    {Function = GetInterruptsForPlayer, Text = "Get Player Interrupts"},
    {Function = GetDispellsForPlayer, Text = "Get Player Dispells"}
}

function DetailsTTSDown()
    if not menuOpen then return end

    if selectingPlayer then
        selectedPlayerIndex = selectedPlayerIndex % #playerNames + 1
        Speech:speak(playerNames[selectedPlayerIndex])
    else
        currentOption = currentOption % #menuOptions + 1
        Speech:speak(menuOptions[currentOption].Text)
    end
end

local function CloseMenu()
    menuOpen = false
    selectingPlayer = false
    Speech:speak("Details TTS Menu Closed")
end

function DetailsTTSMenu()
    if menuOpen then
        CloseMenu()
    else
        menuOpen = true
        Speech:speak("Details TTS Menu Opened")
    end
end

function DetailsTTSUp()
    if not menuOpen then return end

    if selectingPlayer then
        selectedPlayerIndex = (selectedPlayerIndex - 2) % #playerNames + 1
        Speech:speak(playerNames[selectedPlayerIndex])
    else
        currentOption = (currentOption - 2) % #menuOptions + 1
        Speech:speak(menuOptions[currentOption].Text)
    end
end

function DetailsTTSEnter()
    if not menuOpen then return end

    if selectingPlayer then
        local playerName = playerNames[selectedPlayerIndex]
        local selectedOption = menuOptions[currentOption]

        if selectedOption then
            selectedOption.Function(playerName)
            CloseMenu()
        end
    else
        if currentOption == 1 then
            menuOptions[1].Function()
            CloseMenu()
        else
            selectingPlayer = true
            UpdatePlayerList()
            Speech:speak("Select a player.")
        end
    end
end

SLASH_DETAILSTTSINFO1 = '/detailsttsinfo'
SlashCmdList["DETAILSTTSINFO"] = function(msg)
    GetAllPlayersInfo()
end

SLASH_DETAILSTTSDAMAGE1 = '/detailsttsdamage'
SlashCmdList["DETAILSTTSDAMAGE"] = function(msg)
    GetDamageForPlayer(msg)
end

SLASH_DETAILSTTSHEALING1 = '/detailsttshealing'
SlashCmdList["DETAILSTTSHEALING"] = function(msg)
    GetHealingForPlayer(msg)
end

SLASH_DETAILSTTSDAMAGETAKEN1 = '/detailsttsdamagetaken'
SlashCmdList["DETAILSTTSDAMAGETAKEN"] = function(msg)
    GetDamageTakenForPlayer(msg)
end

function table.contains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end
