local Recipes=require('../src/shared/CraftConfig')
local Items=require('../src/shared/ItemConfig').Items
local Rules=require('../src/shared/ProgressionRules')
local Stations=require('../src/shared/CraftStations')
local function state(skills)
 local s=Rules.New();s.Confirmed=true
 for id in pairs(s.Stats) do s.Stats[id]=0 end
 for id,n in pairs(skills) do s.Skills[id]=n end
 return s
end
for id,r in pairs(Recipes) do
 local item=Items[r.Output]
 local req=r.Requirements and r.Requirements.Skills
 if item and item.Weapon and req and req.Repair then
  local skill=item.Firearm and item.Firearm.Skill or (r.Output=='Mine' and 'Traps' or 'Melee')
  assert(req[skill]==req.Repair,id)
  assert(not Rules.Meets(state({Repair=req.Repair}),r.Requirements),'repair alone must not unlock '..id)
  assert(not Rules.Meets(state({[skill]=req[skill]}),r.Requirements),'combat skill alone must not unlock '..id)
  assert(Rules.Meets(state({Repair=req.Repair,[skill]=req[skill]}),r.Requirements),id)
 end
end
local mine=Recipes.MakeMine
assert(mine.Ingredients.Scrap==2 and mine.Ingredients.Chemicals==1 and mine.Ingredients.Coal==1)
assert(mine.Requirements.Skills.Traps==100 and mine.Requirements.Skills.Repair==100)
assert(Stations.Matches(mine,'Workstation') and not Stations.Matches(mine,'ArmsBench'))
assert(Recipes.MakeAT4.Ingredients.Iron==3)
assert(Recipes.MakeAT4.Requirements.Skills.Repair==150 and Recipes.MakeAT4.Requirements.Skills.HeavyWeapons==150)
assert(not Rules.Meets(state({Repair=149}),Recipes.MakeAmmoAT4.Requirements))
assert(Rules.Meets(state({Repair=150}),Recipes.MakeAmmoAT4.Requirements),'rockets need no heavy weapons skill')
assert(Recipes.MakeAmmoAT4.Ingredients.Scrap==1 and Recipes.MakeAmmoAT4.Ingredients.Chemicals==1)
assert(Recipes.MakeAmmoAT4.Output=='AmmoAT4FMJ' and Recipes.MakeAmmoAT4.OutputCount==1,'rockets are individual rounds, not 30-round packs')
for _,id in ipairs({'MakeAT4','MakeAmmoAT4'}) do
 assert(Stations.Matches(Recipes[id],'ArmsBench') and not Stations.Matches(Recipes[id],'Workstation'))
end
print('PASS: independent repair/combat gates, mine costs and station, factory-only launcher and individual rocket')
