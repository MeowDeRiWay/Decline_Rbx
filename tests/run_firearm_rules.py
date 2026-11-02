from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
mock=(root/'tests/city_geometry.fixture.luau').read_text()
rules=(root/'src/shared/FirearmRules.luau').read_text()
cases='''
assert(Rules.RocketYaw(.9,.1,1)==0,"successful aim keeps the initial direction")
assert(Rules.RocketYaw(.1,.5,1)>Rules.RocketYaw(.8,.9,1),"poor chance widens deviation")
assert(math.abs(Rules.RocketYaw(0,1,-1)+math.rad(5))<1e-9,"deviation is bounded to5 degrees")
assert(Rules.BoxCount(50,0)==50 and Rules.BoxCount(50,.99999)==50)
assert(Rules.BoxCount(-1,.5)==nil and Rules.BoxCount(0/0,.5)==nil)
assert(Rules.AmmoID("223","FMJ")=="Ammo223FMJ" and Rules.AmmoID("223","AP")=="Ammo223AP")
assert(not Rules.AmmoID("355","FMJ") and not Rules.AmmoID("223","FJM"))
assert(Rules.AmmoID("9mm","FMJ")=="Ammo9mmFMJ" and Rules.AmmoID("308","AP")=="Ammo308AP")
local origin=Vector3.new(0,0,-2)
local frame=CFrame.new(Vector3.new(0,0,0))
local a,b=Rules.Interval(origin,Vector3.new(0,0,1),frame,Vector3.new(2,3,.1))
assert(math.abs((b-a)-.1)<1e-6,"real thin wall thickness")
local _,angled=Rules.Interval(Vector3.new(-1.41421356,0,-1.41421356),Vector3.new(1/math.sqrt(2),0,1/math.sqrt(2)),frame,Vector3.new(4,3,.1))
local x,y=Rules.Interval(Vector3.new(-1.41421356,0,-1.41421356),Vector3.new(1/math.sqrt(2),0,1/math.sqrt(2)),frame,Vector3.new(4,3,.1))
assert(math.abs(y-x-.1*math.sqrt(2))<1e-6,"oblique path longer")
local merged=Rules.Merge({{.05,.1},{0,.05},{.025,.075},{.3,.4}})
assert(#merged==2 and merged[1][1]==0 and merged[1][2]==.1,"contiguous/overlapping layers counted once, gaps preserved")
assert(math.abs(Rules.Cost("Brick",.1,"223")-180.1)<1e-6)
assert(Rules.Cost("Brick",.1,"9mm")==math.huge and Rules.Cost("Concrete",.1,"223")==math.huge)
assert(Rules.Cost("Concrete",.1,"308")<450)
assert(Rules.Cost("Wood",.1,"AP")==Rules.Cost("Wood",.1,"FMJ"))
assert(Rules.Cost("Unknown",.1,"AP")==math.huge)
for _,case in ipairs({{"223","FMJ",0,.2},{"223","AP",3,.2},{"308","FMJ",0,.4},{"308","AP",6,.4},{"9mm","FMJ",0,.05},{"9mm","AP",2,.1}}) do
 local absorption,resistance=Rules.ArmorIgnore(case[1],case[2]);assert(absorption==case[3] and resistance==case[4])
end
print("PASS: full ammo boxes, invalid caliber/type, thin/angled wall intervals, layer union/no double counting, caliber material gates and armor ignore, unknown stops")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'rules.luau';p.write_text(mock+'\nlocal Rules=(function()\n'+rules+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
