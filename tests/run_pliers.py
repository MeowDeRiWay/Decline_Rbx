"""Actual pliers click routing, default template and atomic inventory bundle."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path):return '(function()\n'+(root/path).read_text()+'\nend)()'
s=(root/'tests/fixtures/town_mock.luau').read_text()+'\n'+(root/'tests/rig_math.fixture.luau').read_text()
s+='\nlocal Items='+module('src/shared/ItemConfig.luau')+'\nlocal Interaction='+module('src/shared/Interaction.luau')
s+='''
local Input={InputBegan=event(),GetFocusedTextBox=function() end}
local GuiService={MenuIsOpen=false}
local oldGet=game.GetService
function game:GetService(name) return ({UserInputService=Input,GuiService=GuiService})[name] or oldGet(self,name) end
Players.LocalPlayer=a;a:LoadCharacterAsync()
a.Character.HumanoidRootPart.Position=Vector3.new(0,1,0);a.Character:SetAttribute("HandsItem","Pliers")
Enum.UserInputType={MouseButton1=1};Enum.Material={Metal=1};Color3={fromRGB=function() return {} end}
local remote=make("RemoteEvent","ResourceAction",ReplicatedStorage)
local commands={};function remote:FireServer(...) table.insert(commands,{...}) end
local pile=make("Model","PileScrap",workspace,{ResourceType="ScrapPile"});pile.CFrame=CFrame.new(0,0,-1);pile.Size=Vector3.new(1,1,1)
local part=make("Part","Piece",pile)
local Cursor={Get=function() return {Hit={Instance=part}} end}
'''
source=(root/'src/client/Pliers.client.luau').read_text().replace('local Cursor=require(script.Parent.CursorQuery)','').replace('local Interaction=require(Storage.Shared.Interaction)','').replace('local Items=require(Storage.Shared.ItemConfig)','')
s+='\n'+source
s+='''
local click={UserInputType=1,KeyCode={Name="Unknown"}}
Input.InputBegan:Fire(click,false);assert(commands[1][1]=="Dismantle" and commands[1][2]==pile)
a:SetAttribute("InventoryOpen",true);Input.InputBegan:Fire(click,false);assert(#commands==1)
a:SetAttribute("InventoryOpen",nil);a.Character.HumanoidRootPart.Position=Vector3.new(10,1,0)
Input.InputBegan:Fire(click,false);assert(#commands==1,"range enforced before request")
a.Character:SetAttribute("DismantlingScrap",true)
Input.InputBegan:Fire({KeyCode={Name="W"}},false);assert(commands[2][1]=="Cancel","movement cancels work")
a.Character:SetAttribute("DismantlingScrap",nil);a.Character:SetAttribute("HandsItem","ScrapShovel")
a.Character.HumanoidRootPart.Position=Vector3.new(0,1,0)
Input.InputBegan:Fire(click,false);assert(#commands==2,"other tools keep their original input")
'''
s+='\nlocal Recipes='+module('src/shared/CraftConfig.luau')+'\nassert(Recipes.MakePliers.Ingredients.Scrap==2 and Recipes.MakePliers.Requirements.Skills.Repair==50 and Recipes.MakePliers.Station=="Workstation")'
s+='\nlocal Rules='+module('src/shared/InventoryRules.luau')+'\nlocal ItemConfig=Items\nlocal states={[a]=Rules.New()}\nlocal updates=0\nlocal function update() updates+=1 end\nlocal Service={}\n'
inv=(root/'src/server/Services/InventoryService.luau').read_text();s+=inv[inv.index('function Service.AddBundle'):inv.index('function Service.Remove(player,')]
s+='''
assert(not Service.AddBundle(a,{Scrap=2,Fake=1}) and next(states[a].Items)==nil,"invalid bundle cannot partially grant")
assert(not Service.AddBundle(a,{Scrap=0}) and updates==0)
assert(Service.AddBundle(a,{Scrap=2,Rags=3}) and states[a].Items.Scrap==2 and states[a].Items.Rags==3 and updates==1)
'''
s+='\nlocal Visuals={Template=function() return nil end}\n'+(root/'src/server/Pliers.server.luau').read_text().replace('local Visuals=require(script.Parent.Services.EquipmentVisuals)','')
s+='''
local pliers=ServerStorage.Items.Pliers
assert(pliers:IsA("Model") and pliers.PrimaryPart and #pliers:GetChildren()==4)
print("PASS: mouse routing, range/menu guards, movement cancellation, atomic loot bundle and fallback pliers template")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'pliers.luau';p.write_text(s)
 subprocess.run([sys.argv[1],str(p)],check=True)
