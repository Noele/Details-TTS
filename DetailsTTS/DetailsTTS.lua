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
local menuOptions = {"Get All Players Info", "Get Player Damage", "Get Player Healing", "Get Player Damage Taken"}
local currentOption = 1
local selectingPlayer = false
local playerNames = {}
local selectedPlayerIndex = 1

local function GetPartyMemberNames()
    local partyNames = { UnitName("player") }
    
    for i = 1, 4 do
        local name = UnitName("party" .. i)
        if name then
            table.insert(partyNames, name)
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

    -- Format output
    local output = ""
    for playerName, data in pairs(playerData) do
        output = output .. string.format("%s dealt %d damage, healed %d health, took %d damage.\n",
            playerName, data.damageDone or 0, data.healingDone or 0, data.damageTaken or 0)
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
            
            output = output .. actorName .. " did " .. damageDone .. " damage.\n"

            if actor.spells and actor.spells._ActorTable then
                for spellId, spellData in pairs(actor.spells._ActorTable) do
                    local spellName = GetSpellNameById(spellId)
                    local totalDamage = spellData.total or 0
                    local hits = spellData.counter or 0
                    output = output .. string.format("Spell %s - Damage %d - Hits %d\n", spellName, totalDamage, hits)
                end
            end
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
            output = output .. actorName .. " healed for " .. healingDone .. " health.\n"

            if actor.spells and actor.spells._ActorTable then
                for spellId, spellData in pairs(actor.spells._ActorTable) do
                    local spellName = GetSpellNameById(spellId)
                    local totalHealing = spellData.total or 0
                    local hits = spellData.counter or 0
                    output = output .. string.format("Healing Spell %s - Healed %d - Hits %d\n", spellName, totalHealing, hits)
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
            output = output .. actorName .. " took " .. damageTaken .. " damage.\n"
        end
    end

    print(output)
    Speech:speak(output)
end

function DetailsTTSDown()
    if not menuOpen then return end

    if selectingPlayer then
        selectedPlayerIndex = selectedPlayerIndex % #playerNames + 1
        Speech:speak(playerNames[selectedPlayerIndex])
    else
        currentOption = currentOption % #menuOptions + 1
        Speech:speak(menuOptions[currentOption])
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
        Speech:speak(menuOptions[currentOption])
    end
end

function DetailsTTSEnter()
    if not menuOpen then return end

    if selectingPlayer then
        local playerName = playerNames[selectedPlayerIndex]
        if currentOption == 2 then
            GetDamageForPlayer(playerName)
        elseif currentOption == 3 then
            GetHealingForPlayer(playerName)
        elseif currentOption == 4 then
            GetDamageTakenForPlayer(playerName)
        end
        CloseMenu()
    else
        if currentOption == 1 then
            GetAllPlayersInfo()
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
