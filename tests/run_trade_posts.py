"""Actual shop and wallet services: transactions, account income, taxes and ownership."""
from pathlib import Path
import re, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
trade=(root/'src/server/Services/TradePostService.luau').read_text()
trade=re.sub(r'local (Items|Rules|MoneyRules|Interaction|Config|Inventory|Wallet|Towns)=require[^\n]+\n','',trade)
wallet=(root/'src/server/Services/EconomyService.luau').read_text()
wallet=re.sub(r'local R=require[^\n]+\n','local R=MoneyRules\n',wallet)
setup='''
workspace.DescendantAdded=event()
local Config={ReconnectGraceSeconds=300}
local Interaction={NearestPoint=function(object) return object.Position or Vector3.zero end}
local inventory={}
local Inventory={Changed=event()}
local function own(player) inventory[player.UserId]=inventory[player.UserId] or Rules.New();return inventory[player.UserId] end
function Inventory.Snapshot(player) local s=own(player);return {Items=table.clone(s.Items),Stacks=Rules.Stacks(s,Items.Items)} end
function Inventory.Transfer(player,storage,id,amount,into,key)
 local source,target=own(player),storage;if not into then source,target=storage,own(player) end
 local ok=Rules.Transfer(source,target,Items.Items,id,amount,key)
 if ok then Inventory.Changed:Fire(player) end
 return ok
end
local town={ID=1,LeaderID=c.UserId,Tax=2,MaxTax=2}
local observe
local Towns={TradeTown=function(id) return id==1 and town or nil end,OnMarketEvent=function(fn) observe=fn end}
for _,p in ipairs({a,b,c,d}) do p:LoadCharacterAsync();p:SetAttribute("CharacterLevel",5) end
a:SetAttribute("TownID",1);c:SetAttribute("TownID",1);c:SetAttribute("CharacterLevel",30);d:SetAttribute("CharacterLevel",0)
local blocked=false
local wall=make("Part","Wall",workspace)
function workspace:Raycast() return blocked and {Instance=wall} or nil end
local function post(name)
 local model=make("Model",name,workspace,{TradePost=true,TownID=1})
 for _,name in ipairs({"Active","Inactive"}) do
  local group=make("Model",name,model)
  local part=make("Part","Part",group);part.Transparency=0;part.CanCollide=true;part.CanQuery=true;part.CanTouch=true;part:SetAttribute("BlocksVision",true)
 end
 return model
end
local first,second=post("TradePost"),post("Workshop selling table")
assert(Rules.Add(own(a),Items.Items,"Plank",10))
assert(Rules.Add(own(a),Items.Items,"AssaultRifle223",1,{17},{{Loaded=7,Type="AP",UID="shop-rifle"}}))
'''
cases='''
Service.Start()
assert(first.Active.Part.Transparency==0 and first.Inactive.Part.Transparency==0,"unclaimed appearance unchanged")
assert(Wallet.Credit(b,100))
local balance=Wallet.Balance(b)
b:SetAttribute("Money",999999);assert(Wallet.Balance(b)==balance,"replicated display attribute is not the account authority")
clock+=119;Wallet.Step();assert(Wallet.Balance(b)==balance)
clock+=1;Wallet.Step();assert(Wallet.Balance(b)==balance+5,"level5 gives5 dollars every120seconds")
assert(Wallet.Balance(c)==30 and Wallet.Balance(d)==0,"income follows exact level, including30 and0")
Wallet.Step();assert(Wallet.Balance(b)==balance+5,"same income tick cannot be collected twice")
assert(not Wallet.Credit(b,0/0) and not Wallet.Credit(b,1.5))
assert(Service.Open(b,first) and not Service.Command(b,"Claim"),"outsider may browse but cannot claim")
blocked=true;assert(not Service.Open(a,first),"wall blocks post access");blocked=false
assert(Service.Open(a,first) and Service.Command(a,"Claim"))
assert(first.Active.Part.Transparency==0 and first.Inactive.Part.Transparency==0,"claimed appearance unchanged")
assert(not Service.Command(b,"Put","Plank",1) and not Service.Command(b,"Price","Plank",1),"outsider cannot change seller stock/prices")
assert(Service.Command(a,"Put","Plank",10))
assert(not Service.Command(a,"Price","Plank",0/0) and not Service.Command(a,"Price","Plank",.5))
assert(not Service.Command(a,"Release"),"stock cannot be abandoned or lost by releasing post")
assert(Service.Command(a,"Price","Plank",3))
local buyer,seller=Wallet.Balance(b),Wallet.Balance(a)
assert(Service.Command(b,"Buy","Plank",2))
assert(own(b).Items.Plank==2 and Wallet.Balance(b)==buyer-6 and Wallet.Balance(a)==seller+6,"sale transfers two items and exact payment")
assert(not Service.Command(a,"Buy","Plank",1),"seller cannot buy from themselves")
assert(not Service.Command(b,"Buy","Plank",100) and Wallet.Balance(b)==buyer-6,"oversized purchase charges nothing")
assert(Service.Command(a,"Price","Plank",1000000000))
assert(not Service.Command(b,"Buy","Plank",1) and own(b).Items.Plank==2,"unaffordable sale transfers no items")
local gun
for _,stack in ipairs(Inventory.Snapshot(a).Stacks) do if stack.ID=="AssaultRifle223" then gun=stack end end
assert(Service.Command(a,"Put",gun.Key,1) and Service.Command(a,"Price",gun.Key,10))
assert(Service.Command(b,"Buy",gun.Key,1) and not Service.Command(b,"Buy",gun.Key,1),"last weapon cannot be sold twice")
local purchased
for _,stack in ipairs(Inventory.Snapshot(b).Stacks) do if stack.ID=="AssaultRifle223" then purchased=stack end end
assert(purchased.Condition==17 and purchased.Loaded==7 and purchased.AmmoType=="AP","condition and magazine data survive sale")
assert(Service.Open(a,second) and Service.Command(a,"Claim"))
buyer=Wallet.Balance(a);seller=Wallet.Balance(c)
clock+=300;Service.Step()
assert(Wallet.Balance(a)==buyer-2 and Wallet.Balance(c)==seller+2,"two shops owned by one seller pay exactly one tax")
Players.PlayerRemoving:Fire(a);a.Parent=nil
clock+=299;Service.Step();assert(first:GetAttribute("TradeOwnerID")==a.UserId,"short disconnect retains shop")
local returned=player(a.UserId);returned:LoadCharacterAsync();returned:SetAttribute("TownID",1);Players.PlayerAdded:Fire(returned)
assert(first:GetAttribute("TradeOwnerID")==returned.UserId,"rejoin before deadline retains ownership")
Players.PlayerRemoving:Fire(returned);returned.Parent=nil;clock+=301;Service.Step()
assert(first:GetAttribute("TradeOwnerID")==c.UserId and second:GetAttribute("TradeOwnerID")==c.UserId,"disconnect timeout transfers all shops to mayor")
assert(Service.Open(c,first))
local inherited=Service.Snapshot(c)
assert(inherited.Inherited and #inherited.Stock==1 and inherited.Stock[1].Count==8 and inherited.Stock[1].Price==1000000000,"inheritance preserves stock and unit price")
town.LeaderID=0;observe("Leader",1,0)
assert(Service.Open(b,first) and not Service.Command(b,"Claim"),"vacant mayor position reserves inherited goods")
d:SetAttribute("TownID",1);town.LeaderID=d.UserId;observe("Leader",1,d.UserId)
assert(first:GetAttribute("TradeOwnerID")==d.UserId,"new mayor receives reserved shops")
local third=post("Kitchen post");Service.Register(third)
assert(Service.Open(c,third) and Service.Command(c,"Claim"))
observe("Leave",1,c.UserId)
assert(third:GetAttribute("TradeOwnerID")==d.UserId,"explicit departure/expulsion transfers shop immediately")
assert(Service.Open(d,first) and Service.Command(d,"Take","Plank",2) and own(d).Items.Plank==2,"inherited owner can withdraw exact quantities")
local fourth=post("Farm post");Service.Register(fourth)
b:SetAttribute("TownID",1);assert(Service.Open(b,fourth) and Service.Command(b,"Claim"))
local remaining=Wallet.Balance(b);assert(Wallet.Transfer(b,d,remaining));assert(Wallet.Credit(b,1))
local mayorMoney=Wallet.Balance(d);clock+=300;Service.Step()
assert(Wallet.Balance(b)==0 and Wallet.Balance(d)==mayorMoney+1,"insolvent seller pays available dollar without debt")
assert(Service.Command(b,"Release") and fourth:GetAttribute("TradeOwnerID")==0 and fourth.Inactive.Part.Transparency==0,"empty post can be released and keeps authored appearance")
print("PASS: actual wallet income, foreign buyers/member claims, quantity/price/funds guards, atomic sales, weapon metadata, one tax per seller, grace/rejoin/timeout, mayor inheritance and leadership changes")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for name,path in [('Items','ItemConfig'),('Rules','InventoryRules'),('MoneyRules','EconomyRules')]:
    parts.append(f'local {name}=(function()\n'+(root/f'src/shared/{path}.luau').read_text()+'\nend)()')
parts += [setup,'local Wallet=(function()\n'+wallet+'\nend)()','local Service=(function()\n'+trade+'\nend)()',cases]
with tempfile.TemporaryDirectory() as directory:
    path=Path(directory)/'trade.luau';path.write_text('\n'.join(parts))
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
