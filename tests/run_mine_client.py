"""Private mine rendering, prompts, streaming independence and hidden-state cleanup."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'tests/fixtures/town_mock.luau').read_text()+'\n'+(root/'tests/rig_math.fixture.luau').read_text()
s+='\nlocal Visibility=(function()\n'+(root/'src/shared/VisibilityRules.luau').read_text()+'\nend)()\nlocal Config={CreatureViewAngle=160}'
s+=r'''
local RunService={Heartbeat=event()}
local Input={InputBegan=event(),GetFocusedTextBox=function() end}
local GuiService={MenuIsOpen=false}
local Debris={AddItem=function() end}
local TweenService={Create=function() return {Play=function() end} end}
local originalGet=game.GetService
function game:GetService(name) return ({RunService=RunService,UserInputService=Input,GuiService=GuiService,Debris=Debris,TweenService=TweenService})[name] or originalGet(self,name) end
Players.LocalPlayer=a;a.LocaleId="uk-UA";a.CharacterRemoving=event();a:LoadCharacterAsync()
a.Character.HumanoidRootPart.Position=Vector3.new(0,1,0);a.Character:SetAttribute("HandsItem","Mine")
local remote=make("RemoteEvent","MineAction",ReplicatedStorage);remote.OnClientEvent=event()
local commands={};function remote:FireServer(...) table.insert(commands,{...}) end
local source=make("Part","MineVisual",ReplicatedStorage)
Enum.UserInputType={MouseButton1=1};Enum.HighlightDepthMode={Occluded=1};Enum.KeyCode={E=1};Enum.PartType={Ball=1};Enum.Material={Neon=1}
Color3={fromRGB=function() return {} end};TweenInfo={new=function() return {} end};Vector3.one=Vector3.new(1,1,1)
a:SetAttribute("Attention",10);a:SetAttribute("SkillTraps",300)
local sample
local Cursor={Get=function() return sample end}
local ItemConfig={PickupDistance=2}
local blasts=0
local RocketAudio={Explode=function() blasts+=1 end}
local oldNew=Instance.new
Instance.new=function(kind)
 local v=oldNew(kind)
 v.Size=Vector3.new(2,1,2)
 if kind=="ProximityPrompt" then v.Triggered=event() end
 return v
end
'''
s+='\nlocal Interaction=(function()\n'+(root/'src/shared/Interaction.luau').read_text()+'\nend)()'
target=(root/'src/client/MineTarget.luau').read_text().replace('local Cursor=require(script.Parent.CursorQuery)','').replace('local ItemConfig=require(game:GetService("ReplicatedStorage").Shared.ItemConfig)','').replace('local Interaction=require(game:GetService("ReplicatedStorage").Shared.Interaction)','')
s+='\nlocal MineTarget=(function()\n'+target+'\nend)()'
s+='\nlocal MineRules=(function()\n'+(root/'src/shared/MineRules.luau').read_text()+'\nend)()'
source=(root/'src/client/Mines.client.luau').read_text().replace('local RocketAudio=require(script.Parent.RocketAudio)','').replace('local MineTarget=require(script.Parent.MineTarget)','').replace('local MineRules=require(ReplicatedStorage.Shared.MineRules)','')
source=source.replace('local Visibility=require(ReplicatedStorage.Shared.VisibilityRules)','').replace('local Config=require(ReplicatedStorage.Shared.GameConfig)','')
s+='\n'+source
s+=r'''
Input.InputBegan:Fire({UserInputType=1},false);assert(commands[1][1]=="Place")
a:SetAttribute("InventoryOpen",true);Input.InputBegan:Fire({UserInputType=1},false);assert(#commands==1)
a:SetAttribute("InventoryOpen",nil)
local function art() return workspace:FindFirstChild("DetectedMine") end
assert(not art(),"undiscovered mine has no visible clone")
remote.OnClientEvent:Fire("Reveal",1,CFrame.new(0,0,-1),nil,.9)
local model=art();assert(model)
remote.OnClientEvent:Fire("Reveal",1,CFrame.new(0,0,-1),nil,.9)
local count=0;for _,v in ipairs(workspace:GetChildren()) do if v.Name=="DetectedMine" then count+=1 end end
assert(count==1,"repeated snapshots cannot duplicate mine visuals")
RunService.Heartbeat:Fire(.1)
local highlight=model:FindFirstChildOfClass("Highlight")
assert(not model:FindFirstChildOfClass("ProximityPrompt"),"no E disarm prompt")
assert(highlight.Enabled and model.CanQuery)
a.Character.HumanoidRootPart.CFrame=CFrame.Angles(0,math.pi,0);RunService.Heartbeat:Fire(.1)
assert(not highlight.Enabled and model.LocalTransparencyModifier==1 and not model.CanQuery,"mine behind the player is hidden, including its highlight and mouse target")
a.Character.HumanoidRootPart.CFrame=CFrame.identity;RunService.Heartbeat:Fire(.1)
assert(highlight.Enabled and model.CanQuery,"turning back restores a known mine")
sample={Hit={Instance=model}}
Input.InputBegan:Fire({UserInputType=1},false)
assert(commands[2][1]=="Disarm" and commands[2][2]==1,"click disarms instead of placing another mine")
a.Character:SetAttribute("HandsItem","")
a.Character.HumanoidRootPart.Position=Vector3.new(4,1,0);RunService.Heartbeat:Fire(.1)
Input.InputBegan:Fire({UserInputType=1},false);assert(#commands==2,"no disarm beyond two-stud interaction range")
a.Character.HumanoidRootPart.Position=Vector3.new(10,1,0);a:SetAttribute("SkillTraps",0)
RunService.Heartbeat:Fire(.1)
assert(not highlight.Enabled and model.LocalTransparencyModifier==1 and not model.CanQuery,"known/owned mine obeys reduced detection radius")
a.Character.HumanoidRootPart.Position=Vector3.new(0,1,0);RunService.Heartbeat:Fire(.1)
assert(highlight.Enabled and model.LocalTransparencyModifier==0,"known mine survives marker streaming out")
a.Character:SetAttribute("Knockout",true);RunService.Heartbeat:Fire(.1);assert(not highlight.Enabled and not model.CanQuery)
a.Character:SetAttribute("Knockout",false)
remote.OnClientEvent:Fire("Remove",1);assert(model.destroyed and not art())
remote.OnClientEvent:Fire("Explosion",Vector3.zero,20,nil);assert(blasts==1)
print("PASS: undiscovered mines hidden, one private clone, mouse-only disarm, normal interaction range and skill/KO hiding, streaming independence, remove and explosion routing")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'mine_client.luau';p.write_text(s)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
