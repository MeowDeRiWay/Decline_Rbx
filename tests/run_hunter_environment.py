from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/PlayerLifeService.luau').read_text()
s=s[s.index('function Service.Damage('):s.rindex('return Service')]
s='local Defense=(function()\n'+(root/'src/shared/DefenseRules.luau').read_text()+'\nend)()\n'+s
mock='''
local finished={}
local Service={}
local roll=.1
local math=table.clone(math);math.random=function() return roll end
local player={GetAttribute=function(_,key) return key=="DodgeChance" and 50 or 0 end}
local character={GetAttribute=function() return nil end}
local hp={Health=100,Parent=character}
'''
cases='''
assert(Service.Damage(player,hp,10)==0 and hp.Health==100,"environmental damage can be dodged")
roll=.8;assert(Service.Damage(player,hp,10)==10 and hp.Health==90)
roll=.1;assert(Service.Damage(player,hp,10,true)==10 and hp.Health==80,"combat precheck is not rolled twice")
local original=player.GetAttribute
function player:GetAttribute(key)
 if key=="ArmorResistance" then return .2 elseif key=="ArmorAbsorption" then return 3 end
 return original(self,key)
end
assert(Service.Damage(player,hp,20,true)==13,"unprocessed incoming damage gets defense once")
assert(Service.Damage(player,hp,20,true,true)==20,"combat-preprocessed defense is not applied twice")
local baseGet=player.GetAttribute
function player:GetAttribute(key) if key=="AttributesConfirmed" then return false end return baseGet(self,key) end
local before=hp.Health;assert(Service.Damage(player,hp,999,true,true)==0 and hp.Health==before,"creation immunity also covers direct survival damage")
print("PASS: actual PlayerLife environmental dodge, defense order and no double defense/dodge")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'environment.luau';p.write_text(mock+s+cases);subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
