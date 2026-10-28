"""Execute real disconnect/rejoin authority with deterministic lifecycle/engine mocks."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/PlayerSessionService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
source=re.sub(r'local (Config|Inventory|Progression|Life|Towns|Beds)=require[^\n]+\n','',source)
setup='''
local Beds={Leave=function() end}
function methods:GetAttributes() return table.clone(self.attrs) end
local baseClone=methods.Clone
function methods:Clone()
 local clone=baseClone(self)
 clone.CFrame=self.CFrame;clone.Position=self.Position;clone.Anchored=self.Anchored
 clone.CanCollide=self.CanCollide;clone.CanQuery=self.CanQuery
 clone.Health=self.Health;clone.MaxHealth=self.MaxHealth
 if self:IsA("Humanoid") then clone.HealthChanged=event() end
 return clone
end
local timers={}
function task.delay(seconds,fn) table.insert(timers,{At=clock+seconds,Run=fn}) end
local function advance(seconds)
 clock+=seconds
 for _,timer in ipairs(table.clone(timers)) do
  if not timer.Done and timer.At<=clock then timer.Done=true;timer.Run() end
 end
end
local Config={ReconnectGraceSeconds=300}
local stock,saved={},{}
local consumed=0
local Inventory={}
function Inventory.Start()
 Players.PlayerRemoving:Connect(function(p) saved[p.UserId]=stock[p];stock[p]=nil end)
 Players.PlayerAdded:Connect(function(p) stock[p]=saved[p.UserId] or {Items={}};saved[p.UserId]=nil end)
end
function Inventory.Export(p) return stock[p] or saved[p.UserId] end
function Inventory.ForgetOffline(uid,state) if saved[uid]==state then saved[uid]=nil end end
function Inventory.CorpseStorage(state) consumed+=1;return state end
local Progression={Start=function() end,Sync=function(p) p.Synced=true end}
local ko,adopted={},nil
local corpses={}
local Life={KnockoutRecord=function(c) return ko[c] end,ResumeKnockout=function(_,c,r) adopted={Character=c,Record=r} end,
 OfflineCorpse=function(c,state,uid)
  c:SetAttribute("IsCorpse",true);c:SetAttribute("IsDead",true);c:SetAttribute("OfflineUserId",nil)
  corpses[c]=state;c:SetAttribute("OwnerUserId",uid)
 end}
local loads=0
local Towns={Publish=function() end,LoadCharacter=function(p) loads+=1;p.Character=make("Model","FreshSpawn",workspace) end}
local function prepare(p)
 p:LoadCharacterAsync();p.Character.Humanoid.HealthChanged=event()
 p.Character.Humanoid.Health=42;p.Character:SetAttribute("Food",37)
 p.Character.HumanoidRootPart.Anchored=false;p.Character.HumanoidRootPart.CanCollide=true
 p:SetAttribute("TownID",1);p:SetAttribute("TeamID",10);p:SetAttribute("HasSpawned",true)
 p.Team=make("Team","Town",Teams)
 stock[p]={Items={TreeLog=2},Magazine={Loaded=7,Type="AP"}}
 return p.Character
end
'''
cases='''
Service.Start()
local original=prepare(a);local originalPosition=original:GetPivot().Position
a:SetAttribute("Money",45);a:SetAttribute("TradeOpen",true)
Players.PlayerRemoving:Fire(a);a.Parent=nil;original:Destroy()
local bodies=Service.OfflineCharacters();assert(#bodies==1)
local waiting=bodies[1]
assert(waiting.Parent.Name=="DisconnectedPlayers" and waiting.Humanoid.Health==42 and waiting:GetAttribute("Food")==37 and waiting.HumanoidRootPart.Anchored)
local again=player(a.UserId);again:SetAttribute("Money",100);Players.PlayerAdded:Fire(again)
assert(again:GetAttribute("Money")==100 and not again:GetAttribute("TradeOpen"),"session cannot overwrite wallet authority or reopen stale trade UI")
assert(again.Character==waiting and not waiting.HumanoidRootPart.Anchored and again.Synced)
assert(again:GetAttribute("TownID")==1 and again:GetAttribute("HasSpawned") and waiting:GetAttribute("ReturningSession"))
assert(stock[again].Items.TreeLog==2 and stock[again].Magazine.Loaded==7 and stock[again].Magazine.Type=="AP")
advance(301);assert(consumed==0 and #Service.OfflineCharacters()==0,"old timeout cannot kill returned player")
local second=prepare(b)
Players.PlayerRemoving:Fire(b);b.Parent=nil;second:Destroy()
local abandoned=Service.OfflineCharacters()[1]
advance(300)
assert(consumed==1 and corpses[abandoned].Items.TreeLog==2 and abandoned:GetAttribute("OwnerUserId")==b.UserId)
assert(not saved[b.UserId] and #Service.OfflineCharacters()==0,"expired body loot is no longer cached as player inventory")
local late=player(b.UserId);Players.PlayerAdded:Fire(late)
assert(loads==1 and next(stock[late].Items)==nil and corpses[abandoned].Magazine.Loaded==7,"late return spawns fresh without reclaiming loot")
local third=prepare(c)
Players.PlayerRemoving:Fire(c);c.Parent=nil;third:Destroy()
local killed=Service.OfflineCharacters()[1];killed.Humanoid.Health=0;killed.Humanoid.HealthChanged:Fire(0)
assert(consumed==2 and corpses[killed],"offline damage can turn waiting body into corpse")
advance(300);assert(consumed==2,"death plus timeout cannot duplicate loot")
local fourth=prepare(d)
fourth:SetAttribute("Knockout",true);fourth:SetAttribute("KnockoutEndsAt",clock+120)
local part=fourth.HumanoidRootPart;part.Anchored=true
ko[fourth]={Pivot=fourth:GetPivot(),Parts={[part]={Anchored=false,CanCollide=true,CanQuery=true}},BlocksVision=true}
Players.PlayerRemoving:Fire(d);d.Parent=nil;fourth:Destroy()
local downed=Service.OfflineCharacters()[1]
local returned=player(d.UserId);Players.PlayerAdded:Fire(returned)
assert(returned.Character==downed and downed:GetAttribute("Knockout") and downed.HumanoidRootPart.Anchored)
assert(adopted.Character==downed and adopted.Record.Parts[downed.HumanoidRootPart].Anchored==false,"knockout original flags rebound to clone, not destroyed parts")
local dead=player(999);local deadChar=prepare(dead);deadChar:SetAttribute("IsDead",true);stock[dead]={Items={}}
local count=consumed;Players.PlayerRemoving:Fire(dead);dead.Parent=nil
advance(300);assert(consumed==count,"already dead player's existing corpse is not recreated")
local loner=player(1001);local lonerBody=prepare(loner)
loner:SetAttribute("TownID",nil);loner:SetAttribute("TeamID",nil)
lonerBody:SetAttribute("Knockout",true);lonerBody:SetAttribute("KnockoutEndsAt",clock+120)
ko[lonerBody]={Pivot=lonerBody:GetPivot(),Parts={},BlocksVision=true}
Players.PlayerRemoving:Fire(loner);loner.Parent=nil;lonerBody:Destroy()
local beforeLoads=loads;advance(120)
local lonerBack=player(1001);Players.PlayerAdded:Fire(lonerBack)
assert(lonerBack:GetAttribute("OutcastEnd")==true and lonerBack.Character==nil and loads==beforeLoads,"offline neutral death restores ending instead of spawning")
Players.PlayerRemoving:Fire(lonerBack);lonerBack.Parent=nil
local endingAgain=player(1001);Players.PlayerAdded:Fire(endingAgain)
assert(endingAgain:GetAttribute("OutcastEnd")==true,"logging out from the ending cannot bypass it")
print("PASS: offline unaffiliated death and repeated reconnect preserve ending")
print("PASS: actual reconnect clone/health/needs/position/inventory, timeout/death single loot transfer, late fresh spawn, old-timer cancellation and knockout adoption")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup,'local Service=(function()\n'+source+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
