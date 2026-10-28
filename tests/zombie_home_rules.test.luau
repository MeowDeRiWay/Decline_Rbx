local Rules = require("../src/shared/ZombieHomeRules")
local function model(parent, attrs)
 local object = {Parent=parent,attrs=attrs or {}}
 function object:IsA(class) return class=="Model" end
 function object:GetAttribute(key) return self.attrs[key] end
 return object
end
local house=model(nil,{ZHouse=true,ZNumber=3})
local floor=model(house,{Zombie_home=true})
local upstairs=model(house,{Zombie_home=true})
local other=model(nil,{ZHouse=true,ZNumber=5})
assert(Rules.House(floor)==house and Rules.House(upstairs)==house)
assert(Rules.Limit(floor)==3 and Rules.Limit(model(nil))==3)
house.attrs.ZNumber=0; assert(Rules.Limit(floor)==0)
house.attrs.ZNumber=2.9; assert(Rules.Limit(floor)==2)
for _,value in ipairs({-5,0/0,math.huge,"three"}) do
 house.attrs.ZNumber=value
 assert(Rules.Limit(floor)==(value==-5 and 0 or 3))
end
house.attrs.ZNumber=nil; floor.attrs.ZNumber=2; assert(Rules.Limit(floor)==2)
house.attrs.ZNumber=3
local function zombie(source, health, dead)
 local z=model(nil,{IsDead=dead})
 function z:FindFirstChild() return {Value=source,IsA=function(_,class) return class=="ObjectValue" end} end
 function z:FindFirstChildOfClass() return {Health=health} end
 function z:IsDescendantOf() return true end
 return z
end
local objects={zombie(floor,20),zombie(upstairs,20),zombie(floor,0),zombie(floor,20,true),zombie(other,20)}
local creatures={GetChildren=function() return objects end}
assert(Rules.Count(floor,creatures,{})==2 and Rules.Count(upstairs,creatures,{})==2)
table.insert(objects,zombie(floor,20))
assert(Rules.Count(floor,creatures,{})==Rules.Limit(floor))
table.remove(objects,1)
assert(Rules.Count(floor,creatures,{})<Rules.Limit(floor))
local sleeper=zombie(floor,20)
function sleeper:IsDescendantOf() return false end
assert(Rules.Count(floor,creatures,{}, {sleeper})==3,"sleeping NPC still consumes source house quota")
assert(#objects==5,"count cannot mutate caller collections")
print("PASS: house-wide ZNumber, multiple floors, defaults, zero disables, invalid values, living-only source counts and restored capacity")
