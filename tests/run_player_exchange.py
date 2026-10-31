"""Exercise actual exchange, inventory commit and persistent wallet together."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path): return (root/path).read_text()
parts=[module('tests/fixtures/town_mock.luau')]
for var,path in [('Items','ItemConfig'),('InventoryRules','InventoryRules'),('MoneyRules','EconomyRules')]:
 parts.append(f'local {var}=(function()\n'+module(f'src/shared/{path}.luau')+'\nend)()')
parts += ['local Rules=(function()\n'+module('src/shared/ExchangeRules.luau').replace('local Inventory=require(script.Parent.InventoryRules)','local Inventory=InventoryRules')+'\nend)()',module('tests/fixtures/money_store_engine.luau')]
parts += ['local WalletStore=(function()\n'+module('src/server/Services/MoneyStore.luau').replace('local R=require(game:GetService("ReplicatedStorage").Shared.EconomyRules)','local R=MoneyRules')+'\nend)()']
wallet=module('src/server/Services/EconomyService.luau')
wallet=re.sub(r'local R=require[^\n]+\n','local R=MoneyRules\n',wallet).replace('local Store=require(script.Parent.MoneyStore)','local Store=WalletStore')
parts += ['local Wallet=(function()\n'+wallet+'\nend)()']
# Embed the shipped InventoryService.Exchange body, with visual notifications
# mocked; all staging and mutations still run the production implementation.
inventory=module('src/server/Services/InventoryService.luau')
exchange=inventory[inventory.index('function Service.Exchange('):inventory.index('function Service.TakeEquippedLoot')]
exchange=exchange.replace('require(ReplicatedStorage.Shared.ExchangeRules)','Rules')
parts += ['''
local states={}
local Inventory={Changed=event()}
function Inventory.Export(player) return states[player] end
function Inventory.Snapshot(player) return {Stacks=InventoryRules.Stacks(states[player],Items.Items)} end
local function update(player) Inventory.Changed:Fire(player) end
local ItemConfig=Items
local Service=Inventory
''',exchange,'''local Journal={Send=function() end}
for _,p in ipairs({a,b,c,d}) do p:LoadCharacterAsync();states[p]=InventoryRules.New() end
Wallet.Start();assert(Wallet.Credit(a,1000) and Wallet.Credit(b,200))
assert(InventoryRules.Add(states[a],Items.Items,"Plank",10))
assert(InventoryRules.Add(states[b],Items.Items,"Scrap",8))
assert(InventoryRules.Add(states[a],Items.Items,"AssaultRifle223",1,{17},{{Loaded=7,Type="AP",UID="barter-rifle",Mode="Auto"}}))
''']
service=module('src/server/Services/PlayerExchangeService.luau')
service=re.sub(r'local (Rules|MoneyRules|Items|Inventory|Wallet|Journal)=require[^\n]+\n','',service)
parts += ['local Exchange=(function()\n local Items=ItemConfig.Items\n'+service+'\nend)()']
parts += ['''
Exchange.Start()
local state=ReplicatedStorage.PlayerExchangeRemotes.State
local function view(p)
 for i=#state.sent,1,-1 do if state.sent[i].player==p then return state.sent[i].data end end
end
local function cmd(p,action,key,count) return Exchange.Command(p,action,view(p).ID,key,count) end
local function open()
 clock+=4;assert(Exchange.Invite(a,b));assert(cmd(b,"Join"));return view(a).ID
end
local function confirmBoth()
 clock+=3
 local rev=view(a).Revision
 assert(cmd(a,"Confirm",rev));assert(cmd(b,"Confirm",rev))
end
assert(not Exchange.Invite(a,a) and not Exchange.Invite(a,workspace))
a.Character.HumanoidRootPart.Position=Vector3.new(0,0,0)
b.Character.HumanoidRootPart.Position=Vector3.new(6,0,0)
assert(not Exchange.Invite(a,b),"out of reach invitation rejected")
b.Character.HumanoidRootPart.Position=Vector3.zero
local wall=make("Part","Wall",workspace)
function workspace:Raycast() return {Instance=wall} end
assert(not Exchange.Invite(a,b),"no exchange through walls")
function workspace:Raycast() return nil end
local first=open()
assert(not Exchange.Invite(a,c) and not Exchange.Invite(c,b),"one session per player")
assert(not Exchange.Command(c,"Join",first),"outsiders cannot accept")
assert(cmd(a,"Offer","Plank",4) and cmd(b,"Offer","Scrap",3))
assert(cmd(a,"Cash",120) and cmd(b,"Cash",20))
assert(not cmd(a,"Cash",-1) and not cmd(a,"Cash",0/0) and not cmd(a,"Cash",1.5) and not cmd(a,"Cash",1001))
assert(not cmd(a,"Offer","Plank",11) and not cmd(a,"Offer","Plank",-1))
local rifle=InventoryRules.Stacks(states[a],Items.Items)[1]
for _,stack in ipairs(InventoryRules.Stacks(states[a],Items.Items)) do if stack.ID=="AssaultRifle223" then rifle=stack end end
assert(cmd(a,"Offer",rifle.Key,1))
assert(not cmd(a,"Confirm",view(a).Revision),"review delay enforced")
clock+=3;local oldRev=view(a).Revision;assert(cmd(a,"Confirm",oldRev))
assert(cmd(b,"Cash",30));assert(not view(a).Confirmed and not view(b).OtherConfirmed,"change clears both consents")
clock+=3;assert(not cmd(a,"Confirm",oldRev),"stale confirmation refused")
confirmBoth()
assert(not view(a).Open and not view(b).Open)
assert(Wallet.Balance(a)==910 and Wallet.Balance(b)==290)
assert(states[a].Items.Plank==6 and states[a].Items.Scrap==3 and states[b].Items.Plank==4 and states[b].Items.Scrap==5)
assert(not states[a].Items.AssaultRifle223 and states[b].Weapons.AssaultRifle223[1].UID=="barter-rifle" and states[b].Weapons.AssaultRifle223[1].Loaded==7 and states[b].Conditions.AssaultRifle223[1]==17,"exact weapon and magazine preserved")
assert(not Exchange.Command(a,"Confirm",first,oldRev) and Wallet.Balance(a)==910,"completed ID cannot replay")
-- Pure money gifts need no item on the other side.
open();assert(cmd(a,"Cash",100));confirmBoth();assert(Wallet.Balance(a)==810 and Wallet.Balance(b)==390)
-- Cancellation does not escrow/deduct assets.
open();assert(cmd(a,"Cash",100));assert(cmd(a,"Cancel"));assert(Wallet.Balance(a)==810)
-- Equipment cannot be offered by forging a stack key.
assert(InventoryRules.Add(states[a],Items.Items,"MiliArmor1",1))
assert(InventoryRules.Equip(states[a],Items.Items,Items.Slots,"MiliArmor1"))
open();assert(not cmd(a,"Offer","Equipped|Body|MiliArmor1",1));cmd(a,"Cancel")
-- Losing an offered stack invalidates consent. Unrelated equipment updates do not.
open();assert(cmd(a,"Offer","Plank",6));clock+=3;assert(cmd(a,"Confirm",view(a).Revision))
Inventory.Changed:Fire(a);assert(view(a).Confirmed,"unchanged pocket notification preserves consent")
assert(InventoryRules.Remove(states[a],"Plank",1));Inventory.Changed:Fire(a)
assert(not view(a).Confirmed and #view(a).Offer==0,"lost offered items removed and consent reset")
cmd(a,"Cancel")
-- Funds spent after confirming are rechecked, with no item movement on failure.
open();assert(cmd(a,"Cash",800));assert(cmd(b,"Offer","Scrap",1));clock+=3;assert(cmd(a,"Confirm",view(a).Revision))
assert(Wallet.Transfer(a,c,100));local before=states[b].Items.Scrap
assert(not cmd(b,"Confirm",view(b).Revision) and states[b].Items.Scrap==before and Wallet.Balance(a)==710,"insufficient money changes no items")
cmd(a,"Cancel")
open();assert(cmd(a,"Cash",1));b.Character:SetAttribute("Knockout",true);Exchange.Step();assert(not view(a).Open);b.Character:SetAttribute("Knockout",nil)
open();b.Character.HumanoidRootPart.Position=Vector3.new(6,0,0);Exchange.Step();assert(not view(a).Open);b.Character.HumanoidRootPart.Position=Vector3.zero
open();clock+=181;Exchange.Step();assert(not view(a).Open,"inactivity closes the session")
open();Players.PlayerRemoving:Fire(b);assert(not view(a).Open,"disconnect cancels before any trade")
-- Replaced inventory/character cannot inherit stale consent.
WalletStore.Open(b.UserId)
open();states[a]=InventoryRules.New();Exchange.Step();assert(not view(a).Open)
-- Stage all removals first: received goods cannot cover missing outgoing goods.
local x,y=InventoryRules.New(),InventoryRules.New();InventoryRules.Add(x,Items.Items,"Scrap",2)
assert(not Rules.Stage(x,y,Items.Items,{Scrap={ID="Scrap",Key="Scrap",Count=2}},{Scrap={ID="Scrap",Key="Scrap",Count=2}}) and x.Items.Scrap==2 and not y.Items.Scrap)
assert(not Wallet.Exchange(a,b,0/0,0) and not Wallet.Exchange(a,a,0,0))
WalletStore.Save(a.UserId);WalletStore.Save(b.UserId)
assert(MoneyDatabase["User_"..a.UserId].Balance==710 and MoneyDatabase["User_"..b.UserId].Balance==390,"barter uses persistent account balances")
print("PASS: invitations, reach/walls, money-only gifts, bilateral items/cash, exact weapon metadata")
print("PASS: revisions, review delay, stale/duplicate messages, funds changed, lost items, equipped armor protection")
print("PASS: cancellation, KO, distance, timeout, disconnect, replaced inventory and persistent balances")
''']
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'exchange.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
