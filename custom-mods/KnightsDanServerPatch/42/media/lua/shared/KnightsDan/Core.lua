KnightsDan = KnightsDan or {}
local K = KnightsDan
K.version = "0.1.0"
function K.authoritative() return not isClient() end
function K.players(callback)
    if getOnlinePlayers then
        local list = getOnlinePlayers()
        if list then for i=0,list:size()-1 do callback(list:get(i)) end end
    elseif getPlayer and getPlayer() then callback(getPlayer()) end
end
function K.key(player) return PZLinuxGetCharacterKey(player, true) end
function K.store()
    local data = ModData.getOrCreate("KnightsDanCoopV1")
    data.parties = data.parties or {}
    data.invites = data.invites or {}
    data.payouts = data.payouts or {}
    return data
end
function K.member(record, player)
    return record and record.knightsMembers and record.knightsMembers[K.key(player)] ~= nil
end
function K.online(key)
    local found
    K.players(function(p) if K.key(p)==key then found=p end end)
    return found
end
function K.active(player)
    local id = player:getModData().PZLinuxContractId
    return id and PZLinuxContractsGetWorldContract(id) or nil
end
