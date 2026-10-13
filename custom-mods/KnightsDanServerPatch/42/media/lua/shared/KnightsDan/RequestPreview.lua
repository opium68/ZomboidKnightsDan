require "KnightsDan/Core"
function KnightsDan.requestPreview(ids)
    local counts,order = {},{}
    for _,id in ipairs(ids or {}) do
        if not counts[id] then counts[id]=0;table.insert(order,id) end
        counts[id]=counts[id]+1
    end
    local lines={}
    for _,id in ipairs(order) do
        local script=getScriptManager():FindItem(id)
        local name=script and script:getDisplayName() or id
        name=tostring(name):gsub("[<>\r\n]"," ")
        table.insert(lines,name.." x"..counts[id])
    end
    return table.concat(lines,"\n")
end
