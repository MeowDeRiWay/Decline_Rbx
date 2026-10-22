local Rules=require("../src/shared/LootRules")
local Config=require("../src/shared/ZombieLootConfig")
local Items=require("../src/shared/ItemConfig").Items
local expected={Water=.05,Ammo9mmFMJ=.05,Sausage=.01,Rags=.15,Stone=.10}
for id,chance in pairs(expected) do
 local entry=Config[id]
 assert(entry and entry.Chance==chance)
 local function roll(draw,maximum,choice)
  return Rules.Roll({[id]=entry},Items,function(a,b)
   if b==10000 then return draw end
   if id=="Water" and b==2 then return choice or 1 end
   return if maximum then b else a
  end)
 end
 local key=if id=="Water" then "CleanWater" else id
 assert(roll(chance*10000,false)[key]==entry.Min,"chance boundary succeeds and minimum amount")
 assert(roll(chance*10000,true)[key]==entry.Max,"maximum amount reachable")
 assert(next(roll(chance*10000+1,false))==nil,"above chance boundary misses")
 if id=="Water" then
  local water=roll(1,false,2)
  assert(water.DirtyWater==1 and not water.CleanWater,"one bottle, either water type")
 end
end
assert(Config.Potato==nil)
local legacy=Rules.Roll({Stone={Min=1,Max=3}},Items,function(_,b) return b end)
assert(legacy.Stone==3,"legacy guaranteed quantity roll preserved")
print("PASS: zombie drop chances, inclusive quantities, exclusive water choice and legacy loot")
