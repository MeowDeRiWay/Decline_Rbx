"""Run server workflows against a small engine mock; no Studio playtest is implied.
Usage: python tests/run_town_service.py /path/to/luau
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
service = (root / 'src/server/Services/TownService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Ensure=function(position) table.insert(restoredSurfaces,position) end}')
service = service.replace('local Localization=require(game:GetService("ReplicatedStorage").Shared.LocalizationRules)', '')
service = service.replace('local TextService=game:GetService("TextService")', '')
service = service.replace('local Journal=require(script.Parent.JournalService)', '')
service = service.replace('local Doors = require(script.Parent.TownDoors)', '')
service = service.replace('local Progression = require(script.Parent.ProgressionService)', '')
service = service.replace('local BuildingStorage = require(script.Parent.BuildingStorage)', '')
service = service.replace('local Inventory = require(script.Parent.InventoryService)', '')
for variable, module in [('Config', 'TownConfig'), ('Rules', 'TownRules'), ('Interaction', 'Interaction')]:
    service = service.replace(f'local {variable} = require(ReplicatedStorage.Shared.{module})', '')
parts = [(root / 'tests/fixtures/town_mock.luau').read_text(), 'local blockedBuilding=nil; local Progression={CanBuild=function(_,id) return id~=blockedBuilding end}', 'local Doors={MaximumWallLevel=function() return 2 end} function Doors.Start(request) Doors.request=request end function Doors.Admit(player,door,town) Doors.admitted={player,door,town};return true end']
for variable, module in [('Config', 'TownConfig'), ('Rules', 'TownRules')]:
    parts.append(f'local {variable} = (function()\n' + (root / f'src/shared/{module}.luau').read_text() + '\nend)()')
parts.append('''
for id in pairs(logs) do logs[id]=30 end
local scrap={};for id in pairs(logs) do scrap[id]=100 end
function Inventory.Snapshot(p) return {Items={TreeLog=logs[p.UserId] or 0,Scrap=scrap[p.UserId] or 0,Rags=100}} end
function Inventory.ConsumeIngredients(p,recipe,count)
 local wood=(recipe.Ingredients.TreeLog or 0)*count;local metal=(recipe.Ingredients.Scrap or 0)*count
 if (logs[p.UserId] or 0)<wood or (scrap[p.UserId] or 0)<metal then return false end
 logs[p.UserId]=(logs[p.UserId] or 0)-wood;scrap[p.UserId]=(scrap[p.UserId] or 0)-metal;return true
end
''')
parts.append("local journal={} local Journal={Send=function(p,text) table.insert(journal,{Player=p,Text=text}) end} local TextService={FilterStringAsync=function(_,text) if text=='filter fail' then error('filter unavailable') end return {GetNonChatStringForBroadcastAsync=function() return 'Filtered reason' end} end}")
parts.append('local BuildingStorage = (function()\n' + (root / 'src/server/Services/BuildingStorage.luau').read_text() + '\nend)()')
parts.append('''
assert(next(Config.Buildings.Market.Costs[1])==nil,"market is free")
local marketTemplate=make("Model","Market (T1)",ServerStorage.Buildings)
local marketTemplateSpace=make("Model","Space",marketTemplate);make("Part","Floor",marketTemplateSpace)
local marketTemplateMenu=make("Model","BuildingMenu",marketTemplate);make("Part","Sign",marketTemplateMenu)
local marketPlot=make("Model","BuildingSpace",workspace,{TownID=1,TeamID=10,OwnerID=0})
local marketSpace=make("Model","Space",marketPlot);make("Part","Floor",marketSpace)
local marketMenu=make("Model","BuildingMenu",marketPlot);make("Part","Sign",marketMenu)
''')
parts.append('local restoredSurfaces={}')
parts.append('local Localization=(function()\n'+(root/'src/shared/LocalizationRules.luau').read_text()+'\nend)()')
parts.extend(['local Service = (function()\n' + service + '\nend)()', (root / 'tests/fixtures/town_scenarios.luau').read_text(), (root / 'tests/fixtures/building_storage_scenarios.luau').read_text(), (root / 'tests/fixtures/expulsion_scenarios.luau').read_text()])
parts.append('''
local existingRemotes=ReplicatedStorage.TownRemotes
Service.Start()
local remoteCount=0;for _,object in ipairs(ReplicatedStorage:GetChildren()) do if object.Name=="TownRemotes" then remoteCount+=1 end end
assert(ReplicatedStorage.TownRemotes==existingRemotes and remoteCount==1,"town startup is idempotent when trading also initializes it")
local town=Service.TradeTown(1)
local mayor=Players:GetPlayerByUserId(town.LeaderID)
if not mayor then
 mayor=player(9901);Players.PlayerAdded:Fire(mayor);call(mayor,"Join",1)
end
assert(mayor and Service.TradeTown(1).LeaderID==mayor.UserId,"test has an actual mayor")
do
 call(mayor,"Open",flagA)
 call(mayor,"MarketTax",2);assert(Service.TradeTown(1).Tax==2,"mayor may set tax to wall cap")
 call(mayor,"MarketTax",3);assert(Service.TradeTown(1).Tax==2,"tax above wall level rejected")
 call(mayor,"MarketTax",-1);assert(Service.TradeTown(1).Tax==2,"negative tax rejected")
end
local beforeWood,beforeScrap=logs[mayor.UserId] or 0,scrap[mayor.UserId] or 0
call(mayor,"Open",marketPlot);call(mayor,"Build","Market")
local marketApproval
for _,entry in ipairs(ReplicatedStorage.TownRemotes.Notice.sent) do if entry.player==mayor and entry.data.Kind=="Approval" then marketApproval=entry.data.ID end end
assert(marketApproval and not marketPlot:GetAttribute("BuildingID"),"free market still awaits normal mayor approval")
call(mayor,"Reply",marketApproval,true)
assert(marketPlot:GetAttribute("BuildingID")=="Market" and marketPlot:FindFirstChild("Market (T1)"),"actual free market construction succeeds")
assert(logs[mayor.UserId]==beforeWood and scrap[mayor.UserId]==beforeScrap,"market consumes no resources")
local newborn=player(909)
newborn:SetAttribute("OutcastEnd",true)
assert(Service.LoadCharacter(newborn)==false and newborn.Character==nil)
call(newborn,"Join",1);assert(newborn:GetAttribute("TownID")==nil,"ending blocks joining before acknowledgement")
newborn:SetAttribute("HasSpawned",true)
Service.ResetForCreation(newborn);newborn:SetAttribute("OutcastEnd",nil)
call(newborn,"Join",1)
assert(newborn.Character and newborn.Character.Humanoid.Health==newborn.Character.Humanoid.MaxHealth,"new life joins town with full initial health")
assert(#restoredSurfaces>0,"town placement restores target surfaces before spawning")
print("PASS: ending blocks spawn/join and fresh creation resets initial spawn health")
print("PASS: free market construction/approval, mayor tax limits and wall-tier cap")
local probe=player(9981);Players.PlayerAdded:Fire(probe);call(probe,"Join",1)
local root=probe.Character.HumanoidRootPart
root.Position=Vector3.new(60,999,0);tick(1)
assert(probe:GetAttribute("TownFlagDistance")==60 and probe:GetAttribute("TerritoryTownID")~=nil)
root.Position=Vector3.new(61,-999,0);tick(1)
assert(probe:GetAttribute("TownFlagDistance")==61 and probe:GetAttribute("TerritoryTownID")~=nil,"music distance is horizontal and does not shrink the city territory")
print("PASS: nearest flag distance is horizontal and independent of the existing 200-stud territory")
''')
with tempfile.TemporaryDirectory(prefix='decline-town-tests-') as directory:
    test = Path(directory) / 'town_service.luau'
    test.write_text('\n'.join(parts))
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(test)], check=True)
