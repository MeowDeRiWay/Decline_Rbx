from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/PlayerLifeService.luau').read_text()
s=s[s.index('function Service.Damage('):s.rindex('return Service')]
mock='''
local finished={}
local Service={}
local roll=.1
local math=table.clone(math);math.random=function() return roll end
local player={GetAttribute=function() return .5 end}
local character={GetAttribute=function() return nil end}
local hp={Health=100,Parent=character}
'''
cases='''
assert(Service.Damage(player,hp,10)==0 and hp.Health==100,"environmental damage can be dodged")
roll=.8;assert(Service.Damage(player,hp,10)==10 and hp.Health==90)
roll=.1;assert(Service.Damage(player,hp,10,true)==10 and hp.Health==80,"combat precheck is not rolled twice")
print("PASS: actual PlayerLife environmental dodge and combat bypass")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'environment.luau';p.write_text(mock+s+cases);subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
