"""Exercise PvP music timers, affiliations and lifecycle through the real server script."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'tests/fixtures/town_mock.luau').read_text()
for name,path in [('Config','src/shared/AmbientConfig.luau'),('Affiliation','src/shared/AffiliationRules.luau')]:
 s+='\nlocal '+name+'=(function()\n'+(root/path).read_text()+'\nend)()'
s+='''
local callback
local Damage={OnPlayerDamage=function(fn) callback=fn end}
local relation="Neutral"
local Towns={RelationBetween=function() return relation end}
for _,p in ipairs(Players:GetPlayers()) do
 p.CharacterRemoving=event();p:LoadCharacterAsync();p.Character.Humanoid.HealthChanged=event()
end
'''
source=(root/'src/server/Ambient.server.luau').read_text()
source=re.sub(r'local (Damage|Towns|Affiliation|Config)=require\([^\n]+\)\n','',source)
s+='\n'+source+'\n'
s+='''
assert(callback)
assert(a:GetAttribute("TerritoryResolved")==false)
callback(a,b,5)
assert(a:GetAttribute("BattleAmbientUntil")==clock+30 and b:GetAttribute("BattleAmbientUntil")==clock+30)
assert(c:GetAttribute("BattleAmbientUntil")==nil,"bystanders are unaffected")
clock+=10;callback(a,b,1)
assert(a:GetAttribute("BattleAmbientUntil")==clock+30,"real PvP hit refreshes deadline")
local deadline=a:GetAttribute("BattleAmbientUntil")
clock+=1;relation="Ally";callback(a,b,5)
assert(a:GetAttribute("BattleAmbientUntil")==deadline,"allied cities never refresh music")
relation="War";callback(a,b,5);assert(a:GetAttribute("BattleAmbientUntil")==clock+30)
deadline=a:GetAttribute("BattleAmbientUntil");clock+=1
for _,attr in ipairs({"TeamID","GroupID"}) do
 a:SetAttribute(attr,7);b:SetAttribute(attr,7);callback(a,b,5)
 assert(a:GetAttribute("BattleAmbientUntil")==deadline,attr.." friendlies ignored")
 a:SetAttribute(attr,nil);b:SetAttribute(attr,nil)
end
callback(a,a,5);callback(a,b,0);assert(a:GetAttribute("BattleAmbientUntil")==deadline)
a.Character:SetAttribute("Knockout",true);assert(a:GetAttribute("BattleAmbientUntil")==nil)
callback(a,b,5);assert(a:GetAttribute("BattleAmbientUntil")==nil and b:GetAttribute("BattleAmbientUntil")==clock+30)
b.CharacterRemoving:Fire(b.Character)
assert(b:GetAttribute("BattleAmbientUntil")==nil and b:GetAttribute("TerritoryResolved")==false)
print("PASS: neutral/war PvP sets both timers; allies, groups, same team, self and zero damage excluded; refresh, bystander isolation and KO/removal cleanup")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'ambient.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
