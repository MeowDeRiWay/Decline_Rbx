"""Exercise model overrides and clocked reload hand/weapon targets."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path): return '(function()\n'+(root/path).read_text()+'\nend)()'
s=(root/'tests/rig_math.fixture.luau').read_text()
s+="\nlocal Presentation="+module('src/shared/WeaponPresentation.luau')
s+="\nlocal Reload="+module('src/shared/ReloadPose.luau')
s+="\nlocal Items="+module('src/shared/ItemConfig.luau')+".Items"
s+=r'''
function cm.__sub(frame,v) return cf(frame.Position-v,frame.R) end
local attrs={}
local held={GetAttribute=function(_,key) return attrs[key] end,FindFirstChild=function() end}
for id,expected in pairs({Pistol9mm="Pistol",PipePistol9mm="SingleRound",PipeRifle9mm="SingleRound",Rifle223="SingleRound",LSW223="Bullpup",MarksmanRifle223="Bullpup",MarksmanRifle308="AR",MachineGun308="AR",AT4="Rocket",IronKnife="None"}) do
 assert(Items[id],id)
 assert(Presentation.ReloadType(held,Items[id],id)==expected,id)
end
attrs.AnimationSet="Pistol";attrs.ReloadType="Bullpup"
assert(Presentation.AnimationSet(held,Items.AT4)=="Pistol")
assert(Presentation.ReloadType(held,Items.AT4,"AT4")=="Bullpup")
attrs.AnimationSet="typo";attrs.ReloadType=12
assert(Presentation.AnimationSet(held,Items.AT4)=="Launcher")
assert(Presentation.ReloadType(held,Items.AT4,"AT4")=="Rocket")
attrs.AnimationSet=nil;attrs.ReloadType=nil
assert(Presentation.AnimationSet(nil,{Slot="Medicine"})==nil)
local attributes={Reloading=true,ReloadItemID="AT4",ReloadStartedAt=10,ReloadDuration=4,ReloadVisualType="Rocket",ReloadRoundCount=1}
local c={GetAttribute=function(_,key) return attributes[key] end}
attrs.Item_ID="AT4"
local root={CFrame=CFrame.new(3,2,1)*CFrame.Angles(0,.8,0)}
local rest=CFrame.new(.3,.6,.1)*CFrame.Angles(0,.3,0)
local motor={Part1={CFrame=root.CFrame*rest},C0=rest,C1=CFrame.identity,GetAttribute=function() return rest end}
local function near(a,b) assert((a-b).Magnitude<1e-6) end
for _,kind in ipairs({"Pistol","AR","Bullpup","SingleRound","Rocket"}) do
 attributes.ReloadVisualType=kind;attributes.ReloadRoundCount=5
 for _,t in ipairs({0,.15,.3,.5,.7,.9,.99999}) do
  local world,right,left=Reload.Apply(c,root,held,motor,10+4*t)
  assert(world and right.X==right.X and left.Y==left.Y,kind)
  near((root.CFrame*motor.C0*motor.Transform).Position,world.Position)
 end
 near(Reload.Frame(kind,rest,0).Position,rest.Position)
 near(Reload.Frame(kind,rest,1).Position,rest.Position)
 assert(Reload.Apply(c,root,held,motor,14)==nil,"expired reload must release the weapon")
end
attributes.ReloadVisualType="Rocket"
local world,right,left=Reload.Apply(c,root,held,motor,12)
assert((root.CFrame:ToObjectSpace(world)).Position.Y<rest.Position.Y-.4,"rocket tube lowers before rear loading")
attributes.ReloadVisualType="Bullpup";local _,_,bullpup=Reload.Apply(c,root,held,motor,12)
attributes.ReloadVisualType="AR";local _,_,front=Reload.Apply(c,root,held,motor,12)
assert((front-bullpup).Magnitude>.3,"bullpup reaches behind the front magazine position")
attributes.Reloading=false;assert(Reload.Apply(c,root,held,motor,12)==nil,"cancelled reload has no pose")
attributes.Reloading=true;attrs.Item_ID="Other";assert(Reload.Apply(c,root,held,motor,12)==nil,"late reload cannot pose a replacement weapon")
attrs.Item_ID="AT4";attributes.ReloadVisualType="None";assert(Reload.Apply(c,root,held,motor,12)==nil)
print("PASS: model overrides, invalid/missing defaults, rocket lower/rear-load/return, distinct magazine positions, cancellation and replacement guards")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'presentation.luau';p.write_text(s)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
