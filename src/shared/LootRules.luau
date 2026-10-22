local Rules = {}
function Rules.Roll(config,definitions,random)
 local items = {}
 random = random or math.random
 for id,range in pairs(config) do
  if typeof(range) == "table" then
   local minimum,maximum = range.Min,range.Max
   if typeof(minimum) == "number" and typeof(maximum) == "number" and minimum == minimum and maximum == maximum and minimum >= 0 and maximum < math.huge and minimum == math.floor(minimum) and maximum == math.floor(maximum) and maximum >= minimum then
    local chance=range.Chance
    local succeeds=chance==nil or (typeof(chance)=="number" and chance>=0 and chance<=1 and random(1,10000)<=chance*10000)
    if succeeds then
     local itemID=id
     if typeof(range.Choices)=="table" and #range.Choices>0 then itemID=range.Choices[random(1,#range.Choices)] end
     local definition=definitions[itemID]
     if definition and definition.Lootable~=false then
      local count=random(minimum,maximum)
      if count>0 then items[itemID]=(items[itemID] or 0)+count end
     end
    end
   end
  end
 end
 return items
end
return Rules
