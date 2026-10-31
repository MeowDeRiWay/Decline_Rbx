"""Actual persistent wallet across fresh servers, load/write failures, leases and character resets."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'tests/fixtures/town_mock.luau').read_text()
s+='\nlocal MoneyRules=(function()\n'+(root/'src/shared/EconomyRules.luau').read_text()+'\nend)()'
s+='\n'+(root/'tests/fixtures/money_store_engine.luau').read_text()
store=(root/'src/server/Services/MoneyStore.luau').read_text().replace('local R=require(game:GetService("ReplicatedStorage").Shared.EconomyRules)','local R=MoneyRules')
s+='\nlocal function newStore()\n'+store+'\nend\n'
s+='''
local first=newStore()
local account=assert(first.Open(10001));assert(account.Balance==0)
assert(first.Set(account,235) and first.Save(10001,false))
assert(MoneyDatabase.User_10001.Balance==235 and MoneyDatabase.User_10001.Lease)
assert(first.Release(10001) and not MoneyDatabase.User_10001.Lease)
local second=newStore();local restored=assert(second.Open(10001))
assert(restored.Balance==235,"fresh server restores account money")
assert(second.Release(10001))
MoneyDatabase.User_10002={Version=1,Balance=777}
local writes=MoneyWrites;MoneyFailures=1
assert(not first.Open(10002) and not first.Peek(10002) and first.Status(10002)=="LoadFailed")
assert(not first.Save(10002,false) and MoneyWrites==writes and MoneyDatabase.User_10002.Balance==777,"failed load never writes a zero")
clock+=11;assert(first.Open(10002).Balance==777);assert(first.Release(10002))
MoneyDatabase.User_10003={Version=1,Balance="corrupt"};writes=MoneyWrites
assert(not first.Open(10003) and first.Status(10003)=="InvalidData" and MoneyWrites==writes)
local locked=assert(first.Open(10004));assert(first.Set(locked,50))
assert(not second.Open(10004) and second.Status(10004)=="Locked","active session rejects a competing server")
assert(first.Release(10004));clock+=11
local successor=assert(second.Open(10004));assert(successor.Balance==50)
assert(not first.Set(locked,999) and not first.Save(10004,false),"old released server cannot overwrite successor")
assert(second.Set(successor,80) and second.Save(10004,false) and MoneyDatabase.User_10004.Balance==80)
assert(second.Release(10004))
local changed=assert(first.Open(10005));assert(first.Set(changed,10))
MoneyHook=function() assert(first.Set(changed,20)) end
assert(first.Save(10005,false) and MoneyDatabase.User_10005.Balance==10 and changed.Dirty,"change during save remains dirty")
clock+=2;first.Step();assert(MoneyDatabase.User_10005.Balance==20 and not changed.Dirty)
local retry=assert(first.Open(10006));assert(first.Set(retry,40));MoneyFailures=1
assert(not first.Release(10006) and not first.Peek(10006),"failed final save freezes account instead of detaching unsaved cash")
assert(not first.Set(retry,99));clock+=11;first.Step()
assert(MoneyDatabase.User_10006.Balance==40 and not MoneyDatabase.User_10006.Lease,"background retry saves and unlocks disconnected account")
assert(second.Open(10006).Balance==40 and second.Release(10006))
first.Start();MoneyCloseHandlers[#MoneyCloseHandlers]()
assert(MoneyDatabase.User_10005.Balance==20 and not MoneyDatabase.User_10005.Lease,"server shutdown flushes and releases active accounts")
local third=newStore();assert(third.Open(10005).Balance==20 and third.Release(10005))
print("PASS: fresh-server balances, no zero overwrite after failed/corrupt loads, cross-server lease, stale writer denial, in-flight revision, disconnect retry and shutdown")
local WalletStore=newStore()
'''
wallet=(root/'src/server/Services/EconomyService.luau').read_text().replace('local R=require(game:GetService("ReplicatedStorage").Shared.EconomyRules)','local R=MoneyRules').replace('local Store=require(script.Parent.MoneyStore)','local Store=WalletStore')
s+='\nlocal Wallet=(function()\n'+wallet+'\nend)()\n'
s+='''
Wallet.Start();assert(a:GetAttribute("MoneyReady")==true and Wallet.Credit(a,235))
a:SetAttribute("Money",999999);assert(Wallet.Balance(a)==235,"display attribute cannot change authoritative money")
Wallet.Reset(a);assert(Wallet.Balance(a)==235 and a:GetAttribute("Money")==235,"fresh character never wipes account")
a:SetAttribute("Knockout",true);a:LoadCharacterAsync();assert(Wallet.Balance(a)==235)
Players.PlayerRemoving:Fire(a);a.Parent=nil
assert(MoneyDatabase["User_"..a.UserId].Balance==235 and not MoneyDatabase["User_"..a.UserId].Lease)
local again=player(a.UserId);Players.PlayerAdded:Fire(again)
assert(again:GetAttribute("MoneyReady")==true and again:GetAttribute("Money")==235,"rejoin restores durable money")
Wallet.Reset(again);assert(Wallet.Balance(again)==235)
assert(Wallet.Credit(b,100))
assert(not Wallet.Transfer(b,20001,10,function() return false end))
assert(Wallet.Balance(b)==100 and not MoneyDatabase.User_20001.Lease,"failed item transfer charges nothing and releases offline account")
assert(Wallet.Transfer(b,20001,10) and Wallet.Balance(b)==90 and MoneyDatabase.User_20001.Balance==10 and not MoneyDatabase.User_20001.Lease,"offline seller payment is persisted and unlocked")
MoneyCloseHandlers[#MoneyCloseHandlers]()
assert(MoneyDatabase["User_"..again.UserId].Balance==235)
local nextServer=newStore();assert(nextServer.Open(again.UserId).Balance==235)
print("PASS: actual economy restores account money, preserves it through character reset/death/rejoin, protects authority, persists offline payments and flushes on shutdown")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'money.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
